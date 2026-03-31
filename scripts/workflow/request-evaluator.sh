#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/hooks/common.sh"

cd "$ROOT_DIR"

if ! hook_evaluator_is_required_for_current_task; then
  echo "Active task does not require evaluator review." >&2
  exit 1
fi

REVIEW_MODE="${1:-fresh_session}"
if [ "$REVIEW_MODE" != "fresh_session" ] && [ "$REVIEW_MODE" != "same_session" ]; then
  echo "Review mode must be fresh_session or same_session." >&2
  exit 1
fi

PACKET_PATH="$(hook_evaluator_default_packet_path)"

hook_state_update_current_task_evaluator "$("$HOOK_PYTHON_BIN" - "$REVIEW_MODE" "$PACKET_PATH" "$(hook_state_get '.current_task_id // empty')" "$(hook_state_now)" "$(hook_state_current_session_id)" <<'PY'
import json
import sys

review_mode, packet_path, task_id, now, generator_session = sys.argv[1:6]
packet_id = f"eval-packet-task-{task_id}-{now.replace(':', '').replace('-', '')}"
print(json.dumps({
    "status": "pending",
    "verdict": "pending",
    "review_mode": review_mode,
    "packet_id": packet_id,
    "packet_path": packet_path,
    "launch_recorded_at": now,
    "generator_session": generator_session,
    "independence_verified": False,
    "quality_gate_passed": False,
    "quality_issues": [],
    "applied_review_modes": [],
}))
PY
)"

hook_evaluator_emit_packet
