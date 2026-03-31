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
TEST_CMD="$(hook_require_test_command 2>/dev/null || true)"

if [ ! -f "$STATE_FILE" ]; then
  echo "RELEASE GATE BLOCKED: active workflow state is missing." >&2
  echo "Start from a feature spec so the harness can persist active task and phase." >&2
  exit 2
fi

if [ "$(hook_state_get '.feature_integration.required // false')" = "true" ]; then
  if [ "$(hook_state_get '.feature_integration.full_suite_passed // false')" != "true" ]; then
    echo "RELEASE GATE BLOCKED: full-suite integration run has not passed." >&2
    echo "All tasks are complete but the full suite has not been verified together." >&2
    echo "Run: bash scripts/workflow/mark-integration-passed.sh" >&2
    exit 2
  fi
fi

CURRENT_TASK_ID="$(hook_state_get '.current_task_id // empty')"
CURRENT_PHASE="$(hook_state_get '.current_phase // "intent"')"
TASK_TYPE="$(hook_state_get '.task_type // "code"')"
VALIDATION_MODES="$(hook_state_get '.validation_modes // []')"

if [ -n "$CURRENT_TASK_ID" ] && [ "$VALIDATION_MODES" = "[]" -o -z "$VALIDATION_MODES" ]; then
  echo "RELEASE GATE BLOCKED: active task is missing explicit validation modes." >&2
  echo "Task: $CURRENT_TASK_ID" >&2
  exit 2
fi

if printf '%s' "$VALIDATION_MODES" | grep -q '"tests"' && [ -z "$TEST_CMD" ]; then
  echo "RELEASE GATE BLOCKED: missing exact test command." >&2
  echo "Add a '## Exact Test Commands' section to .github/copilot-instructions.md or AGENTS.md." >&2
  echo "Include a copy-pasteable full-suite command, for example: '- Full suite: \`npm test\`'." >&2
  exit 2
fi

if [ -n "$CURRENT_TASK_ID" ] && hook_tdd_is_required_for_current_task; then
  if [ "$(hook_state_get_active_task_tdd_field red_observed)" != "true" ]; then
    echo "RELEASE GATE BLOCKED: active task is missing valid Red evidence." >&2
    echo "Task: $CURRENT_TASK_ID" >&2
    echo "Run a recognized test command that fails for the task before marking completion." >&2
    exit 2
  fi
  if [ "$(hook_state_get_active_task_tdd_field green_observed)" != "true" ]; then
    echo "RELEASE GATE BLOCKED: active task is missing Green evidence after Red." >&2
    echo "Task: $CURRENT_TASK_ID" >&2
    echo "Run a recognized passing test command after the recorded Red before marking completion." >&2
    exit 2
  fi
  if ! hook_tdd_task_complete_allowed; then
    echo "RELEASE GATE BLOCKED: task-complete TDD evidence is not yet valid." >&2
    echo "Task: $CURRENT_TASK_ID" >&2
    exit 2
  fi
fi

if [ -n "$CURRENT_TASK_ID" ] && [ "$(hook_state_get '.manual_ack.required // false')" = "true" ]; then
  if [ "$(hook_state_get_active_task_manual_ack_field acknowledged)" != "true" ]; then
    echo "RELEASE GATE BLOCKED: active task requires manual acknowledgement." >&2
    echo "Task: $CURRENT_TASK_ID" >&2
    echo "Run: bash scripts/workflow/acknowledge-task.sh \"<note>\"" >&2
    exit 2
  fi
fi

if [ -n "$CURRENT_TASK_ID" ] && [ "$(hook_state_get '.semantic_checks.required // false')" = "true" ]; then
  SEMANTIC_JSON="$("$HOOK_PYTHON_BIN" scripts/workflow/evaluate-semantic-checks.py 2>/dev/null || true)"
  if [ -z "$SEMANTIC_JSON" ]; then
    echo "RELEASE GATE BLOCKED: semantic checks could not be evaluated." >&2
    echo "Task: $CURRENT_TASK_ID" >&2
    exit 2
  fi

  hook_state_update_current_task_semantic_checks "$SEMANTIC_JSON" >/dev/null 2>&1 || true

  if [ "$(hook_state_get_active_task_semantic_field status)" = "fail" ]; then
    echo "RELEASE GATE BLOCKED: semantic checks failed." >&2
    echo "Task: $CURRENT_TASK_ID" >&2
    echo "Failing checks: $(hook_state_get_active_task_semantic_field failing_count)" >&2
    exit 2
  fi
fi

if [ -n "$CURRENT_TASK_ID" ] && hook_evaluator_is_required_for_current_task; then
  EVALUATOR_VERDICT="$(hook_evaluator_get_active_field verdict)"
  EVALUATOR_RESULT_PATH="$(hook_evaluator_get_active_field result_path)"

  if [ -z "$EVALUATOR_RESULT_PATH" ]; then
    echo "RELEASE GATE BLOCKED: evaluator review is required but no result artifact is recorded." >&2
    echo "Task: $CURRENT_TASK_ID" >&2
    echo "Write the evaluator result to $(hook_evaluator_default_result_path) and record it before marking completion." >&2
    exit 2
  fi
  if [ ! -f "$EVALUATOR_RESULT_PATH" ]; then
    echo "RELEASE GATE BLOCKED: evaluator result artifact is missing." >&2
    echo "Task: $CURRENT_TASK_ID" >&2
    echo "Expected artifact: $EVALUATOR_RESULT_PATH" >&2
    exit 2
  fi
  if ! hook_evaluator_result_is_valid "$EVALUATOR_RESULT_PATH"; then
    echo "RELEASE GATE BLOCKED: evaluator result artifact is malformed or does not match the active task." >&2
    echo "Task: $CURRENT_TASK_ID" >&2
    echo "Artifact: $EVALUATOR_RESULT_PATH" >&2
    exit 2
  fi
  if [ "$EVALUATOR_VERDICT" = "pending" ]; then
    echo "RELEASE GATE BLOCKED: evaluator review is still pending." >&2
    echo "Task: $CURRENT_TASK_ID" >&2
    echo "Artifact: $EVALUATOR_RESULT_PATH" >&2
    exit 2
  fi
  if [ "$EVALUATOR_VERDICT" = "fail" ]; then
    echo "RELEASE GATE BLOCKED: evaluator review reported blocking findings." >&2
    echo "Task: $CURRENT_TASK_ID" >&2
    echo "Artifact: $EVALUATOR_RESULT_PATH" >&2
    exit 2
  fi
  if ! hook_evaluator_completion_allowed; then
    echo "RELEASE GATE BLOCKED: evaluator evidence does not yet satisfy completion rules." >&2
    echo "Task: $CURRENT_TASK_ID" >&2
    echo "Verdict: $EVALUATOR_VERDICT" >&2
    echo "Independence verified: $(hook_evaluator_get_active_field independence_verified)" >&2
    echo "Quality gate passed: $(hook_evaluator_get_active_field quality_gate_passed)" >&2
    exit 2
  fi
fi

if ! printf '%s' "$VALIDATION_MODES" | grep -q '"tests"'; then
  echo "Release gate: active task $CURRENT_TASK_ID ($TASK_TYPE) in phase $CURRENT_PHASE"
  exit 0
else
  echo "Release gate: running $TEST_CMD"
  if [ -n "$CURRENT_TASK_ID" ]; then
    echo "Release gate: active task $CURRENT_TASK_ID in phase $CURRENT_PHASE"
  fi

  TMP_OUT="$(mktemp)"
  if eval "$TEST_CMD" >"$TMP_OUT" 2>&1; then
    hook_state_record_test_result "$TEST_CMD" "pass" >/dev/null 2>&1 || true
    rm -f "$TMP_OUT"
    exit 0
  fi

  hook_state_record_test_result "$TEST_CMD" "fail" >/dev/null 2>&1 || true

  echo "RELEASE GATE BLOCKED: declared validation did not pass." >&2
  echo "Command: $TEST_CMD" >&2
  if [ -n "$CURRENT_TASK_ID" ]; then
    echo "Task: $CURRENT_TASK_ID" >&2
  fi
  echo "" >&2
  echo "Failure output (last 40 lines):" >&2
  tail -40 "$TMP_OUT" >&2
  rm -f "$TMP_OUT"

  echo "" >&2
  echo "Fix the failing validation before marking the task complete." >&2

  exit 2
fi
