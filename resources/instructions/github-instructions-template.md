# .github/copilot-instructions.md — Project Template
# Copy this file to .github/copilot-instructions.md in your repository.
# GitHub Copilot loads this automatically for every workspace session in VS Code and IntelliJ.
# Fill in every section. Blank sections produce worse agent output than no file at all.
#
# MULTI-AGENT REPOS: This file is the single source of truth for ALL coding agents
# on the repo — GitHub Copilot (VS Code), GitHub Copilot (IntelliJ), and Codex CLI.
# Codex reads AGENTS.md natively; keep AGENTS.md as a thin wrapper that delegates
# here (use resources/instructions/agents-md-template.md as the starting point).
# When you append a lesson after a session, update this file. All agents benefit.
# ──────────────────────────────────────────────────────────────────────────────

# Project: [Project Name]

## Tech Stack
- Language: [e.g. TypeScript 5.x / Python 3.12 / Java 21 / Kotlin 1.9]
- Framework: [e.g. Next.js 14 / FastAPI / Spring Boot 3 / Ktor]
- Database: [e.g. PostgreSQL 16 via Prisma / SQLAlchemy / JPA]
- Test framework: [e.g. Jest + Testing Library / pytest / JUnit 5 / Kotest]
- Build tool: [e.g. npm / Gradle / Maven / cargo]
- CI/CD: GitLab CI/CD — see .gitlab-ci.yml

## Architecture
- [src/components or similar]  → [what lives here, e.g. UI layer, React components]
- [src/services or similar]    → [e.g. Business logic, domain services]
- [src/utils or similar]       → [e.g. Shared helpers, pure functions]
- [src/api or similar]         → [e.g. API route handlers, controllers]
- [tests/unit]                 → Unit tests — mirror src/ structure
- [tests/integration]          → Integration tests — test at service boundary
- [tests/validation]           → Validation engineering — agent output verification
- [specs/]                     → OpenSpec intent files — read before implementing

## Conventions
- Write tests before implementation (TDD via test-driven-development skill)
- Use conventional commits: feat/fix/chore/refactor/test/docs
- Never commit directly to main - branch and MR only
- Run lint + typecheck before opening an MR
- One feature per branch. Branch name: [type]/[ticket-id]-[short-description]
- File naming: [describe your convention, e.g. kebab-case for files, PascalCase for components]
- Import ordering: [describe, e.g. external deps first, then internal, then relative]

## Exact Test Commands
- Full suite: `[copy-pasteable command required]`
- Unit: `[optional command if different]`
- Integration: `[optional command if different]`

Rules for this section:
- The `Full suite` command is mandatory. Harness gates use it for `TaskCompleted` and `pre-push`.
- Commands must be literal terminal commands, not prose.
- If setup is still uncertain, stop and resolve it before enabling the harness.

## GitLab Workflow
- Remote: self-managed GitLab (not github.com)
- Default branch: main
- MR template: .gitlab/merge_request_templates/default.md
- CI gates: lint → typecheck → unit tests → integration tests → build
- All CI gates must pass before merge
- Squash commits on merge
- Delete branch after merge
- Required MR reviewers: [describe policy]

## Security
- No secrets, tokens, or credentials in code, comments, or logs
- All environment variables via ${env:VAR_NAME} — never hardcoded
- Validate and sanitize all user inputs at the boundary
- Use parameterized queries — never string-interpolate SQL
- Auth pattern: [describe your auth approach, e.g. JWT via middleware, session-based]
- PII handling: [describe any data classification rules]

---

## Agent Constraints
# This section grows over time. Every time the agent causes a problem, add a line here.
# Copilot reads this on every session - this is how the agent learns your repo's gotchas.

### Rules
- Always read the relevant specs/features/[feature].spec.md before starting implementation
- Implementation work requires an active spec and a current workflow state file at `.github/agent-state/active-run.json`
- The harness enforces TDD per active task: write the failing test first, let a recognized failing test command record Red, then implement until a recognized passing test command records Green
- Implementation-file edits before Red may be blocked or require confirmation
- Task completion requires both Red and Green evidence plus a passing `Full suite` command
- Tasks marked `Evaluator review: YES` also require a recorded evaluator result with verdict `pass` or `pass_with_risks`
- Non-code tasks must still declare `Task type`, `Validation mode`, and machine-checkable `Semantic checks` or `manual_ack`
- Evaluator-gated tasks should record `Independence policy` and preserve packet metadata for result ingestion
- Tests must be passing before any MR is opened
- Do not modify [list protected paths, e.g. src/auth/, migrations/] without explicit instruction
- Do not change package.json / build.gradle / pom.xml dependencies without asking first
- Do not reformat files outside the scope of the current task

### Past Failures
# Format: [YYYY-MM-DD] — [what the agent did] — [what to do instead]
# Example:
# [2026-03-01] — Agent refactored retry logic in services/http.ts which broke webhook handler —
#                Do not touch services/http.ts retry logic without loading specs/arch.md first

---

## Harness Review
# Revisit this section periodically (every 1–3 months, or after a major model update).
# As models improve, scaffolding that was load-bearing may become unnecessary overhead.
# For each item below, ask: is this still doing real work, or is it ceremony?
#
# [ ] sprint contract confirmation in implementation-plans.md — still catching misalignments?
# [ ] separate-session evaluator in code-review.md — still catching things self-review misses?
# [ ] session-handoff.md — how often is context anxiety actually triggering this?
# [ ] architecture-decisions.md — which decisions is the model now handling without prompting?
# [ ] discovery.md — is the model discovering codebase context reliably on its own?
#
# Strip scaffolding that no longer earns its place. The goal is the minimum harness
# that keeps agent output trustworthy — not the maximum number of skills invoked.
## Harness Maintenance
- Edit canonical assets under `resources/`, not mirrored copies under `.github/` or `scripts/hooks/`
- Regenerate runtime assets with `python scripts/sync/sync_runtime_assets.py`
