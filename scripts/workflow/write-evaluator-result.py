#!/usr/bin/env python3
import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from workflow_state import state_summary as workflow_state_summary


def fail(message: str) -> int:
    print(message, file=sys.stderr)
    return 1


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def load_json(path: str | Path) -> dict:
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def dump_json(path: str | Path, payload: dict) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")
    if path.name == "active-run.json":
        summary_path = path.parent / "session-summary.json"
        with summary_path.open("w", encoding="utf-8") as handle:
            json.dump(workflow_state_summary(payload), handle, indent=2)
            handle.write("\n")


def active_task(state: dict) -> dict | None:
    current_task_id = state.get("current_task_id")
    return next((item for item in state.get("task_list_snapshot", []) if item.get("id") == current_task_id), None)


def evidence_is_placeholder(text: str) -> bool:
    lowered = text.strip().lower()
    if not lowered:
        return True
    placeholders = {
        "todo", "tbd", "n/a", "na", "none", "placeholder", "lorem ipsum",
        "see above", "same as above", "not checked", "not reviewed",
    }
    return lowered in placeholders


def validate_result(state: dict, result: dict) -> tuple[bool, str, dict[str, Any]]:
    task = active_task(state)
    if task is None:
        return False, "Active task is missing from state.", {}
    if not task.get("evaluator_required"):
        return False, "Active task does not require evaluator review.", {}

    evaluator = task.get("evaluator") or {}
    feature = state.get("active_feature")
    task_id = state.get("current_task_id")

    if result.get("feature") != feature:
        return False, "Result feature does not match active feature.", {}
    if result.get("task_id") != task_id:
        return False, "Result task_id does not match current_task_id.", {}
    if result.get("verdict") not in {"pass", "pass_with_risks", "fail"}:
        return False, "Verdict must be pass, pass_with_risks, or fail.", {}
    if result.get("review_mode") not in {"fresh_session", "same_session"}:
        return False, "review_mode must be fresh_session or same_session.", {}
    if not result.get("reviewed_at"):
        return False, "reviewed_at is required.", {}
    if not result.get("reviewer_session"):
        return False, "reviewer_session is required.", {}
    if not result.get("packet_id"):
        return False, "packet_id is required.", {}
    if result.get("packet_id") != evaluator.get("packet_id"):
        return False, "packet_id does not match the active evaluator packet.", {}

    criteria_results = result.get("criteria_results")
    findings = result.get("findings")
    residual_risks = result.get("residual_risks", [])
    applied_modes = result.get("applied_review_modes", [])

    if not isinstance(criteria_results, list) or not criteria_results:
        return False, "criteria_results must be a non-empty list.", {}
    if not isinstance(findings, list):
        return False, "findings must be a list.", {}
    if not isinstance(residual_risks, list):
        return False, "residual_risks must be a list.", {}
    if not isinstance(applied_modes, list):
        return False, "applied_review_modes must be a list.", {}

    quality_issues: list[str] = []
    not_met = 0
    blocking_findings = 0
    for item in criteria_results:
        if not isinstance(item, dict):
            return False, "Each criteria_results entry must be an object.", {}
        criterion = item.get("criterion")
        status = item.get("status")
        evidence = str(item.get("evidence", ""))
        if not criterion or status not in {"MET", "PARTIALLY MET", "NOT MET"}:
            return False, "Each criteria result needs criterion and an allowed status.", {}
        if evidence_is_placeholder(evidence):
            quality_issues.append(f"Criterion {criterion} has placeholder or empty evidence.")
        if status == "NOT MET":
            not_met += 1

    for item in findings:
        if not isinstance(item, dict):
            return False, "Each finding must be an object.", {}
        if item.get("severity") not in {"low", "medium", "high"}:
            return False, "Each finding severity must be low, medium, or high.", {}
        if not isinstance(item.get("blocking"), bool):
            return False, "Each finding blocking field must be boolean.", {}
        if evidence_is_placeholder(str(item.get("summary", ""))) or evidence_is_placeholder(str(item.get("evidence", ""))):
            quality_issues.append("Findings must include non-placeholder summary and evidence.")
        if item.get("blocking"):
            blocking_findings += 1

    if result["verdict"] == "fail" and blocking_findings == 0:
        return False, "Fail verdict requires at least one blocking finding.", {}
    if result["verdict"] in {"pass", "pass_with_risks"} and blocking_findings != 0:
        return False, "Passing verdicts cannot include blocking findings.", {}
    if result["verdict"] == "pass" and not_met:
        quality_issues.append("Pass verdict cannot include NOT MET criteria.")
    if not_met and not findings:
        quality_issues.append("NOT MET criteria require explicit findings.")

    required_modes = list(task.get("adversarial_review_modes", []))
    missing_modes = [mode for mode in required_modes if mode not in applied_modes]
    if missing_modes:
        quality_issues.append(f"Missing required adversarial review modes: {', '.join(missing_modes)}.")

    policy = evaluator.get("independence_policy", task.get("independence_policy", "none"))
    generator_session = evaluator.get("generator_session") or state.get("generator_session")
    reviewer_session = result.get("reviewer_session")
    independence_verified = True
    if policy == "fresh_session_required":
        independence_verified = bool(
            evaluator.get("launch_recorded_at")
            and result.get("review_mode") == "fresh_session"
            and reviewer_session
            and generator_session
            and reviewer_session != generator_session
        )
        if not independence_verified:
            quality_issues.append("Fresh-session independence proof failed.")
    elif policy == "recorded_only":
        independence_verified = bool(evaluator.get("launch_recorded_at"))
        if not independence_verified:
            quality_issues.append("Evaluator launch metadata is missing.")

    quality_gate_passed = len(quality_issues) == 0
    metadata = {
        "blocking_findings": blocking_findings,
        "non_blocking_findings": sum(1 for item in findings if item.get("blocking") is False),
        "criteria_summary": [
            {"criterion": item.get("criterion"), "status": item.get("status"), "evidence": item.get("evidence")}
            for item in criteria_results
        ],
        "quality_issues": quality_issues,
        "quality_gate_passed": quality_gate_passed,
        "independence_verified": independence_verified,
        "applied_review_modes": applied_modes,
        "generator_session": generator_session,
    }
    return quality_gate_passed, "; ".join(quality_issues), metadata


def update_state(state_path: Path, result_path: Path, result: dict, metadata: dict[str, Any]) -> None:
    state = load_json(state_path)
    task = active_task(state)
    findings = result.get("findings", [])
    evaluator_block = {
        "status": "fail" if result["verdict"] == "fail" or not metadata["quality_gate_passed"] else "pass",
        "verdict": result["verdict"],
        "review_mode": result["review_mode"],
        "independence_policy": (task.get("evaluator") or {}).get("independence_policy", task.get("independence_policy", "none")),
        "packet_id": result.get("packet_id"),
        "packet_path": (task.get("evaluator") or {}).get("packet_path"),
        "launch_recorded_at": (task.get("evaluator") or {}).get("launch_recorded_at"),
        "generator_session": metadata["generator_session"],
        "result_path": str(result_path),
        "reviewed_at": result["reviewed_at"],
        "reviewer_session": result["reviewer_session"],
        "independence_verified": metadata["independence_verified"],
        "quality_gate_passed": metadata["quality_gate_passed"],
        "quality_issues": metadata["quality_issues"],
        "applied_review_modes": metadata["applied_review_modes"],
        "blocking_findings": metadata["blocking_findings"],
        "non_blocking_findings": metadata["non_blocking_findings"],
        "criteria_summary": metadata["criteria_summary"],
        "residual_risks": result.get("residual_risks", []),
        "last_updated_at": now_iso(),
    }

    task["evaluator"] = evaluator_block
    task["last_updated_at"] = evaluator_block["last_updated_at"]
    state["evaluator"] = {"required": True, **evaluator_block}
    state["updated_at"] = evaluator_block["last_updated_at"]
    dump_json(state_path, state)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("result_json_path")
    parser.add_argument("--validate-only", action="store_true")
    parser.add_argument("--state-path")
    args = parser.parse_args()

    root_dir = Path(__file__).resolve().parents[2]
    state_json_path = Path(args.state_path).resolve() if args.state_path else root_dir / ".github" / "agent-state" / "active-run.json"
    result_json_path = Path(args.result_json_path).resolve()

    if not state_json_path.exists():
        return fail(f"State file not found: {state_json_path}")
    if not result_json_path.exists():
        return fail(f"Result file not found: {result_json_path}")

    state = load_json(state_json_path)
    result = load_json(result_json_path)
    ok, message, metadata = validate_result(state, result)
    if not ok:
        return fail(message or "Evaluator result failed validation.")
    if args.validate_only:
        print(result_json_path)
        return 0

    update_state(state_json_path, result_json_path, result, metadata)
    print(result_json_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
