---
name: rollout-and-rollback-readiness
description: Plan phased release, feature-flag posture, monitoring, rollback triggers, and recovery steps before production rollout.
---

# Rollout And Rollback Readiness

## Overview

Plan phased release, feature-flag posture, monitoring, rollback triggers, and recovery steps before production rollout.

## Quick Reference

- **Use when:** Use when a feature has meaningful blast radius, requires phased exposure, depends on flags, or needs a defined recovery path if production behavior is worse than expected.
- **Output:** Rollout plan, rollback posture, stop conditions, and operator notes for the release.
- **Duration:** 10-15 minutes.
- **Phase:** Ship gate - after implementation and review, before release.

## Purpose

This skill makes release control explicit. It answers:
- How does this go live?
- How do we limit blast radius?
- What signs tell us to pause?
- What can we do in the first 10 minutes if it goes wrong?

## When to Invoke

Invoke this skill when:
- A feature flag, canary, tenant-by-tenant rollout, or config gate is involved
- The change affects money, auth, data integrity, or shared infrastructure
- A migration or background job must run during release
- Rollback is non-trivial or impossible without a forward fix
- The team wants explicit go/no-go criteria

## Progressive Disclosure

**Tier 1 - Standard Release**
- small blast radius, easy rollback
- define go-live checks and rollback trigger

**Tier 2 - Controlled Rollout**
- phased exposure or flags required
- complete the full process

**Tier 3 - High-Risk Release**
- irreversible changes, large migrations, shared infra, or paging risk
- add named owners, time windows, communications, and forward-fix posture

## Hook Placement

Run this skill:
- After code-review and before release-readiness is finalized
- Again immediately before deploy if the plan changed

## Process

### Step 1 - Define blast radius

Write down:
- who is affected if the release fails
- whether exposure can be limited by tenant, cohort, percent, or environment
- whether data changes make rollback harder

### Step 2 - Choose the rollout mode

Pick one:
- dark launch behind flag
- internal only
- canary or percentage rollout
- tenant or region phased rollout
- full release with fast rollback

### Step 3 - Define stop conditions

State the signals that pause or reverse the rollout:
- error rate threshold
- latency threshold
- failed jobs or queue growth
- business KPI drop
- support tickets or operator observation

### Step 4 - Define rollback posture

Specify:
- immediate rollback action
- whether flag-off is sufficient
- whether code rollback is safe
- whether data/state requires forward-fix instead

### Step 5 - Write operator notes

Include:
- exact rollout steps
- who watches telemetry
- how long each phase should sit before expanding
- communication expectations if rollback is triggered

## Output Format

```text
Rollout And Rollback Plan

Blast Radius
- [...]

Rollout Mode
- [...]

Stop Conditions
- [...]

Rollback Posture
- [...]

Operators
- owner: [...]
- telemetry to watch: [...]
```

## Notes

- "Rollback by redeploy" is not a plan if data or external side effects changed.
- If no one is watching telemetry during rollout, the rollout is uncontrolled.
