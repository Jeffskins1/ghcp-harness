# Milestone 5 Plan: Closed-Loop Harness

Date: 2026-03-27

## Objective

Implement the remaining credibility and maintainability work identified in both
`HARNESS_EVALUATION.md` and `HARNESS_EVALUATION_V5.md` so the harness becomes:

- more enforceably independent in evaluator review
- more machine-checkable in semantic completion
- lighter in recurring prompt/context cost
- easier to maintain without mirrored-asset drift
- clearer about non-code work instead of treating it as an implicit exception

This milestone should deliver six concrete outcomes:

1. Evaluator-gated tasks can prove reviewer independence according to a defined policy.
2. Semantic done conditions can be declared and enforced without chat interpretation.
3. Runtime assets are generated from one canonical source instead of hand-maintained mirrors.
4. Session-start context becomes compact, generated, and cheaper in tokens.
5. Evaluator quality thresholds go beyond schema validity and reject weak reviews.
6. Non-code tasks gain explicit workflow modeling and validation modes.

Milestone 5 should stay focused on the remaining hard gaps after Milestone 4.
Do not reopen solved Milestone 2-4 work unless needed to support these goals.

## Baseline

The current repo already provides the substrate this milestone should build on:

- `.github/agent-state/active-run.json` is the canonical runtime state file.
- `scripts/workflow/` already provides task progression commands and next-task selection.
- `scripts/hooks/release-gate.sh` already enforces TDD and evaluator verdicts.
- `scripts/hooks/evaluator-state.sh` already generates evaluator packets and validates structured results.
- `scripts/hooks/session-start.sh` already summarizes active workflow state instead of dumping full instructions.
- Runtime assets still exist in three trees:
  - `resources/`
  - `.github/`
  - `scripts/` plus `resources/hooks/`

That means Milestone 5 does not need a new workflow engine. It needs to harden
independence and semantic checks, reduce drift, and close the remaining policy gaps.

## Scope

In scope:

- evaluator independence policy and enforceable proof
- semantic done-condition schema and release-gate enforcement
- evaluator-quality scoring or threshold checks
- explicit non-code task types and validation modes
- generated runtime asset sync from one canonical source
- slimmer session-start output and generated status artifacts
- documentation alignment for the above runtime behavior
- smoke coverage for each new gate

Out of scope:

- replacing the current hook architecture entirely
- spawning true remote evaluator agents from inside the hook runtime
- major OpenSpec redesign unrelated to semantic done checks
- broad skill-library rewrites beyond high-frequency operational skills

## Source Findings To Address

From `HARNESS_EVALUATION_V5.md`:

1. Evaluator independence is still packet-driven rather than runtime-enforced.
2. Semantic done conditions need machine-checkable structure beyond prose.
3. Manual mirroring across runtime and resource trees remains a maintenance risk.
4. Non-code task modeling is still light.
5. Evaluator quality is still judged mostly by schema validity, not review depth.
6. Session-start context could still be slimmer and more generated.

From `HARNESS_EVALUATION.md` that still materially remains relevant:

1. Adversarial review is useful but still not strong enough to count as fully reliable autonomy.
2. Token efficiency is still mixed because recurring startup/context behavior and mirrored assets remain.
3. Some scaffolding risks becoming ceremony unless the runtime can prove it earns its cost.

## Design Decisions

### 1. Keep one canonical runtime state file

Continue using `.github/agent-state/active-run.json` as the primary workflow
contract. Add new fields there for independence proof, semantic checks,
non-code validation, and evaluator-quality scoring rather than introducing a
parallel state file as the real source of truth.

Separate artifacts are still useful, but the release gate should read normalized
state from one place.

### 2. Evaluator independence should be policy-based, not inferred

The harness should stop treating “fresh session” as a prose request only.
Define an explicit independence policy for evaluator-gated tasks, for example:

- reviewer session id must differ from generator session id
- reviewer mode must be `fresh_session` for tasks marked independence-required
- evaluator result must include packet id or handoff artifact id
- evaluator launch metadata must be recorded before the result is accepted

If the runtime cannot prove the required policy, completion should be blocked.

### 3. Semantic done conditions must be declared in a structured form

Keep prose `Done when:` for human readability, but add a machine-checkable
block for enforcement. Example shape inside the spec task:

```markdown
Semantic checks:
- type: file_contains
  path: specs/features/foo.spec.md
  pattern: "Rollout Plan"
- type: state_equals
  path: evaluator.status
  value: pass
```

Or, if inline markdown becomes too fragile, generate a normalized semantic-check
artifact from the spec during state sync.

The release gate should evaluate these checks deterministically.

### 4. Non-code tasks must become first-class

Do not let non-code work bypass the workflow by omission. Tasks should declare:

- task type: `code`, `doc`, `research`, `review`, `ops`, `handoff`
- TDD mode: required / not_applicable
- validation mode: tests / semantic_checks / artifact_exists / manual_ack

That lets the harness preserve rigor without pretending every task is a unit of code.

### 5. Runtime assets should have one source of truth

Choose `resources/` as canonical for reusable docs, skill packages, templates,
and hook-distributed assets. `.github/skills`, `.github/prompts`, and
`resources/hooks` or `scripts/hooks` copies should become generated outputs
through a sync script and manifest.

Milestone 5 should make drift structurally difficult, not just socially discouraged.

### 6. Session-start should be generated from state, not from full static docs

The startup view should emit only:

- project identity
- exact test command
- protected-path summary
- active feature/task/phase
- current TDD, evaluator, semantic-check, and independence status
- next runnable task
- links to the canonical instructions and workflow docs

It should not cat full instruction files into the session start path.

### 7. Evaluator quality should include minimum evidence thresholds

Schema validity alone is too weak. For evaluator-required tasks, the runtime
should also reject results that do not meet minimum quality bars, such as:

- all declared criteria addressed
- evidence text is non-empty and not template filler
- blocking findings exist when any criterion is `NOT MET`
- `pass` is disallowed if required adversarial modes were not acknowledged
- minimum count of criterion/evidence items for complex tasks

This should remain deterministic and cheap rather than becoming an LLM-on-LLM loop.

## Workstreams

### Workstream 1: Enforce evaluator independence

Primary files:

- `scripts/hooks/state.sh`
- `scripts/hooks/evaluator-state.sh`
- `scripts/workflow/request-evaluator.sh`
- `scripts/workflow/write-evaluator-result.py`
- `resources/templates/evaluator-entry.md`

Changes:

- record generator session identity in active run state
- introduce evaluator packet ids and packet metadata
- persist evaluator launch metadata before review begins
- extend the evaluator result schema with independence proof fields
- validate reviewer session mismatch and required review mode
- add policy flags for tasks that require strict independence

Recommended state additions:

```json
{
  "generator_session": "codex-session-123",
  "evaluator": {
    "required": true,
    "independence_policy": "fresh_session_required",
    "packet_id": "eval-packet-2-20260327T180000Z",
    "launch_recorded_at": "2026-03-27T18:00:00Z",
    "reviewer_session": "copilot-session-456",
    "independence_verified": true
  }
}
```

Acceptance criteria:

- evaluator-required tasks can declare an independence policy
- result ingestion rejects same-session reviews when policy requires a fresh session
- active state records whether independence was proven, not just requested
- release gate blocks completion when independence proof is missing or invalid

### Workstream 2: Add machine-checkable semantic done conditions

Primary files:

- `scripts/hooks/state.sh`
- `scripts/hooks/release-gate.sh`
- new `scripts/workflow/evaluate-semantic-checks.py`
- `resources/skills/implementation-plans/SKILL.md`
- OpenSpec templates under `resources/openspec/`

Changes:

- define a supported semantic-check schema
- teach state sync to parse and normalize semantic checks per task
- teach release gate to evaluate declared checks for the active task
- expose semantic-check results in top-level state summaries
- document which checks are supported and how to declare them

Initial supported checks should stay intentionally narrow:

- file exists
- file contains pattern
- JSON/state field equals value
- artifact exists
- command exit code equals zero

Acceptance criteria:

- tasks can declare semantic checks in the spec without ambiguous prose parsing
- release gate blocks completion when any required semantic check fails
- state records per-check pass/fail output for the active task

### Workstream 3: Model non-code tasks explicitly

Primary files:

- `scripts/hooks/state.sh`
- `scripts/hooks/release-gate.sh`
- `resources/skills/implementation-plans/SKILL.md`
- `resources/skills/writing-plans/SKILL.md`
- spec templates under `resources/openspec/`

Changes:

- add task type and validation mode parsing
- default code tasks to current TDD behavior
- allow non-code tasks to declare `tdd: not_applicable`
- require at least one explicit validation mode for every task
- add release-gate branching for non-code validations

Example task format:

```markdown
### Task 4 - Publish rollout note
Task type: doc
Validation mode: semantic_checks
TDD: NOT_APPLICABLE
Done when: rollout note exists and links the risk checklist
Semantic checks:
- type: file_exists
  path: docs/rollout.md
```

Acceptance criteria:

- non-code tasks no longer rely on implicit exceptions
- every task has an explicit validation path
- release gate behavior is deterministic for both code and non-code tasks

### Workstream 4: Raise evaluator-quality thresholds

Primary files:

- `scripts/hooks/evaluator-state.sh`
- `scripts/workflow/write-evaluator-result.py`
- `resources/skills/code-review/SKILL.md`
- `resources/templates/evaluator-result-template.json`

Changes:

- require evaluator results to address every required criterion
- reject placeholder or obviously empty evidence text
- record which adversarial review modes were actually applied
- add lightweight quality heuristics:
  - minimum evidence count
  - no `pass` with `NOT MET`
  - no missing mode acknowledgements for required adversarial review
- summarize evaluator quality in active state

Acceptance criteria:

- a syntactically valid but low-effort evaluator result can be rejected
- active state records quality-threshold outcomes
- review docs match the enforced artifact shape

### Workstream 5: Generate runtime assets from one canonical source

Primary files:

- new `scripts/sync/sync_runtime_assets.py`
- optional sync manifest under `resources/`
- `resources/skills/scripts/skill_library.py` if needed
- docs that currently tell users to edit mirrored trees manually

Changes:

- define canonical source directories
- generate `.github/skills/` from `resources/skills/`
- generate `.github/prompts/` from canonical prompt wrappers
- generate hook-distribution copies from canonical hook sources
- document the sync workflow and mark generated targets clearly

Acceptance criteria:

- one command can regenerate runtime/distribution assets
- manual edits to generated targets are unnecessary
- contribution docs identify the canonical edit locations

### Workstream 6: Slim and generate session-start context

Primary files:

- `scripts/hooks/session-start.sh`
- `resources/hooks/session-start.sh`
- optional new generated summary artifact under `.github/agent-state/`
- `resources/instructions/github-instructions-template.md`

Changes:

- keep session-start to compact status lines only
- move any long-form guidance behind references/paths
- generate a concise workflow summary artifact from current state if needed
- include semantic-check and independence status once those gates exist

Acceptance criteria:

- session start no longer emits long static docs
- the summary is sufficient to resume work from persisted state
- startup token cost is materially smaller than the current path

## Suggested Delivery Order

Deliver Milestone 5 in this order:

1. Non-code task model and semantic-check schema
2. Release-gate support for semantic checks
3. Evaluator independence proof and policy enforcement
4. Evaluator-quality thresholds
5. Generated runtime asset sync
6. Compact/generated session-start output

Reasoning:

- semantic checks and non-code task modeling define the core state contract
- evaluator independence and quality then build on the expanded contract
- asset generation and startup slimming are safer after the runtime behavior stabilizes

## Validation Plan

Add deterministic smoke coverage for all of these scenarios:

### Independence enforcement

- evaluator-required task with `fresh_session_required` rejects a result from the generator session id
- the same task accepts a result from a distinct reviewer session id
- completion remains blocked if packet metadata is missing even when verdict is `pass`

### Semantic checks

- a task with passing semantic checks can complete
- a task with one failing semantic check is blocked
- unsupported semantic-check types are rejected during sync or gate evaluation

### Non-code tasks

- a `doc` task with `TDD: NOT_APPLICABLE` and semantic checks can complete without Red/Green
- a `code` task still requires normal TDD evidence
- a task missing validation mode is rejected or blocked

### Evaluator quality

- `pass` plus a `NOT MET` criterion is rejected
- a result missing required adversarial-mode acknowledgements is rejected
- placeholder evidence text is rejected

### Asset generation

- sync command regenerates `.github/skills/`, `.github/prompts/`, and distributed hooks from canonical sources
- regenerated outputs match committed runtime expectations

### Session-start compactness

- startup output remains useful without dumping full instruction content
- startup reflects independence and semantic-check status once added

## Recommended First Slice

If work starts immediately, do this first:

1. Extend the spec/state contract for `Task type`, `Validation mode`, and `Semantic checks`.
2. Add semantic-check evaluation to `release-gate.sh`.
3. Add evaluator independence metadata and rejection rules to result ingestion.
4. Create one smoke fixture with:
   - one normal code task
   - one evaluator-gated task
   - one non-code task
5. Only after those gates work, add runtime asset generation and session-start slimming.

This is the fastest path from a “good autonomous workflow driver” to a
“closed-loop harness with defensible completion semantics.”

## Final Note

Milestone 5 should not add more ceremony unless the runtime can enforce it.

Every new field, section, or artifact introduced in this milestone should pass
one test:

- does it let the harness prove something it could not prove before?

If not, keep it out.
