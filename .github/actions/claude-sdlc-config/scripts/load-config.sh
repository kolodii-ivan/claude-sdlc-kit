#!/usr/bin/env bash
#
# Parses .claude/config.yml and exports its keys as variables to
# $GITHUB_ENV so downstream GitHub Actions workflow steps can read
# them directly via env.X references.

set -euo pipefail

CONFIG_FILE=".claude/config.yml"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: .claude/config.yml not found in $(pwd)" >&2
  exit 1
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq is required but not installed" >&2
  exit 1
fi

if [[ -z "${GITHUB_ENV:-}" ]]; then
  echo "ERROR: GITHUB_ENV is not set" >&2
  exit 1
fi

_export() {
  local _var_name="$1"
  local _yaml_path="$2"
  local _value

  _value="$(yq -r "$_yaml_path" "$CONFIG_FILE")"
  if [[ "$_value" == "null" ]]; then
    echo "ERROR: missing required config key $_yaml_path in $CONFIG_FILE" >&2
    exit 1
  fi

  echo "${_var_name}=${_value}" >> "$GITHUB_ENV"
}

_export ISSUE_PREFIX             '.project.issue_prefix'
_export BRANCH_PREFIX            '.project.branch_prefix'
_export DEFAULT_BRANCH           '.project.default_branch'

_export VERIFY_TYPECHECK         '.verification.typecheck'
_export VERIFY_LINT              '.verification.lint'
_export VERIFY_UNIT_TESTS        '.verification.unit_tests'
_export VERIFY_E2E_TESTS         '.verification.e2e_tests'
_export VERIFY_E2E_NEEDS_PREVIEW '.verification.e2e_requires_preview'

_export PREVIEW_PROVIDER         '.preview.provider'
_export PREVIEW_WAIT_TIMEOUT     '.preview.wait_timeout_min'

_export LIMIT_MAX_ITERATIONS     '.limits.max_iterations'
_export LIMIT_WALL_CLOCK_HOURS   '.limits.wall_clock_hours'
_export LIMIT_STALE_DAYS         '.limits.stale_brainstorm_days'
_export LIMIT_BRAINSTORM_MAX     '.limits.brainstorm_max_invocations'

_export TRIGGER_BRAINSTORM_LABEL '.triggers.brainstorm_label'
_export TRIGGER_CHANGES_LABEL    '.triggers.changes_label'
_export TRIGGER_SKIP_LABEL       '.triggers.skip_label'
_export TRIGGER_STUCK_LABEL      '.triggers.stuck_label'

echo "Loaded config from $CONFIG_FILE"
