#!/usr/bin/env bash

hook_evaluator_is_required_for_current_task() {
  local state_file
  state_file="$(hook_state_file)"
  [ -f "$state_file" ] || return 1
  [ -n "$(hook_state_get '.current_task_id // empty')" ] || return 1

  [ "$(hook_state_get '.evaluator.required // false')" = "true" ]
}

hook_evaluator_get_active_field() {
  local field="$1"
  hook_state_get_active_task_evaluator_field "$field"
}

hook_evaluator_default_result_path() {
  local task_id
  task_id="$(hook_state_get '.current_task_id // empty')"
  if [ -z "$task_id" ]; then
    printf '%s\n' "$(hook_state_dir)/evaluator-result.json"
    return
  fi

  printf '%s\n' "$(hook_state_dir)/evaluator-result-task-${task_id}.json"
}

hook_evaluator_default_packet_path() {
  local task_id
  task_id="$(hook_state_get '.current_task_id // empty')"
  if [ -z "$task_id" ]; then
    printf '%s\n' "$(hook_state_dir)/evaluator-packet.md"
    return
  fi

  printf '%s\n' "$(hook_state_dir)/evaluator-packet-task-${task_id}.md"
}

hook_evaluator_result_is_valid() {
  local result_path="${1:-$(hook_evaluator_get_active_field result_path)}"
  local root_dir
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

  [ -n "$result_path" ] || return 1
  [ -f "$result_path" ] || return 1

  "$HOOK_PYTHON_BIN" "$root_dir/scripts/workflow/write-evaluator-result.py" --validate-only "$result_path" >/dev/null 2>&1
}

hook_evaluator_record_result() {
  local result_path="$1"
  local root_dir
  root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

  [ -n "$result_path" ] || return 1
  "$HOOK_PYTHON_BIN" "$root_dir/scripts/workflow/write-evaluator-result.py" "$result_path" >/dev/null
}

hook_evaluator_completion_allowed() {
  local result_path
  local verdict

  if ! hook_evaluator_is_required_for_current_task; then
    return 0
  fi

  verdict="$(hook_evaluator_get_active_field verdict)"
  result_path="$(hook_evaluator_get_active_field result_path)"

  [ -n "$result_path" ] || return 1
  [ "$verdict" = "pass" ] || [ "$verdict" = "pass_with_risks" ] || return 1
  [ "$(hook_evaluator_get_active_field independence_verified)" = "true" ] || return 1
  [ "$(hook_evaluator_get_active_field quality_gate_passed)" = "true" ] || return 1
  hook_evaluator_result_is_valid "$result_path"
}

hook_evaluator_emit_packet() {
  local output_path="${1:-$(hook_evaluator_default_packet_path)}"
  local state_file
  state_file="$(hook_state_file)"

  [ -f "$state_file" ] || return 1

  hook_state_ensure_dir

  "$HOOK_PYTHON_BIN" - "$state_file" "$output_path" "$(hook_evaluator_default_result_path)" <<'PY'
import json
import os
import sys

state_path, output_path, default_result_path = sys.argv[1:4]

with open(state_path, encoding="utf-8") as handle:
    state = json.load(handle)

current_task_id = state.get("current_task_id") or "none"
task = next((item for item in state.get("task_list_snapshot", []) if item.get("id") == current_task_id), None) or {}
task_title = task.get("title", "")
evaluator = task.get("evaluator") or {}
result_path = evaluator.get("result_path") or default_result_path
review_modes = task.get("adversarial_review_modes", [])
validation_modes = task.get("validation_modes", [])
changed_files = []
session_notes = state.get("session_handoff", {}).get("notes") or ""
for raw_line in session_notes.splitlines():
    line = raw_line.strip()
    if line.lower().startswith("files changed:"):
        changed_files = [item.strip() for item in line.split(":", 1)[1].split(",") if item.strip()]
        break

lines = [
    "# Evaluator Packet",
    "",
    f"- Feature: {state.get('active_feature', 'unknown')}",
    f"- Active spec: {state.get('active_spec', 'unknown')}",
    f"- Task: {current_task_id} - {task_title}".rstrip(),
    f"- Task type: {task.get('task_type', 'code')}",
    f"- Validation modes: {', '.join(validation_modes) if validation_modes else 'none'}",
    f"- Done when: {task.get('done_when', '')}",
    f"- Evaluator review required: {'YES' if task.get('evaluator_required') else 'NO'}",
    f"- Independence policy: {evaluator.get('independence_policy') or task.get('independence_policy', 'none')}",
    f"- Generator session: {evaluator.get('generator_session') or state.get('generator_session', 'unknown')}",
    f"- Evaluator packet id: {evaluator.get('packet_id') or 'missing'}",
    f"- Exact test command: {state.get('last_test_command') or 'missing'}",
    f"- Last test result: {state.get('last_test_result') or 'unknown'}",
    f"- Evaluator result path: {result_path}",
    f"- Adversarial review modes: {', '.join(review_modes) if review_modes else 'none'}",
    "",
    "Review instructions:",
    "1. Read the context file and active spec before implementation details.",
    "2. Review against the acceptance criteria and task done condition, not implementation intent.",
    "3. Satisfy the declared independence policy before recording a verdict.",
    "4. Apply every listed adversarial review mode explicitly before deciding the verdict.",
    "5. Produce a structured JSON result with verdict `pass`, `pass_with_risks`, or `fail`.",
    "6. Include packet_id, applied_review_modes, criterion-by-criterion status, findings, and residual risks.",
    "",
]

if task.get("semantic_checks"):
    lines.append("Semantic checks:")
    for check in task.get("semantic_checks", []):
        rendered = ", ".join(f"{key}={value}" for key, value in check.items())
        lines.append(f"- {rendered}")
    lines.append("")

if changed_files:
    lines.append("Changed files:")
    for path in changed_files:
        lines.append(f"- {path}")
    lines.append("")

lines.extend([
    "Structured result requirements:",
    "- Required fields: feature, task_id, packet_id, verdict, review_mode, reviewed_at, reviewer_session, applied_review_modes, criteria_results, findings",
    "- Criteria statuses: MET, PARTIALLY MET, NOT MET",
    "- Findings must include severity, blocking, summary, and evidence",
])

os.makedirs(os.path.dirname(output_path), exist_ok=True)
with open(output_path, "w", encoding="utf-8") as handle:
    handle.write("\n".join(lines).rstrip() + "\n")
PY

  printf '%s\n' "$output_path"
}
