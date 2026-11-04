#!/usr/bin/env bash
# Runs the Part 4 / Part 6 checks and prints PASS or FAIL for each.
# Usage: scripts/test-access.sh <label>   e.g. scripts/test-access.sh service-principal
NS="${NS:-it3200-lab}"
LABEL="${1:-identity}"

run() {
  local desc="$1"; shift
  if out=$("$@" 2>&1); then
    printf 'PASS  %-34s %s\n' "$desc" "$*"
  else
    printf 'FAIL  %-34s %s\n      %s\n' "$desc" "$*" "$(echo "$out" | tail -1)"
  fi
}

echo "== Access test: $LABEL =="
run "cluster-info"               kubectl cluster-info
run "list nodes"                 kubectl get nodes
run "list namespaces"            kubectl get namespaces
run "list pods (all namespaces)" kubectl get pods -A
run "list pods ($NS)"            kubectl get pods -n "$NS"
run "can create deployments"     kubectl auth can-i create deployments -n "$NS"
run "can create services"        kubectl auth can-i create services -n "$NS"
run "can delete namespaces"      kubectl auth can-i delete namespaces
run "can create in default ns"   kubectl auth can-i create deployments -n default
