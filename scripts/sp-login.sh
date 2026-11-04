#!/usr/bin/env bash
# Signs in as the service principal and points kubectl at the cluster with kubelogin spn mode.
# Uses its own Azure CLI profile and kubeconfig so your personal login stays intact.
# Usage: source scripts/env-from-terraform.sh && source scripts/sp-login.sh
: "${AZURE_CLIENT_ID:?}" "${AZURE_CLIENT_SECRET:?}" "${AZURE_TENANT_ID:?}" "${RG:?}" "${AKS:?}"

export AZURE_CONFIG_DIR="$HOME/.azure-it3200-sp"
export KUBECONFIG="$HOME/.kube/it3200-sp"

# --allow-no-subscriptions: a principal with no Azure role sees no subscription,
# and az login would otherwise fail even though the secret was accepted.
# The secret stays in AZURE_CLIENT_SECRET; kubelogin reads it at token time,
# so it is never written to the kubeconfig.
az login --service-principal \
  --username "$AZURE_CLIENT_ID" \
  --password "$AZURE_CLIENT_SECRET" \
  --tenant "$AZURE_TENANT_ID" \
  --allow-no-subscriptions --output none
az account show --query "{type:user.type, name:user.name, subscription:name}" -o table

az aks get-credentials --resource-group "$RG" --name "$AKS" --overwrite-existing ${SUB_ID:+--subscription "$SUB_ID"} &&
  kubelogin convert-kubeconfig -l spn --client-id "$AZURE_CLIENT_ID" --tenant-id "$AZURE_TENANT_ID" &&
  echo "kubectl now uses the service principal (KUBECONFIG=$KUBECONFIG)."
