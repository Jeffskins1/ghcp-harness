#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/hooks/common.sh"

cd "$ROOT_DIR"

CURRENT_PHASE="$(hook_state_get '.current_phase // empty')"
if [ "$CURRENT_PHASE" != "integration" ]; then
  echo "Not in integration phase (current: ${CURRENT_PHASE:-none})." >&2
  echo "This command is only valid after all tasks are complete." >&2
  exit 1
fi

TEST_CMD="$(hook_require_test_command 2>/dev/null || true)"
if [ -z "$TEST_CMD" ]; then
  echo "No full suite test command found." >&2
  echo "Add an '## Exact Test Commands' section with a full-suite command to .github/copilot-instructions.md or AGENTS.md." >&2
  exit 1
fi

echo "Integration run: $TEST_CMD"

TMP_OUT="$(mktemp)"
NOW="$(hook_state_now)"
if eval "$TEST_CMD" >"$TMP_OUT" 2>&1; then
  rm -f "$TMP_OUT"
  "$HOOK_PYTHON_BIN" - "$(hook_state_file)" "$TEST_CMD" "$NOW" <<'PY'
import json
import sys

state_path, command, now = sys.argv[1:4]
with open(state_path, encoding="utf-8") as handle:
    data = json.load(handle)

data["feature_integration"] = {
    "required": True,
    "full_suite_passed": True,
    "command": command,
    "recorded_at": now,
}
data["current_phase"] = "release"
data["updated_at"] = now

with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
  echo "Full suite passed. Phase: release"
else
  echo "INTEGRATION FAILED: full suite did not pass." >&2
  echo "Command: $TEST_CMD" >&2
  echo "" >&2
  echo "Failure output (last 40 lines):" >&2
  tail -40 "$TMP_OUT" >&2
  rm -f "$TMP_OUT"
  exit 1
fi
