#!/usr/bin/env bash
# watch-rogue-pods.sh
# Watches pods in user namespaces (user\d+) that do not carry
# the label app.kubernetes.io/managed-by=cloudnative-pg.
#
# Usage:
#   scripts/watch-rogue-pods.sh [--interval <seconds>] [--once]
#
#   --interval <s>  Interval between checks (default: 10)
#   --once          Run a single check then exit
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export KUBECONFIG="${REPO_ROOT}/terragrunt/kubeconfig-admin"

INTERVAL=10
ONCE=false

# --------------------------------------------------------------------------
# Argument parsing
# --------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)
      INTERVAL="$2"
      shift 2
      ;;
    --once)
      ONCE=true
      shift
      ;;
    *)
      echo "Usage: $0 [--interval <seconds>] [--once]" >&2
      exit 1
      ;;
  esac
done

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
log() { echo -e "[watch-rogue-pods] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

check_deps() {
  for cmd in kubectl grep; do
    command -v "$cmd" &>/dev/null || { echo "Required command not found: $cmd" >&2; exit 1; }
  done
}

# --------------------------------------------------------------------------
# Main check function
# --------------------------------------------------------------------------
check_rogue_pods() {
  # Retrieve all namespaces matching user\d+
  local user_namespaces
  user_namespaces=$(kubectl get namespaces -o name \
    | grep -E '^namespace/user[0-9]+$' || true)

  if [[ -z "$user_namespaces" ]]; then
    log "No user namespace found."
    return
  fi

  local found_rogue=false

  while IFS= read -r raw_ns; do
    local ns="${raw_ns#namespace/}"
    # Retrieve pods missing the label app.kubernetes.io/managed-by=cloudnative-pg
    local rogue_pods
    rogue_pods=$(kubectl get pods -n "$ns" \
      --field-selector=status.phase!=Succeeded,status.phase!=Failed \
      -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.app\.kubernetes\.io/managed-by}{"\n"}{end}' 2>/dev/null \
      | awk -F'\t' '$2 != "cloudnative-pg" { print $1 }' || true)

    if [[ -n "$rogue_pods" ]]; then
      found_rogue=true
      while IFS= read -r pod; do
        log "ALERT  namespace=\033[31m${ns}\033[0m  pod=\033[31m${pod}\033[0m not managed by cloudnative-pg"
      done <<< "$rogue_pods"
    fi
  done <<< "$user_namespaces"

  if ! $found_rogue; then
    log "OK — no pod unmanaged by cloudnative-pg found in user namespaces."
  fi
}

# --------------------------------------------------------------------------
# Watch loop
# --------------------------------------------------------------------------
check_deps
log "Starting watch (interval=${INTERVAL}s, once=${ONCE})"

while true; do
  check_rogue_pods
  $ONCE && break
  sleep "$INTERVAL"
done
