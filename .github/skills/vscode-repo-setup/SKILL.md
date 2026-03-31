---
name: vscode-repo-setup
description: Bootstrap a repo for GitHub Copilot in VS Code by creating baseline folders, workspace settings, shared instructions, and spec scaffolding.
---

# VS Code Repo Setup

## Overview

Bootstrap a repo for GitHub Copilot in VS Code by creating baseline folders, workspace settings, shared instructions, and spec scaffolding.

## Quick Reference

- **Use when:** Use once per repo before any feature work begins. Run when the repo is missing baseline folders, a copilot-instructions.md, or the shared spec files.
- **Output:** Baseline folders, .github/copilot-instructions.md filled from the repo, .vscode/settings.json, .vscode/extensions.json, AGENTS.md thin wrapper (if Codex users exist on the team), specs/openspec.md, specs/arch.md.
- **Duration:** 10-20 minutes. One-time per repo.
- **Phase:** C (Context Substrate) - runs before the ICTT loop starts.

## Purpose

This skill establishes the context substrate for a repo before any feature work
begins. A complete substrate means every subsequent agent session - whether in
VS Code, IntelliJ, or Codex CLI - starts with accurate project knowledge,
enforced constraints, and test commands it can run without asking.

`.github/copilot-instructions.md` is the **single source of truth** for all
shared project context. All coding agents on the repo draw from it. If the team
also uses Codex CLI, a thin `AGENTS.md` wrapper is created that delegates to
this file rather than duplicating its content.

## When to Invoke

Invoke this skill when any of the following are true:
- The repo has no `.github/copilot-instructions.md`
- The `specs/` or `skills/` folders are missing
- A new developer is onboarding to an existing repo
- The instruction file exists but has placeholder content rather than real stack detail
- You are starting a greenfield project and nothing is set up yet

## Process

### Step 1 - Inspect the repo before touching anything
Read the root directory, any existing config files (package.json, pom.xml, build.gradle,
pyproject.toml, Cargo.toml, go.mod, etc.), the test runner config, and any existing
docs or READMEs. Do not create any files yet.

Identify and record:
- Primary language and version
- Build system and the exact build command
- Test framework and the exact test command (copy-paste ready)
- Module/package layout and key entry points
- Any existing architecture constraints or patterns in the code
- Whether `AGENTS.md` already exists (signals Codex CLI users on the team)

### Step 2 - Create baseline folders
Create any of the following that are missing. Do not overwrite existing content:

```
.github/
.vscode/
specs/
specs/features/
skills/
tests/
```

Also create obvious source folders if the project type implies them (e.g. `src/` for
Node/Java, `app/` for Rails/Django) and they do not already exist.

Stop and report which folders were created vs already present.

### Step 3 - Create .vscode/settings.json and extensions.json
Create `.vscode/settings.json` with GitHub Copilot agent mode enabled:

```json
{
  "github.copilot.chat.agent.enabled": true,
  "github.copilot.chat.agent.runTasks": true
}
```

Create `.vscode/extensions.json` with the recommended extension IDs:

```json
{
  "recommendations": [
    "GitHub.copilot",
    "GitHub.copilot-chat",
    "GitLab.gitlab-workflow",
    "eamodio.gitlens"
  ]
}
```

Skip if either file already exists with content.

### Step 4 - Create .github/copilot-instructions.md
Use `resources/instructions/github-instructions-template.md` as the base.
Fill in every section from what you found in Step 1. Do not leave placeholder text.

Required sections:
1. **Project Knowledge** - stack, language version, module layout, key entry points, build system, architecture boundaries
2. **Exact Test Commands** - add a `## Exact Test Commands` section with:
   - `Full suite: \`...\`` required
   - `Unit: \`...\`` optional
   - `Integration: \`...\`` optional
   The `Full suite` command must be copy-paste ready and unambiguous.
3. **Agent Constraints** - files the agent must not edit without confirmation, patterns to follow, commands that are unsafe in this repo
4. **Persistent Lessons** - start empty, add a note that lessons from future sessions should be appended here
5. **MCP Server References** - list configured MCP servers if any can be detected; otherwise add a placeholder comment

This file is the single source of truth for all coding agents on the repo.
Every lesson appended here is available to the next session in any agent.

If the `Full suite` command cannot be identified confidently, stop and report that the repo setup is incomplete. Do not leave this ambiguous.

After writing the file, print a short summary of what you filled in and ask the developer to confirm the `Full suite` command is correct before continuing.

### Step 5 - Create AGENTS.md (if Codex CLI is used on this repo)
If `AGENTS.md` already exists with real content, skip this step.

If the team uses Codex CLI (or may in future), create a thin `AGENTS.md` at the
repo root using `resources/instructions/agents-md-template.md` as the base.
Do not duplicate the content from copilot-instructions.md - the file should
delegate to it and add only Codex-specific invocation notes.

If it is unclear whether Codex CLI is used, create the file anyway. It costs
nothing and ensures any developer who switches to Codex CLI finds the repo ready.

### Step 6 - Create specs/openspec.md and specs/arch.md
Create `specs/openspec.md` using `resources/spec/basic-spec-template.json` as the
structural reference. Leave intent fields blank - these are filled per feature.

Create `specs/arch.md` with the following sections, populated from your Step 1 findings:
- **System Overview** - one paragraph describing what this repo does
- **Layer Map** - how the code is organised (e.g. API -> Service -> Repository)
- **Key Boundaries** - which layers or services must not be coupled directly
- **Technology Decisions** - locked choices that must not be revisited without a new arch note

Skip any file that already exists.

**The spec file is the inter-agent communication bus.** Each feature spec at
`specs/features/[feature].spec.md` is not just a requirements document - it is
the handoff artifact between agent roles (planner -> generator -> evaluator) and
between sessions when context resets are needed. Every decision, state change,
and open question must be written to the spec file, not left in conversation
history. Anything only in the conversation will not survive a session boundary.

### Step 7 - Confirm and report
Print a checklist of everything created or skipped:

```
Created:
  [done] .github/copilot-instructions.md   ← source of truth for all agents
  [done] AGENTS.md                         ← thin wrapper for Codex CLI
  [done] .vscode/settings.json
  [done] .vscode/extensions.json
  [done] specs/openspec.md
  [done] specs/arch.md
  [done] specs/features/       (folder)
  [done] skills/               (folder)

Skipped (already present):
  - tests/                (existed)

Action required:
  -> Confirm the Full suite command in the Exact Test Commands section is correct
  -> Add MCP server names to copilot-instructions.md if configured
  -> All agents (Copilot + Codex) now read from copilot-instructions.md
```
