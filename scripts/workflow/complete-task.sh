#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck disable=SC1091
. "$ROOT_DIR/scripts/hooks/common.sh"

cd "$ROOT_DIR"

bash "$ROOT_DIR/scripts/hooks/release-gate.sh" </dev/null
"${HOOK_PYTHON_BIN:-python}" "$SCRIPT_DIR/workflow-driver.py" complete-current
