---
name: session-handoff
description: Capture state, decisions, changed files, and re-entry prompts so long-running work can resume cleanly in a fresh agent session.
---

# Session Handoff

## Overview

Capture state, decisions, changed files, and re-entry prompts so long-running work can resume cleanly in a fresh agent session.

The durable checkpoint is `.github/agent-state/active-run.json`, with the spec
remaining the human-readable contract.

## Quick Reference

- **Use when:** Use when a session is running long, the agent shows signs of context anxiety (rushing, cutting corners, wrapping up unfinished work), or you need to pause and resume a task across multiple sessions.
- **Output:** Updated spec with current state, appended lessons in the context file, and a structured prompt ready to start the next session clean.
- **Duration:** 5-10 minutes. Run at any natural task boundary.
- **Phase:** I · T · T - can interrupt any phase of the development loop.

## Purpose

Long-running agent sessions accumulate context until the model begins to
exhibit "context anxiety" - rushing to wrap up, cutting corners on tests,
or skipping steps it would handle carefully in a fresh session. This is not
a model failure; it is a harness design problem. The fix is a deliberate
context reset with a structured handoff rather than letting the session
continue to degrade.

This skill ends the current session cleanly and prepares the next one to
pick up exactly where this one stopped - without re-explaining the project,
the spec, or the decisions already made.

## Signs That a Reset Is Needed

Watch for any of these:
- The agent starts summarising work it hasn't done yet as if it were done
- Test steps get shorter or are skipped with vague justifications
- The agent references "earlier in the conversation" for decisions that
  aren't written down anywhere persistent
- A task that should take multiple steps is suddenly "done" in one
- The agent stops asking for confirmation on consequential changes
- You have been in the same session for more than 60-90 minutes of active work

## Process

### Step 1 - Freeze the current state
Before doing anything else, ask the agent:

```
Stop all implementation work. Do not make any more edits.
Summarise exactly where we are: which tasks from the active spec are done,
which is in progress, and which are not started. Be specific about file
names and what was changed.
```

Do not let the agent continue coding during this step.

### Step 2 - Write state back to the spec
Ask the agent:

```
Update specs/features/[feature].spec.md with a ## Session State section
at the bottom. Record:
- Tasks completed (with brief note of what was done)
- Task currently in progress (what was done, what remains)
- Tasks not yet started
- Any decisions made during this session that are not already in the spec
- Any open questions or blockers discovered
Do not change anything else in the spec.

Then verify `.github/agent-state/active-run.json` reflects the same active spec,
current task, and current phase. If it does not, fix the state file before ending
the session.
```

### Step 3 - Append lessons to the context file
Ask the agent:

```
Review this session for any repeatable lessons - things the agent got wrong,
patterns that worked well, constraints discovered about this repo.
Append them to .github/copilot-instructions.md (or AGENTS.md) under
Persistent Lessons. Format: [YYYY-MM-DD] - [what happened] - [rule going forward].
Only add entries for lessons not already present.
```

### Step 4 - Write the re-entry prompt
Ask the agent to produce a structured prompt you can paste to start the next
session. The prompt should contain:

```
We are resuming work on [feature name].
Active spec: specs/features/[feature].spec.md
Session State section in the spec shows what is done and what remains.

Start by reading:
1. .github/copilot-instructions.md (or AGENTS.md)
2. specs/features/[feature].spec.md - especially the ## Session State section
3. The files changed so far (listed in Session State)

Then confirm your understanding of what remains before doing anything.
Do not re-implement work already marked as done.
```

### Step 5 - End the session
Close the current session entirely. Do not continue in the same context.
Open a new session, paste the re-entry prompt from Step 4, and confirm
the agent's understanding before resuming implementation.

## The Spec as Inter-Agent Communication Bus

The spec file is not just a requirements document - it is the communication
channel between agent sessions, between agent roles (planner -> generator ->
evaluator), and between you and the agent across time. Every decision,
state change, and open question should be written to it. If it is only in
the conversation, it will be lost.

Structure the spec so any agent reading it cold can understand:
- What the feature does and why
- What "done" looks like (acceptance criteria)
- What has already been built (Session State)
- What constraints were discovered during implementation
- What the evaluator will test against

## Evaluator Re-Entry

When resuming after a handoff, the first step for complex changes should be
an evaluator pass on the completed work before continuing. Ask:

```
Before we continue, use code-review to inspect the work completed so far
(listed in the Session State section of the spec). File any findings against
the spec's acceptance criteria. Do not start new implementation until the
review is clean.
```

This catches drift that accumulated in the previous session before it compounds.

For tasks marked `Evaluator review: YES`, generate the evaluator packet before
ending the generator session:

```bash
bash scripts/workflow/generate-evaluator-packet.sh
```

That packet should name the structured result path. After the evaluator writes
the result JSON, record it with:

```bash
python scripts/workflow/write-evaluator-result.py .github/agent-state/evaluator-result-task-[task-id].json
```

The release gate will block completion if the evaluator result is missing,
malformed, still pending, or failed.
