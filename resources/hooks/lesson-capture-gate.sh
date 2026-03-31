#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Hook: Stop
# Fires: When the main agent finishes its turn
# Output: Exit 2 + stderr message to block stop and prompt lesson capture
# Purpose: Prevent sessions from ending without writing back persistent lessons
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

INPUT=$(cat)
STOP_HOOK_ACTIVE="$(hook_extract_stop_active "$INPUT")"
TRANSCRIPT_PATH="$(hook_extract_transcript_path "$INPUT")"
CWD="$(hook_project_dir "$INPUT")"

cd "$CWD" 2>/dev/null || exit 0

# ── Guard against infinite loop ───────────────────────────────────────────────
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# ── Need a transcript to inspect ─────────────────────────────────────────────
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0
fi

# ── Check if any code changes were made this session ─────────────────────────
# Look for Write or Edit tool uses in the transcript
EDIT_COUNT=$(grep -c '"tool_name"\s*:\s*"\(Write\|Edit\)"' "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)

if [ "$EDIT_COUNT" -eq 0 ]; then
  # No file changes this session — no lesson capture needed
  exit 0
fi

# ── Check if the context file was updated this session ───────────────────────
# If copilot-instructions.md or AGENTS.md was written, lessons were likely captured
CONTEXT_UPDATED=$(grep -c \
  '"file_path"\s*:\s*".*\(copilot-instructions\.md\|AGENTS\.md\)"' \
  "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)

if [ "$CONTEXT_UPDATED" -gt 0 ]; then
  # Lessons written — session closed cleanly
  exit 0
fi

# ── Determine which context file to point at ─────────────────────────────────
CONTEXT_FILE="$(hook_context_file)"
[ -z "$CONTEXT_FILE" ] && CONTEXT_FILE="repo context file (not yet created)"

# ── Block stop and prompt for lesson capture ──────────────────────────────────
echo "LESSON CAPTURE GATE" >&2
echo "" >&2
echo "This session made $EDIT_COUNT file edit(s) but the persistent lessons file" >&2
echo "($CONTEXT_FILE) was not updated." >&2
echo "" >&2
echo "Before ending, either:" >&2
echo "  A) Append any repeatable lesson to $CONTEXT_FILE under 'Persistent Lessons'" >&2
echo "     Format: [$(date '+%Y-%m-%d')] — [what happened] — [rule going forward]" >&2
echo "" >&2
echo "  B) Confirm explicitly: 'No new lessons from this session'" >&2
echo "" >&2
echo "This gate exists because lessons compound in value. Missing one costs future" >&2
echo "sessions the same mistake. It takes 30 seconds to write." >&2

exit 2
