#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/hooks/common.sh"

cd "$ROOT_DIR"

COMMAND="${*:-}"
if [ -z "$COMMAND" ]; then
  echo "Usage: bash scripts/workflow/mark-green.sh <recognized passing test command>" >&2
  exit 1
fi

if ! hook_is_test_command "$COMMAND"; then
  echo "Command is not recognized as a test command: $COMMAND" >&2
  exit 1
fi
if [ "$(hook_state_get_active_task_tdd_field red_observed)" != "true" ]; then
  echo "Cannot record Green before Red for the active task." >&2
  exit 1
fi

hook_state_record_test_result "$COMMAND" "pass" >/dev/null 2>&1 || true
hook_tdd_record_green "$COMMAND"
echo "Recorded Green for task $(hook_state_get '.current_task_id // empty')"
