#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Hook: PreToolUse (matcher: Write|Edit)
# Fires: Before any Write or Edit tool call
# Output: JSON — deny or ask for protected paths, allow otherwise
# Purpose: Enforce the Agent Constraints / protected paths from the context file
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

INPUT=$(cat)
CWD="$(hook_project_dir "$INPUT")"
FILE_PATH="$(hook_extract_file_path "$INPUT")"

cd "$CWD" 2>/dev/null || exit 0

[ -z "$FILE_PATH" ] && exit 0

# ── Hard-deny patterns (never edit without a human in the loop) ───────────────
HARD_DENY=(
  "\.env$"
  "\.env\."
  "migrations/"
  ".github/workflows/"
)

for pattern in "${HARD_DENY[@]}"; do
  if echo "$FILE_PATH" | grep -qE "$pattern"; then
    jq -n --arg path "$FILE_PATH" --arg pattern "$pattern" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": ("BLOCKED: " + $path + " matches hard-deny pattern \"" + $pattern + "\". This file requires explicit human instruction to modify. Check the Agent Constraints section in copilot-instructions.md.")
      }
    }'
    exit 0
  fi
done

# ── Soft-ask patterns (confirm before editing) ────────────────────────────────
SOFT_ASK=(
  "package\.json$"
  "package-lock\.json$"
  "yarn\.lock$"
  "build\.gradle"
  "pom\.xml$"
  "go\.mod$"
  "Cargo\.toml$"
  "pyproject\.toml$"
  "requirements\.txt$"
  "Gemfile$"
  "\.gitignore$"
  "Dockerfile"
  "docker-compose"
)

for pattern in "${SOFT_ASK[@]}"; do
  if echo "$FILE_PATH" | grep -qE "$pattern"; then
    jq -n --arg path "$FILE_PATH" --arg pattern "$pattern" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": ("CONFIRM REQUIRED: " + $path + " is a dependency or config file. Changes here affect all developers. Confirm this edit is intentional and in scope for the active task.")
      }
    }'
    exit 0
  fi
done

# ── Project-specific protected paths from repo hook config ─────────────────────
PROTECTED_PATHS_FILE="$(hook_protected_paths_file)"
if [ -n "$PROTECTED_PATHS_FILE" ] && [ -f "$PROTECTED_PATHS_FILE" ]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue
    if echo "$FILE_PATH" | grep -qF "$line"; then
      jq -n --arg path "$FILE_PATH" --arg rule "$line" '{
        "hookSpecificOutput": {
          "hookEventName": "PreToolUse",
          "permissionDecision": "ask",
          "permissionDecisionReason": ("CONFIRM REQUIRED: " + $path + " matches protected rule \"" + $rule + "\" from repo protected-paths. Confirm this edit is intentional.")
        }
      }'
      exit 0
    fi
  done < "$PROTECTED_PATHS_FILE"
fi

ACTIVE_SPEC="$(hook_state_infer_active_spec)"
if [ -n "$ACTIVE_SPEC" ] && [ -f "$ACTIVE_SPEC" ]; then
  hook_state_sync "$ACTIVE_SPEC" >/dev/null 2>&1 || true
fi

if hook_tdd_is_required_for_current_task; then
  if hook_tdd_is_test_path "$FILE_PATH"; then
    if [ "$(hook_state_get_active_task_tdd_field red_observed)" = "true" ]; then
      jq -n --arg path "$FILE_PATH" '{
        "hookSpecificOutput": {
          "hookEventName": "PreToolUse",
          "permissionDecision": "ask",
          "permissionDecisionReason": ("TDD CHECK: " + $path + " is a test file and the active task already has Red recorded. Confirm this test edit is intentional. If approved and applied, the harness will invalidate current TDD evidence and require a fresh Red/Green cycle.")
        }
      }'
      exit 0
    fi
    exit 0
  fi

  if hook_tdd_is_implementation_path "$FILE_PATH" && [ "$(hook_state_get_active_task_tdd_field red_observed)" != "true" ]; then
    jq -n --arg path "$FILE_PATH" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": ("TDD CHECK: " + $path + " looks like implementation code, but the active task has no valid Red yet. Write or update the failing test first, run it, and let the harness record Red evidence before implementation edits.")
      }
    }'
    exit 0
  fi
fi

exit 0
