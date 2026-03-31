#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/hooks/common.sh"

cd "$ROOT_DIR"

NOTE="${1:-Manual acknowledgement recorded.}"
ACK_BY="${HARNESS_SESSION_ID:-${CODEX_SESSION_ID:-${COPILOT_SESSION_ID:-manual-session}}}"

hook_state_update_current_task_manual_ack "$("$HOOK_PYTHON_BIN" - "$NOTE" "$ACK_BY" <<'PY'
import json
import sys

note, acknowledged_by = sys.argv[1:3]
print(json.dumps({
    "acknowledged": True,
    "acknowledged_by": acknowledged_by,
    "note": note,
}))
PY
)"

echo "$NOTE"
