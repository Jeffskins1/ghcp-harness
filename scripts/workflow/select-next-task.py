#!/usr/bin/env python3
import argparse
import json
import sys

from workflow_state import active_task, load_state, next_runnable_task, refresh_summaries, save_state, set_current_task, state_path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Set the selected task as current_task_id in state.")
    args = parser.parse_args()

    path = state_path()
    if not path.exists():
        print(f"State file not found: {path}", file=sys.stderr)
        return 1

    state = load_state(path)
    refresh_summaries(state)
    current = active_task(state)
    task, blockers = next_runnable_task(state, prefer_current=True)

    if args.apply and task:
        set_current_task(state, task.get("id"))
        save_state(path, state)
        current = active_task(state)
        task = current

    payload = {
        "current_task_id": state.get("current_task_id"),
        "current_task_status": (current or {}).get("status"),
        "next_task_id": (task or {}).get("id"),
        "next_task_title": (task or {}).get("title"),
        "next_task_status": (task or {}).get("status"),
        "depends_on": (task or {}).get("depends_on", []),
        "adversarial_review_modes": (task or {}).get("adversarial_review_modes", []),
        "blocked_tasks": blockers,
    }
    print(json.dumps(payload, indent=2))
    return 0 if task else 2


if __name__ == "__main__":
    raise SystemExit(main())
