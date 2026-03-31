#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/hooks/common.sh"

cd "$ROOT_DIR"

SPEC_PATH="${1:-}"
if [ -n "$SPEC_PATH" ]; then
  hook_state_sync "$SPEC_PATH" >/dev/null
elif ACTIVE_SPEC="$(hook_state_infer_active_spec)" && [ -n "$ACTIVE_SPEC" ] && [ -f "$ACTIVE_SPEC" ]; then
  hook_state_sync "$ACTIVE_SPEC" >/dev/null
fi

"${HOOK_PYTHON_BIN:-python}" "$SCRIPT_DIR/select-next-task.py" --apply
