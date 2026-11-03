.DEFAULT_GOAL := help
SHELL := /bin/bash

TF   := terraform -chdir=infra
PORT ?= 8080
MSG  ?= Plan a 3-day trip to Lisbon from London in June
export MSG
# AUTO=1 skips Terraform's confirmation prompt (apply/destroy).
AUTO ?=
TF_APPROVE := $(if $(AUTO),-auto-approve,)

# Resolved lazily from Terraform outputs (only valid while the stack exists).
RG  = $$($(TF) output -raw resource_group)
AKS = $$($(TF) output -raw aks_name)

.PHONY: help init fmt validate plan apply destroy output creds status logs port-forward chat aks-status stop start

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make <target> [AUTO=1] [PORT=8080] [MSG=\"...\"]\n\n"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ Terraform (all infrastructure changes go through here)
init: ## terraform init
	$(TF) init -input=false

fmt: ## terraform fmt
	$(TF) fmt -recursive

validate: init ## terraform validate
	$(TF) validate

plan: init ## terraform plan
	$(TF) plan -input=false

apply: init ## Create/update everything (builds image, deploys, registers agent). AUTO=1 skips prompt
	$(TF) apply -input=false $(TF_APPROVE)

output: ## Show terraform outputs
	$(TF) output

destroy: ## Destroy ALL resources (starts AKS first if stopped, cleans kubeconfig). AUTO=1 skips prompt
	@RG=$(RG) AKS=$(AKS); \
	if [ -n "$$AKS" ]; then \
	  state=$$(az aks show -g "$$RG" -n "$$AKS" --query powerState.code -o tsv 2>/dev/null || true); \
	  if [ "$$state" = "Stopped" ]; then \
	    echo "AKS is stopped; starting it so Terraform can delete the Kubernetes resources..."; \
	    az aks start -g "$$RG" -n "$$AKS"; \
	  fi; \
	fi; \
	$(TF) destroy -input=false $(TF_APPROVE); rc=$$?; \
	if [ $$rc -eq 0 ] && [ -n "$$AKS" ]; then \
	  echo "Removing local kubeconfig entries for $$AKS"; \
	  kubectl config delete-context "$$AKS" >/dev/null 2>&1 || true; \
	  kubectl config delete-cluster "$$AKS" >/dev/null 2>&1 || true; \
	  kubectl config unset "users.clusterUser_$${RG}_$${AKS}" >/dev/null 2>&1 || true; \
	fi; \
	exit $$rc

##@ Cluster
creds: ## Fetch kubeconfig for the AKS cluster
	@az aks get-credentials -g $(RG) -n $(AKS) --overwrite-existing

status: ## Show nodes and pods
	kubectl get nodes
	kubectl -n travel get pods,svc

logs: ## Tail agent logs
	kubectl -n travel logs deploy/travel-agent -f

aks-status: ## Show AKS power state (Running/Stopped)
	@az aks show -g $(RG) -n $(AKS) --query powerState.code -o tsv

stop: ## Stop AKS (deallocate nodes to save cost)
	./scripts/stop.sh

start: ## Start AKS
	./scripts/start.sh

##@ Try the agent
port-forward: ## Forward the agent service to localhost:$(PORT) (keep running)
	kubectl -n travel port-forward svc/travel-agent $(PORT):80

chat: ## Send MSG to the agent (needs `make port-forward` running)
	@curl -s -m 150 localhost:$(PORT)/chat -H 'content-type: application/json' \
	  -d "$$(python3 -c 'import json,os; print(json.dumps({"message": os.environ["MSG"]}))')" | python3 -m json.tool
