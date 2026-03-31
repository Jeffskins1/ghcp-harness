---
name: codex-repo-setup
description: Bootstrap a repo for Codex-driven delivery by creating baseline folders, AGENTS.md, and shared spec scaffolding. Use once per repo before feature work.
---

# Codex Repo Setup

## Overview

Bootstrap a repo for Codex-driven delivery by creating baseline folders, AGENTS.md, and shared spec scaffolding. Use once per repo before feature work.

## Quick Reference

- **Use when:** Use once per repo before any feature work begins. Run when the repo is missing AGENTS.md, baseline folders, or the shared spec files.
- **Output:** Baseline folders, AGENTS.md (thin wrapper if copilot-instructions.md exists; full file if this is a Codex-only repo), specs/openspec.md, specs/arch.md.
- **Duration:** 10-20 minutes. One-time per repo.
- **Phase:** C (Context Substrate) - runs before the ICTT loop starts.

## Purpose

This skill establishes the context substrate for a repo before any Codex CLI
session begins. Codex reads `AGENTS.md` natively at session start.

**Multi-agent repos:** If the repo already has `.github/copilot-instructions.md`
(written by VS Code or IntelliJ developers), that file is the single source of
truth for all shared project content. In that case this skill creates a thin
`AGENTS.md` that delegates to it - no duplication, no sync problem. Lessons
written by Copilot users are available to Codex on the next session, and vice versa.

**Codex-only repos:** If no `copilot-instructions.md` exists, this skill creates a
full `AGENTS.md` with all project context. If Copilot users join later, the content
migrates to `copilot-instructions.md` and `AGENTS.md` becomes the thin wrapper.

## When to Invoke

Invoke this skill when any of the following are true:
- The repo has no `AGENTS.md`
- The `specs/` or `skills/` folders are missing
- A new Codex CLI developer is onboarding to an existing repo
- `AGENTS.md` exists but duplicates `copilot-instructions.md` (consolidation needed)
- You are starting a greenfield project with Codex CLI

## Process

### Step 1 - Inspect the repo before touching anything
Read the root directory, any existing config files (package.json, pom.xml,
build.gradle, pyproject.toml, Cargo.toml, go.mod, etc.), the test runner config,
and any existing docs or READMEs. Do not create any files yet.

Identify and record:
- Primary language and version
- Build system and the exact build command
- Test framework and the exact test command (copy-paste ready, no ambiguity)
- Module/package layout and key entry points
- Any existing architecture constraints or patterns visible in the code
- **Whether `.github/copilot-instructions.md` already exists** - this determines
  which path to take in Step 3

### Step 2 - Create baseline folders
Create any of the following that are missing. Do not overwrite existing content:

```
specs/
specs/features/
skills/
tests/
```

Stop and report which folders were created vs already present.

### Step 3 - Create AGENTS.md

#### Path A - copilot-instructions.md already exists (multi-agent repo)
Create a thin `AGENTS.md` at the repo root using
`resources/instructions/agents-md-template.md` as the base.

The file should:
- Direct Codex to read `.github/copilot-instructions.md` first
- Add only Codex-specific invocation notes (session start command, `--context` flag usage)
- Not duplicate any content from copilot-instructions.md

Tell the developer: "copilot-instructions.md is the source of truth. Lessons go
there. AGENTS.md delegates to it."

#### Path B - no copilot-instructions.md (Codex-only repo)
Create a full `AGENTS.md` at the repo root with these sections, populated from
your Step 1 findings:

```markdown
# Project Knowledge

[Stack, language version, module layout, key entry points, build system,
architecture boundaries - enough for an agent with no prior context to
understand what it is working in.]

## Exact Test Command

[Copy-paste ready command. No ambiguity. Example:]
npm test
./gradlew test
pytest tests/
cargo test

[If multiple scopes exist, list each with a label:]
Unit:        npm run test:unit
Integration: npm run test:integration

# Agent Constraints

[Rules the agent must not break:]
- Do not edit files under [generated path] - they are auto-generated
- Do not run [dangerous command] in this repo
- Follow [pattern] for all new service classes
- Ask before changing shared interfaces

# Persistent Lessons

[Start empty. Append failure lessons and fixes after each session.
Format: [YYYY-MM-DD] - [what failed] - [fix applied]]

# MCP Server References

[List configured MCP servers and what each is used for:]
<!-- Example:
- gitlab: GitLab API - MR creation, issue lookup
- postgres: Database introspection
- playwright: Browser automation for e2e tests
-->

---
# Note: If GitHub Copilot users join this repo, migrate this content to
# .github/copilot-instructions.md and replace this file with the thin
# AGENTS.md wrapper from resources/instructions/agents-md-template.md.
```

After writing the file, print a short summary of what you filled in and ask the
developer to confirm the test command is correct before continuing.

### Step 4 - Create specs/openspec.md and specs/arch.md
Create `specs/openspec.md` using `resources/openspec/basic-spec-template.json` as the
structural reference. Leave intent fields blank - these are filled per feature.

Create `specs/arch.md` with the following sections, populated from your Step 1 findings:
- **System Overview** - one paragraph describing what this repo does
- **Layer Map** - how the code is organised
- **Key Boundaries** - which layers or services must not be coupled directly
- **Technology Decisions** - locked choices that must not be revisited without a new arch note

Skip any file that already exists.

**The spec file is the inter-agent communication bus.** Each feature spec at
`specs/features/[feature].spec.md` is not just a requirements document - it is
the handoff artifact between agent roles (planner -> generator -> evaluator) and
between Codex sessions when context resets are needed. Pin it at session start
with `codex --context specs/features/[feature].spec.md`. Every decision, state
change, and open question must be written to the spec file - anything left only
in conversation history will not survive a session boundary.

### Step 5 - Confirm and report

**Multi-agent repo (Path A):**
```
Created:
  [done] AGENTS.md                         ← thin wrapper; delegates to copilot-instructions.md
  [done] specs/openspec.md
  [done] specs/arch.md
  [done] specs/features/       (folder)
  [done] skills/               (folder)

Source of truth: .github/copilot-instructions.md
Action required:
  -> Lessons go in copilot-instructions.md - not AGENTS.md
  -> Pin the active spec per session: codex --context specs/features/[feature].spec.md
```

**Codex-only repo (Path B):**
```
Created:
  [done] AGENTS.md                         ← full project context
  [done] specs/openspec.md
  [done] specs/arch.md
  [done] specs/features/       (folder)
  [done] skills/               (folder)

Action required:
  -> Confirm test command in AGENTS.md is correct
  -> Add MCP server names to AGENTS.md if configured
  -> Pin the active spec per session: codex --context specs/features/[feature].spec.md
  -> If Copilot users join: migrate AGENTS.md content to copilot-instructions.md
```
