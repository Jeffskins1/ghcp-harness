#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

INPUT="$(cat)"
COMMAND="$(hook_extract_command "$INPUT")"
EXIT_CODE="$(hook_extract_exit_code "$INPUT")"
OUTPUT="$(hook_extract_output "$INPUT")"
CWD="$(hook_project_dir "$INPUT")"

cd "$CWD" 2>/dev/null || exit 0

if ! hook_is_test_command "$COMMAND"; then
  exit 0
fi

ACTIVE_SPEC="$(hook_state_infer_active_spec)"
if [ -n "$ACTIVE_SPEC" ] && [ -f "$ACTIVE_SPEC" ]; then
  hook_state_sync "$ACTIVE_SPEC" >/dev/null 2>&1 || true
fi

if [ "$EXIT_CODE" -eq 0 ]; then
  hook_state_record_test_result "$COMMAND" "pass" >/dev/null 2>&1 || true
  if hook_tdd_is_required_for_current_task; then
    if [ "$(hook_state_get_active_task_tdd_field red_observed)" = "true" ]; then
      hook_tdd_record_green "$COMMAND"
    else
      hook_tdd_record_test_outcome "pass" "red"
    fi
  fi
  exit 0
fi

hook_state_record_test_result "$COMMAND" "fail" >/dev/null 2>&1 || true

RED_STATUS_MESSAGE=""
if hook_tdd_is_required_for_current_task; then
  if hook_tdd_failure_counts_as_red "$COMMAND" "$OUTPUT"; then
    hook_tdd_record_red "$COMMAND"
    RED_STATUS_MESSAGE="Valid Red recorded for the active task. Next phase: implement the minimum change to make the test pass."
  else
    hook_tdd_record_test_outcome "fail" "red"
    RED_STATUS_MESSAGE="Failure detected, but it did not count as a valid Red because it looks like an infrastructure/setup problem rather than a task-scoped failing test."
  fi
fi

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
FAILURE_SNIPPET="$(printf '%s' "$OUTPUT" | tail -60)"

jq -n \
  --arg ts "$TIMESTAMP" \
  --arg cmd "$COMMAND" \
  --arg snippet "$FAILURE_SNIPPET" \
  --arg tdd "$RED_STATUS_MESSAGE" \
  --argjson code "$EXIT_CODE" \
  '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": (
        "TEST FAILURE at " + $ts + "\n" +
        "Command: " + $cmd + "\n" +
        "Exit code: " + ($code | tostring) + "\n\n" +
        "Failure output (last 60 lines):\n" +
        "----------------------------------------\n" +
        $snippet + "\n" +
        "----------------------------------------\n\n" +
        (if $tdd != "" then $tdd + "\n\n" else "" end) +
        "Required next step: use debugging.md to fix the failure before continuing."
      )
    }
  }'

exit 0
