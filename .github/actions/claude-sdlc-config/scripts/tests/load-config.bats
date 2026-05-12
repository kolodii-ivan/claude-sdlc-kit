#!/usr/bin/env bats
#
# Tests for load-config.sh: parses .claude/config.yml and exports keys
# as GITHUB_ENV variables for downstream workflow steps.

SCRIPT="$BATS_TEST_DIRNAME/../load-config.sh"

setup() {
  TMPDIR_TEST="$(mktemp -d)"
  mkdir -p "$TMPDIR_TEST/.claude"
  cat > "$TMPDIR_TEST/.claude/config.yml" <<'EOF'
project:
  issue_prefix: GH
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
  export GITHUB_ENV="$TMPDIR_TEST/github_env"
  : > "$GITHUB_ENV"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

@test "exports ISSUE_PREFIX from project.issue_prefix" {
  cd "$TMPDIR_TEST"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -Fx 'ISSUE_PREFIX=GH' "$GITHUB_ENV"
}

@test "exports DEFAULT_BRANCH from project.default_branch" {
  cd "$TMPDIR_TEST"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -Fx 'DEFAULT_BRANCH=master' "$GITHUB_ENV"
}

@test "exports VERIFY_TYPECHECK preserving whitespace" {
  cd "$TMPDIR_TEST"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -Fx 'VERIFY_TYPECHECK=npm run typecheck' "$GITHUB_ENV"
}

@test "exports LIMIT_MAX_ITERATIONS as integer" {
  cd "$TMPDIR_TEST"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -Fx 'LIMIT_MAX_ITERATIONS=5' "$GITHUB_ENV"
}

@test "exports TRIGGER_BRAINSTORM_LABEL" {
  cd "$TMPDIR_TEST"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -Fx 'TRIGGER_BRAINSTORM_LABEL=needs-spec' "$GITHUB_ENV"
}

@test "fails with clear error when .claude/config.yml missing" {
  rm -rf "$TMPDIR_TEST/.claude"
  cd "$TMPDIR_TEST"
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *".claude/config.yml not found"* ]] || [[ "$output" == *".claude/config.yml not found"* ]]
}
