#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

INPUT="$(cat 2>/dev/null || true)"
CWD="$(hook_project_dir "$INPUT")"
FILE_PATH="$(hook_extract_file_path "$INPUT")"

cd "$CWD" 2>/dev/null || exit 0

[ -z "$FILE_PATH" ] && exit 0

ACTIVE_SPEC="$(hook_state_infer_active_spec)"
if [ -n "$ACTIVE_SPEC" ] && [ -f "$ACTIVE_SPEC" ]; then
  hook_state_sync "$ACTIVE_SPEC" >/dev/null 2>&1 || true
fi

if ! hook_tdd_is_required_for_current_task; then
  exit 0
fi

if ! hook_tdd_is_test_path "$FILE_PATH"; then
  exit 0
fi

if [ "$(hook_state_get_active_task_tdd_field red_observed)" != "true" ] && [ "$(hook_state_get_active_task_tdd_field green_observed)" != "true" ]; then
  exit 0
fi

hook_tdd_invalidate_due_to_test_edit "$FILE_PATH"

exit 0
