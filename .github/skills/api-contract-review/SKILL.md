---
name: api-contract-review
description: Review API, event, webhook, and schema changes for compatibility, versioning, validation, failure semantics, and consumer impact. Use before implementing or releasing interface changes.
---

# API Contract Review

## Overview

Review API, event, webhook, and schema changes for compatibility, versioning, validation, failure semantics, and consumer impact. Use before implementing or releasing interface changes.

## Quick Reference

- **Use when:** Use when creating or changing APIs, events, webhooks, RPC methods, message schemas, or other producer-consumer contracts.
- **Output:** Contract review with compatibility rules, error model decisions, validation requirements, and client-impact notes.
- **Duration:** 10-20 minutes.
- **Phase:** I / C - after discovery, before implementation or before releasing a contract change.

## Purpose

This skill prevents accidental interface drift. It reviews the public contract
the system exposes to other humans, services, and clients, with emphasis on
compatibility, clarity, and failure semantics.

## When to Invoke

Invoke this skill when:
- A new endpoint, event, webhook, or response shape is introduced
- An existing field, status code, enum, or error payload changes
- Clients may update independently of the server
- Idempotency, pagination, filtering, or versioning matter
- The team says "contract", "breaking change", or "API review"

## Progressive Disclosure

**Tier 1 - Internal Only**
- for tightly coupled internal consumers
- review naming, shape, and error semantics

**Tier 2 - Standard Contract**
- for most APIs and events
- complete the full process

**Tier 3 - Public Or Shared Contract**
- for external clients, many consumers, SDKs, or long-lived integrations
- add compatibility matrix, migration notes, and deprecation plan

## Hook Placement

Run this skill:
- After architecture-decisions when interfaces are being locked
- Before coding the endpoint or publisher
- Again before release if implementation changed the agreed shape

## Process

### Step 1 - Define the contract

Capture:
- producer and consumer
- request/input shape
- response/output or event shape
- auth expectations
- side effects

### Step 2 - Review compatibility

Ask:
- Is this additive, behavior-changing, or breaking?
- Can older clients continue to work?
- Are enum expansions safe?
- Are nullable, optional, and default semantics explicit?
- Does pagination or filtering preserve stable behavior?

### Step 3 - Review failure semantics

Check:
- status/error codes are consistent
- retryable vs non-retryable errors are distinguishable
- idempotency rules are explicit where duplication is possible
- timeouts and partial failures are documented

### Step 4 - Review naming and clarity

Prefer:
- domain terms over storage terms
- explicit units and timestamps
- stable identifiers
- predictable field names and envelope patterns

### Step 5 - Define validation

Require:
- contract tests or schema tests
- negative cases for invalid input and auth failures
- compatibility tests if multiple client versions may coexist

## Output Format

```text
API Contract Review

Contract
- producer: [...]
- consumers: [...]

Compatibility
- [additive / behavior change / breaking]
- client impact: [...]

Error Model
- [key decisions]

Required Validation
- [tests]

Open Risks
- [risk]
```

## Notes

- A contract change is not safe just because the code compiles on both sides.
- If clients can update independently, default to Tier 3.
