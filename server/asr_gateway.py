"""
ASR 网关：键盘扩展 --WSS--> 这里 --> 云识别

只依赖 websockets（其余用标准库），可直接 python 跑起来。

协议
  C->S  二进制帧   PCM16LE / 16kHz / 单声道
  C->S  文本帧     {"type":"finish"}
  S->C  文本帧     {"type":"partial","text":"..."} / {"type":"final","text":"..."}

provider
  mock      不联网，返回固定文本（联调）
  openai    Whisper，攒到 finish 一次性转写（标准库发请求）
  deepgram  真流式，边收边出（推荐，延迟最低）

运行
  pip install websockets
  ASR_PROVIDER=mock python asr_gateway.py            # 0.0.0.0:8080
  ASR_PROVIDER=deepgram DEEPGRAM_API_KEY=xx python asr_gateway.py
"""

import asyncio
import io
import json
import os
import ssl
import urllib.request
import wave

import websockets

PROVIDER = os.getenv("ASR_PROVIDER", "mock").lower()
OPENAI_KEY = os.getenv("OPENAI_API_KEY", "")
DEEPGRAM_KEY = os.getenv("DEEPGRAM_API_KEY", "")
AUTH_TOKEN = os.getenv("ASR_TOKEN", "")
PORT = int(os.getenv("PORT", "8080"))
MAX_SECONDS = 120


def _headers(ws):
    """兼容不同 websockets 版本取请求头"""
    obj = getattr(ws, "request_headers", None)
    if obj is not None:
        return obj
    req = getattr(ws, "request", None)
    if req is not None:
        return getattr(req, "headers", {}) or {}
    return getattr(ws, "headers", {}) or {}


def _authorized(ws):
    if not AUTH_TOKEN:
        return True
    h = _headers(ws)
    try:
        if h.get("authorization") == "Bearer " + AUTH_TOKEN:
            return True
    except Exception:
        pass
    path = getattr(ws, "path", "") or ""
    if "token=" + AUTH_TOKEN in path:
        return True
    return False


def pcm_to_wav(pcm: bytes) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(16000)
        w.writeframes(pcm)
    return buf.getvalue()


def _post_multipart(url, headers, fields, file_field, filename, filedata, mime):
    boundary = "----tlbboundary7c3f"
    body = io.BytesIO()
    for k, v in fields.items():
        body.write(("--" + boundary + "\r\n").encode())
        body.write(('Content-Disposition: form-data; name="%s"\r\n\r\n' % k).encode())
        body.write(str(v).encode() + b"\r\n")
    body.write(("--" + boundary + "\r\n").encode())
    body.write(('Content-Disposition: form-data; name="%s"; filename="%s"\r\n'
                % (file_field, filename)).encode())
    body.write(("Content-Type: %s\r\n\r\n" % mime).encode())
    body.write(filedata + b"\r\n")
    body.write(("--" + boundary + "--\r\n").encode())

    data = body.getvalue()
    h = dict(headers)
    h["Content-Type"] = "multipart/form-data; boundary=" + boundary
    req = urllib.request.Request(url, data=data, headers=h, method="POST")
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8", "ignore"))


class Session:
    def __init__(self, ws):
        self.ws = ws
        self.pcm = bytearray()
        self.finished = asyncio.Event()
        self.final_sent = False

    async def emit(self, kind, text):
        if self.final_sent:
            return
        await self.ws.send(json.dumps({"type": kind, "text": text}, ensure_ascii=False))
        if kind == "final":
            self.final_sent = True

    # ---------- providers ----------

    async def run_mock(self):
        await self.emit("partial", "你好")
        await asyncio.sleep(0.3)
        await self.emit("final", "你好，这是一段测试文字。")

    async def run_openai(self):
        await self.finished.wait()
        if not self.pcm:
            await self.emit("final", "")
            return
        wav = pcm_to_wav(bytes(self.pcm))
        loop = asyncio.get_event_loop()
        try:
            res = await loop.run_in_executor(
                None,
                lambda: _post_multipart(
                    "https://api.openai.com/v1/audio/transcriptions",
                    {"Authorization": "Bearer " + OPENAI_KEY},
                    {"model": "whisper-1", "language": "zh"},
                    "file", "a.wav", wav, "audio/wav",
                ),
            )
            text = (res.get("text") or "").strip()
        except Exception as e:  # noqa: BLE001
            text = ""
            await self.emit("partial", "[识别失败] " + str(e)[:60])
        await self.emit("final", text)

    async def run_deepgram(self):
        url = ("wss://api.deepgram.com/v1/listen"
               "?encoding=linear16&sample_rate=16000&channels=1"
               "&language=zh-CN&interim_results=true&punctuate=true")
        headers = {"Authorization": "Token " + DEEPGRAM_KEY}
        ssl_ctx = ssl.create_default_context()
        async with websockets.connect(url, additional_headers=headers, ssl=ssl_ctx) as dg:

            async def pump():
                while True:
                    if self.pcm:
                        chunk = bytes(self.pcm[:6400])
                        del self.pcm[:6400]
                        try:
                            await dg.send(chunk)
                        except Exception:
                            return
                    await asyncio.sleep(0.05)

            async def reader():
                async for raw in dg:
                    try:
                        msg = json.loads(raw)
                    except Exception:
                        continue
                    alt = (msg.get("channel", {}).get("alternatives") or [{}])[0]
                    text = alt.get("transcript", "")
                    if not text:
                        continue
                    await self.emit("partial", text)
                    if msg.get("speech_final"):
                        await self.emit("final", text)
                        return

            tasks = [asyncio.create_task(pump()), asyncio.create_task(reader())]
            await self.finished.wait()
            await asyncio.sleep(0.8)
            for t in tasks:
                t.cancel()
            if not self.final_sent:
                await self.emit("final", "")


async def handler(ws, path=None):
    if not _authorized(ws):
        try:
            await ws.close(code=4401, reason="unauthorized")
        except Exception:
            pass
        return

    sess = Session(ws)
    runner = {
        "mock": sess.run_mock,
        "openai": sess.run_openai,
        "deepgram": sess.run_deepgram,
    }.get(PROVIDER, sess.run_mock)
    task = asyncio.create_task(runner())
    total = 0

    try:
        async for msg in ws:
            if isinstance(msg, (bytes, bytearray)):
                if total < 16000 * 2 * MAX_SECONDS:
                    sess.pcm.extend(msg)
                    total += len(msg)
                continue
            try:
                data = json.loads(msg)
            except Exception:
                continue
            if data.get("type") == "finish":
                sess.finished.set()
                break
    except Exception:
        pass
    finally:
        sess.finished.set()
        try:
            await asyncio.wait_for(task, timeout=30)
        except Exception:
            pass
        try:
            await ws.close()
        except Exception:
            pass


async def main():
    print("ASR gateway provider=%s port=%d auth=%s"
          % (PROVIDER, PORT, "on" if AUTH_TOKEN else "off"), flush=True)
    async with websockets.serve(handler, "0.0.0.0", PORT, max_size=2 * 1024 * 1024):
        await asyncio.Future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
