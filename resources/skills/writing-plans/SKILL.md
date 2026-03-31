---
name: writing-plans
description: Break an approved spec into atomic, ordered, agent-sized tasks before implementation.
---

# Writing Plans

## Overview

Break an approved spec into atomic, ordered, agent-sized tasks before implementation.

## Quick Reference

- **Use when:** Use after brainstorming is complete and intent is clear, before implementation begins. Run whenever a spec feels too large to hand directly to an agent session.
- **Output:** Ordered list of atomic tasks, each shippable independently.
- **Duration:** 10-20 minutes of spec decomposition.
- **Phase:** I (Intent) / C (Context) boundary - after spec is written, before the first Copilot agent session opens.

## Purpose

An agent session that starts with "implement the payments feature" will either
hallucinate a plan or produce a monolithic change that is impossible to review.
This skill breaks a spec into atomic tasks - each small enough to be completed
in a single agent session, each independently testable, each committable on its
own merits.

Atomic means: one concern, one area of the codebase, one test scenario.

## When to Invoke

Invoke this skill when any of the following are true:
- The OpenSpec acceptance criteria list has more than three items
- The feature touches more than two files or services
- The implementation will produce a diff larger than ~200 lines
- The feature involves a schema migration AND application logic AND UI changes
- You are uncertain where to start

## Process

### Step 1 - Read the spec
Load the relevant `specs/features/[feature].spec.md`. Confirm:
- Intent is clear and agreed (brainstorming complete)
- Acceptance criteria are specific and observable
- Test scenarios are listed
- Out-of-scope is explicit

Do not proceed if the spec is incomplete.

### Step 2 - Identify the layers
List every layer the feature touches. Common layers:
- Data layer (schema, migrations, seed data)
- Repository / data access layer
- Service / business logic layer
- API / controller layer
- UI / component layer
- Tests (each layer has its own tests)
- Configuration / environment

### Step 3 - Decompose into atomic tasks

**Rule 1: Data before logic.**
Schema changes and migrations come first. Nothing else can run until the data
model is correct.

**Rule 2: Logic before API.**
Service layer before controllers. Controllers should be thin wrappers.

**Rule 3: API before UI.**
Endpoint must exist and be tested before the UI consumes it.

**Rule 4: Tests travel with their layer.**
Each task includes writing the tests for that layer. There is no separate
"write tests" task at the end.

**Rule 5: Each task has a clear done condition.**
A task is done when its layer's tests pass. Not when "it looks right."

### Step 4 - Write the task list

Format each task as:
```
[ ] Task N - [Layer]: [What to build]
    Files: [list of files to create or modify]
    Done when: [specific test or observable condition]
    Depends on: [task number(s), or "none"]
    Task type: [code/doc/research/review/ops/handoff]
    Validation mode: [tests/semantic_checks/artifact_exists/manual_ack]
    TDD: [required/NOT_APPLICABLE]
    Evaluator review: [YES/NO]
    Independence policy: [fresh_session_required/recorded_only/none]
    Semantic checks:
    - type: [file_exists/file_contains/state_equals/artifact_exists/command_exit_code]
      path: [file or state path when applicable]
```

Example decomposition for "user CSV export" feature:

```
[ ] Task 1 - Data: Add export_jobs table migration
    Files: migrations/YYYYMMDD_add_export_jobs.sql
    Done when: migration runs cleanly on dev, schema matches spec
    Depends on: none

[ ] Task 2 - Repository: ExportJobRepository CRUD
    Files: src/repositories/export-job.repository.ts, tests/unit/export-job.repository.test.ts
    Done when: unit tests pass for create, findById, updateStatus
    Depends on: Task 1

[ ] Task 3 - Service: ExportService - queue and process export
    Files: src/services/export.service.ts, tests/unit/export.service.test.ts
    Done when: unit tests pass for happy path + failure modes from spec
    Depends on: Task 2

[ ] Task 4 - API: POST /exports endpoint
    Files: src/api/exports.controller.ts, tests/integration/exports.test.ts
    Done when: integration test covers 201, 400, 401 responses
    Depends on: Task 3

[ ] Task 5 - UI: Export button + status polling on dashboard
    Files: src/components/ExportButton.tsx, tests/unit/ExportButton.test.tsx
    Done when: unit tests pass, Storybook story renders all states
    Depends on: Task 4
```

### Step 5 - Validate the decomposition

Before handing to the agent, confirm:
- Each task can be completed in one agent session (< 30 min estimate)
- Each task's "done when" maps to a test scenario in the spec
- The dependency order is correct - no task depends on something not yet built
- There are no orphaned tasks (every task connects to a spec acceptance criterion)

### Step 6 - Add tasks to the spec

Paste the task list into the OpenSpec file under a new section:

```markdown

## Implementation Plan
[paste task list here]
```

This makes the plan part of the versioned spec, not just a chat message.

## Notes for Skill Authors

Add project-specific layer templates in Step 2 for your stack.
For example, a Django project would add: models -> serializers -> views -> urls -> frontend.
A Java Spring project would add: entities -> repositories -> services -> controllers -> DTOs.
