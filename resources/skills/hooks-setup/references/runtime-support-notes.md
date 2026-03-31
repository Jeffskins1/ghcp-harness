# Runtime Support Notes

- GitHub Copilot hooks are in **Preview** in both VS Code and IntelliJ as of
  March 2026. Behavior may change; check release notes when updating.
- IntelliJ currently exposes 4 events vs VS Code's 8. Use the shared
  `.github/hooks/hooks.json` - IntelliJ silently ignores events it does not
  support.
- Codex CLI hooks are **experimental** and require an opt-in feature flag.
  Only 3 events are available now; `PreToolUse` and `PostToolUse` are on the
  roadmap. Monitor the Codex CLI changelog at
  https://developers.openai.com/codex/changelog
- To disable a specific hook temporarily, comment it out of the relevant
  hooks.json rather than deleting it.
- Protected paths in `.github/hooks/protected-paths.txt` should be reviewed
  whenever the codebase structure changes significantly.
- Git hook scripts live in `scripts/hooks/git/` so they stay in sync across
  the team, but each developer must run `install.sh` once per clone.
