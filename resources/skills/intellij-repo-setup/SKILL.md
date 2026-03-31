---
name: intellij-repo-setup
description: Bootstrap a repo for GitHub Copilot in IntelliJ by creating baseline folders, shared instructions, and spec scaffolding for JVM-centric workflows.
---

# IntelliJ Repo Setup

## Overview

Bootstrap a repo for GitHub Copilot in IntelliJ by creating baseline folders, shared instructions, and spec scaffolding for JVM-centric workflows.

## Quick Reference

- **Use when:** Use once per repo before any feature work begins. Run when the repo is missing baseline folders, a copilot-instructions.md, or the shared spec files.
- **Output:** Baseline folders, .github/copilot-instructions.md filled from the repo (JVM-aware), AGENTS.md thin wrapper (if Codex users exist on the team), specs/openspec.md, specs/arch.md.
- **Duration:** 10-20 minutes. One-time per repo.
- **Phase:** C (Context Substrate) - runs before the ICTT loop starts.

## Purpose

This skill establishes the context substrate for a JVM-based repo before any
feature work begins in IntelliJ. A complete substrate means every Copilot Chat
session starts with accurate stack knowledge, correct test commands, and agent
constraints - without the developer re-explaining the project each time.

`.github/copilot-instructions.md` is the **single source of truth** for all
shared project context. GitHub Copilot in both VS Code and IntelliJ reads this
file natively. If the team also uses Codex CLI, a thin `AGENTS.md` wrapper is
created that delegates to this file rather than duplicating its content.

IntelliJ projects commonly use Gradle or Maven, Run Configurations for test
execution, and module-based source layouts. This skill accounts for those
specifics when building the instruction file.

## When to Invoke

Invoke this skill when any of the following are true:
- The repo has no `.github/copilot-instructions.md`
- The `specs/` or `skills/` folders are missing
- A new developer is onboarding to an existing JVM repo
- The instruction file exists but has placeholder content rather than real stack detail
- You are starting a greenfield Java or Kotlin project

## Process

### Step 1 - Inspect the repo before touching anything
Read the root directory, build files (`build.gradle`, `build.gradle.kts`, `pom.xml`,
`settings.gradle`), any existing `src/` layout, test source directories, and READMEs.
Do not create any files yet.

Identify and record:
- Language: Java or Kotlin (or mixed), and version
- Build system: Gradle (Groovy or Kotlin DSL) or Maven
- Test framework: JUnit 4/5, TestNG, Kotest, or other
- The exact test command for the terminal (e.g. `./gradlew test`, `mvn test`)
- Any available Run Configurations relevant to testing
- Module structure and key package/layer boundaries
- Any existing architecture patterns (e.g. hexagonal, layered, DDD aggregates)
- Whether `AGENTS.md` already exists (signals Codex CLI users on the team)

### Step 2 - Create baseline folders
Create any of the following that are missing. Do not overwrite existing content:

```
.github/
specs/
specs/features/
skills/
```

For JVM projects the source layout (`src/main/`, `src/test/`) is managed by the
build system - do not create these manually if they are absent.

Stop and report which folders were created vs already present.

### Step 3 - Create .github/copilot-instructions.md
Use `resources/instructions/github-instructions-template.md` as the base.
Fill in every section from what you found in Step 1. Do not leave placeholder text.

Required sections:
1. **Project Knowledge** - language and version (Java/Kotlin), build system (Gradle/Maven),
   module layout, key package names, entry points, and architecture layer boundaries
2. **Exact Test Commands** - add a `## Exact Test Commands` section. Prefer wrapper commands.
   Required format:
   - `Full suite: \`./gradlew test\`` or `Full suite: \`mvn test\``
   - `Unit: \`...\`` optional
   - `Integration: \`...\`` optional
   The `Full suite` command is mandatory and must be terminal-ready.
3. **Agent Constraints** - files the agent must not edit (e.g. generated code under
   `build/`), patterns to follow (e.g. no mutable shared state, use existing service
   interfaces), commands that are unsafe in this repo
4. **Run Configuration note** - document any key IntelliJ Run Configurations the
   developer should know about for manual test execution
5. **Persistent Lessons** - start empty; lessons from future sessions are appended here
6. **MCP Server References** - list configured MCP servers if detectable; otherwise
   add a placeholder comment

This file is the single source of truth for all coding agents on the repo.
GitHub Copilot in VS Code reads it too - no separate file needed for VS Code devs.

If the `Full suite` command is ambiguous, stop and report the setup gap instead
of guessing.

After writing the file, print a short summary of what you filled in and ask the
developer to confirm the `Full suite` command is correct before continuing.

### Step 4 - Create AGENTS.md (if Codex CLI is used on this repo)
If `AGENTS.md` already exists with real content, skip this step.

If the team uses Codex CLI (or may in future), create a thin `AGENTS.md` at the
repo root using `resources/instructions/agents-md-template.md` as the base.
Do not duplicate the content from copilot-instructions.md - the file should
delegate to it and add only Codex-specific invocation notes.

If it is unclear whether Codex CLI is used, create the file anyway. It costs
nothing and ensures any developer who switches to Codex CLI finds the repo ready.

### Step 5 - Create specs/openspec.md and specs/arch.md
Create `specs/openspec.md` using `resources/openspec/basic-spec-template.json` as the
structural reference. Leave intent fields blank - these are filled per feature.

Create `specs/arch.md` with the following sections, populated from your Step 1 findings:
- **System Overview** - one paragraph describing what this repo does
- **Layer Map** - how the code is organised (e.g. Controller -> Service -> Repository)
- **Key Boundaries** - which layers or modules must not be coupled directly
- **Technology Decisions** - locked choices (e.g. Spring Boot version, ORM, DB)

Skip any file that already exists.

**The spec file is the inter-agent communication bus.** Each feature spec at
`specs/features/[feature].spec.md` is not just a requirements document - it is
the handoff artifact between agent roles (planner -> generator -> evaluator) and
between sessions when context resets are needed. Every decision, state change,
and open question must be written to the spec file, not left in conversation
history. Anything only in the conversation will not survive a session boundary.

### Step 6 - Confirm and report
Print a checklist of everything created or skipped:

```
Created:
  [done] .github/copilot-instructions.md   ← source of truth for all agents
  [done] AGENTS.md                         ← thin wrapper for Codex CLI
  [done] specs/openspec.md
  [done] specs/arch.md
  [done] specs/features/       (folder)
  [done] skills/               (folder)

Skipped (already present):
  - .github/              (existed)

Action required:
  -> Confirm the Full suite command in the Exact Test Commands section matches your Gradle/Maven setup
  -> Add any IntelliJ Run Configuration names for integration or e2e tests
  -> Add MCP server names to copilot-instructions.md if configured
  -> All agents (Copilot + Codex) now read from copilot-instructions.md
```
