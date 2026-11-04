#!/usr/bin/env bash
# Prints the manifests with your ACR login server filled in. Pipe to kubectl apply -f -.
set -euo pipefail
: "${ACR_LOGIN_SERVER:?source scripts/env-from-terraform.sh first}"
K8S="$(dirname "$0")/../k8s"
for f in "$@"; do
  sed "s|ACR_LOGIN_SERVER|$ACR_LOGIN_SERVER|g" "$K8S/$f"
  echo "---"
done
