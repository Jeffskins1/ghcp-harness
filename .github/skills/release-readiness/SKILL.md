---
name: release-readiness
description: Confirm a change is ready for merge or release with green tests, linked specs, reviewer guidance, and recorded lessons.
---

# Release Readiness

## Overview

Confirm a change is ready for merge or release with green tests, linked specs, reviewer guidance, and recorded lessons.

## Quick Reference

- **Use when:** Use once implementation and review are complete and the work is about to be opened as an MR or handed to CI.
- **Output:** Ready-to-ship checklist tied to spec, tests, and team workflow.
- **Duration:** 5-10 minutes.
- **Phase:** Ship gate.

## Purpose

This skill ensures the work is not merely coded, but actually ready to move
through the team's delivery process.

## When to Invoke

Invoke this skill when:
- All tasks are complete and the full-suite integration run has passed
- Review findings are resolved or documented
- An MR description or handoff summary is needed

## Hook Placement

Run this skill at the MR-prep hook and failure-capture hook:
- Before opening the MR
- After CI surprises expose missing readiness checks

## Checklist

Confirm:
- active spec is linked in the prompt, MR, or handoff
- acceptance criteria are covered by tests or explicitly deferred
- full-suite integration run has been recorded (`feature_integration.full_suite_passed: true` in
  `.github/agent-state/active-run.json`) — if not, run `bash scripts/workflow/mark-integration-passed.sh`
- constraints and failures discovered during the session were written back to
  `copilot-instructions.md` or `AGENTS.md`
- commands needed for reviewers are documented
- the MR summary matches the actual implementation

## Output Format

```text
Ready to ship:
- Spec linked
- Full-suite integration run recorded (2026-03-31T14:22:00Z)
- Review findings resolved
- Failure log updated

Still blocked:
- Integration pipeline credentials not yet configured in CI
```
