#!/usr/bin/env bash
#
# Run every SDLC kit test and print a combined summary.
#
# Usage: bash sdlc-kit/tests/run-all.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TESTS=(
  "$SCRIPT_DIR/smoke.sh"
  "$SCRIPT_DIR/load-config-roundtrip.sh"
)

OVERALL_FAIL=0

for t in "${TESTS[@]}"; do
  echo ""
  echo "════════════════════════════════════════════════════════════════════════"
  echo "▶ $(basename "$t")"
  echo "════════════════════════════════════════════════════════════════════════"
  if bash "$t"; then
    echo "→ $(basename "$t"): OK"
  else
    echo "→ $(basename "$t"): FAILED"
    OVERALL_FAIL=$((OVERALL_FAIL + 1))
  fi
done

echo ""
echo "════════════════════════════════════════════════════════════════════════"
if [ "$OVERALL_FAIL" -eq 0 ]; then
  echo "All test suites passed."
  exit 0
else
  echo "$OVERALL_FAIL test suite(s) failed."
  exit 1
fi
