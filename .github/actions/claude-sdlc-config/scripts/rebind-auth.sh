#!/usr/bin/env bash
#
# Re-bind git auth after the Claude Code action scrubs it.
# Source this file in workflow steps that need to push.
# Requires: GH_TOKEN env var (workflow secret).

rebind_git_auth() {
  if [ -z "${GH_TOKEN:-}" ]; then
    echo "rebind_git_auth: GH_TOKEN is not set" >&2
    return 1
  fi
  local AUTH_HEADER
  AUTH_HEADER=$(printf 'x-access-token:%s' "$GH_TOKEN" | base64)
  git config --local --unset-all http.https://github.com/.extraheader 2>/dev/null || true
  git config --local http.https://github.com/.extraheader "AUTHORIZATION: basic $AUTH_HEADER"
}
