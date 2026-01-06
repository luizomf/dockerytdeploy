import asyncio
import socket

import uvloop
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
async def root() -> str:
  loop = asyncio.get_event_loop()

  if isinstance(loop, uvloop.loop.Loop):
    return f"D0001 0004 (FROM ACTION): {socket.gethostname()}"

  return socket.gethostname()


@app.get("/health")
async def health_check() -> dict[str, str]:
  return {"status": "healthy"}
