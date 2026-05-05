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
#set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VARIABLES_FILE="${REPO_ROOT}/terragrunt/variables.yaml"
INSTRUCTIONS_TPL="${REPO_ROOT}/charts/users/instructions.html"
KUBECONFIG_ADMIN="${REPO_ROOT}/terragrunt/kubeconfig-admin"
KUBECONFIGS_DIR="${REPO_ROOT}/kubeconfigs"
export KUBECONFIG="${KUBECONFIG_ADMIN}"
GARAGE_NAMESPACE="${GARAGE_NAMESPACE:-garage}"

# --- Configurable via env vars ---
RELEASE_NAME="${RELEASE_NAME:-users}"
RELEASE_NAMESPACE="${RELEASE_NAMESPACE:-users}"
TOKEN_WAIT_SECONDS="${TOKEN_WAIT_SECONDS:-60}"

log()  { echo "[setup-users] $*"; }
die()  { echo "[setup-users] ERROR: $*" >&2; exit 1; }
garage() { kubectl exec -n "${GARAGE_NAMESPACE}" sts/garage -c garage -- /garage "$@"; }

# --------------------------------------------------------------------------
# 0. Preflight checks
# --------------------------------------------------------------------------
for cmd in kubectl yq; do
  if ! command -v "$cmd" &>/dev/null; then
    die "ERROR: '$cmd' is required but not found in PATH."
  fi
done

if [[ ! -f "${KUBECONFIG_ADMIN}" ]]; then
  die "ERROR: Admin kubeconfig not found at ${KUBECONFIG_ADMIN}"
fi

# --------------------------------------------------------------------------
# 1. Parse variables.yaml
# --------------------------------------------------------------------------
USER_COUNT=$(yq '.users' "${VARIABLES_FILE}")
CLUSTER_NAME=$(yq '.name' "${VARIABLES_FILE}")
SERVER=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}')
CA_DATA=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
K8S_CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')

# --------------------------------------------------------------------------
# 2. Fetch passwords
# --------------------------------------------------------------------------

PASSWORD_FILE=$(mktemp -p /dev/shm)
cd "${REPO_ROOT}/terragrunt/03-app" && terraform output -json users_passwords > "${PASSWORD_FILE}"


# --------------------------------------------------------------------------
# 3. Build ConfigMap with one HTML entry per user
# --------------------------------------------------------------------------
echo "==> ${USER_COUNT} users to configure on cluster '${CLUSTER_NAME}'"
CM_NAME="${RELEASE_NAME}-instructions"

# Generate one HTML file per user in a fresh temp directory
TMPDIR_HTML=$(mktemp -d)
trap 'rm -rf "${TMPDIR_HTML}"' EXIT
mkdir -p "${KUBECONFIGS_DIR}"

for i in $(seq 1 "${USER_COUNT}"); do

  USERNAME="user${i}"
  SECRET_NAME="${USERNAME}"
  NAMESPACE="${USERNAME}"
  PASSWORD=$(yq ".${USERNAME}" "${PASSWORD_FILE}")
  log "==> ${USERNAME}"

  # Fetch token
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
      log "    Token not available yet for '${USERNAME}', retrying... (${ELAPSED}s elapsed)"
      ELAPSED=$(( ELAPSED + INTERVAL ))
    fi
  done

  if [[ -z "${TOKEN}" ]]; then
    log "    WARNING: token not available for '${USERNAME}' after ${TOKEN_WAIT_SECONDS}s, skipping."
    continue
  fi

  # Build kubeconfig 
  log "    kubeconfig..."
  KUBECONFIG_FILE="${KUBECONFIGS_DIR}/${USERNAME}-kubeconfig.yaml"
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
  log "    kubeconfig...OK"
  
  # Build instructions
  log "    instructions..."
  sed "s/__USERNAME__/${USERNAME}/g" "${INSTRUCTIONS_TPL}" \
  | sed "s/__PASSWORD__/${PASSWORD}/g"  \
  | sed "s/__SA_TOKEN__/${TOKEN}/g" > "${TMPDIR_HTML}/${USERNAME}.html"
  
  chmod 600 "${TMPDIR_HTML}/${USERNAME}.html"
  log "    instructions...OK"

  BUCKET_NAME="${USERNAME}-backup"
  API_KEY_NAME="${USERNAME}-backup-key"

  # Bucket
  if ! garage bucket info "${BUCKET_NAME}" &>/dev/null; then
    log "    Creating bucket '${BUCKET_NAME}'"
    garage bucket create "${BUCKET_NAME}"
  else
    log "    Bucket '${BUCKET_NAME}' already exists — skipping"
  fi

  # API key
  if ! garage key info "${API_KEY_NAME}" &>/dev/null; then
    log "    Creating API key '${API_KEY_NAME}'"
    garage key create "${API_KEY_NAME}" > /dev/null
  else
    log "    API key '${API_KEY_NAME}' already exists — skipping"
  fi

  # Permissions (idempotent)
  garage bucket allow --read --write --owner "${BUCKET_NAME}" --key "${API_KEY_NAME}" >/dev/null

  # Retrieve credentials
  ACCESS_KEY_ID=$(garage key info "${API_KEY_NAME}" 2>/dev/null \
    | grep 'Key ID:' | awk '{print $3}')
  ACCESS_SECRET_KEY=$(garage key info --show-secret "${API_KEY_NAME}" 2>/dev/null \
    | grep 'Secret key:' | awk '{print $3}')

  [[ -z "${ACCESS_KEY_ID}" ]]     && die "Could not retrieve Access Key ID for ${USERNAME}"
  [[ -z "${ACCESS_SECRET_KEY}" ]] && die "Could not retrieve Secret Key for ${USERNAME}"

  # Kubernetes secret (create or update — idempotent via dry-run + apply)
  log "    Injecting secret '${SECRET_NAME}' in namespace '${USERNAME}'"
  kubectl create secret generic "${USERNAME}-barman-backup" \
    --namespace "${USERNAME}" \
    --from-literal=AWS_ACCESS_KEY_ID="${ACCESS_KEY_ID}" \
    --from-literal=AWS_SECRET_ACCESS_KEY="${ACCESS_SECRET_KEY}" \
    --from-literal=AWS_ENDPOINT_URL="http://garage.${GARAGE_NAMESPACE}.svc.cluster.local:3900" \
    --from-literal=AWS_DEFAULT_REGION=garage \
    --from-literal=BUCKET_NAME="${BUCKET_NAME}" \
    --dry-run=client -o yaml \
    | kubectl apply -f -
  log "    Secret injected."

  # Configure CNPG ObjectStore
  kubectl apply -f - <<EOF
apiVersion: barmancloud.cnpg.io/v1
kind: ObjectStore
metadata:
  name: ${USERNAME}-garage-store
  namespace: ${USERNAME}
spec:
  configuration:
    destinationPath: s3://${BUCKET_NAME}/
    endpointURL: http://garage.${GARAGE_NAMESPACE}.svc.cluster.local:3900
    s3Credentials:
      accessKeyId:
        name: ${USERNAME}-barman-backup
        key: AWS_ACCESS_KEY_ID
      secretAccessKey:
        name: ${USERNAME}-barman-backup
        key: AWS_SECRET_ACCESS_KEY
      region:
        name: ${USERNAME}-barman-backup
        key: AWS_DEFAULT_REGION
    wal:
      compression: gzip
    data:
      immediateCheckpoint: true
EOF

done

# ----------------------------
# 5. Push ConfigMap and Secret
# ----------------------------
echo "==> Applying ConfigMap '${CM_NAME}' in namespace '${RELEASE_NAMESPACE}'..."
kubectl create configmap "${CM_NAME}" \
  --namespace="${RELEASE_NAMESPACE}" \
  --from-file="${TMPDIR_HTML}" \
  --dry-run=client -o yaml \
  | kubectl apply -f - >/dev/null

echo "    ConfigMap updated."


KUBECONFIG_SECRET_NAME="${RELEASE_NAME}-kubeconfigs"
echo "==> Applying Secret '${KUBECONFIG_SECRET_NAME}' in namespace '${RELEASE_NAMESPACE}'..."
kubectl create secret generic "${KUBECONFIG_SECRET_NAME}" \
  --namespace="${RELEASE_NAMESPACE}" \
  --from-file="${KUBECONFIGS_DIR}" \
  --dry-run=client -o yaml \
  | kubectl apply -f - >/dev/null
echo "    Secret updated."

echo ""
