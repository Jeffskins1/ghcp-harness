---
name: accessibility-and-ux-validation
description: Review user-facing changes for accessibility, usability, keyboard flow, content clarity, and interaction quality before release. Use for forms, navigation, interactive surfaces, and critical user tasks.
---

# Accessibility And UX Validation

## Overview

Review user-facing changes for accessibility, usability, keyboard flow, content clarity, and interaction quality before release. Use for forms, navigation, interactive surfaces, and critical user tasks.

## Quick Reference

- **Use when:** Use when a change affects UI, forms, navigation, content flow, visual hierarchy, or interactive behavior that users must perceive, understand, and operate.
- **Output:** Accessibility and UX findings, required fixes, and validation steps for the active interface.
- **Duration:** 10-20 minutes.
- **Phase:** T / Ship gate - after implementation, before release of user-facing changes.

## Purpose

This skill reviews whether an interface works for real users, including users
who navigate with keyboards, assistive technology, zoom, or constrained
attention. It combines a11y basics with product UX checks so the team does not
ship technically functional but hard-to-use interfaces.

## When to Invoke

Invoke this skill when:
- A form, modal, menu, table, dashboard, or settings flow changes
- New copy, validation messages, or error handling is introduced
- Focus order, keyboard interaction, or responsive behavior matters
- The team wants a pre-ship UI quality gate

## Progressive Disclosure

**Tier 1 - Quick Validation**
- for small UI tweaks
- review labels, focus, error states, and responsiveness

**Tier 2 - Standard Validation**
- for most user-facing work
- complete the full process

**Tier 3 - Critical Flow**
- checkout, auth, onboarding, or high-volume forms
- add task completion checks, assistive-tech assumptions, and edge-state review

## Hook Placement

Run this skill:
- After implementation of user-facing work
- Before release-readiness on flows that affect users directly
- After design or support feedback exposes usability issues

## Process

### Step 1 - Define the user task

Write one sentence:
"The user needs to [action] so they can [outcome]."

Reviewing a page without a task in mind produces shallow results.

### Step 2 - Check operability

Verify:
- all interactive elements are keyboard reachable
- focus order follows visual order
- focus is visible
- modals, menus, and dialogs trap and restore focus correctly

### Step 3 - Check clarity

Review:
- labels and headings
- validation and error language
- button copy and destructive action warnings
- empty states, loading states, and success states

### Step 4 - Check accessibility basics

Look for:
- semantic structure and accessible names
- form labels and error association
- sufficient contrast
- non-color-only cues
- sensible zoom and responsive behavior
- table, image, and icon semantics where relevant

### Step 5 - Define validation

Before ship, collect:
- keyboard walkthrough of the core task
- responsive check at common breakpoints
- error-state review
- automated accessibility scan if the repo has one

## Output Format

```text
Accessibility And UX Validation

User Task
- [...]

Findings
1. [issue] -> [impact]

Required Fixes
- [...]

Validation
- [manual or automated check]

Residual Risks
- [...]
```

## Notes

- Do not accept "works with a mouse" as sufficient validation.
- If the interface relies on color alone to communicate state, it is incomplete.
- The highest-value check is whether the user can complete the task without
  confusion, not whether the page looks polished.
