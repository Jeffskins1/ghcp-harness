#!/usr/bin/env python3
import json
from pathlib import Path
from typing import Any


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def state_path(root: Path | None = None) -> Path:
    base = root or repo_root()
    return base / ".github" / "agent-state" / "active-run.json"


def load_state(path: Path) -> dict:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def summary_path(root: Path | None = None) -> Path:
    base = root or repo_root()
    return base / ".github" / "agent-state" / "session-summary.json"


def state_summary(state: dict) -> dict:
    task = active_task(state) or {}
    return {
        "updated_at": state.get("updated_at"),
        "active_feature": state.get("active_feature"),
        "active_spec": state.get("active_spec"),
        "current_task_id": state.get("current_task_id"),
        "current_task_title": task.get("title"),
        "current_phase": state.get("current_phase"),
        "task_type": state.get("task_type"),
        "validation_modes": state.get("validation_modes", []),
        "last_test_result": state.get("last_test_result"),
        "semantic_checks": {
            "required": (state.get("semantic_checks") or {}).get("required"),
            "status": (state.get("semantic_checks") or {}).get("status"),
            "failing_count": (state.get("semantic_checks") or {}).get("failing_count"),
        },
        "manual_ack": {
            "required": (state.get("manual_ack") or {}).get("required"),
            "acknowledged": (state.get("manual_ack") or {}).get("acknowledged"),
        },
        "evaluator": {
            "required": (state.get("evaluator") or {}).get("required"),
            "status": (state.get("evaluator") or {}).get("status"),
            "verdict": (state.get("evaluator") or {}).get("verdict"),
            "independence_policy": (state.get("evaluator") or {}).get("independence_policy"),
            "independence_verified": (state.get("evaluator") or {}).get("independence_verified"),
            "quality_gate_passed": (state.get("evaluator") or {}).get("quality_gate_passed"),
        },
        "adversarial_review_modes": state.get("adversarial_review_modes", []),
        "feature_integration": {
            "required": (state.get("feature_integration") or {}).get("required"),
            "full_suite_passed": (state.get("feature_integration") or {}).get("full_suite_passed"),
            "recorded_at": (state.get("feature_integration") or {}).get("recorded_at"),
        },
    }


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(state, handle, indent=2)
        handle.write("\n")
    if path.name == "active-run.json":
        summary = summary_path(path.parents[2])
        summary.parent.mkdir(parents=True, exist_ok=True)
        with summary.open("w", encoding="utf-8") as handle:
            json.dump(state_summary(state), handle, indent=2)
            handle.write("\n")


def active_task(state: dict) -> dict | None:
    current_task_id = state.get("current_task_id")
    return next((item for item in state.get("task_list_snapshot", []) if item.get("id") == current_task_id), None)


def default_tdd(mode: str = "required") -> dict:
    return {
        "mode": mode,
        "red_required": mode == "required",
        "red_observed": False,
        "green_observed": False,
        "refactor_allowed": False,
        "task_complete_allowed": False,
        "red_command": None,
        "green_command": None,
        "red_recorded_at": None,
        "green_recorded_at": None,
        "last_test_outcome": None,
    }


def default_evaluator(required: bool = False) -> dict:
    return {
        "status": "pending" if required else "not_required",
        "verdict": "pending" if required else "not_required",
        "review_mode": "fresh_session" if required else "none",
        "independence_policy": "fresh_session_required" if required else "none",
        "packet_id": None,
        "packet_path": None,
        "launch_recorded_at": None,
        "generator_session": None,
        "result_path": None,
        "reviewed_at": None,
        "reviewer_session": None,
        "independence_verified": False,
        "quality_gate_passed": False,
        "quality_issues": [],
        "applied_review_modes": [],
        "blocking_findings": 0,
        "non_blocking_findings": 0,
        "criteria_summary": [],
        "residual_risks": [],
        "last_updated_at": None,
    }


def default_feature_integration() -> dict:
    return {
        "required": False,
        "full_suite_passed": False,
        "command": None,
        "recorded_at": None,
    }


def default_manual_ack() -> dict:
    return {
        "required": False,
        "acknowledged": False,
        "acknowledged_at": None,
        "acknowledged_by": None,
        "note": "",
    }


def default_semantic_summary(required: bool = False) -> dict:
    return {
        "required": required,
        "status": "pending" if required else "not_required",
        "checks": [],
        "evaluated_at": None,
        "failing_count": 0,
    }


def normalize_validation_modes(value: Any) -> list[str]:
    allowed = {"tests", "semantic_checks", "artifact_exists", "manual_ack"}
    if isinstance(value, str):
        candidates = [value]
    elif isinstance(value, list):
        candidates = value
    else:
        candidates = []

    normalized: list[str] = []
    for item in candidates:
        if item is None:
            continue
        mode = str(item).strip().lower().replace(" ", "_")
        if mode in allowed and mode not in normalized:
            normalized.append(mode)
    return normalized


def task_requires_semantic_checks(task: dict | None) -> bool:
    if not task:
        return False
    modes = normalize_validation_modes(task.get("validation_modes"))
    return "semantic_checks" in modes or "artifact_exists" in modes


def dependency_status(task: dict, tasks_by_id: dict[str, dict]) -> tuple[bool, list[str]]:
    missing = []
    for dependency in task.get("depends_on", []):
        candidate = tasks_by_id.get(dependency)
        if (candidate or {}).get("status") != "complete":
            missing.append(dependency)
    return not missing, missing


def next_runnable_task(state: dict, prefer_current: bool = True) -> tuple[dict | None, list[dict]]:
    tasks = state.get("task_list_snapshot", [])
    tasks_by_id = {item.get("id"): item for item in tasks}
    current = active_task(state)
    blockers = []

    if prefer_current and current and current.get("status") != "complete":
        ready, missing = dependency_status(current, tasks_by_id)
        if ready:
            return current, blockers
        blockers.append({"id": current.get("id"), "missing_dependencies": missing})

    for task in tasks:
        if task.get("status") == "complete":
            continue
        ready, missing = dependency_status(task, tasks_by_id)
        if ready:
            return task, blockers
        blockers.append({"id": task.get("id"), "missing_dependencies": missing})

    return None, blockers


def _phase_for_task(task: dict | None) -> str:
    if not task:
        return "planning"
    tdd = task.get("tdd") or default_tdd()
    if tdd.get("green_observed"):
        return "refactor"
    if tdd.get("red_observed"):
        return "green"
    return "red"


def refresh_summaries(state: dict) -> dict:
    task = active_task(state)
    if not task:
        state["current_phase"] = "planning"
        state["tdd_evidence"] = default_tdd()
        state["evaluator"] = {"required": False, **default_evaluator(False)}
        state["task_type"] = "none"
        state["validation_modes"] = []
        state["manual_ack"] = default_manual_ack()
        state["semantic_checks"] = default_semantic_summary(False)
        state["adversarial_review_modes"] = []
        return state

    validation_modes = normalize_validation_modes(task.get("validation_modes"))
    tdd = default_tdd((task.get("tdd") or {}).get("mode", "required"))
    tdd.update(task.get("tdd") or {})
    evaluator = default_evaluator(bool(task.get("evaluator_required")))
    evaluator.update(task.get("evaluator") or {})
    manual_ack = default_manual_ack()
    manual_ack.update(task.get("manual_ack") or {})
    semantic_checks = default_semantic_summary(task_requires_semantic_checks(task))
    semantic_checks.update(task.get("semantic_checks_summary") or {})

    state["current_phase"] = _phase_for_task(task)
    state["tdd_evidence"] = tdd
    state["task_type"] = task.get("task_type", "code")
    state["validation_modes"] = validation_modes
    state["manual_ack"] = manual_ack
    state["semantic_checks"] = semantic_checks
    state["evaluator"] = {
        "required": bool(task.get("evaluator_required")),
        **evaluator,
    }
    state["adversarial_review_modes"] = list(task.get("adversarial_review_modes", []))
    return state


def set_current_task(state: dict, task_id: str) -> dict:
    tasks = state.get("task_list_snapshot", [])
    target = next((item for item in tasks if item.get("id") == task_id), None)
    if target is None:
        raise ValueError(f"Unknown task id: {task_id}")

    tasks_by_id = {item.get("id"): item for item in tasks}
    ready, missing = dependency_status(target, tasks_by_id)
    if not ready:
        missing_csv = ", ".join(missing)
        raise ValueError(f"Task {task_id} is blocked by incomplete dependencies: {missing_csv}")

    previous = active_task(state)
    if previous and previous.get("status") == "in_progress" and previous.get("id") != task_id:
        previous["status"] = "not_started"

    if target.get("status") != "complete":
        target["status"] = "in_progress"

    state["current_task_id"] = task_id
    return refresh_summaries(state)


def complete_current_task(state: dict) -> tuple[dict, dict | None]:
    task = active_task(state)
    if task is None:
        raise ValueError("No active task to complete.")

    task["status"] = "complete"
    next_task, _ = next_runnable_task(state, prefer_current=False)
    state["current_task_id"] = next_task.get("id") if next_task else None
    if next_task and next_task.get("status") != "complete":
        next_task["status"] = "in_progress"
    refresh_summaries(state)

    if next_task is None:
        # All tasks done — require full-suite integration run before release
        state["feature_integration"] = {**default_feature_integration(), "required": True}
        state["current_phase"] = "integration"

    return state, next_task
