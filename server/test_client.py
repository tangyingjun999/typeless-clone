import asyncio, json, sys, websockets

async def main(uri):
    async with websockets.connect(uri) as ws:
        # 480ms 静音 PCM16 16k
        for _ in range(15):
            await ws.send(b"\x00\x00" * 512)
            await asyncio.sleep(0.02)
        await ws.send(json.dumps({"type": "finish"}))
        while True:
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=8)
            except Exception as e:
                print("RECV-END", type(e).__name__); break
            print("GOT", msg)
            if '"final"' in msg:
                break

asyncio.run(main(sys.argv[1] if len(sys.argv) > 1 else "ws://127.0.0.1:8080/ws/stream"))
