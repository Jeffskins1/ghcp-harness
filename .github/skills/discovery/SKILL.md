---
name: discovery
description: Ground a task in the existing codebase, current behavior, constraints, and ticket context before planning or spec writing.
---

# Discovery

## Overview

Ground a task in the existing codebase, current behavior, constraints, and ticket context before planning or spec writing.

## Quick Reference

- **Use when:** Use before brainstorming when the request references existing code, an issue, or an unclear part of the system.
- **Output:** Grounded summary of current state, constraints, and unknowns.
- **Duration:** 5-15 minutes.
- **Phase:** I (Intent) - before spec authoring.

## Purpose

This skill prevents the agent from planning against guesses. Run it when the
feature depends on existing behavior, prior tickets, or unclear architecture.
The output should tell the team what already exists, what is missing, and what
must be answered before writing or updating an OpenSpec.

## When to Invoke

Invoke this skill when any of the following are true:
- The request references an existing screen, service, endpoint, or workflow
- The repo contains relevant code but the current behavior is not obvious
- The ticket links to external acceptance criteria or prior work
- The team is unsure which spec or architecture doc should be treated as active

## Hook Placement

Run this skill at the spec-selection hook:
- Before brainstorming for changes to existing systems
- Before writing a new spec for legacy or partially documented areas
- Before handing a task to a background agent that did not author the spec

## Process

### Step 1 - Load the request
- Read the ticket, issue, prompt, or user request
- Restate the problem in one sentence

### Step 2 - Inspect the current system
- Find the relevant files, docs, tests, and config
- Identify the current behavior, not the intended behavior
- Note any missing documentation or contradictory sources

### Step 3 - Summarize findings
Produce:
1. Current state
2. Relevant files and docs
3. Constraints already present
4. Unknowns that must be resolved before spec writing

### Step 4 - Hand off
- If intent is still fuzzy, run `brainstorming`
- If intent is clear, write or update the OpenSpec

## Example Output

```text
Current state:
- CSV exports already exist in the admin portal only
- User-facing export endpoint does not exist

Relevant files:
- specs/arch.md
- src/admin/export-service.ts
- tests/integration/admin-exports.test.ts

Constraints:
- Existing export job table can be reused
- Email delivery already handled by NotificationService

Unknowns:
- Whether user exports share the same retention period
- Whether product wants inline download or async delivery
```
