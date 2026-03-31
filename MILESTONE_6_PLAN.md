# Milestone 6 Plan: Harness Instrumentation And Continuous Improvement

Date: 2026-03-27

## Objective

Instrument the harness so it can produce reliable measures of effectiveness,
quality, friction, and context economy across multiple developers without
turning runtime state into a merge-conflict magnet.

Milestone 6 should add a telemetry model that is:

- local-first for active runtime state
- safe for multiple developers on different workstations
- cheap enough to leave on by default
- structured enough to support trend analysis
- explicit about what is shared versus what remains local

This milestone should deliver five concrete outcomes:

1. The harness emits structured events for key workflow transitions and failures.
2. Local runtime telemetry stays uncommitted and per-worktree.
3. Developers can export sanitized per-workstation summaries for aggregation.
4. CI or batch tooling can aggregate summaries into team-level metrics.
5. The repo gains a clear observability contract for harness improvement.

## Problem Statement

The harness now has strong runtime state and deterministic gates, but it still
lacks a historical telemetry stream.

That means it can answer:

- what is true right now

But it cannot reliably answer:

- where developers get blocked most often
- whether evaluator gates are catching real issues
- whether task lead time is improving or worsening
- whether session-start and handoff payloads are creeping upward
- whether the harness is earning its complexity over time

Snapshots are not enough for continuous improvement. We need append-only events
plus derived summaries.

## Core Design Decision

### Separate runtime state from telemetry

Do not reuse `.github/agent-state/active-run.json` as the historical record.

Use two layers:

1. Local runtime state
2. Local event capture plus shared derived summaries

This keeps active workflow files practical while still enabling analytics.

## Target Storage Model

### Local runtime state

These remain local, operational, and generally uncommitted:

- `.github/agent-state/active-run.json`
- `.github/agent-state/session-summary.json`
- `.github/agent-state/events.jsonl`
- `.github/agent-state/evaluator-result-*.json`
- `.github/agent-state/evaluator-packet-*.md`

### Shared derived artifacts

These are safe to aggregate and optionally publish through CI:

- `artifacts/harness-metrics/<developer>-<machine>-<date>.json`
- `artifacts/harness-metrics/<developer>-<machine>-<date>.md`
- `artifacts/harness-metrics/summary/<date>.json`
- optional `metrics/harness-weekly-summary.md`

Raw event logs should not be committed. Derived summaries are the shared layer.

## Event Model

Introduce an append-only local event stream:

- `.github/agent-state/events.jsonl`

Each line is one structured event.

Recommended common fields:

```json
{
  "timestamp": "2026-03-27T18:15:00Z",
  "run_id": "sample-feature-20260327-1810",
  "feature": "sample-feature",
  "task_id": "3",
  "task_type": "code",
  "phase": "green",
  "session_id": "codex-session-abc",
  "event_type": "release_gate_blocked",
  "status": "blocked",
  "reason_code": "missing_green",
  "validation_modes": ["tests"],
  "metadata": {
    "attempt": 1
  }
}
```

### Required event types

- `feature_started`
- `run_resumed`
- `task_started`
- `red_recorded`
- `green_recorded`
- `manual_ack_recorded`
- `semantic_checks_evaluated`
- `evaluator_requested`
- `evaluator_result_recorded`
- `release_gate_passed`
- `release_gate_blocked`
- `task_completed`
- optional `feature_completed`

### Required reason codes for blocked or failed events

- `missing_validation_mode`
- `missing_test_command`
- `missing_red`
- `missing_green`
- `semantic_check_failed`
- `manual_ack_missing`
- `evaluator_pending`
- `evaluator_independence_failed`
- `evaluator_quality_failed`
- `evaluator_blocking_findings`
- `full_suite_failed`

Stable reason codes matter more than verbose messages.

## Measures To Derive

Milestone 6 should focus on four measure families.

### 1. Flow efficiency

- task lead time
- feature lead time
- time spent blocked
- resume frequency
- handoff frequency

### 2. Gate effectiveness

- release gate block rate
- block reasons distribution
- semantic-check fail rate
- evaluator rejection rate
- evaluator independence-failure rate

### 3. Quality and credibility

- evaluator disagreement rate
- pass-with-risks rate
- adversarial-review coverage rate
- rework proxy: follow-up tasks attributable to earlier incomplete work

### 4. Context economy

- session-start payload size
- evaluator packet size
- handoff note size
- active spec size
- task block size
- context-to-completion ratio proxy

Do not try to measure everything. Start with durable, operational signals.

## Out Of Scope

Milestone 6 should not:

- store raw transcripts in the repo
- export prompt text or evaluator evidence bodies as telemetry
- build a full external telemetry service
- depend on centralized infra to function locally
- add model-token accounting unless the runtime can capture it reliably

## Workstreams

### Workstream 1: Add an event emitter

Primary files:

- new `scripts/metrics/emit-event.py`
- `scripts/hooks/common.sh`
- `scripts/workflow/README.md`

Changes:

- add a tiny shared event-emission utility
- write newline-delimited JSON to `.github/agent-state/events.jsonl`
- make event writes safe when the file does not yet exist
- include current feature, task, phase, and validation context automatically when possible

Acceptance criteria:

- one command can append a well-formed event
- emitted events are valid JSONL and stable in schema
- event writing is cheap enough for hook usage

### Workstream 2: Instrument workflow commands and gates

Primary files:

- `scripts/workflow/start-feature.sh`
- `scripts/workflow/resume-run.sh`
- `scripts/workflow/start-task.sh`
- `scripts/workflow/mark-red.sh`
- `scripts/workflow/mark-green.sh`
- `scripts/workflow/request-evaluator.sh`
- `scripts/workflow/acknowledge-task.sh`
- `scripts/workflow/complete-task.sh`
- `scripts/hooks/release-gate.sh`
- `scripts/workflow/evaluate-semantic-checks.py`
- `scripts/workflow/write-evaluator-result.py`

Changes:

- emit task lifecycle events
- emit release-gate pass/block events
- emit evaluator request/result events
- emit semantic-check result events
- emit manual-ack events
- attach stable reason codes to failures

Acceptance criteria:

- a normal task lifecycle produces a coherent event trail
- blocked flows emit reason-coded failure events
- evaluator independence and quality failures are visible in telemetry

### Workstream 3: Export sanitized local metrics

Primary files:

- new `scripts/metrics/export-local-metrics.py`
- new `artifacts/harness-metrics/` conventions documented in repo docs

Changes:

- read local `events.jsonl`
- calculate bounded summary metrics
- emit a sanitized JSON summary
- optionally emit a human-readable markdown companion

Suggested output fields:

- developer id
- machine id
- repo id
- date range
- tasks completed
- features started
- median task lead time
- release gate block rate
- block reasons
- semantic-check failures
- evaluator requests
- evaluator rejections
- independence failures
- median session-start payload size
- median evaluator packet size
- median handoff note size

Acceptance criteria:

- export does not include transcripts, prompt text, or large free-form bodies
- export can run on a workstation without CI
- export output is stable enough for later aggregation

### Workstream 4: Aggregate metrics across developers

Primary files:

- new `scripts/metrics/aggregate-metrics.py`
- optional CI config or usage docs

Changes:

- merge multiple local export files
- produce date-bounded summaries
- compute team-level medians, totals, and distributions
- optionally emit markdown for lightweight reporting

Acceptance criteria:

- multiple developer summaries can merge without conflicts
- aggregate output answers core effectiveness questions
- raw runtime state is not required in the aggregation step

### Workstream 5: Document privacy, sharing, and retention rules

Primary files:

- `scripts/workflow/README.md`
- `resources/instructions/github-instructions-template.md`
- optional new metrics README under `scripts/metrics/`

Changes:

- document what stays local
- document what can be shared
- document recommended `.gitignore` behavior
- define retention and summary cadence recommendations

Acceptance criteria:

- developers can tell which files are local operational state versus shared analytics artifacts
- the repo avoids accidental commits of raw runtime telemetry

## Suggested Delivery Order

Implement Milestone 6 in this order:

1. Event emitter
2. Gate and workflow instrumentation
3. Local export script
4. Aggregation script
5. Documentation and CI wiring

Reasoning:

- without events, there is nothing reliable to export
- without export, there is nothing safe to aggregate
- CI wiring should be last so the local model is stable first

## Validation Plan

### Event emission

- starting a feature emits `feature_started`
- starting a task emits `task_started`
- red and green transitions emit the expected events

### Gate instrumentation

- a missing Green produces `release_gate_blocked` with `missing_green`
- a semantic-check failure produces `release_gate_blocked` with `semantic_check_failed`
- evaluator independence failure produces `evaluator_result_recorded` with failure metadata and appropriate reasoning in derived export

### Local export

- export succeeds from only local event data
- export excludes prompt text, transcripts, and free-form evidence bodies
- export computes expected counts from a smoke event log

### Aggregation

- two exported summaries from different developers merge cleanly
- aggregate output preserves per-reason distributions
- aggregate output computes team-level medians correctly

## Recommended First Slice

If implementation starts immediately, do this first:

1. Add `emit-event.py`
2. Instrument `start-feature`, `start-task`, `mark-red`, `mark-green`, `request-evaluator`, `write-evaluator-result.py`, and `release-gate.sh`
3. Add `export-local-metrics.py`
4. Run one local smoke log through export

That is enough to start collecting meaningful data without waiting for CI aggregation.

## Final Note

Milestone 6 should treat the harness as a product that needs feedback loops.

The instrumentation layer should answer:

- where does the harness help?
- where does it create friction?
- where does it fail to catch problems?
- where is context cost starting to creep upward?

If a metric cannot inform a concrete change to the harness, do not add it.
