---
name: security-review-and-threat-modeling
description: Review trust boundaries, misuse cases, controls, secrets, auth flows, and abuse paths before implementation or release of sensitive changes.
---

# Security Review And Threat Modeling

## Overview

Review trust boundaries, misuse cases, controls, secrets, auth flows, and abuse paths before implementation or release of sensitive changes.

## Quick Reference

- **Use when:** Use when work touches authentication, authorization, secrets, external input, file handling, payments, admin actions, or any feature that expands the system's attack surface.
- **Output:** Threat model, prioritized risks, required mitigations, and explicit validation steps for the active change.
- **Duration:** 10-25 minutes.
- **Phase:** I / C / T - design review before implementation, or risk review before release.

## Purpose

This skill gives the team a repeatable way to look for security problems before
they become implementation details or release surprises. It is not a generic
"check OWASP" reminder. It produces a concrete threat model tied to the current
feature, code path, and deployment context.

Use it to answer:
- What can go wrong?
- Where are the trust boundaries?
- Which mitigations are mandatory before ship?
- What security checks must be added to tests and review?

## When to Invoke

Invoke this skill when any of the following are true:
- A new endpoint, webhook, queue consumer, or background job is introduced
- The feature handles user input, files, HTML, SQL, templates, or shell commands
- Auth, roles, session handling, tokens, API keys, or secrets are involved
- The change touches admin flows, billing, PII, or cross-tenant access
- A third-party integration can act on behalf of users or systems
- The team says "security-sensitive", "threat model", or "attack surface"

## Progressive Disclosure

Run only the depth the change requires:

**Tier 1 - Fast Screen**
- Use for small, internal, low-risk changes
- Identify assets, entry points, trust boundaries, and top 3 risks

**Tier 2 - Full Review**
- Use for most production features
- Complete the whole process below and write explicit mitigations

**Tier 3 - Deep Dive**
- Use for auth, payments, secrets, multi-tenant data, uploads, or compliance work
- In addition to the full review, require abuse cases, logging expectations,
  failure-mode analysis, and release gates

## Hook Placement

Run this skill:
- After discovery, once the current flow is understood
- Before architecture-decisions for security-sensitive work
- Again before release-readiness if the implementation drifted from the plan

For Milestone 4 evaluator-gated tasks, this skill also serves as the
`security_adversary` lens when the evaluator packet requests it.

## Process

### Step 1 - Define the review surface

Write down:
- The feature or change being reviewed
- The actors involved: end user, admin, service account, external system
- The assets at risk: money, secrets, tenant data, personal data, privileges
- The entry points: UI forms, APIs, webhooks, file upload, CLI, jobs, config

### Step 2 - Map trust boundaries

List where data or authority crosses a boundary:
- browser -> backend
- public endpoint -> internal service
- app -> third-party API
- worker -> database
- admin action -> tenant data

If no trust boundary is visible, the review is probably too shallow.

### Step 3 - Enumerate threats

For each boundary and entry point, check:
- spoofing: can an attacker impersonate a user or service?
- tampering: can input, state, or jobs be altered unexpectedly?
- repudiation: would actions be hard to audit later?
- information disclosure: can data leak across users, roles, or tenants?
- denial of service: can the path be abused for cost, latency, or exhaustion?
- elevation of privilege: can the caller gain more authority than intended?

Do not write a giant list. Capture only realistic threats tied to the change.

### Step 4 - Decide mitigations

For each credible threat, record:
- mitigation now: must be built before ship
- mitigation later: acceptable only with explicit deferral
- residual risk: what remains even after mitigation

Common mitigation areas:
- input validation and output encoding
- authn/authz checks at the correct boundary
- tenant scoping and ownership checks
- secret handling and rotation
- rate limiting, quotas, and backpressure
- idempotency and replay protection
- safe file handling and content-type validation
- secure defaults in config and error handling

### Step 5 - Define required validation

Convert the mitigations into checks:
- tests that prove unauthorized access is blocked
- review checks for secrets, unsafe config, and trust-boundary assumptions
- logging or audit events needed for sensitive actions
- negative cases for abuse, malformed input, and boundary violations

### Step 6 - Write the output back to the spec

Add a short section to the active spec or task notes:
- Security Risks
- Required Mitigations
- Deferred Risks
- Validation Required Before Ship

## Output Format

```text
Security Review

Scope
- [feature/change]
- [actors]
- [assets]

Trust Boundaries
- [boundary]

Top Threats
1. [threat] -> [impact]
2. [threat] -> [impact]

Required Mitigations
- [mitigation]

Deferred / Accepted Risks
- [risk + rationale]

Validation
- [test or review check]
```

## Notes

- Security review is not complete until mitigations are tied to tests, review,
  or release gates.
- If the change affects authorization or tenant isolation, default to Tier 3.
- If you cannot explain the trust boundaries in one screen of text, stop and
  clarify the architecture first.
