---
name: brainstorming
description: Run a structured discovery dialogue to refine feature intent, scope, assumptions, and edge cases before spec writing or implementation.
---

# Brainstorming

## Overview

Run a structured discovery dialogue to refine feature intent, scope, assumptions, and edge cases before spec writing or implementation.

## Quick Reference

- **Use when:** Use when starting a new feature, encountering design uncertainty, or when intent feels underspecified before writing an OpenSpec.
- **Output:** Refined intent statement + structured decisions ready for spec authoring.
- **Duration:** 5-15 minutes of dialogue before spec writing begins.
- **Phase:** I (Intent) - runs before the ICTT loop proper starts.

## Purpose

Good OpenSpecs come from good questions, not good guesses. This skill drives a
structured Socratic dialogue to surface assumptions, surface edge cases, align
on scope, and produce a sharp intent statement before a single line of spec
(or code) is written.

Do not skip this step when requirements feel obvious. The obvious cases are
exactly where unspoken assumptions live.

## When to Invoke

Invoke this skill when any of the following are true:
- You are starting a feature that touches more than one service or layer
- The ticket description is vague, uses business language, or lacks acceptance criteria
- You feel uncertain about what "done" looks like
- The feature involves a user-facing interaction you haven't built before
- A previous implementation of something similar produced surprises

## Process

### Step 1 - State the raw intent
Write one sentence: "I want to [action] so that [outcome]."
Do not overthink it. This is the starting point, not the final answer.

### Step 2 - Socratic questioning rounds
The agent will ask questions across these five dimensions. Answer each before moving on.

**User & Persona**
- Who specifically uses this feature? What is their goal in that moment?
- What does success look like to them - not to us?
- What would make them say this feature is broken, even if it technically works?

**Scope & Boundaries**
- What is explicitly out of scope for this iteration?
- What adjacent features could this touch that we are not changing?
- What happens if we ship a minimal version now and extend later?

**Data & State**
- What data does this feature read? Where does it come from?
- What data does this feature write or mutate? What are the side effects?
- What is the state before and after this feature runs?

**Failure & Edge Cases**
- What are the top three ways this feature could fail?
- What should happen when it fails - to the user, to the data, to downstream systems?
- What are the edge cases at the boundaries (empty state, max volume, concurrent users)?

**Dependencies & Risk**
- What services, APIs, or systems does this depend on?
- What breaks if any of those dependencies are unavailable?
- What is the highest-risk assumption in this design?

### Step 3 - Synthesize decisions
After the dialogue, write down:
1. Refined intent statement (one sentence, updated from Step 1)
2. Key decisions made (each as a one-liner: "We decided X because Y")
3. Assumptions being made explicitly (each as: "We are assuming X - validate before shipping")
4. Out-of-scope list (explicit exclusions for this iteration)

### Step 4 - Hand off to spec
The output of this skill is the input to the OpenSpec `## Intent` and `## Out of Scope`
sections. Copy your refined intent statement and decisions into the spec file.
Run the writing-plans skill next to decompose into tasks.

## Example Output

```
Refined intent: Enable authenticated users to export their transaction history
as a CSV file covering any 90-day window, triggered from the account dashboard.

Decisions:
- 90-day max window (not unlimited) to bound query cost
- CSV only in v1 (PDF deferred)
- Export is async - email link when ready, not inline download

Assumptions:
- User's email address is verified before they can trigger export
- Transaction volume per user is under 100k rows in any 90-day window

Out of scope (this iteration):
- Custom column selection
- Scheduled / recurring exports
- Admin-triggered exports on behalf of users
```
