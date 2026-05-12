#!/usr/bin/env bash
#
# Smoke test for the Claude SDLC kit.
#
# Runs install.sh against the local working tree in a fresh tmp git repo, then
# asserts that every expected file is present, every YAML parses, every script
# is syntactically valid, config substitution worked, the bot identity was
# patched into all three workflows, and .gitignore was appended.
#
# Usage: bash sdlc-kit/tests/smoke.sh

set -euo pipefail

# ---- locate the kit ---------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---- result accounting ------------------------------------------------------

PASS=0
FAIL=0
FAIL_LINES=()

pass() {
  PASS=$((PASS + 1))
  printf '  \033[32m✓\033[0m %s\n' "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  FAIL_LINES+=("$1")
  printf '  \033[31m✗\033[0m %s\n' "$1"
}

assert_file() {
  if [ -f "$1" ]; then
    pass "exists: $1"
  else
    fail "missing: $1"
  fi
}

assert_dir() {
  if [ -d "$1" ]; then
    pass "exists: $1/"
  else
    fail "missing: $1/"
  fi
}

assert_yaml() {
  if ruby -ryaml -e "YAML.load_file(ARGV[0])" "$1" >/dev/null 2>&1; then
    pass "valid YAML: $1"
  else
    fail "invalid YAML: $1"
  fi
}

assert_bash_syntax() {
  if bash -n "$1" 2>/dev/null; then
    pass "valid bash: $1"
  else
    fail "syntax error: $1"
  fi
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local label="${3:-$needle}"
  if grep -qF "$needle" "$file" 2>/dev/null; then
    pass "$file contains: $label"
  else
    fail "$file missing: $label"
  fi
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  if grep -qF "$needle" "$file" 2>/dev/null; then
    fail "$file should NOT contain: $needle"
  else
    pass "$file does not contain: $needle"
  fi
}

# ---- preflight --------------------------------------------------------------

echo "── Preflight: required tools ───────────────────────────────────────────"
for cmd in git bash ruby node sed grep; do
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "tool available: $cmd"
  else
    fail "tool missing: $cmd"
  fi
done

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Preflight failed — install missing tools and retry."
  exit 1
fi

# ---- prepare scratch repo ---------------------------------------------------

echo ""
echo "── Setup: scratch repo ─────────────────────────────────────────────────"
TMP_REPO="$(mktemp -d -t sdlc-smoke.XXXXXX)"
trap 'rm -rf "$TMP_REPO"' EXIT

(
  cd "$TMP_REPO"
  git init -q
  git config user.email "smoke@test.local"
  git config user.name "smoke"
  printf 'node_modules\n' > .gitignore
)
pass "initialised tmp repo at $TMP_REPO"

# ---- run installer ----------------------------------------------------------

echo ""
echo "── Run installer ───────────────────────────────────────────────────────"
INSTALL_LOG="$TMP_REPO/install.log"

set +e
(
  cd "$TMP_REPO"
  SDLC_KIT_LOCAL_SOURCE="$KIT_DIR" \
  SDLC_KIT_ISSUE_PREFIX="LP" \
  SDLC_KIT_BRANCH_PREFIX="feature" \
  SDLC_KIT_DEFAULT_BRANCH="master" \
  SDLC_KIT_VERIFY_TYPECHECK="npm run typecheck" \
  SDLC_KIT_VERIFY_LINT="npm run lint" \
  SDLC_KIT_VERIFY_UNIT_TESTS="npm test" \
  SDLC_KIT_VERIFY_E2E_TESTS="npx playwright test" \
  SDLC_KIT_E2E_NEEDS_PREVIEW="true" \
  SDLC_KIT_PREVIEW_PROVIDER="vercel" \
  SDLC_KIT_BOT_EMAIL="smoke-bot@example.com" \
  SDLC_KIT_BOT_NAME="smoke-bot" \
  bash "$KIT_DIR/install.sh" </dev/null
) >"$INSTALL_LOG" 2>&1
INSTALL_STATUS=$?
set -e

if [ "$INSTALL_STATUS" -eq 0 ]; then
  pass "install.sh exited 0"
else
  fail "install.sh exited $INSTALL_STATUS — see $INSTALL_LOG"
  echo ""
  echo "── install.sh output ───────────────────────────────────────────────────"
  cat "$INSTALL_LOG"
  exit 1
fi

cd "$TMP_REPO"

# ---- assert: expected files exist -------------------------------------------

echo ""
echo "── Files: workflows, actions, prompts, scripts ─────────────────────────"

for f in \
  .github/workflows/claude-brainstorm.yml \
  .github/workflows/claude-implement.yml \
  .github/workflows/claude-iterate.yml \
  .github/actions/claude-sdlc-config/action.yml \
  .github/actions/claude-sdlc-config/scripts/load-config.sh \
  .github/actions/claude-sdlc-config/scripts/rebind-auth.sh \
  .github/actions/preview-wait-vercel/action.yml \
  .github/actions/preview-wait-vercel/scripts/wait.sh \
  .github/actions/preview-wait-none/action.yml \
  .github/actions/preview-wait-netlify/action.yml \
  .github/actions/preview-wait-github-pages/action.yml \
  .claude/config.yml \
  .claude/ui-routes.json \
  .claude/prompts/brainstorm.md \
  .claude/prompts/plan.md \
  .claude/prompts/implement.md \
  .claude/prompts/debug.md \
  .claude/prompts/respond.md \
  .claude/prompts/address-feedback.md \
  scripts/screenshot-routes.mjs
do
  assert_file "$f"
done

# ---- assert: YAML validity --------------------------------------------------

echo ""
echo "── YAML: workflows + composite actions parse ───────────────────────────"

while IFS= read -r -d '' f; do
  assert_yaml "$f"
done < <(find .github -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)

assert_yaml .claude/config.yml

# ---- assert: bash script syntax --------------------------------------------

echo ""
echo "── Bash: script syntax ─────────────────────────────────────────────────"

while IFS= read -r -d '' f; do
  assert_bash_syntax "$f"
done < <(find .github -type f -name '*.sh' -print0)

# ---- assert: JSON + JS validity --------------------------------------------

echo ""
echo "── Other: JSON + JS parse ──────────────────────────────────────────────"

if node -e "JSON.parse(require('fs').readFileSync('.claude/ui-routes.json','utf8'))" 2>/dev/null; then
  pass "valid JSON: .claude/ui-routes.json"
else
  fail "invalid JSON: .claude/ui-routes.json"
fi

if node --check scripts/screenshot-routes.mjs 2>/dev/null; then
  pass "valid JS:   scripts/screenshot-routes.mjs"
else
  fail "syntax error: scripts/screenshot-routes.mjs"
fi

# ---- assert: config substitution worked ------------------------------------

echo ""
echo "── Config: template substitution ───────────────────────────────────────"

CONFIG=.claude/config.yml
assert_not_contains "$CONFIG" "__ISSUE_PREFIX__"
assert_not_contains "$CONFIG" "__BRANCH_PREFIX__"
assert_not_contains "$CONFIG" "__DEFAULT_BRANCH__"
assert_not_contains "$CONFIG" "__VERIFY_TYPECHECK__"
assert_not_contains "$CONFIG" "__PREVIEW_PROVIDER__"

assert_contains "$CONFIG" "issue_prefix: LP"             "issue_prefix: LP"
assert_contains "$CONFIG" "branch_prefix: feature"       "branch_prefix: feature"
assert_contains "$CONFIG" "default_branch: master"       "default_branch: master"
assert_contains "$CONFIG" 'typecheck: "npm run typecheck"' 'typecheck command'
assert_contains "$CONFIG" "provider: vercel"             "preview.provider: vercel"
assert_contains "$CONFIG" "e2e_requires_preview: true"   "e2e_requires_preview: true"

# ---- assert: bot identity patched into workflows ---------------------------

echo ""
echo "── Bot identity: substituted in workflows ──────────────────────────────"

for wf in .github/workflows/claude-brainstorm.yml \
          .github/workflows/claude-implement.yml \
          .github/workflows/claude-iterate.yml; do
  assert_contains     "$wf" "smoke-bot@example.com" "bot email"
  assert_contains     "$wf" '"smoke-bot"'           "bot name"
  assert_not_contains "$wf" "pothuyjohn@gmail.com"
done

# ---- assert: gitignore appended --------------------------------------------

echo ""
echo "── .gitignore: appended ────────────────────────────────────────────────"

assert_contains .gitignore "/test-results"
assert_contains .gitignore "/playwright-report"

# ---- assert: workflows reference real composite actions --------------------

echo ""
echo "── Workflows: composite-action references resolve ──────────────────────"

while IFS= read -r ref; do
  rel="${ref#./}"
  if [ -f "${rel}/action.yml" ]; then
    pass "action exists: $rel"
  else
    fail "action missing: $rel (referenced from a workflow but no action.yml)"
  fi
done < <(grep -hRoE 'uses: \./\.github/actions/[A-Za-z0-9_-]+' .github/workflows/ \
         | awk '{print $2}' \
         | sort -u)

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
echo "All smoke checks passed."
