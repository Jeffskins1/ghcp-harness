# Evaluator Packet

- Feature: [feature-name]
- Active spec: specs/features/[feature-name].spec.md
- Task: [task-id] - [task-title]
- Task type: [code/doc/research/review/ops/handoff]
- Validation modes: [tests / semantic_checks / artifact_exists / manual_ack]
- Done when: [done-when]
- Evaluator review required: YES
- Independence policy: [fresh_session_required / recorded_only / none]
- Generator session: [generator-session-id]
- Evaluator packet id: [packet-id]
- Exact test command: [full-suite-command]
- Last test result: pass / fail / unknown
- Evaluator result path: .github/agent-state/evaluator-result-task-[task-id].json
- Adversarial review modes: contract_adversary / regression_adversary / security_adversary / token_context_adversary

Review instructions:
1. Read the context file and active spec before implementation details.
2. Review against the acceptance criteria and task done condition, not against implementation intent.
3. Prefer a fresh session for evaluator-required tasks.
4. Apply every listed adversarial review mode explicitly before deciding the verdict.
5. Return a structured JSON result using `resources/templates/evaluator-result-template.json`.
6. Use verdict `pass`, `pass_with_risks`, or `fail`.

Structured result requirements:
- Required fields: `feature`, `task_id`, `packet_id`, `verdict`, `review_mode`, `reviewed_at`, `reviewer_session`, `applied_review_modes`, `criteria_results`, `findings`
- Criteria statuses: `MET`, `PARTIALLY MET`, `NOT MET`
- Findings must include `severity`, `blocking`, `summary`, and `evidence`
