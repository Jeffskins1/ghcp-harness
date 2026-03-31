---
name: code-review
description: Perform a risk-focused code review against acceptance criteria, including regression, missing-test, and scope-drift checks, with a strong bias toward fresh-session evaluation for complex changes.
---

# Code Review

## Overview

Perform a risk-focused code review against acceptance criteria, including regression, missing-test, and scope-drift checks, with a strong bias toward fresh-session evaluation for complex changes.

## Quick Reference

- **Use when:** Use after implementation is green and before opening an MR. For complex changes, run as a separate agent session (fresh context) rather than in the same session that wrote the code.
- **Output:** Findings list plus a structured evaluator result for evaluator-gated tasks.
- **Duration:** 5-15 minutes.
- **Phase:** Ship gate - after tests, before MR.

## Bundled Resources

- `references/evaluator-calibration.md`: Load when review criteria are subjective or you need guidance for calibrating a fresh evaluator session.

## Purpose

This skill turns review into a deliberate checkpoint instead of a casual skim.
It also corrects a known failure mode in single-agent workflows: **self-evaluation
bias**. Agents reliably give mediocre work a passing grade when asked to review
their own output. The fix is to treat the reviewer as a separate role - ideally
a fresh session with no attachment to the implementation decisions.

## Complexity Triage - Choose Your Review Mode

Before running this skill, classify the change:

**Routine** - all of the following are true:
- Touches one layer or one component
- Acceptance criteria are concrete and testable
- No shared interfaces or cross-cutting concerns changed
- No new dependencies added
-> Run a **self-check review** in the current session (see Section A below)

**Complex** - any of the following are true:
- Crosses layer boundaries or touches shared interfaces
- Acceptance criteria include subjective or UX-quality judgements
- Architectural decisions were made during implementation
- The session has been running long (context anxiety risk)
- The change touches auth, payments, data migrations, or security boundaries
-> Run a **separate-session evaluator review** (see Section B below)

When in doubt, treat the change as complex. The cost of a fresh session is
low; the cost of a missed regression in a complex change is high.

## Adversarial Review Modes

For Milestone 4 workflow-driven reviews, the evaluator packet may list one or
more adversarial review modes. Apply each listed lens explicitly:

- `contract_adversary`: challenge whether the change truly satisfies the spec and task done condition
- `regression_adversary`: look for collateral breakage, surrounding behavior drift, and integration risk
- `security_adversary`: challenge trust boundaries, abuse paths, authz, secrets, and unsafe input handling
- `token_context_adversary`: challenge prompt bloat, state drift, missing handoff context, and resume fragility

High-risk tasks should not be reviewed with a generic "looks fine" pass. The
review should name which adversarial lenses were applied.

---

## Section A - Self-Check Review (Routine Changes)

Use when the change is routine and the session context is still fresh.

Ask the agent in the current session:

```
Use code-review. Inspect the final diff for:
- behavioral regressions against the active spec
- missing or weak tests (especially failure paths)
- acceptance criteria gaps
- accidental scope creep
- unsafe config or dependency changes

File findings against the spec's acceptance criteria, not against your
own judgement of the implementation. Report residual risks explicitly.
```

### Output Format

```
Findings:
- [file] line [N]: [what is wrong and which acceptance criterion it affects]

Residual risks:
- [what remains untested or uncertain and why it was not addressed]

Verdict: PASS / NEEDS FIXES
```

---

## Section B - Separate-Session Evaluator Review (Complex Changes)

Use when the change is complex or when self-evaluation bias is a material risk.

**Why a separate session:** The generator session that wrote the code has
context attachment - it made tradeoffs, justified decisions, and accumulated
assumptions. An evaluator starting fresh reads the diff cold, the same way
a human reviewer does, and will catch things the generator rationalised away.

### Step 1 - Prepare the evaluator entry point
Before ending or pausing the generator session, ensure the spec is current:
- `## Acceptance Criteria` is complete and matches what was actually built
- `## Session State` (if a handoff was done) lists files changed
- Any decisions made during implementation are written into the spec

### Step 2 - Start a fresh evaluator session
Open a new session. Do not continue in the generator session.

Paste this entry prompt:

```
You are the evaluator for a completed implementation. Your job is to find
problems, not to praise the work. Assume nothing is correct until you verify it.

Read in this order:
1. .github/copilot-instructions.md (or AGENTS.md) - project constraints
2. specs/features/[feature].spec.md - the contract you are testing against
3. The diff or changed files listed in the spec

Then file findings against the acceptance criteria. For each criterion, state
explicitly whether it is MET, PARTIALLY MET, or NOT MET, with evidence.
Return a structured JSON result artifact at the path named in the evaluator
packet or `.github/agent-state/evaluator-result-task-[task-id].json`.
```

### Step 3 - Calibrate for skepticism
If the evaluator is too lenient (marks everything MET without strong evidence),
add a calibration instruction:

```
Before filing your verdict, ask yourself: if this were a stranger's code and
I had no context about how it was built, would I be confident shipping it?
Flag anything you cannot verify directly from the diff and the test output.
```

If the evaluator packet lists adversarial review modes, add a short section in
your review notes that states which mode you applied and what it checked.

### Step 4 - Produce the structured result first
For evaluator-gated tasks, the result artifact is the machine-readable source of
truth. Use this shape:

```json
{
  "feature": "feature-name",
  "task_id": "3",
  "packet_id": "eval-packet-task-3-20260327T160000Z",
  "verdict": "pass_with_risks",
  "review_mode": "fresh_session",
  "reviewed_at": "2026-03-27T16:00:00Z",
  "reviewer_session": "copilot-evaluator-session-1",
  "applied_review_modes": ["contract_adversary", "regression_adversary"],
  "criteria_results": [
    {
      "criterion": "AC-1",
      "status": "MET",
      "evidence": "tests/integration/example.test.ts covers the required path"
    }
  ],
  "findings": [
    {
      "severity": "medium",
      "blocking": false,
      "criterion": "AC-3",
      "summary": "Failure path coverage is still missing",
      "evidence": "No automated assertion found for rejected input"
    }
  ],
  "residual_risks": [
    "Integration behavior was reviewed statically but not exercised live"
  ]
}
```

Allowed verdicts:
- `pass`: no blocking findings
- `pass_with_risks`: no blocking findings, but residual risks remain
- `fail`: one or more blocking findings

### Step 5 - File bugs against the contract
For each NOT MET or PARTIALLY MET criterion, the evaluator should produce
a concrete bug report:

```
Bug: [criterion not met]
Evidence: [specific line, file, or test output]
Fix required: [what needs to change]
Blocking: YES / NO
```

### Step 6 - Return findings to the generator
Blocking bugs go back to the generator session for fixes before MR.
Non-blocking findings are documented in the MR description as known residual risks.

For harness-gated tasks, the generator should then run
`python scripts/workflow/write-evaluator-result.py .github/agent-state/evaluator-result-task-[task-id].json`
to record the result into `.github/agent-state/active-run.json`.

The harness will reject evaluator results that:
- omit the active packet id or required adversarial review mode acknowledgements
- claim `pass` while any criterion is `NOT MET`
- reuse the generator session when the independence policy requires a fresh session
- use placeholder evidence instead of concrete findings

---

## Hook Placement

Run this skill:
- After the final test pass
- Before `glab mr create`
- After a session handoff resume (evaluator pass on completed work before continuing)

---
