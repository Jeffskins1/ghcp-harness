#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/common.sh"

INPUT="$(cat)"
CWD="$(hook_project_dir "$INPUT")"
PROMPT="$(hook_extract_prompt "$INPUT")"

cd "$CWD" 2>/dev/null || exit 0

if [ -z "$PROMPT" ]; then
  exit 0
fi

if printf '%s' "$PROMPT" | grep -qiE \
  'setup|install|inspect|configure|repo[ -]?setup|create.*spec|brainstorm|discovery|review|debug|explain|what|how|why|list|show|read|summari[sz]e|document|plan|handoff'; then
  exit 0
fi

if printf '%s' "$PROMPT" | grep -qiE 'spec\.md|specs/|active spec|implementation plan'; then
  exit 0
fi

if ! printf '%s' "$PROMPT" | grep -qiE \
  'build|implement|add feature|write code|fix bug|create endpoint|ship|code this|make the change|update the feature|deliver|complete the task'; then
  exit 0
fi

if printf '%s' "$PROMPT" | grep -qi 'override spec guard'; then
  exit 0
fi

ACTIVE_SPEC="$(hook_state_infer_active_spec)"
if [ -n "$ACTIVE_SPEC" ] && [ -f "$ACTIVE_SPEC" ]; then
  hook_state_sync "$ACTIVE_SPEC" >/dev/null 2>&1 || true
  exit 0
fi

echo "SPEC GUARD BLOCKED: implementation work requires an active spec." >&2
echo "Create or select a feature spec under specs/features/ first." >&2
echo "If a human intentionally wants to proceed without a spec, resubmit with the exact phrase: override spec guard" >&2

exit 2
