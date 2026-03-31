#!/usr/bin/env python3
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from workflow_state import active_task, load_state, state_path


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def walk_path(data: dict[str, Any], dotted: str) -> Any:
    current: Any = data
    for part in dotted.split("."):
        if not part:
            continue
        if isinstance(current, dict):
            current = current.get(part)
        else:
            return None
    return current


def normalize_root(path: Path) -> Path:
    return path.resolve().parents[2]


def evaluate_check(root: Path, state: dict[str, Any], check: dict[str, Any]) -> dict[str, Any]:
    check_type = str(check.get("type", "")).strip()
    result = {"type": check_type, "passed": False}
    if "path" in check:
        result["path"] = check["path"]

    if check_type in {"file_exists", "artifact_exists"}:
        target = root / str(check.get("path", ""))
        passed = target.exists()
        result["passed"] = passed
        result["details"] = f"Exists: {target}" if passed else f"Missing: {target}"
        return result

    if check_type == "file_contains":
        target = root / str(check.get("path", ""))
        pattern = str(check.get("pattern", ""))
        if not target.exists():
            result["details"] = f"Missing file: {target}"
            return result
        text = target.read_text(encoding="utf-8")
        passed = pattern in text
        result["passed"] = passed
        result["pattern"] = pattern
        result["details"] = "Pattern found" if passed else "Pattern missing"
        return result

    if check_type == "state_equals":
        dotted = str(check.get("path", ""))
        expected = check.get("value")
        actual = walk_path(state, dotted)
        passed = actual == expected
        result["passed"] = passed
        result["actual"] = actual
        result["expected"] = expected
        result["details"] = "State matched expected value" if passed else "State value differed"
        return result

    if check_type == "command_exit_code":
        command = str(check.get("command", ""))
        expected = int(check.get("exit_code", 0))
        completed = subprocess.run(command, cwd=root, shell=True, capture_output=True, text=True)
        passed = completed.returncode == expected
        result["passed"] = passed
        result["command"] = command
        result["expected"] = expected
        result["actual"] = completed.returncode
        result["details"] = "Command exit code matched" if passed else "Command exit code differed"
        if completed.stdout:
            result["stdout"] = completed.stdout[-500:]
        if completed.stderr:
            result["stderr"] = completed.stderr[-500:]
        return result

    result["details"] = f"Unsupported semantic check type: {check_type}"
    return result


def main() -> int:
    path = state_path()
    if len(sys.argv) > 1:
        path = Path(sys.argv[1]).resolve()
    if not path.exists():
        print(json.dumps({"status": "missing_state"}))
        return 1

    state = load_state(path)
    task = active_task(state)
    checks = (task or {}).get("semantic_checks", [])
    if not checks:
        print(json.dumps({
            "status": "not_required",
            "checks": [],
            "evaluated_at": now_iso(),
            "failing_count": 0,
        }, indent=2))
        return 0

    root = normalize_root(path)
    results = [evaluate_check(root, state, check) for check in checks]
    failing_count = sum(1 for item in results if not item.get("passed"))
    payload = {
        "status": "pass" if failing_count == 0 else "fail",
        "checks": results,
        "evaluated_at": now_iso(),
        "failing_count": failing_count,
    }
    print(json.dumps(payload, indent=2))
    return 0 if failing_count == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
