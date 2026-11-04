#!/usr/bin/env bash
# Builds the sample app into ACR. Run as your personal account (needs push rights).
set -euo pipefail
: "${ACR:?source scripts/env-from-terraform.sh first}"
cd "$(dirname "$0")/../app"

if az acr build --registry "$ACR" --image hello-it3200:v1 . ; then
  echo "Built in ACR with ACR Tasks."
else
  echo "ACR Tasks unavailable; building locally and pushing."
  az acr login --name "$ACR"
  docker build --platform linux/amd64 -t "$ACR_LOGIN_SERVER/hello-it3200:v1" .
  docker push "$ACR_LOGIN_SERVER/hello-it3200:v1"
fi

az acr repository show-tags --name "$ACR" --repository hello-it3200 -o table
