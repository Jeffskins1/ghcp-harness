from __future__ import annotations

from pathlib import Path


SKILL_ORDER = [
    "accessibility-and-ux-validation",
    "api-contract-review",
    "architecture-decisions",
    "brainstorming",
    "code-review",
    "codex-repo-setup",
    "data-migration-safety-review",
    "debugging",
    "discovery",
    "hooks-setup",
    "implementation-plans",
    "intellij-repo-setup",
    "observability-planning",
    "performance-and-scalability-review",
    "release-readiness",
    "rollout-and-rollback-readiness",
    "security-review-and-threat-modeling",
    "session-handoff",
    "test-driven-development",
    "vscode-repo-setup",
    "writing-plans",
]


SKILLS = {
    "accessibility-and-ux-validation": {
        "display_name": "Accessibility And UX Validation",
        "description": (
            "Review user-facing changes for accessibility, usability, keyboard "
            "flow, content clarity, and interaction quality before release. Use "
            "for forms, navigation, interactive surfaces, and critical user tasks."
        ),
        "short_description": "Validate accessibility and UX before ship",
        "default_prompt": (
            "Use $accessibility-and-ux-validation to review this interface for "
            "usability, accessibility, and pre-release issues."
        ),
    },
    "api-contract-review": {
        "display_name": "API Contract Review",
        "description": (
            "Review API, event, webhook, and schema changes for compatibility, "
            "versioning, validation, failure semantics, and consumer impact. Use "
            "before implementing or releasing interface changes."
        ),
        "short_description": "Review API compatibility and contract risk",
        "default_prompt": (
            "Use $api-contract-review to inspect this API or schema change for "
            "compatibility, validation, and client impact."
        ),
    },
    "architecture-decisions": {
        "display_name": "Architecture Decisions",
        "description": (
            "Lock interfaces, boundaries, dependencies, and top risks before "
            "implementation when a change crosses layers, services, or shared "
            "interfaces."
        ),
        "short_description": "Lock interfaces and boundaries before build",
        "default_prompt": (
            "Use $architecture-decisions to lock the interfaces, boundaries, "
            "constraints, and top risks for this change."
        ),
    },
    "brainstorming": {
        "display_name": "Brainstorming",
        "description": (
            "Run a structured discovery dialogue to refine feature intent, "
            "scope, assumptions, and edge cases before spec writing or "
            "implementation."
        ),
        "short_description": "Refine feature intent before planning",
        "default_prompt": (
            "Use $brainstorming to refine the intent, scope, edge cases, and "
            "decision points for this feature."
        ),
    },
    "code-review": {
        "display_name": "Code Review",
        "description": (
            "Perform a risk-focused code review against acceptance criteria, "
            "including regression, missing-test, and scope-drift checks, with a "
            "strong bias toward fresh-session evaluation for complex changes."
        ),
        "short_description": "Run a risk-focused acceptance-criteria review",
        "default_prompt": (
            "Use $code-review to review this completed change against the spec, "
            "diff, regressions, and missing tests."
        ),
    },
    "codex-repo-setup": {
        "display_name": "Codex Repo Setup",
        "description": (
            "Bootstrap a repo for Codex-driven delivery by creating baseline "
            "folders, AGENTS.md, and shared spec scaffolding. Use once per repo "
            "before feature work."
        ),
        "short_description": "Bootstrap a repo for Codex workflows",
        "default_prompt": (
            "Use $codex-repo-setup to inspect this repo and create the baseline "
            "Codex instructions and shared spec scaffolding."
        ),
    },
    "data-migration-safety-review": {
        "display_name": "Data Migration Safety Review",
        "description": (
            "Plan safe schema changes, backfills, deploy ordering, rollback "
            "posture, and data validation for migration-heavy work."
        ),
        "short_description": "Review migration order, safety, and rollback",
        "default_prompt": (
            "Use $data-migration-safety-review to plan the migration sequence, "
            "rollback posture, and validation checks for this change."
        ),
    },
    "debugging": {
        "display_name": "Debugging",
        "description": (
            "Diagnose failing tests, regressions, or blocked implementation "
            "attempts before making more code changes. Use when the failure is "
            "not obvious after one or two tries."
        ),
        "short_description": "Diagnose failures before making more changes",
        "default_prompt": (
            "Use $debugging to diagnose this failure, isolate the root cause, "
            "and define the smallest correct fix target."
        ),
    },
    "discovery": {
        "display_name": "Discovery",
        "description": (
            "Ground a task in the existing codebase, current behavior, "
            "constraints, and ticket context before planning or spec writing."
        ),
        "short_description": "Ground the task in existing behavior",
        "default_prompt": (
            "Use $discovery to inspect the current implementation and summarize "
            "the existing behavior, constraints, and relevant files."
        ),
    },
    "hooks-setup": {
        "display_name": "Hooks Setup",
        "description": (
            "Install and configure shared hook-based guardrails across Codex, "
            "Copilot, and Git workflows. Use when bootstrapping repo automation, "
            "validation gates, and session guardrails."
        ),
        "short_description": "Install shared hook guardrails for agents",
        "default_prompt": (
            "Use $hooks-setup to plan or install the shared hook guardrails for "
            "this repository and its agent workflows."
        ),
    },
    "implementation-plans": {
        "display_name": "Implementation Plans",
        "description": (
            "Turn an approved spec into ordered execution tasks with "
            "dependencies, done conditions, and validation targets before coding."
        ),
        "short_description": "Turn specs into executable task order",
        "default_prompt": (
            "Use $implementation-plans to turn the approved spec into ordered "
            "implementation tasks, dependencies, and done conditions."
        ),
    },
    "intellij-repo-setup": {
        "display_name": "IntelliJ Repo Setup",
        "description": (
            "Bootstrap a repo for GitHub Copilot in IntelliJ by creating "
            "baseline folders, shared instructions, and spec scaffolding for "
            "JVM-centric workflows."
        ),
        "short_description": "Bootstrap IntelliJ and Copilot repo setup",
        "default_prompt": (
            "Use $intellij-repo-setup to inspect this repo and create the "
            "IntelliJ-focused instructions and spec scaffolding."
        ),
    },
    "observability-planning": {
        "display_name": "Observability Planning",
        "description": (
            "Define logs, metrics, traces, alerts, and diagnostic hooks for "
            "features that must be supportable in production."
        ),
        "short_description": "Plan logs, metrics, traces, and alerts",
        "default_prompt": (
            "Use $observability-planning to define the logs, metrics, traces, "
            "alerts, and diagnostics for this feature."
        ),
    },
    "performance-and-scalability-review": {
        "display_name": "Performance And Scalability Review",
        "description": (
            "Assess latency, throughput, fan-out, load, caching, and bottleneck "
            "risks before implementation or release of performance-sensitive "
            "changes."
        ),
        "short_description": "Review load, latency, and bottleneck risk",
        "default_prompt": (
            "Use $performance-and-scalability-review to assess this design for "
            "load, latency, fan-out, and bottleneck risk."
        ),
    },
    "release-readiness": {
        "display_name": "Release Readiness",
        "description": (
            "Confirm a change is ready for merge or release with green tests, "
            "linked specs, reviewer guidance, and recorded lessons."
        ),
        "short_description": "Confirm the change is ready to ship",
        "default_prompt": (
            "Use $release-readiness to confirm this change is ready for reviewer "
            "handoff, merge, or release."
        ),
    },
    "rollout-and-rollback-readiness": {
        "display_name": "Rollout And Rollback Readiness",
        "description": (
            "Plan phased release, feature-flag posture, monitoring, rollback "
            "triggers, and recovery steps before production rollout."
        ),
        "short_description": "Plan rollout phases and rollback safety",
        "default_prompt": (
            "Use $rollout-and-rollback-readiness to define rollout phases, "
            "rollback triggers, and recovery posture for this launch."
        ),
    },
    "security-review-and-threat-modeling": {
        "display_name": "Security Review And Threat Modeling",
        "description": (
            "Review trust boundaries, misuse cases, controls, secrets, auth "
            "flows, and abuse paths before implementation or release of "
            "sensitive changes."
        ),
        "short_description": "Review trust boundaries and abuse paths",
        "default_prompt": (
            "Use $security-review-and-threat-modeling to inspect this change for "
            "threats, trust boundaries, controls, and abuse cases."
        ),
    },
    "session-handoff": {
        "display_name": "Session Handoff",
        "description": (
            "Capture state, decisions, changed files, and re-entry prompts so "
            "long-running work can resume cleanly in a fresh agent session."
        ),
        "short_description": "Package context for a clean fresh session",
        "default_prompt": (
            "Use $session-handoff to capture the current state, decisions, and "
            "re-entry prompt for the next session."
        ),
    },
    "test-driven-development": {
        "display_name": "Test-Driven Development",
        "description": (
            "Drive red-green-refactor delivery from spec scenarios, with failing "
            "tests first and scoped validation per task."
        ),
        "short_description": "Drive red-green-refactor from the spec",
        "default_prompt": (
            "Use $test-driven-development to drive this task from failing tests "
            "to green validation and safe refactoring."
        ),
    },
    "vscode-repo-setup": {
        "display_name": "VS Code Repo Setup",
        "description": (
            "Bootstrap a repo for GitHub Copilot in VS Code by creating baseline "
            "folders, workspace settings, shared instructions, and spec "
            "scaffolding."
        ),
        "short_description": "Bootstrap VS Code and Copilot repo setup",
        "default_prompt": (
            "Use $vscode-repo-setup to inspect this repo and create the VS Code "
            "Copilot instructions and shared spec scaffolding."
        ),
    },
    "writing-plans": {
        "display_name": "Writing Plans",
        "description": (
            "Break an approved spec into atomic, ordered, agent-sized tasks "
            "before implementation."
        ),
        "short_description": "Split an approved spec into atomic tasks",
        "default_prompt": (
            "Use $writing-plans to break this approved spec into atomic, "
            "ordered, agent-sized implementation tasks."
        ),
    },
}


REFERENCE_EXTRACTIONS = {
    "code-review": {
        "Notes for Skill Authors": {
            "filename": "evaluator-calibration.md",
            "description": (
                "Load when review criteria are subjective or you need guidance "
                "for calibrating a fresh evaluator session."
            ),
            "title": "Evaluator Calibration",
        }
    },
    "hooks-setup": {
        "Notes": {
            "filename": "runtime-support-notes.md",
            "description": (
                "Load when you need runtime-specific hook support notes, "
                "preview limitations, or install caveats."
            ),
            "title": "Runtime Support Notes",
        }
    },
    "test-driven-development": {
        "Notes for Skill Authors": {
            "filename": "project-test-setup-template.md",
            "description": (
                "Load when adapting this skill to a repo-specific test runner, "
                "single-test command, coverage flow, or integration harness."
            ),
            "title": "Project Test Setup Template",
        },
        "Project Test Setup": {
            "filename": "project-test-setup-template.md",
            "description": (
                "Load when adapting this skill to a repo-specific test runner, "
                "single-test command, coverage flow, or integration harness."
            ),
            "title": "Project Test Setup Template",
        },
    },
}


DROP_SECTIONS = {
    "brainstorming": {"Notes for Skill Authors"},
    "codex-repo-setup": {"Notes for Skill Authors"},
    "intellij-repo-setup": {"Notes for Skill Authors"},
    "session-handoff": {"Notes for Skill Authors"},
    "test-driven-development": set(),
    "vscode-repo-setup": {"Notes for Skill Authors"},
    "code-review": set(),
    "hooks-setup": set(),
}


def skills_root_from_script(script_path: Path) -> Path:
    return script_path.resolve().parents[1]


def repo_root_from_skills(skills_root: Path) -> Path:
    return skills_root.resolve().parents[1]
