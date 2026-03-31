---
name: debugging
description: Diagnose failing tests, regressions, or blocked implementation attempts before making more code changes. Use when the failure is not obvious after one or two tries.
---

# Debugging

## Overview

Diagnose failing tests, regressions, or blocked implementation attempts before making more code changes. Use when the failure is not obvious after one or two tries.

## Quick Reference

- **Use when:** Use when tests fail, behavior regresses, or the agent cannot make progress after one or two implementation attempts.
- **Output:** Root-cause summary, narrowed fix target, and validation steps.
- **Duration:** 5-20 minutes.
- **Phase:** T (Tests) / recovery loop.

## Purpose

This skill stops the agent from thrashing. It narrows a failure to a specific
cause before the next code change is made.

## When to Invoke

Invoke this skill when:
- A failing test is not obviously caused by the latest change
- The same failure survives two fix attempts
- The error may be environmental, data-related, or architectural

## Hook Placement

Run this skill at the test-loop hook:
- After a failed test run
- Before a broad refactor "to see if it helps"
- Before capturing a new failure rule in persistent context

## Process

### Step 1 - Reproduce
- Record the exact failing command, scenario, or stack trace

### Step 2 - Narrow
- Identify where the failure starts
- Separate symptom from root cause
- List the smallest plausible fix surface

### Step 3 - Validate the theory
- State what evidence would confirm the diagnosis
- State what evidence would falsify it

### Step 4 - Hand off
- Apply the fix only after the diagnosis is specific
- If the failure reveals a repeating pattern, add it to the instructions file

## Output Format

```text
Failure:
- Integration test returns 500 instead of 201

Likely root cause:
- Validation rejects ISO date strings before controller mapping

Confirm by:
- Re-running the request with service validation bypassed

Fix target:
- Request DTO parsing, not export generation
```
