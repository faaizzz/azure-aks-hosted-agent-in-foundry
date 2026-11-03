from functools import lru_cache

from fastapi import FastAPI
from pydantic import BaseModel

from .graph import build_agent

app = FastAPI(title="travel-agent")


class ChatRequest(BaseModel):
    message: str


@lru_cache(maxsize=1)
def get_agent():
    return build_agent()


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.post("/chat")
def chat(req: ChatRequest):
    result = get_agent().invoke({"messages": [("user", req.message)]})
    msgs = result["messages"]
    tools_used = [t["name"] for m in msgs for t in (getattr(m, "tool_calls", None) or [])]
    return {"reply": msgs[-1].content, "tools_used": tools_used}
