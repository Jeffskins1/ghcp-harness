---
name: implementation-plans
description: Turn an approved spec into ordered execution tasks with dependencies, done conditions, and validation targets before coding.
---

# Implementation Plans

## Overview

Turn an approved spec into ordered execution tasks with dependencies, done conditions, and validation targets before coding.

The active run state lives in `.github/agent-state/active-run.json`. Planning
must leave that file with a resolvable active spec, task snapshot, and current
task so a later session can resume without reconstructing the workflow from chat.

## Quick Reference

- **Use when:** Use after architecture is settled and before a coding session starts for a specific task.
- **Output:** Confirmed sprint contract + ordered execution plan with task ownership and done conditions.
- **Duration:** 10-20 minutes.
- **Phase:** C (Context) - final handoff before implementation.

## Purpose

This skill turns an approved spec into an execution sequence the agent can run
without inventing ordering, ownership, or done conditions mid-flight.

It also establishes the **sprint contract** - an explicit, shared understanding
of what "done" means before a single line of code is written. Misalignments
between what the spec says and what the agent understands surface here, not
during review. A confirmed sprint contract is the most effective way to prevent
the agent from producing technically correct work that misses the actual intent.

## When to Invoke

Invoke this skill when:
- The architecture is settled
- The next step is implementation
- The feature must be split into agent-sized units

## Hook Placement

Run this skill:
- After architecture-decisions
- Before the first coding prompt
- Again whenever the plan becomes stale after scope or design changes

---

## Process

### Step 1 - Read the active spec
Use the current acceptance criteria and test scenarios as the source of truth.
Read the full spec, not just the task list.

### Step 2 - Confirm the sprint contract
Before slicing the work, the agent must restate the acceptance criteria in its
own words. This is the sprint contract step - it surfaces gaps between what the
spec says and what the agent understood.

Ask the agent:

```
Read the active spec at specs/features/[feature].spec.md.
Before creating the implementation plan, restate in your own words:
1. What this feature does (one sentence)
2. What each acceptance criterion requires - specifically, how you would
   verify it is met
3. Any criterion you find ambiguous or that could be interpreted multiple ways

Do not start planning yet. Wait for my confirmation.
```

Review the restatement. If anything is wrong or incomplete, correct it now.
Corrections go back into the spec before planning starts - not just into the
conversation.

Only confirm and continue once the agent's understanding matches the spec.
This confirmation is the sprint contract.

### Step 3 - Slice the work
Break the implementation into ordered tasks. Each task must:
- Touch one main concern
- Have a clear dependency list
- Have a single observable done condition that maps to a spec criterion
- Be completable within one focused agent session (context budget in mind)

Tasks that are too large invite context anxiety mid-implementation. If a task
feels like it could run long, split it further.

### Step 4 - Add execution guidance
Each task should state:
- Files or layers involved
- Exact test or validation target
- Which prior task it depends on
- Whether the task is normal harness-enforced TDD work or a deliberate non-code exception
- Task type: `code`, `doc`, `research`, `review`, `ops`, or `handoff`
- Validation mode: one or more of `tests`, `semantic_checks`, `artifact_exists`, `manual_ack`
- TDD mode: `required` or `NOT_APPLICABLE`
- Semantic checks when done conditions need machine-checkable enforcement
- Whether this task warrants a **separate-session evaluator review** on completion
  (flag tasks that cross boundaries, touch shared interfaces, or have subjective criteria)
  and remember that `Evaluator review: YES` is a runtime completion gate, not advisory metadata
- Which adversarial review lens must be applied when evaluator review is required

### Step 5 - Attach to the spec
Add or refresh the `## Implementation Plan` section in the OpenSpec. The spec
is the inter-agent communication bus - if the plan is only in the conversation
it will not survive a session boundary or an agent handoff.

Format each task so any agent reading the spec cold can execute it:

```markdown

## Implementation Plan

### Task 1 - [name]
Files: [list]
Does: [what it implements]
Done when: [exact verifiable condition]
Depends on: none / Task N
Task type: code / doc / research / review / ops / handoff
Validation mode: tests / semantic_checks / artifact_exists / manual_ack
TDD: required / NOT_APPLICABLE
Evaluator review: YES / NO
Independence policy: fresh_session_required / recorded_only / none
Adversarial review: contract_adversary, regression_adversary / none
Semantic checks:
- type: file_exists
  path: docs/example.md
```

### Step 6 - Flag session boundary risks
Review the full task list and identify any task that is likely to push a
session to context limits. Mark these explicitly:

```
Warning: Session boundary risk: Tasks 3-4 together may exhaust context.
  Run session-handoff between Task 3 and Task 4.
```

This makes handoffs planned rather than reactive.

### Step 7 - Sync workflow state
After the plan is confirmed, ensure the harness can derive a machine-readable
task snapshot from the active spec. The active run state should capture:
- active spec path
- task ids and statuses
- current task id
- current phase
- evaluator requirement for the current task
- evaluator verdict state for the current task when review is recorded
- adversarial review modes for the current task

If the spec structure is too loose for the state file to parse, tighten the
task formatting before implementation starts.

The active task will default to harness-enforced TDD unless you make a clear
case that it is a non-code task. Plan tasks narrowly enough that a single Red
and Green pair can be attributed to the task without ambiguity.

---

## Notes

- The sprint contract in Step 2 is the highest-value step. A 5-minute
  confirmation here prevents a 2-hour rework cycle after review.
- Tasks marked `Evaluator review: YES` should be followed by a fresh-session
  code review using Section B of code-review, not same-session self-review.
- Non-code tasks should not omit validation; use semantic checks, artifact existence,
  or manual acknowledgement explicitly instead of leaving validation implicit.
- If `Adversarial review:` is omitted, the harness will still infer default
  review lenses for evaluator-gated tasks. Add the line explicitly when the
  task needs a specific contract, regression, security, or token/context pass.
- Those tasks cannot complete until the evaluator result artifact is recorded
  and the verdict is `pass` or `pass_with_risks`.
- Use `writing-plans` for the canonical atomic decomposition pattern. This
  skill is the execution-facing version: it answers "what do we run next" and
  "do we both agree on what done looks like" once the spec is ready to hand
  to an agent.
- If the spec's acceptance criteria are ambiguous after the Step 2 restatement,
  go back to brainstorming or architecture-decisions before proceeding.
  Do not implement against a contract neither party is confident in.
