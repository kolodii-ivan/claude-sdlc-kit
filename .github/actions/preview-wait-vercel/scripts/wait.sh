#!/usr/bin/env bash
#
# Poll Vercel deployments API until the deployment for $COMMIT_SHA reaches state=READY.
# Required env: VERCEL_TOKEN, VERCEL_PROJECT_ID, COMMIT_SHA, TIMEOUT_MIN
# Outputs (via $GITHUB_OUTPUT): preview_url, ready

set -euo pipefail

if [ -z "${VERCEL_TOKEN:-}" ] || [ -z "${VERCEL_PROJECT_ID:-}" ]; then
  echo "Missing VERCEL_TOKEN or VERCEL_PROJECT_ID secret." >&2
  echo "preview_url=" >> "$GITHUB_OUTPUT"
  echo "ready=false" >> "$GITHUB_OUTPUT"
  exit 1
fi

DEADLINE=$(( $(date +%s) + TIMEOUT_MIN * 60 ))
POLL_INTERVAL=30

while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  RESPONSE=$(curl -sS -H "Authorization: Bearer $VERCEL_TOKEN" \
    "https://api.vercel.com/v6/deployments?projectId=${VERCEL_PROJECT_ID}&limit=20")

  STATE=$(printf '%s' "$RESPONSE" \
    | jq -r --arg sha "$COMMIT_SHA" \
        '.deployments[] | select(.meta.githubCommitSha == $sha) | .readyState' \
    | head -n1)
  URL=$(printf '%s' "$RESPONSE" \
    | jq -r --arg sha "$COMMIT_SHA" \
        '.deployments[] | select(.meta.githubCommitSha == $sha) | .url' \
    | head -n1)

  echo "Vercel state for $COMMIT_SHA: ${STATE:-not-found}"

  if [ "$STATE" = "READY" ]; then
    echo "preview_url=https://${URL}" >> "$GITHUB_OUTPUT"
    echo "ready=true" >> "$GITHUB_OUTPUT"
    exit 0
  fi

  if [ "$STATE" = "ERROR" ] || [ "$STATE" = "CANCELED" ]; then
    echo "Vercel deployment ended in non-success state: $STATE" >&2
    echo "preview_url=" >> "$GITHUB_OUTPUT"
    echo "ready=false" >> "$GITHUB_OUTPUT"
    exit 1
  fi

  sleep "$POLL_INTERVAL"
done

echo "Vercel preview did not reach READY within ${TIMEOUT_MIN} minutes." >&2
echo "preview_url=" >> "$GITHUB_OUTPUT"
echo "ready=false" >> "$GITHUB_OUTPUT"
exit 1
