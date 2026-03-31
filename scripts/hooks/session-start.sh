#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

INPUT="$(cat 2>/dev/null || true)"
CWD="$(hook_project_dir "$INPUT")"

cd "$CWD" 2>/dev/null || exit 0

ACTIVE_SPEC="$(hook_state_infer_active_spec)"
if [ -n "$ACTIVE_SPEC" ] && [ -f "$ACTIVE_SPEC" ]; then
  hook_state_sync "$ACTIVE_SPEC" >/dev/null 2>&1 || true
fi

STATE_FILE="$(hook_state_file)"
SUMMARY_FILE="$(hook_state_summary_file)"
CONTEXT_FILE="$(hook_context_file)"
TEST_CMD="$(hook_require_test_command 2>/dev/null || true)"
PROTECTED_PATHS_FILE="$(hook_protected_paths_file)"
NEXT_TASK_JSON="$("$HOOK_PYTHON_BIN" scripts/workflow/select-next-task.py 2>/dev/null || true)"
NEXT_TASK_ID="$(printf '%s' "$NEXT_TASK_JSON" | "$HOOK_PYTHON_BIN" - <<'PY'
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print("")
    raise SystemExit(0)
try:
    data = json.loads(raw)
except Exception:
    print("")
    raise SystemExit(0)
print(data.get("next_task_id", ""))
PY
)"
NEXT_TASK_TITLE="$(printf '%s' "$NEXT_TASK_JSON" | "$HOOK_PYTHON_BIN" - <<'PY'
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print("")
    raise SystemExit(0)
try:
    data = json.loads(raw)
except Exception:
    print("")
    raise SystemExit(0)
print(data.get("next_task_title", ""))
PY
)"

echo "HARNESS SESSION START"
echo "project: ${PWD##*/}"
echo "instructions: ${CONTEXT_FILE:-missing}"
echo "test command: ${TEST_CMD:-missing}"

if [ -n "$PROTECTED_PATHS_FILE" ] && [ -f "$PROTECTED_PATHS_FILE" ]; then
  echo "protected paths: $(grep -vc '^[[:space:]]*#\|^[[:space:]]*$' "$PROTECTED_PATHS_FILE" 2>/dev/null) rules (${PROTECTED_PATHS_FILE})"
fi

if [ -f "$STATE_FILE" ]; then
  CURRENT_TASK_TITLE="$(hook_state_current_task_title)"
  echo "state: $STATE_FILE"
  [ -f "$SUMMARY_FILE" ] && echo "summary: $SUMMARY_FILE"
  echo "feature: $(hook_state_get '.active_feature // "none"')"
  echo "task: $(hook_state_get '.current_task_id // "none"')${CURRENT_TASK_TITLE:+ - $CURRENT_TASK_TITLE}"
  if [ -n "$CURRENT_TASK_TITLE" ]; then
    echo "task title: $CURRENT_TASK_TITLE"
  fi
  echo "phase: $(hook_state_get '.current_phase // "intent"')"
  echo "task type: $(hook_state_get '.task_type // "none"')"
  echo "validation: $(hook_state_get '.validation_modes // []')"
  echo "tdd mode: $(hook_state_get '.tdd_evidence.mode // "required"')"
  echo "last test: $(hook_state_get '.last_test_result // "unknown"')"
  echo "semantic checks: $(hook_state_get '.semantic_checks.status // "not_required"')"
  echo "manual ack: $(hook_state_get '.manual_ack.acknowledged // false')"
  echo "evaluator: required=$(hook_state_get '.evaluator.required // false') verdict=$(hook_state_get '.evaluator.verdict // "pending"') independence=$(hook_state_get '.evaluator.independence_verified // false') quality=$(hook_state_get '.evaluator.quality_gate_passed // false')"
  echo "review modes: $(hook_state_get '.adversarial_review_modes // []')"
  if [ -n "$NEXT_TASK_ID" ]; then
    echo "next task: $NEXT_TASK_ID${NEXT_TASK_TITLE:+ - $NEXT_TASK_TITLE}"
  fi
else
  echo "state: missing"
  echo "active spec: ${ACTIVE_SPEC:-none}"
fi

echo "docs: scripts/workflow/README.md"
echo "resume rule: trust the state file first, then re-read the active spec before editing."

exit 0
