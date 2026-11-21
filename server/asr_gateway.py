"""
ASR 网关：键盘扩展 --WSS--> 这里 --> 云 ASR

协议（与 ios/Keyboard/StreamingASR.swift 对应）
  C->S  二进制帧: PCM16LE / 16kHz / 单声道
  C->S  文本帧: {"type":"finish"}
  S->C  文本帧: {"type":"partial","text":"..."} / {"type":"final","text":"..."}

provider 可切换：
  mock      —— 不联网，2 秒后返回固定文本（本地联调用）
  openai    —— Whisper（把整段音频攒起来一次性转写，伪流式）
  deepgram  —— Deepgram 真流式（延迟最低，推荐）

运行：
  pip install fastapi uvicorn websockets httpx
  ASR_PROVIDER=mock uvicorn asr_gateway:app --host 0.0.0.0 --port 8080
  生产要挂在 TLS 后面（wss://），可用 Caddy/Nginx 反代。
"""
import asyncio, json, os, audioop, base64, io, wave
from fastapi import FastAPI, WebSocket, WebSocketDisconnect

PROVIDER = os.getenv("ASR_PROVIDER", "mock")
OPENAI_KEY = os.getenv("OPENAI_API_KEY", "")
DEEPGRAM_KEY = os.getenv("DEEPGRAM_API_KEY", "")
AUTH_TOKEN = os.getenv("ASR_TOKEN", "")          # 简单 Bearer 校验，留空则不校验

app = FastAPI(title="typeless-clone ASR gateway")


class Session:
    """攒 PCM，出结果"""

    def __init__(self, ws: WebSocket):
        self.ws = ws
        self.pcm = bytearray()
        self.finished = asyncio.Event()
        self.final_sent = False

    async def emit(self, kind: str, text: str):
        if self.final_sent and kind != "final":
            return
        await self.ws.send_text(json.dumps({"type": kind, "text": text}, ensure_ascii=False))
        if kind == "final":
            self.final_sent = True

    # ---------- 各 provider ----------

    async def run_mock(self):
        await self.emit("partial", "你好")
        await asyncio.sleep(0.4)
        await self.emit("final", "你好，这是一段测试文字。")

    async def run_openai(self):
        """Whisper：攒到 finish 再一次性转写，中间用假 partial 占位"""
        await self.finished.wait()
        import httpx
        # PCM16 -> WAV
        buf = io.BytesIO()
        with wave.open(buf, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(16000)
            w.writeframes(bytes(self.pcm))
        buf.seek(0)
        async with httpx.AsyncClient(timeout=60) as cli:
            r = await cli.post(
                "https://api.openai.com/v1/audio/transcriptions",
                headers={"Authorization": f"Bearer {OPENAI_KEY}"},
                files={"file": ("a.wav", buf, "audio/wav")},
                data={"model": "whisper-1", "language": "zh"},
            )
        text = ""
        if r.status_code == 200:
            text = r.json().get("text", "")
        else:
            text = f"[ASR 失败 {r.status_code}]"
        await self.emit("final", text.strip())

    async def run_deepgram(self):
        """Deepgram 真流式：边收边转，partial 实时回显"""
        import websockets
        url = ("wss://api.deepgram.com/v1/listen"
               "?encoding=linear16&sample_rate=16000&channels=1"
               "&language=zh-CN&interim_results=true&punctuate=true")
        async with websockets.connect(url, extra_headers={"Authorization": f"Token {DEEPGRAM_KEY}"}) as dg:

            async def pump():
                while True:
                    try:
                        await dg.send(bytes(self.pcm))
                    except Exception:
                        return
                    self.pcm.clear()
                    await asyncio.sleep(0.05)

            async def read():
                async for raw in dg:
                    msg = json.loads(raw)
                    alt = msg.get("channel", {}).get("alternatives", [{}])[0]
                    text = alt.get("transcript", "")
                    if not text:
                        continue
                    await self.emit("partial" if not msg.get("is_final") else "partial", text)
                    if msg.get("speech_final") or msg.get("is_final"):
                        await self.emit("final", text)

            pump_task = asyncio.create_task(pump())
            read_task = asyncio.create_task(read())
            await self.finished.wait()
            await asyncio.sleep(0.6)
            pump_task.cancel(); read_task.cancel()
            if not self.final_sent:
                await self.emit("final", "")


@app.websocket("/ws/stream")
async def stream(ws: WebSocket):
    await ws.accept()
    if AUTH_TOKEN:
        hdr = ws.headers.get("authorization", "")
        if hdr != f"Bearer {AUTH_TOKEN}":
            await ws.close(code=4401)
            return

    sess = Session(ws)
    runner = {"mock": sess.run_mock, "openai": sess.run_openai, "deepgram": sess.run_deepgram}.get(PROVIDER, sess.run_mock)
    task = asyncio.create_task(runner())
    try:
        while True:
            msg = await ws.receive()
            if msg.get("bytes"):
                sess.pcm.extend(msg["bytes"])
            elif msg.get("text"):
                data = json.loads(msg["text"])
                if data.get("type") == "finish":
                    sess.finished.set()
                    break
    except WebSocketDisconnect:
        pass
    finally:
        sess.finished.set()
        try:
            await asyncio.wait_for(task, timeout=20)
        except Exception:
            pass
        try:
            await ws.close()
        except Exception:
            pass


@app.get("/healthz")
async def health():
    return {"ok": True, "provider": PROVIDER}
