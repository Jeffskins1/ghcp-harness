#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/hooks/common.sh"

cd "$ROOT_DIR"

COMMAND="${*:-}"
if [ -z "$COMMAND" ]; then
  echo "Usage: bash scripts/workflow/mark-red.sh <recognized failing test command>" >&2
  exit 1
fi

if ! hook_is_test_command "$COMMAND"; then
  echo "Command is not recognized as a test command: $COMMAND" >&2
  exit 1
fi

hook_state_record_test_result "$COMMAND" "fail" >/dev/null 2>&1 || true
hook_tdd_record_red "$COMMAND"
echo "Recorded Red for task $(hook_state_get '.current_task_id // empty')"
