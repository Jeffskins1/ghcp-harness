---
name: data-migration-safety-review
description: Plan safe schema changes, backfills, deploy ordering, rollback posture, and data validation for migration-heavy work.
---

# Data Migration Safety Review

## Overview

Plan safe schema changes, backfills, deploy ordering, rollback posture, and data validation for migration-heavy work.

## Quick Reference

- **Use when:** Use when schema changes, backfills, re-indexing, or data shape transitions are part of the work.
- **Output:** Safe migration sequence, rollback posture, validation plan, and operational risks for the active change.
- **Duration:** 10-20 minutes.
- **Phase:** C / T - after architecture is understood, before implementation or before release of migration-heavy work.

## Purpose

This skill prevents "the migration worked on my machine" from becoming a
production incident. It focuses on ordering, reversibility, data correctness,
and deploy safety when a feature changes persistent data.

Use it to answer:
- Can this migration run safely in production?
- What must happen before, during, and after deploy?
- How do we validate correctness and recover if it goes wrong?

## When to Invoke

Invoke this skill when:
- Tables, columns, indexes, constraints, or document shapes change
- A migration requires a backfill or data transform
- Old and new application versions may coexist during deploy
- The work changes cardinality, nullability, enum values, or ownership rules
- A queue, cache, search index, or analytics pipeline depends on the data shape

## Progressive Disclosure

**Tier 1 - Simple Change**
- additive column or index with no backfill
- review sequence, compatibility, and validation only

**Tier 2 - Standard Migration**
- additive schema plus backfill or read/write changes
- complete the full process

**Tier 3 - High-Risk Migration**
- destructive changes, large tables, tenant data, zero-downtime needs, or
  long-running backfills
- require explicit rollback posture, runtime monitoring, and staged rollout

## Hook Placement

Run this skill:
- After writing-plans identifies schema or data work
- Before the first migration is authored
- Again before release-readiness for high-risk changes

## Process

### Step 1 - Classify the change

Write down:
- additive, transform, or destructive
- schema only, data only, or both
- online or maintenance-window dependent
- expected scale: rows, tenants, documents, partitions, or index size

### Step 2 - Check compatibility

Ask:
- Can old code run against the new schema?
- Can new code run before the backfill completes?
- Are reads and writes safe during mixed-version deploys?
- Do defaults, null handling, and enum changes preserve behavior?

If the answer is "only if deployed in a specific order", write that order down.

### Step 3 - Design the execution sequence

Typical safe order:
1. Add new schema in a backward-compatible way
2. Deploy code that can read old and new shapes
3. Backfill or dual-write
4. Verify correctness and completeness
5. Switch reads to the new source
6. Remove old paths only after confidence is established

If a destructive change is proposed first, challenge it.

### Step 4 - Decide rollback posture

Choose one:
- reversible: schema and code can both roll back cleanly
- forward-fix only: rollback is unsafe; recovery requires new code
- restore-based: rollback depends on snapshot restore or reprocessing

State the trigger for invoking rollback or forward-fix.

### Step 5 - Define validation

Capture:
- pre-deploy checks: backups, row counts, index existence, lock expectations
- in-flight checks: migration duration, errors, retries, backlog, dead letters
- post-deploy checks: counts match, reads succeed, writes land correctly
- business checks: reports, user workflows, or downstream jobs still work

### Step 6 - Write operator notes

Document:
- exact deploy order
- whether traffic shaping, feature flags, or maintenance mode are needed
- who watches the migration and what they watch
- stop conditions and recovery actions

## Output Format

```text
Data Migration Safety Review

Change Type
- [additive/transform/destructive]
- [scale]

Compatibility
- old code on new schema: [yes/no/with conditions]
- new code before backfill: [yes/no/with conditions]

Execution Sequence
1. [...]
2. [...]

Rollback Posture
- [reversible / forward-fix only / restore-based]

Validation
- pre-deploy: [...]
- post-deploy: [...]

Operational Risks
- [risk]
```

## Notes

- Prefer expand-and-contract over destructive one-step migrations.
- A backfill is part of the feature, not an operational afterthought.
- If validation depends on "spot check a few rows", the plan is too weak.
