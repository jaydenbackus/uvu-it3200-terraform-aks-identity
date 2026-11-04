#!/usr/bin/env bash
# Runs the Part 4 / Part 6 checks against the current kubeconfig.
# Usage: scripts/test-access.sh <label>   e.g. scripts/test-access.sh service-principal
NS="${NS:-it3200-lab}"
LABEL="${1:-identity}"

run() {
  local desc="$1"; shift
  if out=$("$@" 2>&1); then
    printf 'OK      %-30s %s\n' "$desc" "$*"
  else
    printf 'DENIED  %-30s %s\n        %s\n' "$desc" "$*" "$(echo "$out" | grep -v '^$' | tail -1 | cut -c1-220)"
  fi
}

can() {
  local desc="$1"; shift
  printf '%-7s %-30s kubectl auth can-i %s\n' "$(kubectl auth can-i "$@" 2>/dev/null | head -1 | cut -d" " -f1)" "$desc" "$*"
}

echo "== Access test: $LABEL =="
run "cluster-info"               kubectl cluster-info
run "list nodes"                 kubectl get nodes
run "list namespaces"            kubectl get namespaces
run "list pods (all namespaces)" kubectl get pods -A
run "list pods ($NS)"            kubectl get pods -n "$NS"
echo "-- permission checks (yes/no) --"
can "create deployments in $NS"  create deployments -n "$NS"
can "create services in $NS"     create services -n "$NS"
can "create deployments default" create deployments -n default
can "read secrets in $NS"        get secrets -n "$NS"
can "create rolebindings in $NS" create rolebindings -n "$NS"
can "delete namespaces"          delete namespaces
