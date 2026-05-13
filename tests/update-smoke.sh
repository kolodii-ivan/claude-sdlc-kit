#!/usr/bin/env bash
#
# Smoke test for the update command:
#   1. Install
#   2. Modify a prompt
#   3. update — verify modified file is skipped, others refreshed
#   4. update --force — verify modified file is overwritten

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLI="$KIT_DIR/packages/cli/bin/cli.js"

PASS=0; FAIL=0
pass() { PASS=$((PASS + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  \033[31m✗\033[0m %s\n' "$1"; }

TMP="$(mktemp -d -t sdlc-update.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

(cd "$TMP" && git init -q && git config user.email t@e.l && git config user.name t)

echo "── Install ──"
(cd "$TMP" && node "$CLI" install --pin v0.0.0-dev --issue-prefix LP --bot-email smoke@e.l --bot-name s </dev/null) > /dev/null
[ -f "$TMP/.claude/prompts/plan.md" ] && pass "installed" || fail "install missing files"

echo ""
echo "── Modify a prompt ──"
echo "# my custom guidance" >> "$TMP/.claude/prompts/plan.md"
pass "appended to plan.md"

echo ""
echo "── update (no --force) ──"
UPDATE_OUT="$(cd "$TMP" && node "$CLI" update 2>&1)"
echo "$UPDATE_OUT" | grep -q "skipped (modified locally): .claude/prompts/plan.md" \
  && pass "skipped modified prompt" \
  || fail "didn't skip modified prompt; got: $UPDATE_OUT"
grep -q "my custom guidance" "$TMP/.claude/prompts/plan.md" \
  && pass "modified file preserved" \
  || fail "modified file was overwritten"

echo ""
echo "── update --force ──"
FORCE_OUT="$(cd "$TMP" && node "$CLI" update --force 2>&1)"
echo "$FORCE_OUT" | grep -q "force-overwrote (was modified): .claude/prompts/plan.md" \
  && pass "force overwrote modified prompt" \
  || fail "didn't force-overwrite; got: $FORCE_OUT"
grep -q "my custom guidance" "$TMP/.claude/prompts/plan.md" \
  && fail "modified file was NOT overwritten" \
  || pass "modified file overwritten"

echo ""
echo "── Summary: PASS=$PASS FAIL=$FAIL ──"
[ "$FAIL" -eq 0 ]
