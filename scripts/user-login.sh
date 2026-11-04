#!/usr/bin/env bash
# Signs in as your personal Entra account and uses kubelogin's Azure CLI mode.
set -euo pipefail
: "${RG:?}" "${AKS:?}"

az login --output none
az account show --query "{type:user.type, name:user.name, tenant:tenantId}" -o table

az aks get-credentials --resource-group "$RG" --name "$AKS" --overwrite-existing
kubelogin convert-kubeconfig -l azurecli
