#!/usr/bin/env bash
# Operational toggle (not an infrastructure change): start the stopped AKS cluster.
set -euo pipefail
cd "$(dirname "$0")/../infra"
rg=$(terraform output -raw resource_group)
aks=$(terraform output -raw aks_name)
az aks start --resource-group "$rg" --name "$aks"
