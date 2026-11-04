#!/usr/bin/env bash
# Usage: source scripts/env-from-terraform.sh
# Exports Terraform outputs as env vars for the current shell. Prints no secrets.
TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"
tfo() { terraform -chdir="$TF_DIR" output -raw "$1"; }

export RG="$(tfo resource_group_name)"
export AKS="$(tfo aks_cluster_name)"
export ACR="$(tfo acr_name)"
export ACR_LOGIN_SERVER="$(tfo acr_login_server)"
export NS="$(tfo app_namespace)"

# Names kubelogin's spn mode reads
export AZURE_TENANT_ID="$(tfo tenant_id)"
export AZURE_CLIENT_ID="$(tfo sp_client_id)"
export AZURE_CLIENT_SECRET="$(tfo sp_client_secret)"

echo "Exported RG=$RG AKS=$AKS ACR=$ACR NS=$NS AZURE_CLIENT_ID=$AZURE_CLIENT_ID (secret hidden)"
