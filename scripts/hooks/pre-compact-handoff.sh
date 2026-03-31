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
TIMESTAMP="$(date '+%Y-%m-%d %H:%M')"

if [ -f "$STATE_FILE" ]; then
  CHECKPOINT_NOTE="Compaction at $TIMESTAMP"
  hook_state_mark_handoff "$CHECKPOINT_NOTE" >/dev/null 2>&1 || true
  echo "Pre-compact checkpoint written to $STATE_FILE"
  echo "Active spec: $(hook_state_get '.active_spec // "none"')"
  echo "Current task: $(hook_state_get '.current_task_id // "none"')"
  echo "Current phase: $(hook_state_get '.current_phase // "intent"')"
else
  echo "Pre-compact notice: no workflow state file found."
fi

echo "Context compaction starting. Resume from the state file and active spec after compaction."

exit 0
