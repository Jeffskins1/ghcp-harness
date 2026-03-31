---
name: performance-and-scalability-review
description: Assess latency, throughput, fan-out, load, caching, and bottleneck risks before implementation or release of performance-sensitive changes.
---

# Performance And Scalability Review

## Overview

Assess latency, throughput, fan-out, load, caching, and bottleneck risks before implementation or release of performance-sensitive changes.

## Quick Reference

- **Use when:** Use when the change affects hot paths, large datasets, expensive queries, external APIs, fan-out behavior, concurrency, or latency- sensitive user flows.
- **Output:** Performance budget, bottleneck hypotheses, validation plan, and scale risks for the active change.
- **Duration:** 10-20 minutes.
- **Phase:** C / T - before implementation of risky paths or before release of performance-sensitive work.

## Purpose

This skill forces performance assumptions into the open before the system is
asked to prove them in production. It is not a substitute for measurement; it
is a way to decide what must be measured and what risks must be controlled.

## When to Invoke

Invoke this skill when:
- A request path touches many services, queries, or large payloads
- A job processes many records or fans out across tenants/users
- Caching, batching, streaming, pagination, or indexing choices matter
- The user experience depends on tight latency or responsiveness
- The team expects traffic growth, burst traffic, or heavy concurrency

## Progressive Disclosure

**Tier 1 - Fast Review**
- for modest changes on known-good paths
- define latency target, likely bottleneck, and quick validation

**Tier 2 - Standard Review**
- for most production features with meaningful load
- complete the whole process

**Tier 3 - Scale Review**
- for hot paths, shared services, large backfills, or high concurrency
- require explicit budgets, fallback behavior, and load-test or profiling plans

## Hook Placement

Run this skill:
- After discovery, once the relevant path is understood
- Before architecture-decisions when design choices affect scale
- Before release if no performance evidence exists for a sensitive path

For Milestone 4 evaluator-gated tasks, this skill can back the
`regression_adversary` lens for changes where performance, fan-out, or shared
system behavior could regress outside the directly touched code.

## Process

### Step 1 - Define the load shape

Write down:
- expected request/job volume
- peak vs average load
- payload size or record count
- concurrency expectations
- critical latency target or batch completion target

### Step 2 - Map expensive operations

Identify:
- database queries and cardinality growth
- remote API calls and retry behavior
- serialization, parsing, or file work
- loops, fan-out, N+1 risks, or queue amplification

### Step 3 - Form bottleneck hypotheses

State the most likely limits:
- DB CPU or lock contention
- network latency or third-party SLA
- memory growth
- queue backlog
- single-threaded bottleneck

Do not guess vaguely. Name the suspect subsystem.

### Step 4 - Decide mitigation patterns

Choose only what the path needs:
- indexes, pagination, batching, caching
- async offload
- circuit breaking and timeouts
- backpressure and concurrency limits
- streaming instead of full materialization

### Step 5 - Define evidence

Before ship, collect one or more of:
- benchmark or profile on the hot path
- integration test with realistic volume
- query plan inspection
- queue throughput measurement
- latency measurements under representative conditions

## Output Format

```text
Performance Review

Load Shape
- [volume]
- [peak]
- [latency target]

Likely Bottlenecks
- [component] -> [why]

Mitigations
- [decision]

Evidence Required
- [benchmark/profile/test]

Residual Risks
- [risk]
```

## Notes

- "We can optimize later" is acceptable only if the path is not on the critical
  user journey and the evidence supports the risk tradeoff.
- A performance review without a load shape is just intuition.
