#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/hooks/common.sh"

cd "$ROOT_DIR"

ACTIVE_SPEC="${1:-}"
if [ -n "$ACTIVE_SPEC" ] && [ -f "$ACTIVE_SPEC" ]; then
  hook_state_sync "$ACTIVE_SPEC" >/dev/null 2>&1 || true
else
  ACTIVE_SPEC="$(hook_state_infer_active_spec)"
  if [ -n "$ACTIVE_SPEC" ] && [ -f "$ACTIVE_SPEC" ]; then
    hook_state_sync "$ACTIVE_SPEC" >/dev/null 2>&1 || true
  fi
fi

if ! hook_evaluator_is_required_for_current_task; then
  echo "No evaluator-required active task found." >&2
  exit 1
fi

hook_evaluator_emit_packet "${2:-}"
