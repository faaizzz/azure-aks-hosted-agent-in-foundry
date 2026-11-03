import os

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from langchain_openai import AzureChatOpenAI
from langgraph.prebuilt import create_react_agent

from .tools import TOOLS

SYSTEM_PROMPT = (
    "You are a helpful travel planning assistant. Use the tools to look up flights, "
    "hotels and weather, then give a concise day-by-day plan with an estimated total cost. "
    "Never ask clarifying questions: assume sensible defaults (e.g. mid-month dates, one traveller, "
    "the main airport), state your assumptions briefly, and always call the tools first."
)


def build_agent():
    # In AKS, workload identity injects AZURE_CLIENT_ID/TENANT_ID/FEDERATED_TOKEN_FILE;
    # locally this falls back to `az login`. No API keys are used.
    token_provider = get_bearer_token_provider(
        DefaultAzureCredential(), "https://cognitiveservices.azure.com/.default"
    )
    llm = AzureChatOpenAI(
        azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
        azure_deployment=os.environ["AZURE_OPENAI_DEPLOYMENT"],
        api_version=os.environ.get("AZURE_OPENAI_API_VERSION", "2025-04-01-preview"),
        azure_ad_token_provider=token_provider,
    )
    return create_react_agent(llm, TOOLS, prompt=SYSTEM_PROMPT)
