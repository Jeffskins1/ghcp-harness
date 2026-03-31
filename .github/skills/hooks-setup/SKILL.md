---
name: hooks-setup
description: Install and configure shared hook-based guardrails across Codex, Copilot, and Git workflows. Use when bootstrapping repo automation, validation gates, and session guardrails.
---

# Hooks Setup

## Overview

Install and configure shared hook-based guardrails across Codex, Copilot, and Git workflows. Use when bootstrapping repo automation, validation gates, and session guardrails.

## Quick Reference

- **Use when:** Use once per developer per repo, after the repo-setup skill. Run when a developer joins the team or when hooks are not yet installed on their local machine.
- **Output:** Agent-specific hook config wired, git hooks installed in .git/hooks/, and scripts committed to version control.
- **Duration:** 10-15 minutes. One-time per developer.
- **Phase:** C (Context Substrate) - harness layer, runs before any feature work.

## Bundled Resources

- `references/runtime-support-notes.md`: Load when you need runtime-specific hook support notes, preview limitations, or install caveats.

## Purpose

This skill installs two layers of automated guardrails that enforce ICTT
standards without requiring developers to remember to run them:

**Agent lifecycle hooks** - run inside each coding agent's session:
- GitHub Copilot (VS Code & IntelliJ): configured in `.github/hooks/hooks.json`
- Codex CLI: configured in `.codex/hooks.json` (experimental, opt-in)

**Git hooks** - run at commit and push time, agent-agnostic:
- `commit-msg`: enforces conventional commit format
- `pre-commit`: secrets scan, .env guard, lint
- `pre-push`: blocks direct push to main/master, runs test suite

## Hook Systems By Agent

### GitHub Copilot - VS Code & IntelliJ

Config file: `.github/hooks/hooks.json` (committed to version control)

VS Code and IntelliJ Copilot share the same config file format. Hooks are
picked up automatically when the file exists on the default branch. The file
must be in `.github/hooks/` - any `.json` filename in that folder is loaded.

**VS Code - 8 lifecycle events:**

| Event | Can block? | What it does |
|---|---|---|
| `SessionStart` | No | Loads context file, git state, active specs before first prompt |
| `UserPromptSubmit` | Yes | Warns or blocks when implementation starts without an active spec |
| `PreToolUse` | Yes (deny/ask/allow) | Guards file edits and protected paths |
| `PostToolUse` | Yes | Injects debugging context when test commands fail |
| `PreCompact` | No | Writes session state to active spec before context compaction |
| `SubagentStart` | No | Tracks subagent lifecycle for complex multi-step tasks |
| `SubagentStop` | No | Tracks subagent lifecycle for complex multi-step tasks |
| `TaskCompleted` | Yes | Runs the release gate before a task can be declared done |
| `Stop` | Yes | Blocks session close if code changed but no lessons written back |

**IntelliJ - 4 documented events (Preview as of March 2026):**

| Event | Can block? | What it does |
|---|---|---|
| `userPromptSubmitted` | Yes | Warns or blocks before a prompt enters the session |
| `preToolUse` | Yes | Guards file edits and protected paths |
| `postToolUse` | Yes | Injects debugging context when test commands fail |
| `errorOccurred` | No | Captures error state for logging or recovery actions |

Note: VS Code and IntelliJ share the same `.github/hooks/hooks.json`. Events
not recognized by IntelliJ are silently ignored, so a single shared file works
for repos where developers use both IDEs. `TaskCompleted` should be wired in
for runtimes that support it. If a runtime ignores it, keep the `pre-push`
hook as the fallback release gate.

Blocking behavior: exit with code `2` to deny. Return `permissionDecision:
"deny"` or `"ask"` from `PreToolUse` hooks to block or prompt. When multiple
hooks target the same event, the most restrictive result wins.

### Codex CLI

Config file: `.codex/hooks.json` (experimental - must be opted in)

Enable the hooks engine by passing the feature flag at session start:
```
codex -c features.codex_hooks=true
```
Or add to `~/.codex/config.toml` under `[features]` for persistent opt-in:
```toml
[features]
codex_hooks = true
```

**3 lifecycle events (as of v0.115.0):**

| Event | Can block? | What it does |
|---|---|---|
| `SessionStart` | No | Loads AGENTS.md context and active specs before first prompt |
| `UserPromptSubmit` | Yes | Warns or blocks prompts before they enter session history |
| `Stop` | No | Captures session state before session ends |

Note: More events are planned. `PreToolUse`, `PostToolUse`, and file-level
hooks are on the roadmap but not yet available. The hooks engine is under
active development.

### Git Hooks - All Agents & All Developers

Git hooks apply regardless of which coding agent a developer uses. They run
at commit and push time and are installed per developer per clone.

| Hook | Trigger | What it does |
|---|---|---|
| `commit-msg` | git commit | Rejects non-conventional commit messages |
| `pre-commit` | git commit | Secrets scan, .env guard, lint on staged files |
| `pre-push` | git push | Blocks push to main/master; runs test suite |

## Process

### Step 1 - Verify prerequisites

Check that the following exist. If any are missing, run the repo-setup skill:
- `.github/copilot-instructions.md` or `AGENTS.md` (context substrate)
- `specs/` folder
- `scripts/` folder (will be created in Step 2 if absent)

### Step 2 - Copy hook scripts

Copy all scripts from `resources/hooks/` into `scripts/hooks/` in the repo root.
Create the `scripts/hooks/` and `scripts/hooks/git/` folders if they don't exist.

```
scripts/
  hooks/
    session-start.sh
    spec-guard.sh
    file-guard.sh
    bash-guard.sh
    test-failure-capture.sh
    pre-compact-handoff.sh
    lesson-capture-gate.sh
    release-gate.sh
    state.sh
    tdd-state.sh
    evaluator-state.sh
    git/
      commit-msg
      pre-commit
      pre-push
      install.sh
```

Make all scripts executable:
```bash
chmod +x scripts/hooks/*.sh
chmod +x scripts/hooks/git/*
```

### Step 3 - Wire GitHub Copilot hooks

Create `.github/hooks/hooks.json` in the repo root. This file is shared by
VS Code and IntelliJ Copilot automatically.

Example structure (adapt event names and commands to your repo):
```json
{
  "hooks": [
    {
      "event": "SessionStart",
      "command": "bash scripts/hooks/session-start.sh"
    },
    {
      "event": "UserPromptSubmit",
      "command": "bash scripts/hooks/spec-guard.sh"
    },
    {
      "event": "PreToolUse",
      "command": "bash scripts/hooks/file-guard.sh",
      "timeout": 30
    },
    {
      "event": "PostToolUse",
      "command": "bash scripts/hooks/test-failure-capture.sh"
    },
    {
      "event": "PreCompact",
      "command": "bash scripts/hooks/pre-compact-handoff.sh"
    },
    {
      "event": "TaskCompleted",
      "command": "bash scripts/hooks/release-gate.sh",
      "timeout": 120
    },
    {
      "event": "Stop",
      "command": "bash scripts/hooks/lesson-capture-gate.sh"
    }
  ]
}
```

Commit this file to version control. All team members get the same hooks
automatically when they pull, regardless of which IDE they use.

`TaskCompleted` is where the harness enforces TDD proof, evaluator verdicts,
and the feature integration gate. For tasks marked `Evaluator review: YES`, the
release gate only allows completion after a valid evaluator result artifact has
been recorded into `.github/agent-state/active-run.json`. When all tasks are
complete, the gate additionally requires a full-suite integration run recorded
via `bash scripts/workflow/mark-integration-passed.sh` before release is allowed.

### Step 4 - Wire Codex CLI hooks (if team uses Codex CLI)

Create `.codex/hooks.json` in the repo root.

Example structure:
```json
{
  "hooks": [
    {
      "event": "SessionStart",
      "command": "bash scripts/hooks/session-start.sh"
    },
    {
      "event": "UserPromptSubmit",
      "command": "bash scripts/hooks/spec-guard.sh"
    },
    {
      "event": "Stop",
      "command": "bash scripts/hooks/lesson-capture-gate.sh"
    }
  ]
}
```

Commit this file. Each Codex user must also enable the hooks engine:
```bash
codex -c features.codex_hooks=true [prompt]
```
Or add `codex_hooks = true` under `[features]` in `~/.codex/config.toml`.

Note: Codex CLI hooks are experimental as of March 2026. Test carefully and
monitor the Codex CLI changelog for new events as they are added.

### Step 5 - Configure protected paths

Create `.github/hooks/protected-paths.txt` with repo-specific paths that
should require confirmation before the agent edits them.

Start with this baseline and add project-specific paths:

```
# .github/hooks/protected-paths.txt
# One pattern per line. Supports substring matching against file paths.
# Lines starting with # are comments.

# Core application boundaries
src/auth/
src/payments/
src/security/

# Infrastructure
infrastructure/
terraform/
k8s/
helm/

# Database
migrations/
seeds/

# CI/CD
.gitlab-ci.yml
.github/workflows/

# Secrets and environment
.env
.env.production
.env.staging
```

### Step 6 - Install git hooks

Run the git hooks installer for the developer's local machine:

```bash
bash scripts/hooks/git/install.sh
```

This copies `commit-msg`, `pre-commit`, and `pre-push` into `.git/hooks/`
and makes them executable. It backs up any existing hooks before overwriting.

**Note:** Git hooks are per-machine, not per-repo-clone. Every developer who
clones the repo must run this step. The scripts are version-controlled in
`scripts/hooks/git/` so they stay in sync, but each developer installs them
locally.

### Step 7 - Verify installation

```bash
# 1. Verify git hooks are installed
ls -la .git/hooks/commit-msg .git/hooks/pre-commit .git/hooks/pre-push

# 2. Test commit-msg hook (should be rejected)
git commit --allow-empty -m "bad commit message"
# Expected: "COMMIT REJECTED: Non-conventional commit format"

# 3. Test commit-msg hook (should pass)
git commit --allow-empty -m "chore: verify hooks installation"
# Expected: commit succeeds

# 4. Verify Copilot hooks config
cat .github/hooks/hooks.json | jq '.hooks | map(.event)'
# Expected: ["SessionStart","UserPromptSubmit","PreToolUse","PostToolUse","PreCompact","TaskCompleted","Stop"]

# 5. Verify Codex CLI hooks config (if applicable)
cat .codex/hooks.json | jq '.hooks | map(.event)'
# Expected: ["SessionStart","UserPromptSubmit","Stop"]
```

### Step 8 - Confirm and report

```
Installed:
  GITHUB COPILOT HOOKS
  [done] .github/hooks/hooks.json          <- Copilot hook wiring (VS Code & IntelliJ)
  [done] .github/hooks/protected-paths.txt <- Protected file rules

  CODEX CLI HOOKS (if applicable)
  [done] .codex/hooks.json                 <- Codex hook wiring
  ~ Each Codex user enables: codex -c features.codex_hooks=true

  HOOK SCRIPTS (shared by all agents)
  [done] scripts/hooks/session-start.sh
  [done] scripts/hooks/spec-guard.sh
  [done] scripts/hooks/file-guard.sh
  [done] scripts/hooks/test-failure-capture.sh
  [done] scripts/hooks/pre-compact-handoff.sh
  [done] scripts/hooks/lesson-capture-gate.sh
  [done] scripts/hooks/release-gate.sh
  [done] scripts/hooks/state.sh
  [done] scripts/hooks/tdd-state.sh

  GIT HOOKS (local only, not in git)
  [done] .git/hooks/commit-msg
  [done] .git/hooks/pre-commit
  [done] .git/hooks/pre-push

Committed to version control (shared with team):
  -> .github/hooks/hooks.json
  -> .github/hooks/protected-paths.txt
  -> .codex/hooks.json (if applicable)
  -> scripts/hooks/*.sh
  -> scripts/hooks/git/*

Per-developer install required (git hooks):
  -> Each developer runs: bash scripts/hooks/git/install.sh
```

## TDD Enforcement Behavior

After Milestone 2, the shared runtime behavior is:

- `state.sh` persists task-scoped TDD evidence inside `.github/agent-state/active-run.json`
- `test-failure-capture.sh` records valid Red and Green transitions for the active task
- `file-guard.sh` asks before implementation edits when the task has no Red yet
- `release-gate.sh` blocks task completion if Red or Green evidence is missing

Make sure repo test files follow recognizable conventions such as `tests/`,
`__tests__/`, `*.test.*`, or `*.spec.*`, and keep implementation files under
stable source roots where possible. The heuristics are intentionally simple.
