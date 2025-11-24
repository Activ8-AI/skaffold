#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: ./run_and_log.sh stacks/<stack>.yaml [persona] [role] [payload-json]" >&2
  exit 1
fi

STACK_PATH="$1"
PERSONA="${2:-kim}"
ROLE="${3:-advisor}"
PAYLOAD="${4:-{}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

TS="$(date -u +%Y-%m-%d/%H%M%S)"
RUN_DIR="PreservationVault/runs/${TS}"
mkdir -p "${RUN_DIR}/outputs"

python3 codex_relay.py \
  --persona "${PERSONA}" \
  --role "${ROLE}" \
  --payload "${PAYLOAD}" \
  --stacks-dir "stacks" \
  --stack-path "${STACK_PATH}" \
  --run-dir "${RUN_DIR}" > "${RUN_DIR}/relay.json"

python3 codex_logger.py --run-dir "${RUN_DIR}" --record-env

cp codex_evaluation.json "${RUN_DIR}/evaluation.json"

git -C PreservationVault add .
git -C PreservationVault commit -m "Run ${TS}" >/dev/null 2>&1 || true
