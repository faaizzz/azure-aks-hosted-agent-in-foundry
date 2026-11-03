#!/usr/bin/env bash
# Operational toggle (not an infrastructure change): deallocate AKS nodes to save cost.
set -euo pipefail
cd "$(dirname "$0")/../infra"
rg=$(terraform output -raw resource_group)
aks=$(terraform output -raw aks_name)
az aks stop --resource-group "$rg" --name "$aks"
