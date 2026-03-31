---
name: observability-planning
description: Define logs, metrics, traces, alerts, and diagnostic hooks for features that must be supportable in production.
---

# Observability Planning

## Overview

Define logs, metrics, traces, alerts, and diagnostic hooks for features that must be supportable in production.

## Quick Reference

- **Use when:** Use when adding a new feature, service, background job, queue consumer, integration, or failure-prone workflow that must be diagnosable in production.
- **Output:** Minimum observability contract: logs, metrics, traces, alerts, and operator questions the system must answer.
- **Duration:** 10-20 minutes.
- **Phase:** C / T - after architecture is clear, before implementation or before release for under-instrumented work.

## Purpose

This skill makes production behavior legible. It defines the minimum telemetry
needed so engineers can answer:
- Did it work?
- How long did it take?
- Why did it fail?
- Who was affected?
- What should wake a human up?

## When to Invoke

Invoke this skill when:
- A new user flow, endpoint, async job, webhook, or integration is added
- A change is operationally important or hard to reproduce locally
- The team says "we need monitoring", "we need tracing", or "how will we know?"
- A prior incident showed missing logs, metrics, or alerting

## Progressive Disclosure

**Tier 1 - Minimum Contract**
- for low-risk internal features
- define key success/failure logs and 2-3 core metrics

**Tier 2 - Standard Production**
- for most user-facing or async flows
- complete the full process, including alerts and dashboards

**Tier 3 - Mission-Critical**
- for revenue, auth, data pipelines, or paging-worthy flows
- add SLOs, burn-rate alerts, correlation IDs, and runbook links

## Hook Placement

Run this skill:
- After architecture-decisions, before implementation starts
- During release-readiness if the change lacks operational visibility
- After debugging a blind incident, to write missing signals back into process

## Process

### Step 1 - Define the operator questions

List the questions on-call or support must be able to answer:
- Did the request/job complete?
- What failed, and where?
- How many users or tenants were affected?
- Is the system degrading or fully broken?

### Step 2 - Pick the core telemetry

For each important flow, define:
- logs: structured events for state transitions and failures
- metrics: counters, error rate, latency, queue depth, retry count, throughput
- traces: request or job path across services and dependencies

Do not log everything. Log what supports diagnosis.

### Step 3 - Define identifiers and context

Specify which fields must be present where relevant:
- request ID / correlation ID
- user ID or tenant ID where safe
- job ID or event ID
- integration or dependency name
- result or failure reason

Never log secrets or raw sensitive payloads.

### Step 4 - Set alert thresholds

Decide:
- what is page-worthy
- what is ticket-worthy
- what belongs only on a dashboard

Prefer symptom-based alerts:
- error rate too high
- p95 latency too high
- queue age too high
- success rate too low

### Step 5 - Define validation

Before ship, verify:
- logs appear with the expected fields
- metrics move during normal and failure paths
- traces stitch across boundaries where needed
- alerts are testable and not obviously noisy

## Output Format

```text
Observability Plan

Flow
- [feature or path]

Operator Questions
- [...]

Required Logs
- [event] with [fields]

Required Metrics
- [metric] -> [reason]

Tracing
- [where span/correlation is required]

Alerts
- [condition] -> [action level]

Validation
- [how to prove telemetry exists]
```

## Notes

- If a background job can fail silently, observability is incomplete.
- Logs explain individual cases; metrics reveal trends; traces connect systems.
- If the plan cannot distinguish user error from system error, refine it.
