from functools import lru_cache

from . import telemetry

telemetry.setup()  # must run before LangChain/LangGraph are imported

from fastapi import FastAPI  # noqa: E402
from pydantic import BaseModel  # noqa: E402

from .graph import build_agent  # noqa: E402

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
