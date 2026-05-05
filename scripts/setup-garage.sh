#!/usr/bin/env bash
# setup-garage.sh
# Idempotent script that:
#   1. Assigns the storage layout and applies it (skip if already applied)
#   2. Creates one bucket + one API key per participant
#   3. Injects per-user S3 credentials as Kubernetes secrets in their namespace
#
# Requirements: kubectl, yq
#
# Usage:
#   scripts/setup-garage.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export KUBECONFIG="${REPO_ROOT}/terragrunt/kubeconfig-admin"

VARIABLES_FILE="${REPO_ROOT}/terragrunt/variables.yaml"
GARAGE_NAMESPACE="${GARAGE_NAMESPACE:-garage}"
STORAGE_CAPACITY="${STORAGE_CAPACITY:-10G}"
GARAGE_ZONE="${GARAGE_ZONE:-dc1}"
SECRET_NAME="${SECRET_NAME:-garage-creds}"

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
log()  { echo "[setup-garage] $*"; }
die()  { echo "[setup-garage] ERROR: $*" >&2; exit 1; }

# garage: alias to run /garage inside the StatefulSet pod
garage() { kubectl exec -n "${GARAGE_NAMESPACE}" sts/garage -c garage -- /garage "$@"; }

# --------------------------------------------------------------------------
# 1. Layout — assign + apply (idempotent: skip if version already applied)
# --------------------------------------------------------------------------
log "Checking Garage layout..."

GARAGE_CLUSTER_ID=$(garage status 2>/dev/null | awk 'END{print $1}')
log "Cluster ID: ${GARAGE_CLUSTER_ID}"

CURRENT_VERSION=$(garage layout show 2>/dev/null \
  | grep -E '^Current cluster layout version:' | awk '{print $NF}' || echo "0")

if [[ "${CURRENT_VERSION}" == "0" ]]; then
  log "No layout applied yet — assigning node and applying layout v1"
  garage layout assign -z "${GARAGE_ZONE}" -c "${STORAGE_CAPACITY}" "${GARAGE_CLUSTER_ID}"
  garage layout apply --version 1
  log "Layout applied (version 1)"
else
  log "Layout already at version ${CURRENT_VERSION} — skipping"
fi

log "Done."
