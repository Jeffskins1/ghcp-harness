#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# ICTT Git Hooks Installer
# Run once per developer per repo: bash scripts/hooks/git/install.sh
# Copies git hooks into .git/hooks/ and makes them executable
# ─────────────────────────────────────────────────────────────────────────────

set -e

# ── Locate the .git directory ─────────────────────────────────────────────────
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null)
if [ -z "$GIT_DIR" ]; then
  echo "ERROR: Not inside a git repository. Run from the repo root." >&2
  exit 1
fi

HOOKS_DIR="$GIT_DIR/hooks"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  Installing ICTT git hooks into $HOOKS_DIR/"
echo ""

INSTALLED=0
SKIPPED=0
BACKED_UP=0

for hook in commit-msg pre-commit pre-push; do
  SRC="$SCRIPT_DIR/$hook"
  DEST="$HOOKS_DIR/$hook"

  if [ ! -f "$SRC" ]; then
    echo "  WARNING: $hook not found at $SRC — skipping" >&2
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Back up any existing hook that isn't ours
  if [ -f "$DEST" ] && ! grep -q "ICTT" "$DEST" 2>/dev/null; then
    BACKUP="$DEST.backup-$(date '+%Y%m%d%H%M%S')"
    cp "$DEST" "$BACKUP"
    echo "  ⚠ Backed up existing $hook → $(basename "$BACKUP")"
    BACKED_UP=$((BACKED_UP + 1))
  fi

  cp "$SRC" "$DEST"
  chmod +x "$DEST"
  echo "  ✓ $hook"
  INSTALLED=$((INSTALLED + 1))
done

echo ""
echo "  Done: $INSTALLED installed, $SKIPPED skipped, $BACKED_UP backed up"
echo ""
echo "  Hooks installed:"
echo "    commit-msg  — enforces conventional commit format"
echo "    pre-commit  — secrets scan, .env guard, lint"
echo "    pre-push    — blocks push to main/master, runs test suite"
echo ""
echo "  To verify: git commit --allow-empty -m 'bad message' (should be rejected)"
echo ""
