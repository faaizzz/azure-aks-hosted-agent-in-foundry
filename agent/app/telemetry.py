"""OpenTelemetry setup so Foundry can show this agent's traces (external agent).

Must run before LangChain/LangGraph are imported. No-op when
APPLICATIONINSIGHTS_CONNECTION_STRING is unset (e.g. local runs).
"""
import os


def setup() -> None:
    conn = os.environ.get("APPLICATIONINSIGHTS_CONNECTION_STRING")
    if not conn:
        return

    os.environ.setdefault("AZURE_EXPERIMENTAL_ENABLE_GENAI_TRACING", "true")
    os.environ.setdefault("OTEL_SEMCONV_STABILITY_OPT_IN", "gen_ai_latest_experimental")
    os.environ.setdefault("OTEL_INSTRUMENTATION_GENAI_CAPTURE_MESSAGE_CONTENT", "SPAN_AND_EVENT")

    from microsoft.opentelemetry import use_microsoft_opentelemetry

    agent_name = os.environ.get("AGENT_NAME", "travel-planner-agent")
    use_microsoft_opentelemetry(
        enable_azure_monitor=True,
        azure_monitor_connection_string=conn,
        sampling_ratio=1.0,
        instrumentation_options={
            "fastapi": {"enabled": False},
            "langchain": {
                "enabled": True,
                # Foundry matches traces to the registration by this gen_ai.agent.id.
                "agent_id": os.environ.get("OTEL_AGENT_ID", f"{agent_name}-v1"),
                "agent_name": agent_name,
            },
        },
    )
