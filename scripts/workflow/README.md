# Workflow Commands

Milestone 4 adds a repeatable command layer on top of the harness state file.

Use these commands from the repo root:

- `bash scripts/workflow/start-feature.sh specs/features/<feature>.spec.md`
- `bash scripts/workflow/resume-run.sh`
- `bash scripts/workflow/select-next-task.py`
- `bash scripts/workflow/start-task.sh <task-id>`
- `bash scripts/workflow/mark-red.sh "<failing test command>"`
- `bash scripts/workflow/mark-green.sh "<passing test command>"`
- `bash scripts/workflow/request-evaluator.sh [fresh_session|same_session]`
- `bash scripts/workflow/acknowledge-task.sh "<note>"`
- `python scripts/workflow/evaluate-semantic-checks.py`
- `python scripts/sync/sync_runtime_assets.py`
- `bash scripts/workflow/complete-task.sh`

Behavior:

- `start-feature` syncs the spec into `.github/agent-state/active-run.json` and picks the first runnable task.
- `resume-run` refreshes state from the active spec and re-selects the next runnable task if needed.
- `select-next-task.py` reports the next runnable task from task status plus `Depends on`.
- `start-task` validates dependencies before moving the active pointer.
- `mark-red` and `mark-green` drive task-scoped TDD state without relying on free-form chat.
- test edits after Red now trigger confirmation and invalidate existing TDD evidence if the edit is applied.
- `request-evaluator` emits a deterministic evaluator packet and preserves the requested reviewer session mode.
- `acknowledge-task` records explicit validation for tasks using `Validation mode: manual_ack`.
- `evaluate-semantic-checks.py` evaluates machine-checkable done conditions for the active task.
- `sync_runtime_assets.py` regenerates `.github/skills`, `.github/prompts`, and `scripts/hooks` from `resources/`.
- `complete-task` runs the release gate first, then marks the active task complete and advances to the next runnable task automatically.

Task plan requirements:

- Each task should include `Depends on: none` or a concrete prior task id.
- Each task should include `Task type`, `Validation mode`, and `TDD`.
- Tasks using `Validation mode: semantic_checks` should include a `Semantic checks:` block.
- High-risk evaluator-gated tasks should include `Adversarial review:` when the default inferred review lenses are not enough.
- Evaluator-gated tasks should include `Independence policy:` when they require fresh-session proof.
- Supported adversarial review modes are `contract_adversary`, `regression_adversary`, `security_adversary`, and `token_context_adversary`.
