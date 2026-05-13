#!/usr/bin/env bash
#
# End-to-end smoke test for the kit CLI.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLI="$KIT_DIR/packages/cli/bin/cli.js"

PASS=0; FAIL=0; FAIL_LINES=()
pass() { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); FAIL_LINES+=("$1"); printf '  \033[31m✗\033[0m %s\n' "$1"; }
assert_file()       { [ -f "$1" ]                 && pass "exists: $1"            || fail "missing: $1"; }
assert_no_file()    { [ ! -f "$1" ]               && pass "absent: $1"            || fail "should be absent: $1"; }
assert_yaml()       { ruby -ryaml -e "YAML.load_file(ARGV[0])" "$1" 2>/dev/null && pass "valid YAML: $1" || fail "invalid YAML: $1"; }
assert_contains()   { grep -qF "$2" "$1" 2>/dev/null && pass "$1 contains: $2" || fail "$1 missing: $2"; }
assert_no_contains(){ grep -qF "$2" "$1" 2>/dev/null && fail "$1 should not contain: $2" || pass "$1 OK without: $2"; }

echo "── Preflight ──"
for cmd in git bash ruby node; do
  command -v "$cmd" >/dev/null && pass "tool: $cmd" || fail "missing tool: $cmd"
done
[ "$FAIL" -eq 0 ] || { echo "preflight failed"; exit 1; }

TMP="$(mktemp -d -t sdlc-smoke.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

echo ""
echo "── Setup scratch repo ──"
(cd "$TMP" && git init -q && git config user.email t@e.l && git config user.name t && printf 'node_modules\n' > .gitignore)
pass "tmp repo: $TMP"

echo ""
echo "── Run install ──"
(
  cd "$TMP"
  SDLC_KIT_BOT_EMAIL="smoke@example.com" \
  SDLC_KIT_BOT_NAME="smoke-bot" \
  node "$CLI" install \
    --pin "v0.0.0-dev" \
    --issue-prefix LP \
    --branch-prefix feature \
    --default-branch master \
    --preview-provider vercel </dev/null
) > "$TMP/install.log" 2>&1 \
  && pass "install exited 0" \
  || { fail "install failed — see $TMP/install.log"; cat "$TMP/install.log"; exit 1; }

cd "$TMP"

echo ""
echo "── Files present ──"
for f in \
  .github/workflows/claude-brainstorm.yml \
  .github/workflows/claude-implement.yml \
  .github/workflows/claude-iterate.yml \
  .claude/config.yml \
  .claude/ui-routes.json \
  .claude/.kit-manifest.json \
  .claude/prompts/brainstorm.md \
  .claude/prompts/plan.md \
  .claude/prompts/implement.md \
  .claude/prompts/debug.md \
  .claude/prompts/respond.md \
  .claude/prompts/address-feedback.md \
  scripts/screenshot-routes.mjs; do
  assert_file "$f"
done

# Composite actions must NOT be copied — they're referenced from the kit.
assert_no_file .github/actions/claude-sdlc-config/action.yml
assert_no_file .github/actions/preview-wait-vercel/action.yml

echo ""
echo "── YAML validity ──"
for f in .github/workflows/*.yml .claude/config.yml; do
  assert_yaml "$f"
done

echo ""
echo "── Stub pin substitution ──"
for f in .github/workflows/claude-brainstorm.yml \
         .github/workflows/claude-implement.yml \
         .github/workflows/claude-iterate.yml; do
  assert_contains "$f" "@v0.0.0-dev"
  assert_no_contains "$f" "__PIN__"
done

echo ""
echo "── Config substitution ──"
assert_contains .claude/config.yml "issue_prefix: LP"
assert_contains .claude/config.yml "default_branch: master"
assert_contains .claude/config.yml "provider: vercel"

echo ""
echo "── Manifest JSON shape ──"
node -e "
  const m = JSON.parse(require('fs').readFileSync('.claude/.kit-manifest.json','utf8'));
  if (m.kit_repo !== 'kolodii-ivan/claude-sdlc-kit') process.exit(1);
  if (m.pin !== 'v0.0.0-dev') process.exit(1);
  if (typeof m.files !== 'object') process.exit(1);
  if (!m.files['.claude/prompts/brainstorm.md']) process.exit(1);
  if (m.files['.claude/config.yml']) process.exit(1);
" && pass "manifest JSON structure" || fail "manifest JSON shape wrong"

echo ""
echo "── Summary ──"
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
[ "$FAIL" -eq 0 ] || { for l in "${FAIL_LINES[@]}"; do echo "  - $l"; done; exit 1; }
