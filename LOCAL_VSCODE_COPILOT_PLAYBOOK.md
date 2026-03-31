# Local VS Code Copilot Harness Playbook

Date: 2026-03-27

## Purpose

This playbook shows how to test the harness locally with GitHub Copilot in VS Code using Agent Mode.

It includes:

- a recommended sample project
- how to create a fresh repo
- which harness files to copy in
- which starter app files to create
- how to run the harness against a real feature
- what to observe while testing

## Recommended Test Project

Use a small but non-trivial project:

**Project:** `task-ops-api`

**Stack:**

- Node.js 20
- TypeScript
- Express
- Vitest
- Supertest

**Why this project**

It is small enough to build in a few sessions, but large enough to exercise:

- intent capture
- spec writing
- TDD
- task decomposition
- service/API layering
- failure-path tests
- evaluator review
- hooks and guardrails

## Project Goal

Build a small API for personal task management with these features:

1. Create a task
2. List tasks
3. Mark a task complete
4. Filter tasks by status
5. Reject invalid input cleanly

That is enough to test the harness without adding frontend complexity yet.

## Preconditions

Before starting, make sure you have:

- VS Code installed
- GitHub Copilot and GitHub Copilot Chat extensions installed
- Copilot Agent Mode available in your VS Code build
- Git installed
- Git Bash available in `PATH`
- Node.js and npm installed

## Automated Setup

The repo bootstrap in Phases 1-5 is now automated.

From a PowerShell terminal in `ghcp-harness`, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-local-vscode-copilot.ps1
```

By default, the script:

- creates `task-ops-api` as a sibling of `ghcp-harness`
- initializes Git
- creates the baseline folder structure
- copies the harness hooks, workflow helpers, templates, prompts, and skills
- writes the starter app, test, VS Code settings, Copilot instructions, and sample feature spec
- installs npm dependencies
- installs the local Git hooks if `bash` is available
- runs `npm test`

If you want a different target folder or project name:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-local-vscode-copilot.ps1 `
  -ProjectName my-harness-run `
  -OutputRoot C:\Users\jeffs\OneDrive\Documents\projects\Agents
```

Useful flags:

- `-Force` overwrites scaffold files in an existing repo directory
- `-SkipDependencyInstall` skips `npm install`
- `-SkipGitHooksInstall` skips `bash scripts/hooks/git/install.sh`
- `-SkipValidation` skips the final `npm test`

Use the skip flags when you only want the file scaffold, or when Node/npm/Git Bash are not ready yet.

## What The Script Creates

The script replaces the manual work that previously lived in Phases 1-5:

- repo creation and `git init`
- Node/TypeScript starter files
- baseline folders under `.github/`, `.vscode/`, `scripts/`, `resources/`, `specs/`, `src/`, and `tests/`
- harness runtime hook scripts and Git hooks
- workflow helpers and evaluator templates
- Copilot hook config, protected paths, prompts, and reusable skills
- starter `copilot-instructions.md`, `specs/arch.md`, and `specs/features/task-creation-and-completion.spec.md`

If you need to inspect or customize the bootstrap, see:

- `scripts/setup-local-vscode-copilot.ps1`

## Phase 6: Open In VS Code

### Step 1. Open the repo

```powershell
code C:\Users\jeffs\OneDrive\Documents\projects\Agents\task-ops-api
```

### Step 2. Verify Copilot sees the repo context

In VS Code:

- open Copilot Chat
- switch to Agent Mode
- confirm the repo is trusted
- confirm Copilot can see workspace files

## Phase 7: Drive The Harness

Use the following prompt sequence.

### Step 3. Start with discovery

Prompt:

```text
Read .github/copilot-instructions.md, specs/arch.md, and specs/features/task-creation-and-completion.spec.md.
Summarize the feature, the acceptance criteria, and the implementation tasks.
Do not implement anything yet.
```

Expected result:

- Copilot reads the spec
- the harness should orient around the repo and spec

### Step 4. Force the sprint contract step

Prompt:

```text
Use implementation-plans. Restate the feature in your own words, map each acceptance criterion to how you would verify it, and identify any ambiguity. Do not code yet.
```

Expected result:

- Copilot should produce a spec-grounded restatement
- you should confirm it before moving on

### Step 5. Run the TDD step for Task 1

Prompt:

```text
Use test-driven-development for Task 1 from specs/features/task-creation-and-completion.spec.md.
Write only the failing unit tests first for the task service. Do not implement yet.
```

Expected result:

- agent writes tests only
- no service implementation yet

Then run:

```powershell
npm test
```

You want to see failing tests for the right reason.

Checks:

- `.github/agent-state/active-run.json` should exist.
- `current_phase` should move to `green` after the first valid failing test run.
- `task_list_snapshot[0].tdd.red_observed` should become `true`.
- If you try to edit `src/services/task-service.ts` before Red, Copilot should ask for confirmation or otherwise show TDD friction.

### Step 6. Ask for the minimum implementation

Prompt:

```text
Now implement the minimum code to make the Task 1 unit tests pass. Keep business rules in src/services/task-service.ts.
```

Then run:

```powershell
npm test
```

Checks:

- the passing run after Red should move `current_phase` to `refactor`
- `task_list_snapshot[0].tdd.green_observed` should become `true`
- `task_list_snapshot[0].tdd.task_complete_allowed` should become `true`

### Step 7. Ask for refactor only if green

Prompt:

```text
Refactor Task 1 for clarity without changing behavior. Keep the tests green.
```

Then re-run:

```powershell
npm test
```

### Step 8. Move to Task 2

Prompt:

```text
Use test-driven-development for Task 2 from the active spec.
Write the failing integration tests first for create/list/complete and failure cases. Do not implement yet.
```

Then:

```powershell
npm test
```

Then ask for the minimal route implementation.

Repeat the same checks for Task 2. The harness should require a new Red for the
new task rather than reusing Task 1 evidence.

### Step 9. Verify completion gating

Before marking a task complete in Copilot, inspect:

```powershell
Get-Content .github/agent-state/active-run.json
```

You want to confirm the active task shows:

- `red_observed: true`
- `green_observed: true`
- `task_complete_allowed: true`

If you attempt completion after a passing run but without a prior Red, the
release gate should block completion.

## Phase 8: Exercise Review And Evaluator Gating

### Step 10. Run self-check review

Prompt:

```text
Use code-review. Review the current implementation against the active spec and file findings against the acceptance criteria.
```

### Step 11. Generate the evaluator packet for the evaluator-gated task

After Task 2 is green, run:

```powershell
bash scripts/workflow/generate-evaluator-packet.sh
```

Checks:

- `.github/agent-state/evaluator-packet-task-2.md` should be created.
- The packet should include the active spec, Task 2 title, exact test command, and the expected result path.

### Step 12. Run separate-session evaluator review

Open a fresh Copilot session and prompt:

```text
You are the evaluator for a completed implementation. Your job is to find problems, not to praise the work.

Read in this order:
1. .github/copilot-instructions.md
2. specs/features/task-creation-and-completion.spec.md
3. .github/agent-state/evaluator-packet-task-2.md
4. The changed files for the feature

For each acceptance criterion, state whether it is MET, PARTIALLY MET, or NOT MET, with evidence.
Flag weak tests, behavior gaps, and accidental scope creep.
Write the structured evaluator JSON result to .github/agent-state/evaluator-result-task-2.json.
```

Checks:

- The evaluator result file should include `feature`, `task_id`, `verdict`, `review_mode`, `reviewed_at`, `reviewer_session`, `criteria_results`, and `findings`.
- Allowed verdicts are `pass`, `pass_with_risks`, and `fail` only.

### Step 13. Record the evaluator result into workflow state

From the generator session, run:

```powershell
python scripts/workflow/write-evaluator-result.py .github/agent-state/evaluator-result-task-2.json
```

Checks:

- `.github/agent-state/active-run.json` should show the Task 2 `evaluator` block populated.
- Top-level `.evaluator.verdict` should match the recorded result.
- `blocking_findings` and `non_blocking_findings` should reflect the artifact.

### Step 14. Verify evaluator-gated completion behavior

Perform all of these checks:

- Delete or rename `.github/agent-state/evaluator-result-task-2.json` and verify completion is blocked.
- Restore the file but remove required fields or make the `task_id` wrong and verify `write-evaluator-result.py` rejects it.
- Record a result with `verdict: fail` and at least one blocking finding and verify completion is blocked even if tests are green.
- Record a result with `verdict: pass` and verify completion is allowed when TDD evidence and the full-suite command are also green.
- Record a result with `verdict: pass_with_risks` and verify completion is still allowed.

## Phase 9: Manual Validations From `tmp/`

These checks roll up the manual expectations already represented by the repo's
temporary smoke fixtures.

### Milestone 1 parity checks

From the behavior covered under `tmp/harness-smoke/`, `tmp/harness-smoke-final/`,
`tmp/harness-smoke-nospec/`, and `tmp/harness-smoke-final-nospec/`, verify:

- Starting a session with an active spec creates `.github/agent-state/active-run.json`.
- The state file resolves `active_feature`, `active_spec`, `current_task_id`, and `current_phase` from the spec alone.
- `session-start.sh` reports the active feature/spec/current task instead of requiring state reconstruction from chat.
- If there is no active spec and you submit an implementation prompt like `implement the feature now`, `spec-guard.sh` blocks it.
- `TaskCompleted` only works when an exact full-suite command exists in `## Exact Test Commands`.
- The release gate records the last test command and last test result back into state.

### Milestone 2 parity checks

From the behavior covered under `tmp/milestone-2-smoke/`, verify:

- After the first valid failing test run for a task, `.github/agent-state/active-run.json` shows `red_observed: true` and `current_phase: green`.
- Test infrastructure failures such as `command not found` do not count as valid Red evidence.
- Test-file edits under `tests/` remain allowed before Red.
- Implementation-file edits under `src/` before Red trigger `file-guard.sh` friction.
- After a later passing test run for the same task, the state file shows `green_observed: true`, `task_complete_allowed: true`, and `current_phase: refactor`.
- When Copilot moves from Task 1 to Task 2, the new task requires its own Red and Green evidence.
- Completion is blocked without prior Red.
- Completion is blocked with Red but no later Green.
- Completion only succeeds once Red, Green, and the declared full-suite command all succeed.

### Milestone 3 checks

Verify all of these locally:

- A task with `Evaluator review: NO` still completes through the Milestone 1 and 2 gates.
- A task with `Evaluator review: YES` and no recorded evaluator result is blocked at completion.
- A malformed evaluator result artifact is rejected by `python scripts/workflow/write-evaluator-result.py ...`.
- A recorded evaluator result with `verdict: fail` blocks completion.
- A recorded evaluator result with `verdict: pass` allows completion when TDD evidence and the full-suite command are also green.
- A recorded evaluator result with `verdict: pass_with_risks` also allows completion and leaves residual risks visible in `.github/agent-state/active-run.json`.
- Re-running session start or state sync does not erase the evaluator result for the same task.

## Phase 10: What To Observe While Testing

Use this checklist.

### Intent discipline

- Did Copilot read the spec before coding?
- Did it stay within scope?
- Did it map work back to acceptance criteria?

### TDD discipline

- Did it write tests before implementation?
- Did the first test run fail for the expected reason?
- Did it avoid implementation leakage into the test-writing step?

### Task discipline

- Did it stay on Task 1 before jumping to Task 2?
- Did it define “done” in terms of tests?
- Did it keep route and service concerns separated?

### Evaluation discipline

- Did self-review catch anything meaningful?
- Did the fresh evaluator session find issues the generator session missed?
- Did the structured evaluator result line up with the actual review findings?

### Harness behavior

- Did `session-start` orient the session?
- Did `spec-guard` trigger when appropriate?
- Did `test-failure-capture` help after failed test runs?
- Did `release-gate.sh` enforce both TDD and evaluator gates?
- Did the git hooks work locally?

## Milestone 2 Checks

Add these checks to every local Copilot run:

- After the first valid failing test run for a task, `.github/agent-state/active-run.json` should show `red_observed: true` for that task and `current_phase: green`.
- After a later passing test run for the same task, the state file should show `green_observed: true`, `task_complete_allowed: true`, and `current_phase: refactor`.
- If Copilot tries to edit an implementation file such as `src/services/task-service.ts` before Red, `file-guard.sh` should ask for confirmation or otherwise show TDD friction.
- Test-file edits under paths like `tests/` should still be allowed before Red.
- When Copilot moves from Task 1 to Task 2, the new task should require its own Red and Green evidence rather than reusing Task 1 state.
- If completion is attempted without prior Red, or with Red but no later Green, `release-gate.sh` should block the completion attempt.
- Completion should only succeed once Red, Green, and the declared full-suite command have all succeeded.

## Milestone 3 Checks

Add these checks for evaluator-gated tasks:

- `session-start.sh` should show evaluator requirement, status, verdict, and the expected packet path for the active task.
- `bash scripts/workflow/generate-evaluator-packet.sh` should create a deterministic evaluator packet under `.github/agent-state/`.
- `python scripts/workflow/write-evaluator-result.py ...` should reject malformed JSON or artifacts that do not match the active task.
- The active task `evaluator` block in `.github/agent-state/active-run.json` should capture `status`, `verdict`, `review_mode`, `result_path`, `reviewed_at`, reviewer session, finding counts, and criterion summaries.
- `release-gate.sh` should block evaluator-required tasks when the result is missing, malformed, pending, or failed.
- `release-gate.sh` should allow evaluator-required tasks only when the verdict is `pass` or `pass_with_risks` and the Milestone 2 TDD gates also pass.

### Milestone 4 checks

Verify all of these locally:

- `python scripts/workflow/select-next-task.py` should return the first runnable incomplete task whose `Depends on` tasks are complete.
- `bash scripts/workflow/start-feature.sh <spec>` should sync state and set the next runnable task automatically.
- `bash scripts/workflow/start-task.sh <task-id>` should refuse blocked tasks with incomplete dependencies.
- `bash scripts/workflow/complete-task.sh` should run the release gate, mark the active task complete, and advance `current_task_id` to the next runnable task.
- `bash scripts/workflow/request-evaluator.sh` should emit an evaluator packet that includes the current task's adversarial review modes.
- High-risk evaluator-gated tasks without an explicit `Adversarial review:` line should still show inferred review modes in `.github/agent-state/active-run.json`.

## What Counts As A Good Local Test

The local test is successful if:

1. You can bootstrap a new repo with the harness files.
2. Copilot Agent Mode reads and uses the spec as the source of truth.
3. The agent can implement both tasks through tests and validation.
4. A fresh evaluator session can return a structured result against acceptance criteria.
5. The hooks provide useful friction rather than random noise.

## What This Test Will Not Yet Prove

This playbook will let you validate the harness directionally, but it will not prove full autonomy yet.

It will not prove:

- automatic next-task selection
- automatic spawning of a fresh evaluator session

For Milestone 3 specifically, this playbook should now prove local task-state
enforcement, local TDD evidence tracking, and local evaluator gating once a
structured evaluator result is recorded.

Those are the upgrades described in `HARNESS_IMPLEMENTATION_PLAN.md`.

## Recommended Next Experiment

Once `task-ops-api` works, run a second, slightly harder experiment:

**Project:** `task-ops-api-v2`

Add:

- persistent storage with SQLite
- migration file
- one cross-cutting feature like due dates or tags

That will stress:

- migration safety
- cross-layer planning
- evaluator review quality
- context-window preservation across longer work

## Minimal File Checklist

For the new test repo, the minimum useful file set is:

```text
.github/copilot-instructions.md
.github/hooks/hooks.json
.github/hooks/protected-paths.txt
.github/skills/*
.github/prompts/*
.vscode/settings.json
.vscode/extensions.json
scripts/hooks/common.sh
scripts/hooks/state.sh
scripts/hooks/tdd-state.sh
scripts/hooks/evaluator-state.sh
scripts/hooks/session-start.sh
scripts/hooks/spec-guard.sh
scripts/hooks/file-guard.sh
scripts/hooks/bash-guard.sh
scripts/hooks/test-failure-capture.sh
scripts/hooks/pre-compact-handoff.sh
scripts/hooks/lesson-capture-gate.sh
scripts/hooks/release-gate.sh
scripts/hooks/git/commit-msg
scripts/hooks/git/pre-commit
scripts/hooks/git/pre-push
scripts/hooks/git/install.sh
scripts/workflow/generate-evaluator-packet.sh
scripts/workflow/write-evaluator-result.py
resources/templates/evaluator-entry.md
resources/templates/evaluator-result-template.json
specs/arch.md
specs/features/task-creation-and-completion.spec.md
src/app.ts
src/server.ts
tests/integration/health.test.ts
package.json
tsconfig.json
vitest.config.ts
```

## Final Guidance

For the first run, keep the project small and keep yourself in the loop.

The right goal for this playbook is not “prove full autonomy.” It is:

- prove the harness can shape Copilot behavior
- identify where the hooks help
- identify where the workflow still depends on manual steering

That gives you a clean baseline before you implement the stronger harness changes.
