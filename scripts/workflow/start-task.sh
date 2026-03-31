#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/hooks/common.sh"

cd "$ROOT_DIR"

TASK_ID="${1:-}"
if [ -z "$TASK_ID" ]; then
  echo "Usage: bash scripts/workflow/start-task.sh <task-id> [spec-path]" >&2
  exit 1
fi

SPEC_PATH="${2:-}"
if [ -n "$SPEC_PATH" ]; then
  hook_state_sync "$SPEC_PATH" >/dev/null
fi

"${HOOK_PYTHON_BIN:-python}" "$SCRIPT_DIR/workflow-driver.py" start-task "$TASK_ID"
