#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Hook: PreToolUse (matcher: Bash)
# Fires: Before any Bash tool call
# Output: JSON — deny dangerous commands, ask for risky ones, allow safe ones
# Purpose: Prevent irreversible actions; enforce branch discipline
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

INPUT=$(cat)
COMMAND="$(hook_extract_command "$INPUT")"

[ -z "$COMMAND" ] && exit 0

# ── HARD DENY ─────────────────────────────────────────────────────────────────

# Force push to protected branches
if echo "$COMMAND" | grep -qE 'git push.*(--force|-f)' && \
   echo "$COMMAND" | grep -qE '\b(main|master|develop|production|release)\b'; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "Force push to a protected branch is blocked. Use a feature branch and open an MR. If this is truly needed, a human must run the command manually."
    }
  }'
  exit 0
fi

# Skip commit hooks
if echo "$COMMAND" | grep -qE 'git commit.*(--no-verify|-n\b)'; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "--no-verify bypasses pre-commit hooks and is blocked. Fix the underlying hook failure instead of skipping it."
    }
  }'
  exit 0
fi

# Destructive removal of source directories
if echo "$COMMAND" | grep -qE 'rm -rf.*(src|app|lib|components|services|tests?|spec)/'; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "Bulk removal of source directories is blocked. Delete specific files instead, or use the Edit tool to clear file content."
    }
  }'
  exit 0
fi

# Destructive SQL without WHERE (basic check)
if echo "$COMMAND" | grep -qiE '(DROP TABLE|TRUNCATE TABLE|DELETE FROM [a-zA-Z_]+\s*;)'; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "Destructive SQL statement blocked. Use migration files for schema changes. DELETE statements must include a WHERE clause."
    }
  }'
  exit 0
fi

# Direct commit to main/master (committing while on protected branch)
if echo "$COMMAND" | grep -qE '^git commit' && ! echo "$COMMAND" | grep -qE 'git commit.*-m'; then
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  if echo "$CURRENT_BRANCH" | grep -qE '^(main|master|develop|production)$'; then
    jq -n --arg branch "$CURRENT_BRANCH" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": ("Direct commit to " + $branch + " is blocked. Create a feature branch first: git checkout -b feat/[description]")
      }
    }'
    exit 0
  fi
fi

# ── SOFT ASK ──────────────────────────────────────────────────────────────────

# New dependency installs
if echo "$COMMAND" | grep -qE '^(npm install|npm i|yarn add|pip install|cargo add|go get|gem install) [a-zA-Z@]'; then
  PACKAGE=$(echo "$COMMAND" | sed -E 's/^(npm install|npm i|yarn add|pip install|cargo add|go get|gem install) //' | awk '{print $1}')
  jq -n --arg pkg "$PACKAGE" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "ask",
      "permissionDecisionReason": ("New dependency: \"" + $pkg + "\". Confirm this package is not already in the project and is within scope for the active task.")
    }
  }'
  exit 0
fi

# Committing everything (git commit -a)
if echo "$COMMAND" | grep -qE 'git commit -a|git commit --all'; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "ask",
      "permissionDecisionReason": "git commit -a stages all tracked changes. Confirm no unrelated files will be included in this commit."
    }
  }'
  exit 0
fi

# Database migrations (creating new ones)
if echo "$COMMAND" | grep -qE '(migrate:create|migration:generate|alembic revision|rails generate migration|sequelize migration:generate)'; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "ask",
      "permissionDecisionReason": "Database migration creation detected. Confirm the migration name is descriptive and this is the right time to create it (architecture should be locked before generating migrations)."
    }
  }'
  exit 0
fi

exit 0
