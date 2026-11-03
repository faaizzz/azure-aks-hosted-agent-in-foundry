"""Register / unregister the AKS-hosted agent in Foundry as an *external agent* (preview).

Usage: register_external_agent.py {create|delete}
Env:   FOUNDRY_PROJECT_ENDPOINT, AGENT_NAME, OTEL_AGENT_ID, AGENT_DESCRIPTION
Run via `uv run --with 'azure-ai-projects>=2.3.0' --with azure-identity` (see infra/register.tf).
"""
import os
import sys

from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import ExternalAgentDefinition
from azure.identity import DefaultAzureCredential

action = sys.argv[1] if len(sys.argv) > 1 else "create"
name = os.environ["AGENT_NAME"]

project = AIProjectClient(
    endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"],
    credential=DefaultAzureCredential(),
    allow_preview=True,  # sends Foundry-Features: ExternalAgents=V1Preview
)

if action == "create":
    agent = project.agents.create_version(
        agent_name=name,
        description=os.environ.get("AGENT_DESCRIPTION", ""),
        definition=ExternalAgentDefinition(otel_agent_id=os.environ["OTEL_AGENT_ID"]),
    )
    print(f"Registered external agent: {agent.name}")
    print(f"Resolved otel_agent_id: {agent.definition.otel_agent_id}")
elif action == "delete":
    try:
        project.agents.delete(agent_name=name, force=True)
        print(f"Deleted external agent registration: {name}")
    except Exception as exc:  # already gone / project gone: don't block destroy
        print(f"Skipping delete ({exc})")
else:
    sys.exit(f"unknown action {action}")
