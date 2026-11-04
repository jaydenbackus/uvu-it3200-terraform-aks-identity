#!/usr/bin/env bash
# Signs in as the service principal and points kubectl at the cluster with kubelogin spn mode.
# Usage: source scripts/env-from-terraform.sh && scripts/sp-login.sh
set -euo pipefail
: "${AZURE_CLIENT_ID:?}" "${AZURE_CLIENT_SECRET:?}" "${AZURE_TENANT_ID:?}" "${RG:?}" "${AKS:?}"

az login --service-principal \
  --username "$AZURE_CLIENT_ID" \
  --password "$AZURE_CLIENT_SECRET" \
  --tenant "$AZURE_TENANT_ID" \
  --output none
az account show --query "{type:user.type, name:user.name, tenant:tenantId}" -o table

az aks get-credentials --resource-group "$RG" --name "$AKS" --overwrite-existing
kubelogin convert-kubeconfig -l spn
echo "kubeconfig now uses kubelogin spn mode (reads AZURE_CLIENT_ID / AZURE_CLIENT_SECRET)."
