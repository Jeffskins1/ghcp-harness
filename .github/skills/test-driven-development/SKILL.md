---
name: test-driven-development
description: Drive red-green-refactor delivery from spec scenarios, with failing tests first and harness-recorded evidence per task.
---

# Test-Driven Development

## Overview

Drive red-green-refactor delivery from spec scenarios, with failing tests first and harness-recorded evidence per task.

## Quick Reference

- **Use when:** Use during the T (Tests) phase of the ICTT loop. Invoke when starting implementation of any atomic task from the writing-plans skill output.
- **Output:** Tested, clean implementation - one task at a time.
- **Duration:** One Red-Green-Refactor cycle per atomic task.
- **Phase:** T (Tests) - the exit condition of the inner loop.

## Bundled Resources

- `references/project-test-setup-template.md`: Load when adapting this skill to a repo-specific test runner, single-test command, coverage flow, or integration harness.

## Purpose

Tests written after implementation are confirmations of what you built.
Tests written before implementation are specifications of what you intend to build.

The distinction matters enormously when working with agents. An agent that writes
tests after code will write tests that pass the code it just wrote, even if that
code is wrong. An agent given a failing test first is forced to satisfy a specific,
externally-defined contract.

This skill drives Red-Green-Refactor cycles with the agent, always starting from
the spec's Test Scenarios section.

The harness now enforces the order at runtime:
- the active task starts in `red`
- implementation-file edits are intercepted before a valid Red is recorded
- a failing recognized test command records Red for the current task
- a passing recognized test command only records Green if Red already exists
- task completion is blocked until the active task has both valid Red and Green evidence

## When to Invoke

Invoke this skill at the start of every atomic task from the implementation plan.
Do not start implementation without it.

## The Cycle

### RED - Write a failing test first

1. Open the OpenSpec for the current feature.
   Load it into the agent: `#file:specs/features/[feature].spec.md`

2. Select one Test Scenario from the spec's `## Test Scenarios` section.
   Start with the happy path first.

3. Ask the agent to write ONLY the test for this scenario.
   Prompt example:
   ```
   Write a failing unit test for this scenario from the spec:
   [paste scenario]
   Use [test framework]. Do not implement the function yet.
   The test file goes in tests/unit/[name].test.[ext].
   ```

4. Run the test. Confirm it fails with the expected error
   (e.g. "function not found", not a runtime crash).
   A test that fails for the wrong reason is not a valid Red.
   The harness only counts Red when:
   - the command is recognized as a test command
   - it exits non-zero
   - the active task is TDD-required
   - the failure does not look like obvious setup or infrastructure breakage

### GREEN - Implement the minimum to pass

5. Ask the agent to write the minimum implementation to make the test pass.
   Prompt example:
   ```
   Now implement [function/class] to make that test pass.
   Minimum viable implementation only - no extra features.
   The implementation goes in src/[layer]/[name].[ext].
   ```

6. Run the test. Confirm it passes.
   If it doesn't pass, iterate - ask the agent to diagnose and fix.
   Do not move to Refactor until the test is Green.
   The harness only records Green when a recognized test command passes after Red
   has already been recorded for the same task.

### REFACTOR - Clean without breaking

7. With tests green, ask the agent to refactor for clarity and consistency.
   Prompt example:
   ```
   Refactor [file] for clarity. Apply project conventions from
   #file:.github/copilot-instructions.md. Do not change behaviour.
   Tests must still pass after refactoring.
   ```

8. Run tests again. Confirm still Green.
   If tests break during refactor, revert the refactor and diagnose.

### REPEAT - Next scenario

9. Return to the spec. Select the next Test Scenario.
   Repeat the cycle: Red -> Green -> Refactor.

10. When all Test Scenarios from the spec are covered and green,
    the task is done. Open the MR.

## Harness Enforcement Notes

- Test files are always allowed during the `red` phase. Use standard paths such
  as `tests/`, `__tests__/`, `*.test.*`, or `*.spec.*` so the edit guard
  recognizes them correctly.
- Implementation-like files under common source roots such as `src/`, `app/`,
  `lib/`, and `pkg/` will trigger a pre-edit `ask` response until Red exists.
- A passing suite before any valid Red does not satisfy task completion.
- The release gate still runs the repo's declared full-suite command after TDD
  evidence is present. Red/Green evidence is required, but it does not replace
  full validation.

## Failure Handling

If the agent cannot make a test green after two attempts:
1. Stop and read the test + implementation together carefully.
2. Check whether the spec's test scenario is itself ambiguous.
   If so, update the spec first, then continue.
3. If the implementation requires a dependency that doesn't exist yet,
   check the task dependency order from writing-plans. You may be working
   out of sequence.
4. Add a note to `## Past Failures` in `copilot-instructions.md` if a
   pattern emerges (e.g. the agent repeatedly misunderstands a particular
   abstraction in your codebase).

## Coverage Policy

Minimum coverage per task:
- Happy path: required
- Primary failure mode: required
- Edge cases listed in spec: required
- Edge cases not in spec: optional (add to spec if you find them)

Do not chase coverage percentage. Chase scenario coverage from the spec.
A 90% coverage score with no scenario for "what happens when the database
is unavailable" is worthless.

## Integration Tests

For tasks at the API/controller layer, add one integration test per task
in addition to unit tests:
- Use a real (test) database, not mocks
- Cover the full request-to-response cycle
- Test the response shape, not just the status code

## Connecting to the ICTT Loop

When all tests are green and the MR is opened, the ICTT loop exit condition
is met. Any test failure that makes it to the GitLab CI pipeline after a
green local run should be added to `## Past Failures` in copilot-instructions.md
with the date and a one-line description of what the agent missed.
