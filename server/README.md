# ASR 网关

键盘把 16k PCM 推上来，这里转发给云 ASR，出 partial/final。

## 本地联调（不需要任何 key）

```bash
pip install fastapi uvicorn websockets httpx
ASR_PROVIDER=mock uvicorn asr_gateway:app --port 8080
```
然后用 `wscat` 或直接让键盘连 `ws://<你的电脑IP>:8080/ws/stream`：
按住说话 → 800ms 后应看到「你好，这是一段测试文字。」

## 接到真实识别

| provider | 需要 | 特点 |
|---|---|---|
| `deepgram` | `DEEPGRAM_API_KEY` | 真流式，partial 实时，延迟最低，**推荐** |
| `openai` | `OPENAI_API_KEY` | whisper-1，松手后一次性转写，简单稳 |
| `mock` | 无 | 固定文本，联调用 |

```bash
ASR_PROVIDER=deepgram DEEPGRAM_API_KEY=xxx ASR_TOKEN=你的口令 uvicorn asr_gateway:app --port 8080
```

## 上生产

必须走 TLS（iOS 的 ATS 不允许明文 ws）：
```
Caddy:  asr.example.com { reverse_proxy 127.0.0.1:8080 }
```
键盘里把 `AppConfig.asrBaseURL` 改成 `wss://asr.example.com/ws/stream`。

## 已知取舍

- `openai` 模式不是真流式，用户要等到松手后 1-3 秒才出字
- `deepgram` 的 `zh-CN` 中文标点偶尔断句偏碎，可用 `smart_format=true` 改善
