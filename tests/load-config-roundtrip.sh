#!/usr/bin/env bash
#
# Roundtrip test for .github/actions/claude-sdlc-config/scripts/load-config.sh.
#
# Writes a representative .claude/config.yml, runs load-config.sh against it,
# and asserts every documented key is exported to $GITHUB_ENV with the
# expected value.
#
# Usage: bash sdlc-kit/tests/load-config-roundtrip.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOAD_CONFIG="$KIT_DIR/.github/actions/claude-sdlc-config/scripts/load-config.sh"

PASS=0
FAIL=0
FAIL_LINES=()

pass() { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() {
  FAIL=$((FAIL + 1))
  FAIL_LINES+=("$1")
  printf '  \033[31m✗\033[0m %s\n' "$1"
}

if ! command -v yq >/dev/null 2>&1; then
  echo "SKIP: yq not installed — install with 'brew install yq' to run this test."
  exit 0
fi

if [ ! -f "$LOAD_CONFIG" ]; then
  echo "ERROR: $LOAD_CONFIG not found." >&2
  exit 1
fi

TMP="$(mktemp -d -t sdlc-loadcfg.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.claude"
cat > "$TMP/.claude/config.yml" <<'EOF'
project:
  issue_prefix: LP
  branch_prefix: feature
  default_branch: master

verification:
  typecheck: "npm run typecheck"
  lint: "npm run lint"
  unit_tests: "npm test"
  e2e_tests: "npx playwright test"
  e2e_requires_preview: true

preview:
  provider: vercel
  wait_timeout_min: 10

limits:
  max_iterations: 5
  wall_clock_hours: 2
  stale_brainstorm_days: 7
  brainstorm_max_invocations: 10

triggers:
  brainstorm_label: needs-spec
  changes_label: needs-changes
  skip_label: no-claude
  stuck_label: needs-human
EOF

GITHUB_ENV_FILE="$TMP/github_env"
: > "$GITHUB_ENV_FILE"

(
  cd "$TMP"
  GITHUB_ENV="$GITHUB_ENV_FILE" bash "$LOAD_CONFIG"
) >/dev/null

assert_kv() {
  local needle="$1"
  if grep -Fxq "$needle" "$GITHUB_ENV_FILE"; then
    pass "exported: $needle"
  else
    fail "missing export: $needle"
  fi
}

echo "── load-config.sh: GITHUB_ENV exports ──────────────────────────────────"

assert_kv "ISSUE_PREFIX=LP"
assert_kv "BRANCH_PREFIX=feature"
assert_kv "DEFAULT_BRANCH=master"
assert_kv "VERIFY_TYPECHECK=npm run typecheck"
assert_kv "VERIFY_LINT=npm run lint"
assert_kv "VERIFY_UNIT_TESTS=npm test"
assert_kv "VERIFY_E2E_TESTS=npx playwright test"
assert_kv "VERIFY_E2E_NEEDS_PREVIEW=true"
assert_kv "PREVIEW_PROVIDER=vercel"
assert_kv "PREVIEW_WAIT_TIMEOUT=10"
assert_kv "LIMIT_MAX_ITERATIONS=5"
assert_kv "LIMIT_WALL_CLOCK_HOURS=2"
assert_kv "LIMIT_STALE_DAYS=7"
assert_kv "LIMIT_BRAINSTORM_MAX=10"
assert_kv "TRIGGER_BRAINSTORM_LABEL=needs-spec"
assert_kv "TRIGGER_CHANGES_LABEL=needs-changes"
assert_kv "TRIGGER_SKIP_LABEL=no-claude"
assert_kv "TRIGGER_STUCK_LABEL=needs-human"

# ---- missing-config error path ---------------------------------------------

echo ""
echo "── load-config.sh: error on missing config ─────────────────────────────"
TMP2="$(mktemp -d -t sdlc-loadcfg-nope.XXXXXX)"
trap 'rm -rf "$TMP" "$TMP2"' EXIT

set +e
(
  cd "$TMP2"
  GITHUB_ENV="$TMP2/env" bash "$LOAD_CONFIG"
) >"$TMP2/out" 2>&1
status=$?
set -e

if [ "$status" -ne 0 ] && grep -qF ".claude/config.yml not found" "$TMP2/out"; then
  pass "exits non-zero with clear error when .claude/config.yml is missing"
else
  fail "missing-config error path broken (exit=$status, output: $(cat "$TMP2/out"))"
fi

# ---- summary ----------------------------------------------------------------

echo ""
echo "──────────────────────────────────────────────────────────────────────"
printf '  PASS: %d\n' "$PASS"
printf '  FAIL: %d\n' "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Failures:"
  for line in "${FAIL_LINES[@]}"; do
    printf '  - %s\n' "$line"
  done
  exit 1
fi

echo ""
echo "All load-config roundtrip checks passed."
