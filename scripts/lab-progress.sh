#!/usr/bin/env bash
# lab-progress.sh
# Displays a per-user progress summary across the workshop labs.
#
# For each lab, validation scripts located in scripts/labs/labN/ are executed
# in alphabetical order. Each script receives the user namespace as $1 and
# must return 0 to pass. Execution stops at the first failure.
#
# Progress is shown as a percentage (passed / total scripts):
#   100%       → green  (completed)
#   0% < x < 100% → orange (in progress)
#   0%         → red    (not started)
#
# Requirements: kubectl
#
# Usage:
#   scripts/lab-progress.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export KUBECONFIG="${REPO_ROOT}/terragrunt/kubeconfig-admin"

LABS_DIR="${SCRIPT_DIR}/labs"

# --------------------------------------------------------------------------
# ANSI colours
# --------------------------------------------------------------------------
RED='\033[0;31m'
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

MAX_SCRIPT_NAME=20  # max chars for the failing script name

# --------------------------------------------------------------------------
# run_lab_checks <namespace> <lab-dir>
# Runs scripts in alphabetical order; stops at first failure.
# Outputs "passed/total/failing-script-name" on stdout.
# --------------------------------------------------------------------------
run_lab_checks() {
  local ns="$1"
  local lab_dir="$2"
  local scripts=()

  while IFS= read -r script; do
    scripts+=("$script")
  done < <(find "$lab_dir" -maxdepth 1 -name '*.sh' -type f | sort)

  local total="${#scripts[@]}"
  local passed=0
  local failed_name=""

  for script in "${scripts[@]}"; do
    if bash "$script" "$ns" </dev/null &>/dev/null; then
      passed=$((passed + 1))
    else
      # Strip leading digits+dash and .sh extension, then truncate
      local raw
      raw=$(basename "$script" .sh | sed 's/^[0-9]*-//')
      failed_name="${raw:0:${MAX_SCRIPT_NAME}}"
      break  # stop at first failure
    fi
  done

  echo "${passed}/${total}/${failed_name}"
}

# Column layout: [pct%] = 6 chars + 1 space + MAX_SCRIPT_NAME chars
COL_WIDTH=$(( 6 + 1 + MAX_SCRIPT_NAME ))

# --------------------------------------------------------------------------
# render_block <passed> <total> [failing-script]
# Prints a coloured progress block, with failing script name when applicable.
# --------------------------------------------------------------------------
render_block() {
  local passed="$1" total="$2" failed_name="${3:-}"
  local pct=0
  [[ "$total" -gt 0 ]] && pct=$(( passed * 100 / total ))

  local pct_text
  pct_text=$(printf "%3d%%" "$pct")

  if   [[ "$pct" -eq 100 ]]; then
    printf "${GREEN}[%4s]${RESET}%-$(( COL_WIDTH - 6 ))s" "$pct_text" ""
  elif [[ "$pct" -gt 0   ]]; then
    printf "${ORANGE}[%4s]${RESET} ${ORANGE}%-${MAX_SCRIPT_NAME}s${RESET}" "$pct_text" "$failed_name"
  else
    printf "${RED}[%4s]${RESET} ${RED}%-${MAX_SCRIPT_NAME}s${RESET}" "$pct_text" "$failed_name"
  fi
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
user_namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' \
  | tr ' ' '\n' \
  | grep -E '^user[0-9]+$' \
  | sort -V || true)

if [[ -z "$user_namespaces" ]]; then
  echo "No user namespace found." >&2
  exit 0
fi

# Discover labs in alphabetical order
mapfile -t lab_dirs < <(find "$LABS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ "${#lab_dirs[@]}" -eq 0 ]]; then
  echo "No lab directories found under ${LABS_DIR}." >&2
  exit 1
fi

# Build header
header_fmt="${BOLD}%-12s"
header_args=("USER")
for lab_dir in "${lab_dirs[@]}"; do
  header_fmt+="  %-${COL_WIDTH}s"
  header_args+=("$(basename "$lab_dir")")
done
header_fmt+="${RESET}\n"

printf "\n${header_fmt}" "${header_args[@]}"
printf '%s\n' "$(printf '─%.0s' $(seq 1 $((12 + ${#lab_dirs[@]} * 18))))"

while IFS= read -r ns; do
  printf "%-12s" "$ns"
  for lab_dir in "${lab_dirs[@]}"; do
    result=$(run_lab_checks "$ns" "$lab_dir")
    passed="${result%%/*}"
    rest="${result#*/}"
    total="${rest%%/*}"
    failed_name="${rest#*/}"
    printf "  "
    render_block "$passed" "$total" "$failed_name"
  done
  printf "\n"
done <<< "$user_namespaces"

printf "\n"
printf "  ${GREEN}[label 100%%]${RESET} completed   "
printf "  ${ORANGE}[label  xx%%]${RESET} in progress   "
printf "  ${RED}[label   0%%]${RESET} not started\n\n"
