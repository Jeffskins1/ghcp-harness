---
name: architecture-decisions
description: Lock interfaces, boundaries, dependencies, and top risks before implementation when a change crosses layers, services, or shared interfaces.
---

# Architecture Decisions

## Overview

Lock interfaces, boundaries, dependencies, and top risks before implementation when a change crosses layers, services, or shared interfaces.

## Quick Reference

- **Use when:** Use after intent is clear but before writing implementation tasks when the feature touches multiple layers, systems, or interfaces.
- **Output:** Documented architectural decisions and constraints for the spec.
- **Duration:** 10-20 minutes.
- **Phase:** I/C boundary - after brainstorming, before writing-plans.

## Purpose

This skill captures the structural decisions an implementer should not have to
invent later. Use it to lock interfaces, boundaries, dependencies, and risks
before the work is decomposed into agent-sized tasks.

## When to Invoke

Invoke this skill when any of the following are true:
- The feature crosses more than one layer
- New endpoints, data models, queues, or integrations are involved
- A change could be implemented in multiple plausible ways
- The team wants to prevent agents from improvising architecture

## Hook Placement

Run this skill at the context-loading hook:
- After discovery and brainstorming
- Before writing-plans
- Before assigning implementation to a coding agent

## Process

### Step 1 - Read the active spec draft
Confirm the draft already contains:
- intent
- acceptance criteria
- out-of-scope boundaries

### Step 2 - Lock decisions
Write one short decision per item:
- layers affected
- data ownership
- API or interface shape
- dependencies reused vs introduced
- operational constraints

### Step 3 - Record risks
State the top implementation risks and how the design limits them.

### Step 4 - Update the spec
Move the output into the spec's architecture section so later skills inherit it.

## Output Format

```text
Decision:
- Service layer owns retry logic; controllers remain thin
- Existing queue worker processes the new job type
- Validation happens at API boundary and service boundary

Risk:
- Background jobs may duplicate work under retries
- Mitigation: idempotency key stored with job record
```
