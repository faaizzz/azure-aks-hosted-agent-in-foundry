# azure-aks-hosted-agent-in-foundry

A sample LangGraph travel agent running on a minimum-cost AKS cluster and calling a model deployed in Azure AI Foundry. **Everything is managed by Terraform** (infra, image build, Kubernetes objects).

```
infra/    Terraform: RG, ACR, AKS (Free tier, 1x B2s), Foundry account + gpt-5-mini,
          workload identity, image build (az acr build), K8s namespace/SA/Deployment/Service
agent/    FastAPI + LangGraph agent (mock flight/hotel/weather tools)
scripts/  stop.sh / start.sh: turn the cluster off/on to save cost
          register_external_agent.py: Foundry external-agent registration (run by Terraform)
```

Auth is keyless: the pod uses AKS workload identity -> Entra ID -> `Cognitive Services OpenAI User` on the Foundry account.

## Deploy
```
az login
cd infra
terraform init
terraform apply
```
Changing anything under `agent/` and re-running `terraform apply` rebuilds the image and rolls out the Deployment.

## Try it
```
az aks get-credentials -g $(terraform output -raw resource_group) -n $(terraform output -raw aks_name)
kubectl -n travel port-forward svc/travel-agent 8080:80
curl -s localhost:8080/chat -H 'content-type: application/json' \
  -d '{"message":"Plan a 3-day trip to Lisbon from London in June"}'
```

## Onboard to Foundry (external agent, preview)
The agent keeps running on AKS; Foundry stores only a registration record and reads its traces.
`terraform apply` does all of it:
1. Creates a Foundry **project** plus Log Analytics + **Application Insights**, connected to the project.
2. The agent emits OpenTelemetry GenAI spans (`gen_ai.agent.id = travel-planner-agent-v1`) to App Insights (`agent/app/telemetry.py`).
3. `terraform_data.register_external_agent` registers `travel-planner-agent` via the Foundry SDK (needs `uv` and your `az login`; your user gets the *Foundry User* role on the project).

View it in the [Foundry portal](https://ai.azure.com) (new portal): project `travel-agents` > Build > Agents > `travel-planner-agent` > Traces. Traces appear 2-5 min after a `/chat` call.
Limits (external agents): no human evaluation, trace-to-dataset, or red teaming. Foundry does not host, proxy or invoke the agent.

## Save cost
- `scripts/stop.sh` / `scripts/start.sh`: deallocate / start the AKS nodes (~$10-15/mo while stopped).
- `terraform destroy`: removes everything ($0).
