#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

OVERALL_FAIL=0

run_shell() {
  local name="$1"
  echo ""
  echo "════════════════════════════════════════════════════════════════════════"
  echo "▶ $name"
  echo "════════════════════════════════════════════════════════════════════════"
  if bash "$SCRIPT_DIR/$name"; then
    echo "→ $name: OK"
  else
    echo "→ $name: FAILED"
    OVERALL_FAIL=$((OVERALL_FAIL + 1))
  fi
}

run_node_tests() {
  echo ""
  echo "════════════════════════════════════════════════════════════════════════"
  echo "▶ CLI unit tests (node --test)"
  echo "════════════════════════════════════════════════════════════════════════"
  if (cd "$SCRIPT_DIR/../packages/cli" && node --test test/*.test.js); then
    echo "→ CLI unit tests: OK"
  else
    echo "→ CLI unit tests: FAILED"
    OVERALL_FAIL=$((OVERALL_FAIL + 1))
  fi
}

run_node_tests
run_shell smoke.sh
run_shell update-smoke.sh
run_shell load-config-roundtrip.sh

echo ""
echo "════════════════════════════════════════════════════════════════════════"
if [ "$OVERALL_FAIL" -eq 0 ]; then
  echo "All test suites passed."
  exit 0
else
  echo "$OVERALL_FAIL suite(s) failed."
  exit 1
fi
