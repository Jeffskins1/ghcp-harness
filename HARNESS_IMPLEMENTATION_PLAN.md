# Agentic Harness Implementation Plan

Date: 2026-03-27

## Goal

Modify and supplement the current `ghcp-harness` so it behaves like a true agentic coding harness:

- intent-first
- spec-driven
- TDD-enforcing
- task-oriented
- self-evaluating
- adversarially reviewing
- context-efficient
- credible for hands-off developer operation

This plan builds on the current codebase rather than replacing it.

## Delivery Strategy

Implement in four phases:

1. Establish hard gates and execution state.
2. Add TDD evidence and evaluator orchestration.
3. Add autonomous task progression and adversarial review modes.
4. Reduce prompt/context overhead and clean up duplicated assets.

The order matters. Hard gates and machine-readable state come first. Without those, later “autonomy” work is mostly ceremony.

## Phase 1: Hard Gates And Execution State

### Objective

Turn the harness from guided prompting into a controlled workflow with enforceable state.

### Step 1. Add machine-readable workflow state

Create a canonical execution state file, for example:

- `.github/agent-state/active-run.json`
- or `specs/features/[feature].state.json`

The file should track:

- active feature spec
- task list snapshot
- task statuses: `not_started | in_progress | blocked | complete`
- current task id
- current phase: `intent | planning | red | green | refactor | evaluator | release`
- last test command run
- last test result
- TDD evidence flags
- evaluator requirement and verdict
- session handoff checkpoint

Files to add or modify:

- `scripts/hooks/common.sh`
- new `scripts/hooks/state/` helpers, or a single `scripts/hooks/state.sh`
- `resources/skills/implementation-plans/SKILL.md`
- `resources/skills/session-handoff/SKILL.md`

Done when:

- the harness can persist and reload task state independently of chat history
- a task can be resumed from state alone

### Step 2. Promote `TaskCompleted` into the active runtime config

Wire `release-gate.sh` into the checked-in Copilot hook configuration, not just the Claude template.

Files to modify:

- `.github/hooks/hooks.json`
- `scripts/hooks/release-gate.sh`
- `resources/hooks/release-gate.sh`
- `resources/skills/hooks-setup/SKILL.md`

Implementation notes:

- use the existing `TaskCompleted` structure already shown in `resources/hooks/claude-settings-template.json`
- if GitHub Copilot runtime does not support `TaskCompleted` consistently across both VS Code and IntelliJ, add a fallback gate triggered on `Stop` and/or a task-marking command

Done when:

- task completion is blocked when declared validation does not pass
- the checked-in runtime config matches the documented behavior

### Step 3. Strengthen spec guard from warning to gate

Upgrade `spec-guard.sh` so implementation-like prompts without an active spec produce `deny` or `ask`, not only `additionalContext`.

Files to modify:

- `scripts/hooks/spec-guard.sh`
- `resources/hooks/spec-guard.sh`
- `resources/skills/hooks-setup/SKILL.md`

Implementation notes:

- keep setup, review, discovery, and documentation prompts exempt
- treat prompts that imply “build”, “implement”, “add feature”, “write code”, “fix bug”, “create endpoint”, etc. as gated work
- allow explicit override only through a clearly intentional user confirmation path

Done when:

- implementation cannot begin without an active spec or explicit human override

### Step 4. Add exact test command validation to setup paths

The harness assumes an “Exact Test Command” exists. Make repo setup and validation enforce its presence.

Files to modify:

- `resources/instructions/github-instructions-template.md`
- `resources/skills/vscode-repo-setup/SKILL.md`
- `resources/skills/intellij-repo-setup/SKILL.md`
- `scripts/hooks/common.sh`

Implementation notes:

- add a standardized section name and parsing format
- fail fast if setup leaves the field ambiguous
- support unit, integration, and full-suite commands where relevant

Done when:

- `release-gate.sh` and `pre-push` can reliably discover the intended test command

### Step 5. Add a state-aware session start

Update `session-start.sh` so it reports:

- active feature
- current task
- required next phase
- evaluator pending status

instead of only dumping raw context and listing specs.

Files to modify:

- `scripts/hooks/session-start.sh`
- `resources/hooks/session-start.sh`

Done when:

- a resumed session has enough state to continue without reconstructing the workflow manually

## Phase 2: TDD Evidence And Evaluator Gating

### Objective

Make the harness prove it followed TDD and force evaluator review where required.

### Step 6. Add TDD evidence tracking

Introduce a lightweight TDD state machine:

- `red_required`
- `red_observed`
- `green_observed`
- `refactor_allowed`
- `task_complete_allowed`

Files to add or modify:

- `scripts/hooks/test-failure-capture.sh`
- new `scripts/hooks/tdd-state.sh`
- `scripts/hooks/common.sh`
- `resources/skills/test-driven-development/SKILL.md`

Implementation notes:

- first relevant test failure for the active task records `red_observed=true`
- implementation edits before `red_observed=true` should trigger a warning or block
- passing tests for the scoped task record `green_observed=true`
- task completion requires both red and green evidence

Done when:

- a task cannot be marked complete unless the harness saw a Red and a Green for that task

### Step 7. Add pre-edit TDD guardrails

Before source implementation files are edited, inspect active task state:

- if the task phase is still `red_required`, block non-test implementation edits
- allow test-file edits first

Files to modify:

- `scripts/hooks/file-guard.sh`
- `resources/hooks/file-guard.sh`

Implementation notes:

- classify test paths by convention: `tests/`, `__tests__/`, `*.test.*`, `*.spec.*`
- only enforce when an active task is in TDD mode

Done when:

- the harness nudges or blocks code-first behavior on TDD tasks

### Step 8. Make evaluator review a gate, not advice

For tasks flagged `Evaluator review: YES`, require an evaluator verdict before:

- next task activation
- release readiness
- merge/push recommendation

Files to add or modify:

- new `scripts/hooks/evaluator-gate.sh`
- `scripts/hooks/release-gate.sh`
- `.github/hooks/hooks.json`
- `resources/skills/code-review/SKILL.md`
- `resources/skills/implementation-plans/SKILL.md`

Implementation notes:

- store evaluator requirement and verdict in the machine-readable state file
- acceptable verdicts: `pass | pass_with_risks | fail`
- `fail` blocks progression

Done when:

- high-risk tasks cannot silently bypass fresh-session evaluation

### Step 9. Standardize evaluator outputs

Create a structured evaluator result schema, for example:

```json
{
  "feature": "checkout-fraud-checks",
  "task_id": 4,
  "criterion_results": [
    { "id": "AC-1", "status": "MET", "evidence": "..." }
  ],
  "findings": [],
  "residual_risks": [],
  "verdict": "pass"
}
```

Files to add or modify:

- `resources/skills/code-review/SKILL.md`
- `resources/skills/code-review/references/evaluator-calibration.md`
- new evaluator result template under `resources/`

Done when:

- evaluator outcomes can be consumed by hooks and workflow state, not just read by humans

## Phase 3: Autonomous Task Progression And Adversarial Review

### Objective

Move from static skills to workflow orchestration that can advance itself safely.

### Step 10. Add next-task selection logic

Build a small task selector that reads:

- spec implementation plan
- state file
- dependencies
- evaluator status

and chooses the next runnable task automatically.

Files to add:

- `scripts/workflow/select-next-task.py` or `.js`
- optional `scripts/workflow/parse-spec.py`

Files to modify:

- `scripts/hooks/session-start.sh`
- `resources/skills/implementation-plans/SKILL.md`

Implementation notes:

- prefer a machine-readable task block if available
- if tasks remain prose-only, add a normalized task export step first

Done when:

- the harness can identify the next valid task without developer steering

### Step 11. Add workflow driver commands

Create explicit workflow scripts or commands such as:

- `start-feature`
- `start-task`
- `mark-red`
- `mark-green`
- `request-evaluator`
- `complete-task`
- `resume-run`

Files to add:

- `scripts/workflow/` command scripts
- a short operator README for these commands

Purpose:

- reduce dependence on free-form prompting
- give the harness a stable execution protocol

Done when:

- the main workflow can be driven by repeatable commands, not only skill prose

### Step 12. Add adversarial review modes

Create explicit review modes beyond generic fresh-session review:

- `contract adversary`: acceptance criteria skepticism
- `regression adversary`: surrounding behavior and integration risk
- `security adversary`: abuse path and trust boundary review
- `token/context adversary`: prompt bloat and state hygiene review

Files to add or modify:

- new skills or prompt packs under `resources/skills/` or `.github/prompts/`
- `resources/skills/code-review/SKILL.md`
- `resources/skills/security-review-and-threat-modeling/SKILL.md`
- `resources/skills/performance-and-scalability-review/SKILL.md`

Implementation notes:

- start with one mandatory adversarial mode for high-risk tasks
- high-risk triggers should include auth, payments, migrations, infra, security boundaries, shared APIs

Done when:

- adversarial review is operationalized as a repeatable harness behavior, not just a concept

### Step 13. Add evaluator launch instructions compatible with both IDEs

If runtime hooks cannot spawn true new sessions, define a deterministic handoff packet the developer or agent can trigger with one command/prompt.

Files to add or modify:

- `resources/skills/session-handoff/SKILL.md`
- `resources/skills/code-review/SKILL.md`
- new `resources/templates/evaluator-entry.md`

Done when:

- the generator-to-evaluator transition is consistent and low-friction

## Phase 4: Token Efficiency, Asset Cleanup, And Documentation Alignment

### Objective

Reduce prompt overhead and maintenance drift without weakening the harness, and
close the remaining credibility gaps after the autonomous workflow stage lands.

### Step 14. Replace full context dump on session start with a compact summary

Change `session-start.sh` to emit:

- project summary
- exact test command
- protected paths summary
- active feature/task
- current gate status
- links to full canonical docs

Avoid catting the entire instruction file every session.

Files to modify:

- `scripts/hooks/session-start.sh`
- `resources/hooks/session-start.sh`
- `resources/instructions/github-instructions-template.md`

Done when:

- session start gives enough context to work while materially reducing recurring prompt size

### Step 15. Collapse duplicated assets into generated outputs

Choose one source-of-truth tree:

- `resources/` as canonical source

Treat these as generated/distributed outputs:

- `.github/skills/`
- `.github/prompts/`
- `scripts/hooks/` if desired

Files to add:

- `scripts/sync/sync_runtime_assets.py` or `.js`
- optional manifest file describing generated targets

Files to modify:

- `resources/skills/scripts/sync_agent_skills.py`
- `resources/skills/hooks-setup/SKILL.md`

Implementation notes:

- never hand-edit both source and distribution copies
- document regeneration as part of contribution workflow

Done when:

- runtime assets can be regenerated from one canonical source without drift

### Step 16. Refactor long prose skills into compact operational formats

For the highest-frequency skills, convert from essay-style guidance to:

- short overview
- state transitions
- required inputs
- produced outputs
- hard rules

Start with:

- `test-driven-development`
- `implementation-plans`
- `code-review`
- `session-handoff`

Done when:

- repeated loading of these skills costs less context while preserving behavior

### Step 17. Align documentation with actual runtime support

Normalize docs so they do not imply stronger runtime support than is wired today.

Files to review and adjust:

- `resources/skills/hooks-setup/SKILL.md`
- `resources/instructions/github-instructions-template.md`
- `README` or new root-level overview doc if added

Done when:

- platform claims for VS Code, IntelliJ, and Codex match the actual checked-in behavior and fallbacks

### Step 18. Make evaluator independence enforceable, not only instructed

For tasks that require evaluator review, add an execution path that creates or
verifiably requests a distinct evaluator session rather than relying on prose
discipline alone.

Files to add or modify:

- `scripts/workflow/request-evaluator.*`
- `scripts/workflow/generate-evaluator-packet.sh`
- `scripts/workflow/write-evaluator-result.py`
- `resources/skills/code-review/SKILL.md`
- `resources/skills/session-handoff/SKILL.md`

Implementation notes:

- require `reviewer_session` to differ from the generator session when the runtime can provide session ids
- if the runtime cannot spawn a new session directly, require an explicit independence attestation field in the result plus a deterministic launch path
- surface evaluator independence status in the workflow state and release summaries

Done when:

- evaluator-required tasks cannot satisfy the gate through same-session review unless explicitly allowed by policy
- the generator-to-evaluator transition is low-friction and auditable

### Step 19. Add machine-checkable semantic done conditions

Move beyond tests and evaluator verdicts by letting tasks declare small,
structured done-condition checks the harness can verify directly.

Files to add or modify:

- new `scripts/workflow/validate-task-done.*`
- `scripts/hooks/release-gate.sh`
- `resources/skills/implementation-plans/SKILL.md`
- spec template files under `resources/openspec/`

Implementation notes:

- add a normalized `Done checks` block per task for commands, file assertions, or state assertions
- keep checks compact and machine-readable; avoid long prose at runtime
- reserve prose `Done when` for human understanding, but make gating rely on the normalized check list

Done when:

- richer task done conditions can be enforced without depending on chat interpretation
- release gating uses structured task checks in addition to TDD and evaluator evidence

### Step 20. Raise evaluator-quality thresholds

Make evaluator pass verdicts more trustworthy by requiring stronger evidence and
review-mode-specific checks.

Files to add or modify:

- `scripts/hooks/evaluator-state.sh`
- `scripts/workflow/write-evaluator-result.py`
- `resources/templates/evaluator-result-template.json`
- `resources/skills/code-review/references/evaluator-calibration.md`

Implementation notes:

- require minimum criterion coverage for every acceptance criterion
- require explicit evidence references for every `MET` claim
- optionally require at least one adversarial mode for high-risk tasks
- reject evaluator results that are schema-valid but too weak to justify the verdict

Done when:

- evaluator results are judged on evidence quality, not only shape
- a low-effort blanket `pass` no longer satisfies the gate

### Step 21. Model non-code and low-code task classes explicitly

Differentiate implementation tasks from design, documentation, migration, and
coordination tasks so the harness applies the right gates without forcing every
task through the same loop.

Files to add or modify:

- `resources/skills/implementation-plans/SKILL.md`
- `scripts/hooks/state.sh`
- `scripts/workflow/select-next-task.py` or equivalent
- spec templates under `resources/openspec/`

Implementation notes:

- add a task mode such as `code | config | docs | review | migration`
- let the planner declare when TDD is not the correct gate, but require an explicit alternative validation mode
- keep mode handling compact so uncommon task classes do not increase common-path prompt load

Done when:

- non-code tasks are handled intentionally rather than as loose exceptions
- the workflow can pick and gate heterogeneous tasks without manual reinterpretation

## Cross-Cutting Design Decisions

These decisions should be made early, before implementation spreads:

### Decision 1. Canonical state location

Pick one:

- per-feature state file near the spec
- central run-state directory

Recommendation:

- use `specs/features/[feature].state.json` for portability and feature-locality

### Decision 2. Source of truth for task structure

Pick one:

- keep prose implementation plans and parse them
- add a normalized machine-readable task block to the spec

Recommendation:

- add a normalized machine-readable task section or adjacent task JSON file

### Decision 3. Gate behavior philosophy

Pick one:

- `warn` by default, `block` rarely
- `block` for workflow-critical violations

Recommendation:

- block for missing spec, failed done conditions, missing evaluator on required tasks, and invalid TDD sequence
- warn for softer style and hygiene issues

### Decision 4. Adversarial review threshold

Recommendation:

- mandatory for any task marked `Evaluator review: YES`
- optional for low-risk single-layer tasks

## Suggested Work Breakdown

### Milestone 1: Minimum Credible Harness

Implement:

- machine-readable task state
- active `TaskCompleted` gate
- stronger spec guard
- exact test command normalization

Outcome:

- the harness becomes enforceable, not just advisory

### Milestone 2: TDD-Proving Harness

Implement:

- TDD evidence state
- pre-edit test-first guard
- task phase transitions

Outcome:

- the harness can credibly claim TDD enforcement

### Milestone 3: Evaluated Harness

Implement:

- evaluator gating
- structured evaluator output
- handoff/evaluator launch packet

Outcome:

- self-evaluation and adversarial review become operational workflow stages

### Milestone 4: Autonomous Harness

Implement:

- next-task selector
- workflow commands
- adversarial review modes

Outcome:

- the harness can progress through work with minimal steering

### Milestone 5: Lean And Closed-Loop Harness

Implement:

- compact session-start summary
- generated runtime assets
- slimmer high-frequency skills
- doc/runtime alignment
- enforceable evaluator independence
- machine-checkable semantic done conditions
- stronger evaluator-quality thresholds
- explicit non-code task modeling

Outcome:

- the harness closes the remaining credibility gaps while becoming cheaper in
  tokens and easier to maintain

## Acceptance Criteria For The Upgraded Harness

The harness should be considered aligned to intent when all of the following are true:

1. An implementation task cannot begin without an active spec.
2. A task cannot be marked complete without:
   - red evidence
   - green evidence
   - passing declared validation
3. A task flagged for evaluator review cannot advance without an evaluator verdict.
4. Session reset/resume works from persisted state, not chat memory.
5. The harness can determine the next runnable task automatically.
6. High-risk tasks receive a repeatable adversarial review pass.
7. Session-start context is compact and does not dump entire instruction files by default.
8. Runtime assets are generated from one canonical source.
9. Evaluator-required tasks can prove reviewer independence according to policy.
10. Structured semantic done checks can be enforced without chat interpretation.
11. Non-code tasks declare explicit validation modes instead of bypassing the workflow implicitly.

## Recommended First Implementation Slice

If work starts immediately, do this first:

1. Add `specs/features/[feature].state.json`.
2. Update `.github/hooks/hooks.json` to include task completion gating.
3. Upgrade `spec-guard.sh` to block implementation without a spec.
4. Normalize “Exact Test Command” handling in setup docs and hook parsing.
5. Update `release-gate.sh` to read the active task from state and enforce required validations.

This is the fastest path from “good methodology” to “credible harness.”

## Final Note

Do not try to solve full autonomy by adding more prompt text first.

The biggest gap in the current harness is not lack of ideas. It is lack of:

- workflow state
- hard gates
- executable task progression
- enforced evaluator transitions

Implement those first. The rest becomes much easier and much more believable once the harness can prove what it did.
