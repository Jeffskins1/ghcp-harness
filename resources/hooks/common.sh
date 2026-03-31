#!/usr/bin/env bash

HOOK_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_PYTHON_BIN="${HOOK_PYTHON_BIN:-$(command -v python3 || command -v python || command -v py.exe || command -v py || true)}"

hook_extract_json_string_by_keys() {
  local input="$1"
  shift
  local key
  for key in "$@"; do
    local value
    value="$(printf '%s' "$input" | sed -nE "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]*(\\\\.[^\"\\\\]*)*)\".*/\\1/p" | head -1)"
    if [ -n "$value" ]; then
      printf '%s\n' "$value" | sed 's/\\"/"/g; s/\\\\/\\/g'
      return
    fi
  done
}

hook_extract_json_number_by_keys() {
  local input="$1"
  shift
  local key
  for key in "$@"; do
    local value
    value="$(printf '%s' "$input" | sed -nE "s/.*\"${key}\"[[:space:]]*:[[:space:]]*([-0-9]+).*/\\1/p" | head -1)"
    if [ -n "$value" ]; then
      printf '%s\n' "$value"
      return
    fi
  done
}

hook_extract_json_bool_by_keys() {
  local input="$1"
  shift
  local key
  for key in "$@"; do
    local value
    value="$(printf '%s' "$input" | sed -nE "s/.*\"${key}\"[[:space:]]*:[[:space:]]*(true|false).*/\\1/p" | head -1)"
    if [ -n "$value" ]; then
      printf '%s\n' "$value"
      return
    fi
  done
}

hook_json_first_value() {
  local input="$1"
  shift

  local value
  value="$(hook_extract_json_string_by_keys "$input" "$@")"
  if [ -n "$value" ]; then
    printf '%s\n' "$value"
    return
  fi

  value="$(hook_extract_json_number_by_keys "$input" "$@")"
  if [ -n "$value" ]; then
    printf '%s\n' "$value"
    return
  fi

  value="$(hook_extract_json_bool_by_keys "$input" "$@")"
  if [ -n "$value" ]; then
    printf '%s\n' "$value"
    return
  fi

  if command -v jq >/dev/null 2>&1; then
    local jq_expr=""
    local separator=""
    local path
    for path in "$@"; do
      jq_expr="${jq_expr}${separator}${path}"
      separator=" // "
    done
    printf '%s' "$input" | jq -r "${jq_expr} // empty" 2>/dev/null
    return
  fi

  if [ -z "$HOOK_PYTHON_BIN" ]; then
    printf '\n'
    return
  fi

  HOOK_JSON_INPUT="$input" "$HOOK_PYTHON_BIN" - "$@" <<'PY'
import json
import os
import sys

raw = os.environ.get("HOOK_JSON_INPUT", "").strip()
if not raw:
    print("")
    raise SystemExit(0)

try:
    data = json.loads(raw)
except Exception:
    print("")
    raise SystemExit(0)

def walk(node, path):
    current = node
    for key in path.split("."):
        if isinstance(current, dict) and key in current:
            current = current[key]
        else:
            return None
    return current

for candidate in sys.argv[1:]:
    dotted = candidate.replace(". //", "").strip()
    dotted = dotted.strip(". ")
    if not dotted:
        continue
    value = walk(data, dotted)
    if value in (None, ""):
        continue
    if isinstance(value, bool):
        print("true" if value else "false")
    elif isinstance(value, (dict, list)):
        print(json.dumps(value))
    else:
        print(value)
    raise SystemExit(0)

print("")
PY
}

hook_project_dir() {
  local input="$1"
  local env_dir="${CLAUDE_PROJECT_DIR:-${CODEX_PROJECT_DIR:-${GITHUB_WORKSPACE:-}}}"

  if [ -n "$env_dir" ]; then
    printf '%s\n' "$env_dir"
    return
  fi

  local value
  value="$(hook_json_first_value "$input" "cwd" "root" "projectRoot")"
  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    printf '.\n'
  fi
}

hook_context_file() {
  if [ -f ".github/copilot-instructions.md" ]; then
    printf '%s\n' ".github/copilot-instructions.md"
  elif [ -f "AGENTS.md" ]; then
    printf '%s\n' "AGENTS.md"
  fi
}

hook_protected_paths_file() {
  if [ -f ".github/hooks/protected-paths.txt" ]; then
    printf '%s\n' ".github/hooks/protected-paths.txt"
  elif [ -f ".claude/protected-paths.txt" ]; then
    printf '%s\n' ".claude/protected-paths.txt"
  fi
}

hook_extract_prompt() {
  local input="$1"
  hook_json_first_value "$input" "prompt" "user_prompt" "text"
}

hook_extract_file_path() {
  local input="$1"
  hook_json_first_value "$input" "file_path" "path"
}

hook_extract_command() {
  local input="$1"
  hook_json_first_value "$input" "command" "cmd"
}

hook_extract_exit_code() {
  local input="$1"
  local value
  value="$(hook_json_first_value "$input" "exit_code")"
  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    printf '0\n'
  fi
}

hook_extract_output() {
  local input="$1"
  hook_json_first_value "$input" "output" "stdout"
}

hook_extract_transcript_path() {
  local input="$1"
  hook_json_first_value "$input" "transcript_path"
}

hook_extract_stop_active() {
  local input="$1"
  local value
  value="$(hook_json_first_value "$input" "stop_hook_active" "hook_active")"
  if [ -n "$value" ]; then
    printf '%s\n' "$value"
  else
    printf 'false\n'
  fi
}

hook_trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

hook_extract_test_command_from_section() {
  local file="$1"
  awk '
    BEGIN { in_section = 0 }
    /^##[[:space:]]+Exact Test Commands?[[:space:]]*$/ { in_section = 1; next }
    in_section && /^##[[:space:]]+/ { exit }
    in_section { print }
  ' "$file" 2>/dev/null | awk '
    {
      line = $0
      sub(/\r$/, "", line)
      if (line ~ /^[[:space:]]*$/) next
      if (line ~ /^[[:space:]]*#/) next

      lower = tolower(line)
      preferred = 0
      if (lower ~ /(full suite|default|exact test command)/) preferred = 1

      command = line
      sub(/^[[:space:]]*[-*][[:space:]]*/, "", command)
      sub(/^[[:space:]]*[A-Za-z0-9 _\/()-]+:[[:space:]]*/, "", command)

      had_backticks = 0
      if (match(command, /`[^`]+`/)) {
        command = substr(command, RSTART + 1, RLENGTH - 2)
        had_backticks = 1
      }

      gsub(/^[[:space:]]+|[[:space:]]+$/, "", command)

      if (had_backticks || command ~ /^(npm|yarn|pnpm|npx|\.\/gradlew|gradlew|mvn|pytest|python -m pytest|python3 -m pytest|py -m pytest|py -3 -m pytest|cargo|go test|rspec|bundle exec rspec|dotnet test|flutter test|mix test|phpunit|bash -lc|sh -lc|powershell -NoProfile -Command)([[:space:]].*)?$/) {
        if (preferred) {
          print command
          exit
        }
        if (fallback == "") {
          fallback = command
        }
      }
    }
    END {
      if (fallback != "") {
        print fallback
      }
    }
  '
}

hook_extract_test_command() {
  local file="$1"
  hook_extract_test_command_from_section "$file" | head -1 | xargs
}

hook_require_test_command() {
  local context_file
  context_file="$(hook_context_file)"

  if [ -z "$context_file" ] || [ ! -f "$context_file" ]; then
    return 1
  fi

  hook_extract_test_command "$context_file"
}

hook_is_test_command() {
  local command="$1"
  printf '%s' "$command" | grep -qiE \
    '(^|[[:space:]])(npm[[:space:]]+(run[[:space:]]+)?test|yarn[[:space:]]+test|pnpm[[:space:]]+(run[[:space:]]+)?test|npx[[:space:]]+(jest|vitest|mocha|ava)|pytest|python[[:space:]]+-m[[:space:]]+pytest|python3[[:space:]]+-m[[:space:]]+pytest|py([[:space:]]+-3)?[[:space:]]+-m[[:space:]]+pytest|go[[:space:]]+test|cargo[[:space:]]+test|rspec|bundle[[:space:]]+exec[[:space:]]+rspec|dotnet[[:space:]]+test|flutter[[:space:]]+test|phpunit|mvn([[:space:]].*)?[[:space:]]test|gradlew([[:space:]].*)?[[:space:]]test|\.\/gradlew([[:space:]].*)?[[:space:]]test|bash[[:space:]]+-lc|sh[[:space:]]+-lc|powershell[[:space:]]+-NoProfile[[:space:]]+-Command)'
}

if [ -f "$HOOK_COMMON_DIR/state.sh" ]; then
  # shellcheck disable=SC1091
  . "$HOOK_COMMON_DIR/state.sh"
fi

if [ -f "$HOOK_COMMON_DIR/tdd-state.sh" ]; then
  # shellcheck disable=SC1091
  . "$HOOK_COMMON_DIR/tdd-state.sh"
fi

if [ -f "$HOOK_COMMON_DIR/evaluator-state.sh" ]; then
  # shellcheck disable=SC1091
  . "$HOOK_COMMON_DIR/evaluator-state.sh"
fi
