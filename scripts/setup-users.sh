#!/usr/bin/env bash
# setup-users.sh
# Populates the users-instructions ConfigMap with per-user HTML pages
# and generates a kubeconfig file for each user's ServiceAccount token.
#
# Requirements: kubectl, yq (https://github.com/mikefarah/yq)
#
# Usage:
#   RELEASE_NAME=users RELEASE_NAMESPACE=default ./scripts/setup-users.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VARIABLES_FILE="${REPO_ROOT}/terragrunt/variables.yaml"
INSTRUCTIONS_TPL="${REPO_ROOT}/charts/users/instructions.html"
KUBECONFIG_ADMIN="${REPO_ROOT}/terragrunt/kubeconfig-admin"
KUBECONFIGS_DIR="${REPO_ROOT}/kubeconfigs"

# --- Configurable via env vars ---
RELEASE_NAME="${RELEASE_NAME:-users}"
RELEASE_NAMESPACE="${RELEASE_NAMESPACE:-users}"
TOKEN_WAIT_SECONDS="${TOKEN_WAIT_SECONDS:-60}"

# --------------------------------------------------------------------------
# 0. Preflight checks
# --------------------------------------------------------------------------
for cmd in kubectl yq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is required but not found in PATH." >&2
    exit 1
  fi
done

if [[ ! -f "${KUBECONFIG_ADMIN}" ]]; then
  echo "ERROR: Admin kubeconfig not found at ${KUBECONFIG_ADMIN}" >&2
  exit 1
fi

export KUBECONFIG="${KUBECONFIG_ADMIN}"

# --------------------------------------------------------------------------
# 1. Parse variables.yaml
# --------------------------------------------------------------------------
USER_COUNT=$(yq '.users' "${VARIABLES_FILE}")
CLUSTER_NAME=$(yq '.name' "${VARIABLES_FILE}")

echo "==> ${USER_COUNT} users to configure on cluster '${CLUSTER_NAME}'"

# --------------------------------------------------------------------------
# 2. Build ConfigMap with one HTML entry per user
# --------------------------------------------------------------------------
CM_NAME="${RELEASE_NAME}-instructions"

# Generate one HTML file per user in a fresh temp directory
TMPDIR_HTML=$(mktemp -d)
trap 'rm -rf "${TMPDIR_HTML}"' EXIT

for i in $(seq 1 "${USER_COUNT}"); do
  USERNAME="user${i}"
  sed "s/__USERNAME__/${USERNAME}/g" "${INSTRUCTIONS_TPL}" > "${TMPDIR_HTML}/${USERNAME}.html"
done

echo "==> Applying ConfigMap '${CM_NAME}' in namespace '${RELEASE_NAMESPACE}'..."
kubectl create configmap "${CM_NAME}" \
  --namespace="${RELEASE_NAMESPACE}" \
  --from-file="${TMPDIR_HTML}" \
  --dry-run=client -o yaml \
  | kubectl apply -f -

echo "    ConfigMap updated."

# --------------------------------------------------------------------------
# 3. Extract cluster info from admin kubeconfig
# --------------------------------------------------------------------------
SERVER=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}')
CA_DATA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
K8S_CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')

# --------------------------------------------------------------------------
# 4. Generate kubeconfig per user
# --------------------------------------------------------------------------
mkdir -p "${KUBECONFIGS_DIR}"

for i in $(seq 1 "${USER_COUNT}"); do
  USERNAME="user${i}"
  SECRET_NAME="${USERNAME}"
  NAMESPACE="${USERNAME}"

  echo "==> Waiting for SA token: secret '${SECRET_NAME}' in namespace '${NAMESPACE}'..."

  TOKEN=""
  ELAPSED=0
  INTERVAL=3
  while [[ -z "${TOKEN}" && ${ELAPSED} -lt ${TOKEN_WAIT_SECONDS} ]]; do
    TOKEN=$(kubectl get secret "${SECRET_NAME}" \
      -n "${NAMESPACE}" \
      -o jsonpath='{.data.token}' 2>/dev/null \
      | base64 --decode 2>/dev/null || true)
    if [[ -z "${TOKEN}" ]]; then
      sleep "${INTERVAL}"
      ELAPSED=$(( ELAPSED + INTERVAL ))
    fi
  done

  if [[ -z "${TOKEN}" ]]; then
    echo "    WARNING: token not available for '${USERNAME}' after ${TOKEN_WAIT_SECONDS}s, skipping." >&2
    continue
  fi

  KUBECONFIG_FILE="${KUBECONFIGS_DIR}/${USERNAME}.yaml"
  cat > "${KUBECONFIG_FILE}" <<EOF
apiVersion: v1
kind: Config
clusters:
- name: ${K8S_CLUSTER_NAME}
  cluster:
    certificate-authority-data: ${CA_DATA}
    server: ${SERVER}
contexts:
- name: ${USERNAME}@${K8S_CLUSTER_NAME}
  context:
    cluster: ${K8S_CLUSTER_NAME}
    namespace: ${NAMESPACE}
    user: ${USERNAME}
current-context: ${USERNAME}@${K8S_CLUSTER_NAME}
users:
- name: ${USERNAME}
  user:
    token: ${TOKEN}
EOF
  chmod 600 "${KUBECONFIG_FILE}"
  echo "    Generated ${KUBECONFIG_FILE}"
done

# --------------------------------------------------------------------------
# 5. Push all kubeconfigs into the users-kubeconfigs Secret
# --------------------------------------------------------------------------
SECRET_NAME="${RELEASE_NAME}-kubeconfigs"
echo "==> Applying Secret '${SECRET_NAME}' in namespace '${RELEASE_NAMESPACE}'..."
kubectl create secret generic "${SECRET_NAME}" \
  --namespace="${RELEASE_NAMESPACE}" \
  --from-file="${KUBECONFIGS_DIR}" \
  --dry-run=client -o yaml \
  | kubectl apply -f -
echo "    Secret updated."

echo ""
echo "Done. Kubeconfigs written to: ${KUBECONFIGS_DIR}/"
