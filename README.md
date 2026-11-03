# azure-aks-hosted-agent-in-foundry

A sample LangGraph travel agent running on a minimum-cost AKS cluster and calling a model deployed in Azure AI Foundry. **Everything is managed by Terraform** (infra, image build, Kubernetes objects, Foundry registration).

```
infra/    Terraform: RG, ACR, AKS (Free tier, 1x B2s), Foundry account + project + gpt-5-mini,
          workload identity, App Insights, image build (az acr build), K8s resources,
          Foundry external-agent registration
agent/    FastAPI + LangGraph agent (mock flight/hotel/weather tools) + OpenTelemetry
scripts/  stop.sh / start.sh: AKS off/on; register_external_agent.py: run by Terraform
Makefile  Shortcuts for everything below
```

Auth is keyless: the pod uses AKS workload identity -> Entra ID -> `Cognitive Services OpenAI User` on the Foundry account.

## Prerequisites
`az` (logged in: `az login`), `terraform`, `kubectl`, `make`, `uv`, `python3`.
Set your subscription in `infra/terraform.tfvars`. The region defaults to `eastus2` (`var.location`); a `TF_VAR_location` exported in your shell overrides it.

## Make targets
Run `make help` for the live list. Add `AUTO=1` to skip Terraform's confirmation prompt.

| Target | What it does |
|---|---|
| `make init` | `terraform init` |
| `make fmt` | `terraform fmt -recursive` |
| `make validate` | `terraform validate` |
| `make plan` | `terraform plan` |
| `make apply` | Create/update everything: infra, image build, K8s deployment, Foundry registration |
| `make output` | Show Terraform outputs |
| `make destroy` | Destroy **all** resources. Starts AKS first if stopped, then removes stale kubeconfig entries |
| `make creds` | Fetch the AKS kubeconfig |
| `make status` | Show nodes, pods and services |
| `make logs` | Tail the agent logs |
| `make aks-status` | Show AKS power state (`Running` / `Stopped`) |
| `make stop` | Stop AKS (deallocate the node to save cost) |
| `make start` | Start AKS |
| `make port-forward` | Forward the agent service to `localhost:$(PORT)` (default 8080); keep it running |
| `make chat MSG="..."` | Send a message to the agent (needs `port-forward` in another terminal) |

Variables: `AUTO=1`, `PORT=8080`, `MSG="..."`.

## Deploy and try it
```
az login
make apply
make creds
make port-forward          # terminal 1
make chat MSG="Plan a 3-day trip to Lisbon from London in June"   # terminal 2
```
Changing anything under `agent/` and re-running `make apply` rebuilds the image and rolls out the Deployment.

## Onboard to Foundry (external agent, preview)
The agent keeps running on AKS; Foundry stores only a registration record and reads its traces. `make apply` does all of it:
1. Creates a Foundry **project** plus Log Analytics + **Application Insights**, connected to the project.
2. The agent emits OpenTelemetry GenAI spans (`gen_ai.agent.id = travel-planner-agent-v1`) to App Insights (`agent/app/telemetry.py`).
3. `terraform_data.register_external_agent` registers `travel-planner-agent` via the Foundry SDK (needs `uv` and your `az login`; your user gets the *Foundry User* role on the project).

View it in the [Foundry portal](https://ai.azure.com) (new portal): project `travel-agents` > Build > Agents > `travel-planner-agent` > Traces. Traces appear 2-5 min after a chat call.

### Limitations
- External agents are **not invokable from Foundry**: no playground chat, and the project's Responses endpoint returns `Agent kind 'external' is not supported`. Test via `make chat`.
- Not publishable to Teams / Microsoft 365 Copilot from Foundry (publishing needs a Foundry-hosted agent endpoint). Options: your own Azure Bot Service channel in front of the AKS agent, or a Foundry hosted agent.
- No human evaluation, trace-to-dataset, or red teaming for external agents.

## Cost (list prices, 730 h/month, excluding tokens)
| Item | Running | Stopped (`make stop`) |
|---|---|---|
| `Standard_B2s` node | ~$30 | $0 |
| 32 GB OS disk | ~$5 | ~$5 |
| Standard load balancer (outbound) | ~$18 | ~$18 (assumed; unverified) |
| Static public IP | ~$4 | ~$4 |
| ACR Basic | ~$5 | ~$5 |
| Log Analytics / App Insights (capped at 0.1 GB/day) | ~$0 | ~$0 |
| **Total** | **~$62** | **~$32** |

Model usage (`gpt-5-mini`, pay per token) is roughly $0.01-0.02 per chat call. `make destroy` brings everything to $0.
