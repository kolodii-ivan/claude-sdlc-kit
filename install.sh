#!/usr/bin/env bash
#
# Install the Claude SDLC kit into the current repo.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kolodii-ivan/land-lab/master/sdlc-kit/install.sh | bash
#   # or, after cloning the kit source:
#   bash sdlc-kit/install.sh
#
# What it does:
#   1. Copies workflows, composite actions, prompts, screenshot script
#   2. Prompts for per-project config; writes `.claude/config.yml`
#   3. Substitutes the bot git identity in the workflow files
#   4. Adds /test-results and /playwright-report to .gitignore (if not already)
#   5. Prints a checklist of secrets and repo settings the user must configure

set -euo pipefail

SOURCE_REPO="${SDLC_KIT_SOURCE_REPO:-kolodii-ivan/land-lab}"
SOURCE_BRANCH="${SDLC_KIT_SOURCE_BRANCH:-master}"

# ---- prelude ----------------------------------------------------------------

if [ ! -d ".git" ]; then
  echo "Error: not a git repo. Run install.sh from the root of the target project." >&2
  exit 1
fi

echo "Installing Claude SDLC kit from ${SOURCE_REPO}@${SOURCE_BRANCH}..."

# ---- fetch the kit -----------------------------------------------------------

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

if git rev-parse --git-dir >/dev/null 2>&1 && \
   git ls-remote --exit-code "https://github.com/${SOURCE_REPO}.git" "$SOURCE_BRANCH" >/dev/null 2>&1; then
  git clone --depth 1 --branch "$SOURCE_BRANCH" "https://github.com/${SOURCE_REPO}.git" "$WORKDIR/source" >/dev/null 2>&1
else
  echo "Error: cannot reach ${SOURCE_REPO}@${SOURCE_BRANCH}." >&2
  exit 1
fi

KIT_DIR="$WORKDIR/source/sdlc-kit"
if [ ! -d "$KIT_DIR" ]; then
  echo "Error: sdlc-kit/ not found in ${SOURCE_REPO}@${SOURCE_BRANCH}." >&2
  exit 1
fi

# ---- copy files --------------------------------------------------------------

copy_tree() {
  local src="$1"
  local dst="$2"
  mkdir -p "$dst"
  cp -R "$src/." "$dst/"
}

echo "  → Copying workflows + actions to .github/"
copy_tree "$KIT_DIR/.github" .github

echo "  → Copying prompts + ui-routes seed to .claude/"
mkdir -p .claude/prompts
cp -R "$KIT_DIR/.claude/prompts/." .claude/prompts/
if [ ! -f .claude/ui-routes.json ]; then
  cp "$KIT_DIR/.claude/ui-routes.json" .claude/ui-routes.json
fi

echo "  → Copying scripts/screenshot-routes.mjs"
mkdir -p scripts
cp "$KIT_DIR/scripts/screenshot-routes.mjs" scripts/

# ---- interactive config -----------------------------------------------------

if [ -f .claude/config.yml ]; then
  echo ""
  echo "  ⚠ .claude/config.yml already exists — skipping config prompt."
  echo "    Review it manually if you want to change values."
else
  echo ""
  echo "Configure the kit (press Enter to accept defaults):"

  prompt() {
    local label="$1"
    local default="$2"
    local var
    read -r -p "  $label [$default]: " var </dev/tty
    printf '%s' "${var:-$default}"
  }

  ISSUE_PREFIX=$(prompt "Issue prefix used in commit messages (GH, LP, etc.)" "GH")
  BRANCH_PREFIX=$(prompt "Branch prefix" "feature")
  DEFAULT_BRANCH=$(prompt "Default branch" "main")
  VERIFY_TYPECHECK=$(prompt "Typecheck command" "npm run typecheck")
  VERIFY_LINT=$(prompt "Lint command" "npm run lint")
  VERIFY_UNIT_TESTS=$(prompt "Unit test command" "npm test")
  VERIFY_E2E_TESTS=$(prompt "E2E test command" "npx playwright test")
  E2E_NEEDS_PREVIEW=$(prompt "Require a live preview before e2e? (true|false)" "true")
  PREVIEW_PROVIDER=$(prompt "Preview provider (vercel|none|netlify|github-pages)" "vercel")

  sed \
    -e "s|__ISSUE_PREFIX__|${ISSUE_PREFIX}|g" \
    -e "s|__BRANCH_PREFIX__|${BRANCH_PREFIX}|g" \
    -e "s|__DEFAULT_BRANCH__|${DEFAULT_BRANCH}|g" \
    -e "s|__VERIFY_TYPECHECK__|${VERIFY_TYPECHECK}|g" \
    -e "s|__VERIFY_LINT__|${VERIFY_LINT}|g" \
    -e "s|__VERIFY_UNIT_TESTS__|${VERIFY_UNIT_TESTS}|g" \
    -e "s|__VERIFY_E2E_TESTS__|${VERIFY_E2E_TESTS}|g" \
    -e "s|__E2E_NEEDS_PREVIEW__|${E2E_NEEDS_PREVIEW}|g" \
    -e "s|__PREVIEW_PROVIDER__|${PREVIEW_PROVIDER}|g" \
    "$KIT_DIR/.claude/config.yml.template" > .claude/config.yml
  echo "  ✓ Wrote .claude/config.yml"
fi

# ---- bot identity -----------------------------------------------------------

# Workflows ship with the kit author's hardcoded bot identity. Replace it with
# the installing repo's. The default is "Claude SDLC Bot" + the repo owner's
# noreply address; the user can override interactively.

REPO_REMOTE=$(git config --get remote.origin.url 2>/dev/null || true)
DEFAULT_BOT_EMAIL="claude-sdlc-bot@noreply.github.com"
DEFAULT_BOT_NAME="claude-sdlc-bot"

if [ -t 0 ] && [ -t 1 ]; then
  echo ""
  echo "Configure the bot identity used by the workflow to commit (press Enter to accept):"
  read -r -p "  Bot email [${DEFAULT_BOT_EMAIL}]: " BOT_EMAIL </dev/tty
  read -r -p "  Bot name [${DEFAULT_BOT_NAME}]: " BOT_NAME </dev/tty
fi
BOT_EMAIL="${BOT_EMAIL:-$DEFAULT_BOT_EMAIL}"
BOT_NAME="${BOT_NAME:-$DEFAULT_BOT_NAME}"

# Replace the hardcoded email/name in each workflow file (POSIX-portable sed).
for wf in .github/workflows/claude-brainstorm.yml \
          .github/workflows/claude-implement.yml \
          .github/workflows/claude-iterate.yml; do
  if [ -f "$wf" ]; then
    sed_inplace() {
      if sed --version >/dev/null 2>&1; then
        sed -i "$1" "$2"
      else
        sed -i '' "$1" "$2"
      fi
    }
    sed_inplace "s|pothuyjohn@gmail.com|${BOT_EMAIL}|g" "$wf"
    sed_inplace "s|\"claude-sdlc-bot\"|\"${BOT_NAME}\"|g" "$wf"
  fi
done
echo "  ✓ Set bot identity to ${BOT_NAME} <${BOT_EMAIL}> in workflows"

# ---- .gitignore -------------------------------------------------------------

if [ -f .gitignore ]; then
  for entry in "/test-results" "/playwright-report"; do
    if ! grep -qxF "$entry" .gitignore; then
      printf '\n%s\n' "$entry" >> .gitignore
      echo "  ✓ Appended $entry to .gitignore"
    fi
  done
fi

# ---- success message --------------------------------------------------------

cat <<'MSG'

────────────────────────────────────────────────────────────
Claude SDLC kit installed.

NEXT STEPS:

1) Set repo secrets (some are optional depending on your preview provider):

     gh secret set CLAUDE_CODE_OAUTH_TOKEN    # generate with `claude setup-token`
     gh secret set VERCEL_TOKEN               # if preview.provider = vercel
     gh secret set VERCEL_PROJECT_ID
     gh secret set VERCEL_AUTOMATION_BYPASS_SECRET  # if your Vercel preview has deployment protection

2) Repo settings → Actions → General → Workflow permissions:
     ☑ Allow GitHub Actions to create and approve pull requests

   Or via CLI:
     gh api -X PUT /repos/<owner>/<repo>/actions/permissions/workflow \
       -f default_workflow_permissions=write \
       -F can_approve_pull_request_reviews=true

3) Commit and push the kit files:

     git add .github .claude scripts .gitignore
     git commit -m "feat: install Claude SDLC kit"
     git push

4) Test the kit by filing an issue:

     gh issue create --title "Add /api/version endpoint" \
                     --body "GET /api/version returns {version: <pkg.json version>}" \
                     --label needs-spec

   Watch the brainstorm workflow converge, then implement runs automatically.

OPTIONAL TWEAKS:

  • Update .claude/ui-routes.json to add routes you want screenshotted on UI PRs
  • Review .claude/config.yml — every value is editable
  • If your project uses Next.js + Vercel + Supabase, see docs/claude-sdlc-setup.md
    in kolodii-ivan/land-lab for the env-var setup + Playwright bypass header pattern
────────────────────────────────────────────────────────────
MSG
