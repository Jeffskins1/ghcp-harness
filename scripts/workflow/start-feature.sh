#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/hooks/common.sh"

cd "$ROOT_DIR"

SPEC_PATH="${1:-}"
if [ -z "$SPEC_PATH" ]; then
  SPEC_PATH="$(hook_state_infer_active_spec)"
fi

if [ -z "$SPEC_PATH" ] || [ ! -f "$SPEC_PATH" ]; then
  echo "Feature spec not found." >&2
  exit 1
fi

hook_state_sync "$SPEC_PATH" >/dev/null
"${HOOK_PYTHON_BIN:-python}" "$SCRIPT_DIR/select-next-task.py" --apply
