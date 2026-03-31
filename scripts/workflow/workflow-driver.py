#!/usr/bin/env python3
import argparse
import json
import sys
from datetime import datetime, timezone

from workflow_state import active_task, complete_current_task, load_state, refresh_summaries, save_state, set_current_task, state_path


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def command_start_task(task_id: str) -> int:
    path = state_path()
    state = load_state(path)
    refresh_summaries(state)
    set_current_task(state, task_id)
    state["updated_at"] = now_iso()
    save_state(path, state)
    task = active_task(state) or {}
    print(json.dumps({
        "current_task_id": task.get("id"),
        "current_task_title": task.get("title"),
        "current_phase": state.get("current_phase"),
        "adversarial_review_modes": task.get("adversarial_review_modes", []),
    }, indent=2))
    return 0


def command_complete_current() -> int:
    path = state_path()
    state = load_state(path)
    refresh_summaries(state)
    completed = active_task(state) or {}
    state, next_task = complete_current_task(state)
    state["updated_at"] = now_iso()
    save_state(path, state)
    print(json.dumps({
        "completed_task_id": completed.get("id"),
        "completed_task_title": completed.get("title"),
        "next_task_id": (next_task or {}).get("id"),
        "next_task_title": (next_task or {}).get("title"),
        "current_phase": state.get("current_phase"),
    }, indent=2))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    start_task_parser = subparsers.add_parser("start-task")
    start_task_parser.add_argument("task_id")

    subparsers.add_parser("complete-current")

    args = parser.parse_args()

    try:
        if args.command == "start-task":
            return command_start_task(args.task_id)
        if args.command == "complete-current":
            return command_complete_current()
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    except FileNotFoundError:
        print(f"State file not found: {state_path()}", file=sys.stderr)
        return 1

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
