# ghcp-harness

A workflow harness for GitHub Copilot that enforces spec-first development, TDD evidence, and evaluator review before any task can ship.

The harness controls how the agent works through a feature — from intent capture through to release — using lifecycle hooks, durable workflow state, and completion gates that block progress until required conditions are met.

---

## What It Enforces

- **Spec before code.** The agent cannot start implementation without an active feature spec. The spec-guard fires on every prompt.
- **TDD sequence.** Each task requires a recorded failing test (Red) before implementation, and a passing test (Green) before completion. The release gate checks for both.
- **Evaluator review.** Tasks flagged for evaluator review require a fresh-session verdict before the next task starts. Weak or same-session reviews are rejected.
- **Integration gate.** After all tasks complete, the full test suite must pass before release. Per-task green tests prove isolation. The integration run proves composition.
- **Session continuity.** Workflow state persists in `.github/agent-state/active-run.json`. Resumed sessions pick up from state, not from reconstructed conversation history.

---

## Requirements

- **GitHub Copilot** with Agent Mode (VS Code or IntelliJ)
- **Bash** available in the terminal (`git bash` on Windows)
- **Python 3.10+** for workflow scripts
- **jq** (optional but recommended — hooks fall back to Python if missing)

---

## Structure

```
resources/          Canonical source for all harness assets
  hooks/            Hook scripts (source of truth)
  skills/           Skill prompt files per workflow mode
  instructions/     Copilot instructions template
  spec/             Spec templates (basic and advanced)
  templates/        Evaluator result and entry templates

scripts/
  hooks/            Runtime copies of hook scripts (synced from resources/)
  workflow/         Workflow commands (start-feature, mark-red, complete-task, etc.)
  sync/             Asset sync tool

.github/
  hooks/            hooks.json wired for GitHub Copilot
  skills/           Runtime skill copies (synced from resources/)
  prompts/          Generated prompt files per skill
```

`resources/` is the canonical edit tree. `scripts/hooks/`, `.github/skills/`, and `.github/prompts/` are generated outputs. Regenerate them after editing resources:

```bash
python scripts/sync/sync_runtime_assets.py
```

---

## Setup

### 1. Copy the harness into your repo

Copy the following into your target repo:

```
.github/hooks/hooks.json
.github/hooks/protected-paths.txt
scripts/hooks/
scripts/workflow/
scripts/sync/
resources/
```

Make hook scripts executable:

```bash
chmod +x scripts/hooks/*.sh
chmod +x scripts/hooks/git/*
chmod +x scripts/workflow/*.sh
```

### 2. Create your instructions file

Copy `resources/instructions/github-instructions-template.md` to `.github/copilot-instructions.md` in your repo and fill in every section. The `## Exact Test Commands` section is required — the release gate and integration gate read the full-suite command from it.

### 3. Install git hooks

```bash
bash scripts/hooks/git/install.sh
```

### 4. Create a spec for your first feature

Copy `resources/spec/basic-spec-template.json` or `resources/spec/advanced-spec-template.yml` to `specs/features/[feature-name].spec.md` and fill it in.

---

## Workflow Commands

Run from the repo root:

| Command | What it does |
|---|---|
| `bash scripts/workflow/start-feature.sh specs/features/<feature>.spec.md` | Initializes state from a spec and picks the first task |
| `bash scripts/workflow/resume-run.sh` | Refreshes state and reports current phase on session resume |
| `python scripts/workflow/select-next-task.py` | Reports the next runnable task |
| `bash scripts/workflow/start-task.sh <task-id>` | Moves the active pointer to a specific task |
| `bash scripts/workflow/mark-red.sh "<failing test command>"` | Records Red evidence for the active task |
| `bash scripts/workflow/mark-green.sh "<passing test command>"` | Records Green evidence for the active task |
| `bash scripts/workflow/request-evaluator.sh` | Generates an evaluator packet for fresh-session review |
| `bash scripts/workflow/write-evaluator-result.py <result.json>` | Records an evaluator verdict into state |
| `bash scripts/workflow/acknowledge-task.sh "<note>"` | Records manual acknowledgement for non-code tasks |
| `bash scripts/workflow/mark-integration-passed.sh` | Runs the full suite and records the result (required after all tasks complete) |
| `bash scripts/workflow/complete-task.sh` | Runs the release gate, then marks the task complete and advances to the next |
| `python scripts/sync/sync_runtime_assets.py` | Regenerates runtime assets from `resources/` |

---

## Workflow Phases

```
intent → planning → red → green → refactor → evaluator → integration → release
```

The harness tracks phase in state. Each `SessionStart` reports the current phase. The release gate blocks completion if the required phase conditions are not met.

After the last task completes, the harness enters `integration` phase. Run `mark-integration-passed.sh` to execute the full suite and advance to `release`.

---

## Skills

Skills are focused prompt files that tell the agent how to execute a specific workflow mode. Load them by referencing the skill name in your prompt or by using the generated `.github/prompts/` files.

Key skills:

| Skill | When to use |
|---|---|
| `implementation-plans` | After architecture is settled, before coding starts |
| `test-driven-development` | During red/green/refactor cycles |
| `code-review` | For evaluator review sessions |
| `session-handoff` | When a session is running long or needs to pause |
| `release-readiness` | Before opening an MR |
| `hooks-setup` | When installing the harness on a new repo |
