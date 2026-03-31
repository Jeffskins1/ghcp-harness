# GitHub Copilot Agentic Harness Evaluation v6

Date: 2026-03-27

## Scope

This reevaluation reflects the repo after Milestone 5 implementation.

Milestone 5 adds:

- explicit task typing and validation modes
- machine-checkable semantic checks
- evaluator independence proof and stronger evaluator-quality thresholds
- generated session summary output
- runtime asset sync from canonical `resources/`
- cleanup guidance for canonical vs generated vs disposable files

## Executive Verdict

The harness is now a closed-loop workflow driver for the cases it explicitly
models.

Compared with v5, it can now prove more than sequence and gate status:

- it can prove how a non-code task is validated
- it can prove whether semantic done conditions passed or failed
- it can reject evaluator results that are independent in name only
- it can reject evaluator artifacts that are syntactically valid but weak
- it can regenerate mirrored runtime assets from one source tree

The remaining limits are narrower and more honest:

- evaluator execution is still external to the hook runtime
- shell-hook behavior was implemented by inspection here because this Windows
  environment would not execute `bash`
- the repo still contains generated/runtime output and old smoke debris that
  should be cleaned or regenerated intentionally

## Updated Scorecard

| Area | Original | v5 | v6 | Notes |
|---|---|---|---|---|
| Intent capture | Strong | Strong | Strong | No regression. |
| Plan generation | Strong | Stronger | Stronger | Plans now carry validation semantics, not just ordering. |
| Stepwise execution | Moderate | Stronger | Stronger | No major change, but task types reduce ambiguity. |
| TDD enforcement | Moderate | Strong | Strong | Code tasks still preserve Red/Green gating. |
| Done-condition enforcement | Weak to Moderate | Strong | Stronger | Semantic checks move non-test completion out of prose-only territory. |
| Self-evaluation | Moderate | Moderate to Strong | Stronger | Independence proof is now runtime-checked. |
| Adversarial evaluation | Moderate | Stronger | Stronger | Required modes are now acknowledged in result ingestion. |
| Hands-off viability | Weak to Moderate | Stronger | Stronger | Non-code tasks are no longer implicit exceptions. |
| Token efficiency | Moderate | Moderate to Strong | Stronger | Session start is compact and summary-driven. |
| Context preservation | Moderate to Strong | Stronger | Stronger | `.github/agent-state/session-summary.json` reduces resume overhead. |
| Maintainability | Moderate | Moderate | Stronger | Canonical asset sync now makes mirrored drift structurally avoidable. |

## What Improved In v6

### 1. Non-code work is now first-class

Relevant files:

- `scripts/hooks/state.sh`
- `scripts/hooks/release-gate.sh`
- `resources/skills/implementation-plans/SKILL.md`
- `resources/skills/writing-plans/SKILL.md`

Tasks can now declare:

- `Task type`
- `Validation mode`
- `TDD`
- `Semantic checks`

That closes one of the biggest credibility gaps from earlier versions: the
harness no longer quietly assumes everything is code or quietly exempts
everything else.

### 2. Semantic done conditions are now machine-checkable

Relevant files:

- `scripts/workflow/evaluate-semantic-checks.py`
- `scripts/hooks/release-gate.sh`
- `scripts/hooks/state.sh`

Supported checks are intentionally narrow and deterministic:

- `file_exists`
- `file_contains`
- `state_equals`
- `artifact_exists`
- `command_exit_code`

This is the right shape. It raises proof quality without adding another LLM loop.

### 3. Evaluator review is materially harder to game

Relevant files:

- `scripts/workflow/request-evaluator.sh`
- `scripts/workflow/write-evaluator-result.py`
- `scripts/hooks/evaluator-state.sh`
- `resources/templates/evaluator-result-template.json`

The harness now records:

- packet id
- packet launch timestamp
- generator session
- independence policy
- applied adversarial review modes
- quality-gate outcome

That means a review can now fail for being weak even if the JSON is well-formed.
That is a real credibility upgrade.

### 4. Runtime assets now have a canonical source

Relevant files:

- `scripts/sync/sync_runtime_assets.py`
- `resources/skills/`
- `resources/hooks/`

`resources/` is now the canonical edit tree. Runtime copies under `.github/`
and `scripts/hooks/` can be regenerated.

This does not eliminate duplication from the checked-in tree, but it does
eliminate manual duplication as the maintenance model.

### 5. Session start is now summary-oriented

Relevant files:

- `scripts/hooks/session-start.sh`
- `scripts/workflow/workflow_state.py`
- `.github/agent-state/session-summary.json`

Startup no longer needs to rely on large static context dumps to tell the agent
where it is. That is both cheaper and more robust.

## Post-v6 Addition: Feature Integration Gate

Added after v6 evaluation (2026-03-31).

### Gap closed

Per-task TDD evidence (red/green) only proves each task in isolation. Nothing
previously required the full test suite to pass across all tasks together before
release. Cross-task conflicts — one task's changes breaking another's — could
pass all individual gates and still ship broken.

### What was added

- `workflow_state.py`: when `complete_current_task()` returns no next task (all
  done), state transitions to `current_phase: "integration"` with
  `feature_integration.required: true, full_suite_passed: false`.
- `scripts/workflow/mark-integration-passed.sh`: agent runs this explicitly.
  It executes the full suite command from the repo's `## Exact Test Commands`
  section, records pass/timestamp/command in state, and advances phase to
  `"release"`. Fails hard if tests fail — state is not updated.
- `release-gate.sh` (both `resources/hooks/` and `scripts/hooks/`): new block
  before all per-task checks — if `feature_integration.required` is true and
  `full_suite_passed` is not, gate blocks with instructions to run the script.

### Enforcement model

The gate follows the same pattern as the evaluator gate: the agent is
responsible for running the check; the hook enforces that it happened and
passed before release is allowed. The hook does not run the suite inline.

### Staleness

The recorded result includes a timestamp. If the agent edits files after the
integration run, agent discipline is required to re-run. No automatic
invalidation — same trade-off as the evaluator verdict.

### Skills and templates updated

- `resources/skills/release-readiness/SKILL.md`
- `resources/skills/session-handoff/SKILL.md`
- `resources/skills/implementation-plans/SKILL.md`
- `resources/skills/hooks-setup/SKILL.md`
- `resources/openspec/advanced-spec-template.yml`
- `resources/openspec/basic-spec-template.json`

## Residual Risks

### 1. Hook verification is still environment-sensitive

I could compile and smoke the Python-side components, but this Windows sandbox
would not execute `bash`, so the shell-hook path was validated by inspection
plus mirrored sync, not by full end-to-end shell execution.

### 2. Generated trees still exist as committed runtime outputs

Even with sync in place, the repo still contains generated/runtime directories:

- `.github/skills/`
- `.github/prompts/`
- `scripts/hooks/`

That is acceptable if the repo wants to be immediately runnable, but it means
cleanup needs policy, not guesswork.

### 3. Old smoke artifacts still muddy the repo

The `tmp/` tree still contains multiple historical smoke directories from older
milestones. They are useful for archaeology, but they are not part of the
harness runtime contract.

## Cleanup Inventory

### Required Canonical Sources

Keep these as the real source of truth:

- `resources/instructions/`
- `resources/openspec/`
- `resources/templates/`
- `resources/skills/`
- `resources/hooks/`
- `scripts/workflow/`
- `scripts/sync/`
- milestone and evaluation docs you still want as design history

### Required Runtime Outputs

Keep these if you want the harness to work immediately after checkout:

- `.github/hooks/hooks.json`
- `.github/hooks/protected-paths.txt`
- `.github/skills/`
- `.github/prompts/`
- `scripts/hooks/`

These are not canonical anymore, but they are operationally required unless you
run the sync command after checkout.

### Regenerable Outputs

These can be deleted and recreated with `python scripts/sync/sync_runtime_assets.py`:

- `.github/skills/`
- `.github/prompts/`
- `scripts/hooks/`

Recommendation: keep them if you want zero-setup runtime behavior; delete them
only if your cleanup process always reruns sync.

### Safe To Delete Now

These are not required for harness behavior:

- `tmp/harness-smoke/`
- `tmp/harness-smoke-final/`
- `tmp/harness-smoke-final-nospec/`
- `tmp/harness-smoke-nospec/`
- `tmp/milestone-2-smoke/`
- `tmp/milestone5-smoke/`
- `scripts/workflow/__pycache__/`
- `resources/skills/scripts/__pycache__/`

### Candidate Historical Docs To Prune

Only delete these if you no longer want the audit trail:

- `HARNESS_EVALUATION.md`
- `HARNESS_EVALUATION_V2.md`
- `HARNESS_EVALUATION_V3.md`
- `HARNESS_EVALUATION_V4.md`
- `HARNESS_EVALUATION_V5.md`
- `MILESTONE_2_PLAN.md`
- `MILESTONE_3_PLAN.md`

I would keep them until the harness stabilizes, then fold them into one concise
design-and-history document.

## Recommended Cleanup Policy

If the goal is a clean but runnable repo, keep:

- `resources/`
- `scripts/workflow/`
- `scripts/sync/`
- `.github/hooks/hooks.json`
- `.github/hooks/protected-paths.txt`
- generated `.github/skills/`, `.github/prompts/`, and `scripts/hooks/`

Delete:

- all `tmp/` smoke trees
- all `__pycache__/` directories

If the goal is a minimum-source repo instead, keep only canonical sources plus
the two `.github/hooks/` config files, and make `python scripts/sync/sync_runtime_assets.py`
part of setup.

## Final Assessment

v6 is the first version of this harness that can reasonably claim:

- explicit workflow state
- deterministic completion semantics for both code and non-code tasks
- enforced evaluator independence policy
- maintainable generated runtime assets

That is a meaningful threshold crossing.

The next work should be cleanup and consolidation, not more ceremony.
