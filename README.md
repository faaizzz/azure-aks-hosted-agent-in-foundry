# azure-aks-hosted-agent-in-foundry

A sample LangGraph travel agent running on a minimum-cost AKS cluster and calling a model deployed in Azure AI Foundry. **Everything is managed by Terraform** (infra, image build, Kubernetes objects).

```
infra/    Terraform: RG, ACR, AKS (Free tier, 1x B2s), Foundry account + gpt-5-mini,
          workload identity, image build (az acr build), K8s namespace/SA/Deployment/Service
agent/    FastAPI + LangGraph agent (mock flight/hotel/weather tools)
scripts/  stop.sh / start.sh: turn the cluster off/on to save cost
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

## Save cost
- `scripts/stop.sh` / `scripts/start.sh`: deallocate / start the AKS nodes (~$10-15/mo while stopped).
- `terraform destroy`: removes everything ($0).
