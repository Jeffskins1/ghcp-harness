#!/usr/bin/env bash

hook_state_default_tdd_field() {
  local field="$1"
  case "$field" in
    mode) printf 'required\n' ;;
    red_required) printf 'true\n' ;;
    red_observed|green_observed|refactor_allowed|task_complete_allowed) printf 'false\n' ;;
    red_command|green_command|red_recorded_at|green_recorded_at|last_test_outcome) printf '\n' ;;
    *) printf '\n' ;;
  esac
}

hook_state_default_evaluator_field() {
  local field="$1"
  local required="${2:-false}"
  case "$field" in
    status|verdict)
      if [ "$required" = "true" ]; then
        printf 'pending\n'
      else
        printf 'not_required\n'
      fi
      ;;
    review_mode)
      if [ "$required" = "true" ]; then
        printf 'fresh_session\n'
      else
        printf 'none\n'
      fi
      ;;
    independence_policy)
      if [ "$required" = "true" ]; then
        printf 'fresh_session_required\n'
      else
        printf 'none\n'
      fi
      ;;
    independence_verified|quality_gate_passed) printf 'false\n' ;;
    blocking_findings|non_blocking_findings) printf '0\n' ;;
    result_path|reviewed_at|reviewer_session|last_updated_at|criteria_summary|residual_risks|packet_id|packet_path|launch_recorded_at|generator_session|quality_issues|applied_review_modes) printf '\n' ;;
    *) printf '\n' ;;
  esac
}

hook_state_default_semantic_field() {
  local field="$1"
  local required="${2:-false}"
  case "$field" in
    required)
      printf '%s\n' "$required"
      ;;
    status)
      if [ "$required" = "true" ]; then
        printf 'pending\n'
      else
        printf 'not_required\n'
      fi
      ;;
    checks) printf '[]\n' ;;
    failing_count) printf '0\n' ;;
    evaluated_at) printf '\n' ;;
    *) printf '\n' ;;
  esac
}

hook_state_default_manual_ack_field() {
  local field="$1"
  case "$field" in
    required|acknowledged) printf 'false\n' ;;
    acknowledged_at|acknowledged_by|note) printf '\n' ;;
    *) printf '\n' ;;
  esac
}

hook_state_dir() {
  printf '%s\n' ".github/agent-state"
}

hook_state_file() {
  printf '%s\n' "$(hook_state_dir)/active-run.json"
}

hook_state_summary_file() {
  printf '%s\n' "$(hook_state_dir)/session-summary.json"
}

hook_state_ensure_dir() {
  mkdir -p "$(hook_state_dir)"
}

hook_state_now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

hook_state_current_session_id() {
  if [ -n "${HARNESS_SESSION_ID:-}" ]; then
    printf '%s\n' "$HARNESS_SESSION_ID"
    return
  fi
  if [ -n "${CODEX_SESSION_ID:-}" ]; then
    printf '%s\n' "$CODEX_SESSION_ID"
    return
  fi
  if [ -n "${COPILOT_SESSION_ID:-}" ]; then
    printf '%s\n' "$COPILOT_SESSION_ID"
    return
  fi
  if [ -n "${CLAUDE_SESSION_ID:-}" ]; then
    printf '%s\n' "$CLAUDE_SESSION_ID"
    return
  fi
  printf 'unknown\n'
}

hook_state_list_specs() {
  if [ ! -d "specs/features" ]; then
    return 0
  fi

  find "specs/features" -maxdepth 1 -type f \( -name "*.spec.md" -o -name "*.md" \) | sort
}

hook_state_infer_active_spec() {
  local state_file
  state_file="$(hook_state_file)"

  if [ -f "$state_file" ]; then
    local from_state
    from_state="$("$HOOK_PYTHON_BIN" - "$state_file" <<'PY'
import json
import sys

path = sys.argv[1]
try:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle)
except Exception:
    print("")
    raise SystemExit(0)

value = data.get("active_spec") or ""
print(value)
PY
)"
    if [ -n "$from_state" ] && [ -f "$from_state" ]; then
      printf '%s\n' "$from_state"
      return
    fi
  fi

  if [ -n "${HARNESS_ACTIVE_SPEC:-}" ] && [ -f "${HARNESS_ACTIVE_SPEC}" ]; then
    printf '%s\n' "${HARNESS_ACTIVE_SPEC}"
    return
  fi

  local spec_count
  spec_count="$(hook_state_list_specs | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "${spec_count:-0}" = "1" ]; then
    hook_state_list_specs | head -1
    return
  fi

  if [ -d "specs/features" ]; then
    ls -t specs/features/*.spec.md specs/features/*.md 2>/dev/null | head -1
  fi
}

hook_state_feature_name_from_spec() {
  local spec="$1"
  local base
  base="$(basename "$spec")"
  base="${base%.spec.md}"
  base="${base%.md}"
  printf '%s\n' "$base"
}

hook_state_tasks_from_spec() {
  local spec="$1"
  "$HOOK_PYTHON_BIN" - "$spec" <<'PY'
import json
import re
import sys

spec_path = sys.argv[1]
try:
    text = open(spec_path, encoding="utf-8").read().splitlines()
except Exception:
    print("[]")
    raise SystemExit(0)

tasks = []
in_plan = False
current = None
in_semantic_checks = False
current_check = None

KNOWN_FIELDS = (
    "Files:",
    "Does:",
    "Done when:",
    "Depends on:",
    "Evaluator review:",
    "Adversarial review:",
    "Adversarial reviews:",
    "Review modes:",
    "Task type:",
    "Validation mode:",
    "Validation modes:",
    "TDD:",
    "Independence policy:",
    "Semantic checks:",
)

def parse_list(value):
    normalized = value.replace(" and ", ",")
    return [item.strip() for item in normalized.split(",") if item.strip()]

def parse_dependencies(value):
    items = []
    for raw in parse_list(value):
        lowered = raw.lower()
        if lowered in {"none", "n/a", "na"}:
            continue
        normalized = re.sub(r"^task\s+", "", raw, flags=re.IGNORECASE).strip()
        if normalized:
            items.append(normalized)
    return items

def parse_review_modes(value):
    aliases = {
        "contract adversary": "contract_adversary",
        "contract_adversary": "contract_adversary",
        "regression adversary": "regression_adversary",
        "regression_adversary": "regression_adversary",
        "security adversary": "security_adversary",
        "security_adversary": "security_adversary",
        "token/context adversary": "token_context_adversary",
        "token context adversary": "token_context_adversary",
        "token_context_adversary": "token_context_adversary",
        "none": "none",
    }
    modes = []
    for raw in parse_list(value):
        key = raw.strip().lower()
        mapped = aliases.get(key)
        if not mapped:
            mapped = re.sub(r"[^a-z0-9]+", "_", key).strip("_")
        if mapped and mapped != "none" and mapped not in modes:
            modes.append(mapped)
    return modes

def parse_validation_modes(value):
    allowed = {"tests", "semantic_checks", "artifact_exists", "manual_ack"}
    modes = []
    for raw in parse_list(value):
        mode = re.sub(r"[^a-z0-9]+", "_", raw.strip().lower()).strip("_")
        if mode in allowed and mode not in modes:
            modes.append(mode)
    return modes

def normalize_task_type(value):
    allowed = {"code", "doc", "research", "review", "ops", "handoff"}
    normalized = re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")
    return normalized if normalized in allowed else "code"

def normalize_tdd(value):
    normalized = re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")
    return "not_applicable" if normalized in {"not_applicable", "na", "n_a"} else "required"

def normalize_independence_policy(value, evaluator_required):
    normalized = re.sub(r"[^a-z0-9]+", "_", value.strip().lower()).strip("_")
    allowed = {"none", "fresh_session_required", "recorded_only"}
    if normalized in allowed:
        return normalized
    return "fresh_session_required" if evaluator_required else "none"

def normalize_scalar(value):
    stripped = value.strip()
    if stripped.startswith('"') and stripped.endswith('"'):
        return stripped[1:-1]
    if stripped.startswith("'") and stripped.endswith("'"):
        return stripped[1:-1]
    lowered = stripped.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    if re.fullmatch(r"-?\d+", stripped):
        return int(stripped)
    return stripped

def default_task(task_id, title):
    return {
        "id": task_id,
        "title": title,
        "files": [],
        "done_when": "",
        "depends_on": [],
        "evaluator_required": False,
        "independence_policy": "none",
        "task_type": "code",
        "validation_modes": [],
        "validation_mode_declared": False,
        "tdd_mode": "required",
        "semantic_checks": [],
        "adversarial_review_modes": [],
        "status": "not_started",
    }

def finalize_task(task):
    if not task["validation_modes"]:
        if task["task_type"] == "code":
            task["validation_modes"] = ["tests"]
        elif task["semantic_checks"]:
            task["validation_modes"] = ["semantic_checks"]
    if task["task_type"] != "code" and task["tdd_mode"] == "required":
        task["tdd_mode"] = "not_applicable"
    if task["evaluator_required"] and task["independence_policy"] == "none":
        task["independence_policy"] = "fresh_session_required"
    return task

for line in text:
    if re.match(r"^##\s+Implementation Plan\s*$", line):
        in_plan = True
        continue
    if in_plan and re.match(r"^##\s+", line):
        break
    if not in_plan:
        continue

    task_match = re.match(r"^### Task\s+(.+)$", line)
    if task_match:
        if current:
            if current_check:
                current["semantic_checks"].append(current_check)
                current_check = None
            tasks.append(finalize_task(current))
        raw = task_match.group(1).strip()
        parsed = re.match(r"^([^:-]+)\s*[-:]\s*(.+)$", raw)
        if parsed:
            task_id = parsed.group(1).strip()
            title = parsed.group(2).strip()
        else:
            task_id = raw
            title = raw
        current = default_task(task_id, title)
        in_semantic_checks = False
        continue

    if not current:
        continue

    if in_semantic_checks:
        if not line.strip():
            continue
        if re.match(r"^### Task\s+", line) or any(line.startswith(prefix) for prefix in KNOWN_FIELDS if prefix != "Semantic checks:"):
            if current_check:
                current["semantic_checks"].append(current_check)
                current_check = None
            in_semantic_checks = False
        else:
            item_match = re.match(r"^\s*-\s*([A-Za-z0-9_]+):\s*(.+?)\s*$", line)
            if item_match:
                if current_check:
                    current["semantic_checks"].append(current_check)
                current_check = {item_match.group(1): normalize_scalar(item_match.group(2))}
                continue
            attr_match = re.match(r"^\s+([A-Za-z0-9_]+):\s*(.+?)\s*$", line)
            if attr_match and current_check is not None:
                current_check[attr_match.group(1)] = normalize_scalar(attr_match.group(2))
                continue

    files = re.match(r"^Files:\s*(.+)$", line)
    if files:
        current["files"] = parse_list(files.group(1).strip())
        continue

    done_when = re.match(r"^Done when:\s*(.+)$", line)
    if done_when:
        current["done_when"] = done_when.group(1).strip()
        continue

    depends_on = re.match(r"^Depends on:\s*(.+)$", line, re.IGNORECASE)
    if depends_on:
        current["depends_on"] = parse_dependencies(depends_on.group(1).strip())
        continue

    evaluator = re.match(r"^Evaluator review:\s*(.+)$", line, re.IGNORECASE)
    if evaluator:
        current["evaluator_required"] = evaluator.group(1).strip().upper() in {"YES", "TRUE", "REQUIRED"}
        current["independence_policy"] = "fresh_session_required" if current["evaluator_required"] else "none"
        continue

    review_modes = re.match(r"^(Adversarial review|Adversarial reviews|Review modes):\s*(.+)$", line, re.IGNORECASE)
    if review_modes:
        current["adversarial_review_modes"] = parse_review_modes(review_modes.group(2).strip())
        continue

    task_type = re.match(r"^Task type:\s*(.+)$", line, re.IGNORECASE)
    if task_type:
        current["task_type"] = normalize_task_type(task_type.group(1))
        continue

    validation_mode = re.match(r"^Validation modes?:\s*(.+)$", line, re.IGNORECASE)
    if validation_mode:
        current["validation_modes"] = parse_validation_modes(validation_mode.group(1))
        current["validation_mode_declared"] = True
        continue

    tdd_mode = re.match(r"^TDD:\s*(.+)$", line, re.IGNORECASE)
    if tdd_mode:
        current["tdd_mode"] = normalize_tdd(tdd_mode.group(1))
        continue

    independence_policy = re.match(r"^Independence policy:\s*(.+)$", line, re.IGNORECASE)
    if independence_policy:
        current["independence_policy"] = normalize_independence_policy(independence_policy.group(1), current["evaluator_required"])
        continue

    semantic_checks = re.match(r"^Semantic checks:\s*$", line, re.IGNORECASE)
    if semantic_checks:
        in_semantic_checks = True
        current_check = None
        continue

if current:
    if current_check:
        current["semantic_checks"].append(current_check)
    tasks.append(finalize_task(current))

print(json.dumps(tasks))
PY
}

hook_state_sync() {
  local requested_spec="${1:-}"
  local state_file
  state_file="$(hook_state_file)"
  local summary_file
  summary_file="$(hook_state_summary_file)"

  hook_state_ensure_dir

  local spec="$requested_spec"
  if [ -z "$spec" ]; then
    spec="$(hook_state_infer_active_spec)"
  fi

  if [ -z "$spec" ] || [ ! -f "$spec" ]; then
    return 1
  fi

  local tasks_json
  tasks_json="$(hook_state_tasks_from_spec "$spec")"
  local generator_session
  generator_session="$(hook_state_current_session_id)"

  "$HOOK_PYTHON_BIN" - "$state_file" "$summary_file" "$spec" "$(hook_state_feature_name_from_spec "$spec")" "$(hook_state_now)" "$tasks_json" "$generator_session" <<'PY'
import json
import os
import sys

state_path, summary_path, spec_path, feature_name, now, tasks_json, generator_session = sys.argv[1:8]

try:
    tasks = json.loads(tasks_json)
except Exception:
    tasks = []

existing = {}
if os.path.exists(state_path):
    try:
        with open(state_path, encoding="utf-8") as handle:
            existing = json.load(handle)
    except Exception:
        existing = {}

def default_tdd(mode="required"):
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

def default_evaluator(required=False, policy="none"):
    return {
        "status": "pending" if required else "not_required",
        "verdict": "pending" if required else "not_required",
        "review_mode": "fresh_session" if required else "none",
        "independence_policy": policy if required else "none",
        "packet_id": None,
        "packet_path": None,
        "launch_recorded_at": None,
        "generator_session": generator_session,
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

def default_manual_ack(required=False):
    return {
        "required": required,
        "acknowledged": False,
        "acknowledged_at": None,
        "acknowledged_by": None,
        "note": "",
    }

def default_semantic_summary(required=False):
    return {
        "required": required,
        "status": "pending" if required else "not_required",
        "checks": [],
        "evaluated_at": None,
        "failing_count": 0,
    }

def merge_with_defaults(previous, defaults):
    merged = {}
    for key, value in defaults.items():
        incoming = previous.get(key) if isinstance(previous, dict) else None
        merged[key] = value if incoming is None else incoming
    return merged

def infer_review_modes(task):
    explicit = task.get("adversarial_review_modes") or []
    if explicit:
        return explicit
    if not task.get("evaluator_required"):
        return []

    modes = ["contract_adversary"]
    haystack = " ".join([task.get("title", ""), " ".join(task.get("files", []))]).lower()
    security_terms = ("auth", "authoriz", "permission", "role", "secret", "token", "credential", "payment", "billing", "pii", "tenant", "security")
    regression_terms = ("shared api", "shared-api", "integration", "migration", "schema", "database", "queue", "worker", "infra", "deploy", "cache", "latency", "performance", "query")
    token_terms = ("prompt", "context", "handoff", "token budget", "context window", "agent-state")
    if any(term in haystack for term in security_terms):
        modes.append("security_adversary")
    if any(term in haystack for term in regression_terms):
        modes.append("regression_adversary")
    if any(term in haystack for term in token_terms):
        modes.append("token_context_adversary")
    deduped = []
    for mode in modes:
        if mode not in deduped:
            deduped.append(mode)
    return deduped

def task_requires_semantic_checks(task):
    modes = task.get("validation_modes", [])
    return "semantic_checks" in modes or "artifact_exists" in modes

previous_tasks = {task.get("id"): task for task in existing.get("task_list_snapshot", [])}
merged_tasks = []
for task in tasks:
    previous = previous_tasks.get(task.get("id"), {})
    merged = dict(task)
    merged["status"] = previous.get("status", task.get("status", "not_started"))
    merged["notes"] = previous.get("notes", "")
    merged["last_updated_at"] = previous.get("last_updated_at")
    merged["files"] = task.get("files", [])
    merged["depends_on"] = task.get("depends_on", [])
    merged["adversarial_review_modes"] = infer_review_modes(task)
    merged["task_type"] = task.get("task_type", "code")
    merged["validation_modes"] = task.get("validation_modes", [])
    merged["validation_mode_declared"] = task.get("validation_mode_declared", False)
    merged["semantic_checks"] = task.get("semantic_checks", [])

    tdd_mode = task.get("tdd_mode", "required")
    previous_tdd = previous.get("tdd") or {}
    merged_tdd = merge_with_defaults(previous_tdd, default_tdd(tdd_mode))
    merged_tdd["mode"] = tdd_mode
    merged_tdd["red_required"] = tdd_mode == "required"
    merged["tdd"] = merged_tdd

    manual_ack_required = "manual_ack" in merged["validation_modes"]
    previous_manual_ack = previous.get("manual_ack") or {}
    merged_manual_ack = merge_with_defaults(previous_manual_ack, default_manual_ack(manual_ack_required))
    merged_manual_ack["required"] = manual_ack_required
    merged["manual_ack"] = merged_manual_ack

    semantic_required = task_requires_semantic_checks(merged)
    previous_semantic = previous.get("semantic_checks_summary") or {}
    merged_semantic = merge_with_defaults(previous_semantic, default_semantic_summary(semantic_required))
    merged_semantic["required"] = semantic_required
    if not semantic_required:
        merged_semantic = default_semantic_summary(False)
    merged["semantic_checks_summary"] = merged_semantic

    previous_evaluator = previous.get("evaluator") or {}
    policy = task.get("independence_policy", "none")
    merged_evaluator = merge_with_defaults(previous_evaluator, default_evaluator(bool(task.get("evaluator_required")), policy))
    merged_evaluator["independence_policy"] = policy if task.get("evaluator_required") else "none"
    merged_evaluator["generator_session"] = previous_evaluator.get("generator_session") or existing.get("generator_session") or generator_session
    if task.get("evaluator_required"):
        if merged_evaluator.get("status") == "not_required":
            merged_evaluator["status"] = "pending"
        if merged_evaluator.get("verdict") == "not_required":
            merged_evaluator["verdict"] = "pending"
        if not merged_evaluator.get("review_mode") or merged_evaluator.get("review_mode") == "none":
            merged_evaluator["review_mode"] = "fresh_session"
    else:
        merged_evaluator = default_evaluator(False, "none")
    merged["evaluator"] = merged_evaluator
    merged_tasks.append(merged)

previous_current_task_id = existing.get("current_task_id")
current_task_id = previous_current_task_id
if not any(task.get("id") == current_task_id for task in merged_tasks):
    current_task_id = None
    for task in merged_tasks:
        if task.get("status") != "complete":
            current_task_id = task.get("id")
            break

current_task = next((task for task in merged_tasks if task.get("id") == current_task_id), None)
current_tdd = (current_task or {}).get("tdd") or default_tdd()
current_evaluator = (current_task or {}).get("evaluator") or default_evaluator(False, "none")
current_semantic = (current_task or {}).get("semantic_checks_summary") or default_semantic_summary(False)
current_manual_ack = (current_task or {}).get("manual_ack") or default_manual_ack(False)

phase = existing.get("current_phase")
if current_task_id is None:
    phase = "planning"
elif previous_current_task_id != current_task_id or not phase or phase == "intent":
    if current_tdd.get("mode") != "required":
        phase = "validate"
    elif current_tdd.get("green_observed"):
        phase = "refactor"
    elif current_tdd.get("red_observed"):
        phase = "green"
    else:
        phase = "red"

tdd_evidence = default_tdd(current_tdd.get("mode", "required"))
for key in tdd_evidence:
    if key in current_tdd:
        tdd_evidence[key] = current_tdd.get(key)

evaluator_summary = default_evaluator(bool((current_task or {}).get("evaluator_required", False)), (current_task or {}).get("independence_policy", "none"))
for key in evaluator_summary:
    if key in current_evaluator and current_evaluator.get(key) is not None:
        evaluator_summary[key] = current_evaluator.get(key)

semantic_summary = default_semantic_summary(bool(current_semantic.get("required")))
for key in semantic_summary:
    if key in current_semantic and current_semantic.get(key) is not None:
        semantic_summary[key] = current_semantic.get(key)

manual_ack_summary = default_manual_ack(bool(current_manual_ack.get("required")))
for key in manual_ack_summary:
    if key in current_manual_ack and current_manual_ack.get(key) is not None:
        manual_ack_summary[key] = current_manual_ack.get(key)

state = {
    "schema_version": 5,
    "updated_at": now,
    "generator_session": existing.get("generator_session") or generator_session,
    "active_feature": feature_name,
    "active_spec": spec_path,
    "task_list_snapshot": merged_tasks,
    "current_task_id": current_task_id,
    "current_phase": phase,
    "task_type": (current_task or {}).get("task_type", "none"),
    "validation_modes": list((current_task or {}).get("validation_modes", [])),
    "last_test_command": existing.get("last_test_command"),
    "last_test_result": existing.get("last_test_result"),
    "last_test_recorded_at": existing.get("last_test_recorded_at"),
    "tdd_evidence": tdd_evidence,
    "semantic_checks": semantic_summary,
    "manual_ack": manual_ack_summary,
    "evaluator": {
        "required": bool((current_task or {}).get("evaluator_required", False)),
        "status": evaluator_summary.get("status"),
        "verdict": evaluator_summary.get("verdict"),
        "review_mode": evaluator_summary.get("review_mode"),
        "independence_policy": evaluator_summary.get("independence_policy"),
        "packet_id": evaluator_summary.get("packet_id"),
        "packet_path": evaluator_summary.get("packet_path"),
        "launch_recorded_at": evaluator_summary.get("launch_recorded_at"),
        "generator_session": evaluator_summary.get("generator_session"),
        "result_path": evaluator_summary.get("result_path"),
        "reviewed_at": evaluator_summary.get("reviewed_at"),
        "reviewer_session": evaluator_summary.get("reviewer_session"),
        "independence_verified": evaluator_summary.get("independence_verified", False),
        "quality_gate_passed": evaluator_summary.get("quality_gate_passed", False),
        "quality_issues": evaluator_summary.get("quality_issues", []),
        "applied_review_modes": evaluator_summary.get("applied_review_modes", []),
        "blocking_findings": evaluator_summary.get("blocking_findings", 0),
        "non_blocking_findings": evaluator_summary.get("non_blocking_findings", 0),
        "criteria_summary": evaluator_summary.get("criteria_summary", []),
        "residual_risks": evaluator_summary.get("residual_risks", []),
        "last_updated_at": evaluator_summary.get("last_updated_at"),
    },
    "adversarial_review_modes": list((current_task or {}).get("adversarial_review_modes", [])),
    "session_handoff": {
        "checkpoint_at": existing.get("session_handoff", {}).get("checkpoint_at"),
        "notes": existing.get("session_handoff", {}).get("notes", ""),
    },
}

summary = {
    "updated_at": now,
    "active_feature": state.get("active_feature"),
    "active_spec": state.get("active_spec"),
    "current_task_id": state.get("current_task_id"),
    "current_task_title": (current_task or {}).get("title"),
    "current_phase": state.get("current_phase"),
    "task_type": state.get("task_type"),
    "validation_modes": state.get("validation_modes", []),
    "last_test_result": state.get("last_test_result"),
    "semantic_checks": {
        "required": semantic_summary.get("required"),
        "status": semantic_summary.get("status"),
        "failing_count": semantic_summary.get("failing_count"),
    },
    "manual_ack": {
        "required": manual_ack_summary.get("required"),
        "acknowledged": manual_ack_summary.get("acknowledged"),
    },
    "evaluator": {
        "required": state["evaluator"]["required"],
        "status": state["evaluator"]["status"],
        "verdict": state["evaluator"]["verdict"],
        "independence_policy": state["evaluator"]["independence_policy"],
        "independence_verified": state["evaluator"]["independence_verified"],
        "quality_gate_passed": state["evaluator"]["quality_gate_passed"],
    },
    "adversarial_review_modes": state.get("adversarial_review_modes", []),
}

os.makedirs(os.path.dirname(state_path), exist_ok=True)
with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(state, handle, indent=2)
    handle.write("\n")
with open(summary_path, "w", encoding="utf-8") as handle:
    json.dump(summary, handle, indent=2)
    handle.write("\n")
PY
}

hook_state_get() {
  local jq_filter="$1"
  local state_file
  state_file="$(hook_state_file)"

  if [ ! -f "$state_file" ]; then
    return 1
  fi

  "$HOOK_PYTHON_BIN" - "$state_file" "$jq_filter" <<'PY'
import json
import sys

state_path, expression = sys.argv[1:3]

with open(state_path, encoding="utf-8") as handle:
    data = json.load(handle)

expr = expression
for marker in (" // empty", " // false", ' // "pending"', ' // "intent"', ' // "none"', " // 0", ' // []'):
    expr = expr.replace(marker, "")
expr = expr.strip()
if expr.startswith("."):
    expr = expr[1:]

value = data
for part in expr.split("."):
    if not part:
        continue
    if isinstance(value, dict):
        value = value.get(part)
    else:
        value = None
        break

if value is None:
    print("")
elif isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, (dict, list)):
    print(json.dumps(value))
else:
print(value)
PY
}

hook_state_record_test_result() {
  local command="$1"
  local result="$2"
  local state_file
  state_file="$(hook_state_file)"
  [ -f "$state_file" ] || return 0

  "$HOOK_PYTHON_BIN" - "$state_file" "$command" "$result" "$(hook_state_now)" <<'PY'
import json
import sys

state_path, command, result, now = sys.argv[1:5]
with open(state_path, encoding="utf-8") as handle:
    data = json.load(handle)

data["last_test_command"] = command
data["last_test_result"] = result
data["last_test_recorded_at"] = now
data["updated_at"] = now

with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
}

hook_state_update_current_task_tdd() {
  local patch_json="$1"
  local state_file
  state_file="$(hook_state_file)"
  [ -f "$state_file" ] || return 0

  "$HOOK_PYTHON_BIN" - "$state_file" "$patch_json" "$(hook_state_now)" <<'PY'
import json
import sys

state_path, patch_json, now = sys.argv[1:4]
with open(state_path, encoding="utf-8") as handle:
    data = json.load(handle)

try:
    patch = json.loads(patch_json)
except Exception:
    patch = {}

def default_tdd(mode="required"):
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

current_task_id = data.get("current_task_id")
task = next((item for item in data.get("task_list_snapshot", []) if item.get("id") == current_task_id), None)
if task is None:
    raise SystemExit(0)

task_tdd = task.get("tdd") or {}
mode = task_tdd.get("mode") or "required"
merged = default_tdd(mode)
for key in merged:
    if key in task_tdd:
        merged[key] = task_tdd.get(key)
for key, value in patch.items():
    if key in merged:
        merged[key] = value

merged["mode"] = merged.get("mode") or mode
merged["red_required"] = merged["mode"] == "required"
task["tdd"] = merged
task["last_updated_at"] = now
data["updated_at"] = now

if patch.get("phase"):
    data["current_phase"] = patch["phase"]

data["tdd_evidence"] = dict(merged)

with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
}

hook_state_get_active_task_tdd_field() {
  local field="$1"
  local state_file
  state_file="$(hook_state_file)"
  [ -f "$state_file" ] || return 1

  local value
  value="$("$HOOK_PYTHON_BIN" - "$state_file" "$field" <<'PY'
import json
import sys

state_path, field = sys.argv[1:3]
with open(state_path, encoding="utf-8") as handle:
    data = json.load(handle)

current_task_id = data.get("current_task_id")
task = next((task for task in data.get("task_list_snapshot", []) if task.get("id") == current_task_id), None)
tdd = (task or {}).get("tdd") or {}
value = tdd.get(field)
if value is None:
    print("")
elif isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
)"

  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    hook_state_default_tdd_field "$field"
  fi
}

hook_state_update_current_task_evaluator() {
  local patch_json="$1"
  local state_file
  state_file="$(hook_state_file)"
  [ -f "$state_file" ] || return 0

  "$HOOK_PYTHON_BIN" - "$state_file" "$patch_json" "$(hook_state_now)" <<'PY'
import json
import sys

state_path, patch_json, now = sys.argv[1:4]
with open(state_path, encoding="utf-8") as handle:
    data = json.load(handle)

try:
    patch = json.loads(patch_json)
except Exception:
    patch = {}

def default_evaluator(required=False, policy="none"):
    return {
        "status": "pending" if required else "not_required",
        "verdict": "pending" if required else "not_required",
        "review_mode": "fresh_session" if required else "none",
        "independence_policy": policy if required else "none",
        "packet_id": None,
        "packet_path": None,
        "launch_recorded_at": None,
        "generator_session": data.get("generator_session"),
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

current_task_id = data.get("current_task_id")
task = next((item for item in data.get("task_list_snapshot", []) if item.get("id") == current_task_id), None)
if task is None:
    raise SystemExit(0)

required = bool(task.get("evaluator_required"))
policy = task.get("independence_policy", "none")
task_evaluator = task.get("evaluator") or {}
merged = default_evaluator(required, policy)
for key in merged:
    if key in task_evaluator and task_evaluator.get(key) is not None:
        merged[key] = task_evaluator.get(key)
for key, value in patch.items():
    if key in merged:
        merged[key] = value

if not required:
    merged = default_evaluator(False, "none")

merged["last_updated_at"] = now if required else merged.get("last_updated_at")
task["evaluator"] = merged
task["last_updated_at"] = now
data["updated_at"] = now

summary = default_evaluator(required, policy)
for key in summary:
    if key in merged and merged.get(key) is not None:
        summary[key] = merged.get(key)

data["evaluator"] = {
    "required": required,
    **summary,
}

with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
}

hook_state_get_active_task_evaluator_field() {
  local field="$1"
  local state_file
  state_file="$(hook_state_file)"
  [ -f "$state_file" ] || return 1

  local required
  required="$(hook_state_get '.evaluator.required // false')"
  local value
  value="$("$HOOK_PYTHON_BIN" - "$state_file" "$field" <<'PY'
import json
import sys

state_path, field = sys.argv[1:3]
with open(state_path, encoding="utf-8") as handle:
    data = json.load(handle)

current_task_id = data.get("current_task_id")
task = next((task for task in data.get("task_list_snapshot", []) if task.get("id") == current_task_id), None)
evaluator = (task or {}).get("evaluator") or {}
value = evaluator.get(field)
if value is None:
    print("")
elif isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, (dict, list)):
    print(json.dumps(value))
else:
    print(value)
PY
)"

  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    hook_state_default_evaluator_field "$field" "$required"
  fi
}

hook_state_update_current_task_semantic_checks() {
  local patch_json="$1"
  local state_file
  state_file="$(hook_state_file)"
  [ -f "$state_file" ] || return 0

  "$HOOK_PYTHON_BIN" - "$state_file" "$patch_json" "$(hook_state_now)" <<'PY'
import json
import sys

state_path, patch_json, now = sys.argv[1:4]
with open(state_path, encoding="utf-8") as handle:
    data = json.load(handle)

try:
    patch = json.loads(patch_json)
except Exception:
    patch = {}

def default_summary(required=False):
    return {
        "required": required,
        "status": "pending" if required else "not_required",
        "checks": [],
        "evaluated_at": None,
        "failing_count": 0,
    }

current_task_id = data.get("current_task_id")
task = next((item for item in data.get("task_list_snapshot", []) if item.get("id") == current_task_id), None)
if task is None:
    raise SystemExit(0)

required = "semantic_checks" in task.get("validation_modes", []) or "artifact_exists" in task.get("validation_modes", [])
summary = default_summary(required)
previous = task.get("semantic_checks_summary") or {}
for key in summary:
    if key in previous and previous.get(key) is not None:
        summary[key] = previous.get(key)
for key, value in patch.items():
    if key in summary:
        summary[key] = value

summary["required"] = required
summary["evaluated_at"] = patch.get("evaluated_at", now if required else summary.get("evaluated_at"))
if not required:
    summary = default_summary(False)

task["semantic_checks_summary"] = summary
task["last_updated_at"] = now
data["semantic_checks"] = summary
data["updated_at"] = now

with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
}

hook_state_get_active_task_semantic_field() {
  local field="$1"
  local state_file
  state_file="$(hook_state_file)"
  [ -f "$state_file" ] || return 1

  local required
  required="$(hook_state_get '.semantic_checks.required // false')"
  local value
  value="$("$HOOK_PYTHON_BIN" - "$state_file" "$field" <<'PY'
import json
import sys

state_path, field = sys.argv[1:3]
with open(state_path, encoding="utf-8") as handle:
    data = json.load(handle)

current_task_id = data.get("current_task_id")
task = next((task for task in data.get("task_list_snapshot", []) if task.get("id") == current_task_id), None)
summary = (task or {}).get("semantic_checks_summary") or {}
value = summary.get(field)
if value is None:
    print("")
elif isinstance(value, bool):
    print("true" if value else "false")
elif isinstance(value, (dict, list)):
    print(json.dumps(value))
else:
    print(value)
PY
)"

  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    hook_state_default_semantic_field "$field" "$required"
  fi
}

hook_state_update_current_task_manual_ack() {
  local patch_json="$1"
  local state_file
  state_file="$(hook_state_file)"
  [ -f "$state_file" ] || return 0

  "$HOOK_PYTHON_BIN" - "$state_file" "$patch_json" "$(hook_state_now)" <<'PY'
import json
import sys

state_path, patch_json, now = sys.argv[1:4]
with open(state_path, encoding="utf-8") as handle:
    data = json.load(handle)

try:
    patch = json.loads(patch_json)
except Exception:
    patch = {}

def default_manual_ack(required=False):
    return {
        "required": required,
        "acknowledged": False,
        "acknowledged_at": None,
        "acknowledged_by": None,
        "note": "",
    }

current_task_id = data.get("current_task_id")
task = next((item for item in data.get("task_list_snapshot", []) if item.get("id") == current_task_id), None)
if task is None:
    raise SystemExit(0)

required = "manual_ack" in task.get("validation_modes", [])
ack = default_manual_ack(required)
previous = task.get("manual_ack") or {}
for key in ack:
    if key in previous and previous.get(key) is not None:
        ack[key] = previous.get(key)
for key, value in patch.items():
    if key in ack:
        ack[key] = value

ack["required"] = required
if ack.get("acknowledged") and not ack.get("acknowledged_at"):
    ack["acknowledged_at"] = now

task["manual_ack"] = ack
task["last_updated_at"] = now
data["manual_ack"] = ack
data["updated_at"] = now

with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
}

hook_state_get_active_task_manual_ack_field() {
  local field="$1"
  local state_file
  state_file="$(hook_state_file)"
  [ -f "$state_file" ] || return 1

  local value
  value="$("$HOOK_PYTHON_BIN" - "$state_file" "$field" <<'PY'
import json
import sys

state_path, field = sys.argv[1:3]
with open(state_path, encoding="utf-8") as handle:
    data = json.load(handle)

current_task_id = data.get("current_task_id")
task = next((task for task in data.get("task_list_snapshot", []) if task.get("id") == current_task_id), None)
ack = (task or {}).get("manual_ack") or {}
value = ack.get(field)
if value is None:
    print("")
elif isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
)"

  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    hook_state_default_manual_ack_field "$field"
  fi
}

hook_state_mark_handoff() {
  local note="$1"
  local state_file
  state_file="$(hook_state_file)"
  [ -f "$state_file" ] || return 0

  "$HOOK_PYTHON_BIN" - "$state_file" "$note" "$(hook_state_now)" <<'PY'
import json
import sys

state_path, note, now = sys.argv[1:4]
with open(state_path, encoding="utf-8") as handle:
    data = json.load(handle)

session_handoff = data.setdefault("session_handoff", {})
session_handoff["checkpoint_at"] = now
session_handoff["notes"] = note
data["updated_at"] = now

with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
    handle.write("\n")
PY
}

hook_state_current_task_title() {
  local state_file
  state_file="$(hook_state_file)"
  [ -f "$state_file" ] || return 0

  "$HOOK_PYTHON_BIN" - "$state_file" <<'PY'
import json
import sys

state_path = sys.argv[1]
with open(state_path, encoding="utf-8") as handle:
    data = json.load(handle)

current_task_id = data.get("current_task_id")
for task in data.get("task_list_snapshot", []):
    if task.get("id") == current_task_id:
        print(task.get("title", ""))
        raise SystemExit(0)

print("")
PY
}
