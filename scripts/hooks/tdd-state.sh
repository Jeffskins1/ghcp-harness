#!/usr/bin/env bash

hook_tdd_is_required_for_current_task() {
  local state_file
  state_file="$(hook_state_file)"
  [ -f "$state_file" ] || return 1
  [ -n "$(hook_state_get '.current_task_id // empty')" ] || return 1

  [ "$(hook_state_get_active_task_tdd_field mode)" = "required" ]
}

hook_tdd_is_test_path() {
  local path="$1"
  printf '%s' "$path" | grep -qiE '(^|/)(tests?|__tests__|test|specs?)/|(\.test\.[^/]+$)|(\.spec\.[^/]+$)'
}

hook_tdd_is_implementation_path() {
  local path="$1"
  if hook_tdd_is_test_path "$path"; then
    return 1
  fi

  printf '%s' "$path" | grep -qiE '(^|/)(src|app|lib|pkg|internal|server|client)/|(\.(c|cc|cpp|cs|go|java|js|jsx|kt|kts|php|py|rb|rs|swift|ts|tsx)$)'
}

hook_tdd_failure_counts_as_red() {
  local command="$1"
  local output="$2"

  if ! hook_is_test_command "$command"; then
    return 1
  fi

  local lower
  lower="$(printf '%s' "$output" | tr '[:upper:]' '[:lower:]')"
  if printf '%s' "$lower" | grep -qE 'command not found|is not recognized as an internal or external command|no such file or directory|missing script:|cannot find module|module not found|failed to resolve|dependency.*not found|package.*not found'; then
    return 1
  fi

  return 0
}

hook_tdd_record_red() {
  local command="$1"
  hook_state_update_current_task_tdd "$("$HOOK_PYTHON_BIN" - "$command" "$(hook_state_now)" <<'PY'
import json
import sys

command, now = sys.argv[1:3]
print(json.dumps({
    "red_observed": True,
    "green_observed": False,
    "refactor_allowed": False,
    "task_complete_allowed": False,
    "red_command": command,
    "red_recorded_at": now,
    "last_test_outcome": "fail",
    "phase": "green",
}))
PY
)" >/dev/null 2>&1 || true
}

hook_tdd_record_green() {
  local command="$1"
  hook_state_update_current_task_tdd "$("$HOOK_PYTHON_BIN" - "$command" "$(hook_state_now)" <<'PY'
import json
import sys

command, now = sys.argv[1:3]
print(json.dumps({
    "green_observed": True,
    "refactor_allowed": True,
    "task_complete_allowed": True,
    "green_command": command,
    "green_recorded_at": now,
    "last_test_outcome": "pass",
    "phase": "refactor",
}))
PY
)" >/dev/null 2>&1 || true
}

hook_tdd_record_test_outcome() {
  local outcome="$1"
  local phase="${2:-}"
  hook_state_update_current_task_tdd "$("$HOOK_PYTHON_BIN" - "$outcome" "$phase" <<'PY'
import json
import sys

outcome, phase = sys.argv[1:3]
patch = {"last_test_outcome": outcome}
if phase:
    patch["phase"] = phase
print(json.dumps(patch))
PY
)" >/dev/null 2>&1 || true
}

hook_tdd_task_complete_allowed() {
  [ "$(hook_state_get_active_task_tdd_field task_complete_allowed)" = "true" ]
}

hook_tdd_invalidate_due_to_test_edit() {
  local path="$1"
  hook_state_update_current_task_tdd "$("$HOOK_PYTHON_BIN" - "$path" "$(hook_state_now)" <<'PY'
import json
import sys

path, now = sys.argv[1:3]
print(json.dumps({
    "red_observed": False,
    "green_observed": False,
    "refactor_allowed": False,
    "task_complete_allowed": False,
    "red_command": None,
    "green_command": None,
    "red_recorded_at": None,
    "green_recorded_at": None,
    "last_test_outcome": None,
    "phase": "red",
}))
PY
)" >/dev/null 2>&1 || true
}
