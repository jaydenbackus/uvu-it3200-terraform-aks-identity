#!/usr/bin/env bash
# Points kubectl at the cluster as your personal Entra account (kubelogin azurecli mode).
# Usage: source scripts/env-from-terraform.sh && source scripts/user-login.sh
: "${RG:?}" "${AKS:?}"
unset AZURE_CONFIG_DIR
export KUBECONFIG="$HOME/.kube/it3200-user"

az account show --query "{type:user.type, name:user.name, subscription:name}" -o table || az login --output none
az aks get-credentials --resource-group "$RG" --name "$AKS" --overwrite-existing &&
  kubelogin convert-kubeconfig -l azurecli &&
  echo "kubectl now uses your personal account (KUBECONFIG=$KUBECONFIG)."
