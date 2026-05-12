# Claude SDLC Kit

Three GitHub Actions workflows that automate the **issue → ready-for-review PR** pipeline using Claude (via `anthropics/claude-code-action@v1`) against your **Claude Max subscription** (or any compatible token).

```
GitHub issue (+ `needs-spec` label)
        ▼
  claude-brainstorm.yml — Claude asks clarifying questions → commits design spec
        ▼  (fires repository_dispatch: spec-ready)
  claude-implement.yml  — writes implementation plan → TDD commits → verify → open PR
                          → wait for preview → run e2e → screenshots → flip PR to ready
        ▼
  claude-iterate.yml    — handles `@claude <instruction>` PR comments (Mode A)
                          and `needs-changes` PR labels (Mode B)
```

## Quick start

```bash
cd /path/to/your/repo
curl -fsSL https://raw.githubusercontent.com/kolodii-ivan/land-lab/master/sdlc-kit/install.sh | bash
```

The installer:
1. Copies workflows, composite actions, prompts, and the screenshot script
2. Prompts for project-specific config (`issue_prefix`, verification commands, preview provider, bot identity)
3. Writes `.claude/config.yml`
4. Patches the bot identity in the workflow files
5. Adds `/test-results` and `/playwright-report` to `.gitignore`
6. Prints a checklist of repo secrets and settings you still need to configure

Run it again later to update workflow files (existing `.claude/config.yml` is preserved).

## What gets installed

```
.github/
  workflows/
    claude-brainstorm.yml      # issue → spec
    claude-implement.yml       # spec → PR
    claude-iterate.yml         # @claude / needs-changes → PR update
  actions/
    claude-sdlc-config/        # loads .claude/config.yml into job env
    preview-wait-vercel/       # polls Vercel deploy by SHA
    preview-wait-none/         # no-op (use when there's no preview platform)
    preview-wait-netlify/      # stub — implement against Netlify API if you use it
    preview-wait-github-pages/ # stub — implement against GitHub Deployments if you use it
.claude/
  config.yml                   # the ONLY file you should edit per project
  ui-routes.json               # routes the screenshot step captures (default: ["/"])
  prompts/
    brainstorm.md              # Claude-facing instruction sets, one per phase
    plan.md
    implement.md
    debug.md
    respond.md
    address-feedback.md
scripts/
  screenshot-routes.mjs        # Playwright-based screenshot capture
```

## Required setup (after install)

### 1. Repo secrets

```bash
gh secret set CLAUDE_CODE_OAUTH_TOKEN     # generate with `claude setup-token` locally
```

If `preview.provider: vercel` in your config:

```bash
gh secret set VERCEL_TOKEN                # https://vercel.com/account/tokens
gh secret set VERCEL_PROJECT_ID           # Vercel dashboard → project → Settings → General
gh secret set VERCEL_AUTOMATION_BYPASS_SECRET  # only if you have Vercel deployment protection
```

For projects that use Supabase (or any service that needs runtime env in CI):

```bash
gh secret set NEXT_PUBLIC_SUPABASE_URL
gh secret set NEXT_PUBLIC_SUPABASE_ANON_KEY
gh secret set SUPABASE_SERVICE_ROLE_KEY
```

(These flow into the workflow via the `env:` block in `claude-implement.yml` / `claude-iterate.yml`. If your project uses different env vars, edit those `env:` blocks — they're the one place that needs project-specific tweaks.)

### 2. Repo Actions settings

**Settings → Actions → General → Workflow permissions:**
- ☑ Allow GitHub Actions to create and approve pull requests

Or via CLI:

```bash
gh api -X PUT /repos/<owner>/<repo>/actions/permissions/workflow \
  -f default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=true
```

### 3. (Optional) Vercel preview env scope

If your project uses Vercel, double-check **Vercel → Settings → Environment Variables**: every secret your app needs at runtime must be enabled for the **Preview** scope, not just Production. Otherwise route handlers will 500 in CI when the e2e tests hit them.

## Using the kit

### File a new issue

```bash
gh issue create --title "Add /api/health endpoint" \
                --body "GET /api/health returns 200 with {ok: true}" \
                --label needs-spec
```

Within minutes:
- `claude-brainstorm.yml` posts a clarifying question (or commits a spec and fires `spec-ready`)
- If a spec was committed: `claude-implement.yml` writes a plan, drives TDD, opens a draft PR, waits for the Vercel preview, runs e2e, posts screenshots if UI changed, flips the PR to ready

### Reply to a clarifying question

Just comment in the issue. Claude re-reads the thread and either asks another question or converges.

### Tweak an existing PR

Comment `@claude <instruction>` on the PR. The iterate workflow applies the change, re-runs verification + e2e, posts a "Done" comment with the updated preview URL.

### Batch review feedback

Apply the `needs-changes` label to a PR with unresolved review threads. The iterate workflow fetches the threads via GraphQL, addresses each (fix commit or push-back reply), re-runs verification, removes the label.

### Opt out

Apply the `no-claude` label to any issue or PR you don't want the kit to touch.

## Configuration reference

Everything in `.claude/config.yml`:

```yaml
project:
  issue_prefix: GH                  # used in commit message format: "<type>: <Subject> | GH-<n> #time <m>m"
  branch_prefix: feature
  default_branch: main

verification:
  typecheck: "npm run typecheck"
  lint: "npm run lint"
  unit_tests: "npm test"
  e2e_tests: "npx playwright test"
  e2e_requires_preview: true        # if true and no preview is ready, escalate with needs-human

preview:
  provider: vercel                  # vercel | none | netlify | github-pages
  wait_timeout_min: 10

limits:
  max_iterations: 5                 # per branch, caps runaway loops
  wall_clock_hours: 2               # per workflow run
  stale_brainstorm_days: 7          # before closing an unanswered brainstorm
  brainstorm_max_invocations: 10

triggers:
  brainstorm_label: needs-spec
  changes_label: needs-changes
  skip_label: no-claude
  stuck_label: needs-human
```

## Preview providers

The kit ships four:

| Provider | Status | Required secrets |
|---|---|---|
| `vercel` | working | `VERCEL_TOKEN`, `VERCEL_PROJECT_ID` |
| `none` | working (no-op; falls back to localhost) | none |
| `netlify` | stub — needs you to fill in the polling logic | `NETLIFY_TOKEN`, `NETLIFY_SITE_ID` |
| `github-pages` | stub — needs you to fill in the polling logic | none |

To swap, edit `.github/workflows/claude-implement.yml` and `claude-iterate.yml` — find the `uses: ./.github/actions/preview-wait-vercel` line and change to the provider you want.

You can also replace that step entirely with custom bash — the contract is just `outputs.preview_url` (string) and `outputs.ready` (`true|false|skipped`).

## Optional: Playwright + Vercel deployment protection

If your Vercel project has Deployment Protection enabled, configure a Protection Bypass token (Vercel → Settings → Deployment Protection → Add) and set `VERCEL_AUTOMATION_BYPASS_SECRET` as a repo secret. Then your `playwright.config.ts` should inject the bypass header:

```ts
const baseURL = process.env.PLAYWRIGHT_TEST_BASE_URL ?? "http://localhost:3000";
const isPreview = baseURL.includes("vercel.app");
const bypassSecret = process.env.VERCEL_AUTOMATION_BYPASS_SECRET;

export default defineConfig({
  use: {
    baseURL,
    ...(isPreview && bypassSecret
      ? {
          extraHTTPHeaders: {
            "x-vercel-protection-bypass": bypassSecret,
            "x-vercel-set-bypass-cookie": "true",
          },
        }
      : {}),
  },
});
```

## Verifying the kit

Run the bundled test suite to verify everything is wired up correctly:

```bash
bash sdlc-kit/tests/run-all.sh
```

It runs two test scripts:

| Script | What it checks |
|---|---|
| `tests/smoke.sh` | Installs the kit into a throwaway tmp repo using `SDLC_KIT_LOCAL_SOURCE`, then asserts: every expected file is present, every YAML parses, every bash script passes `bash -n`, the JS file passes `node --check`, config template substitution worked (no leftover `__PLACEHOLDER__` tokens), bot identity was patched into all three workflows, and `.gitignore` was appended. |
| `tests/load-config-roundtrip.sh` | Feeds a representative `.claude/config.yml` into `load-config.sh` and asserts every documented key is exported to `GITHUB_ENV` with the expected value. Skips if `yq` is not installed. |

Requirements on the host: `bash`, `git`, `ruby` (for YAML parsing), `node` (for JSON + JS syntax checks). Optional: `yq` (for the load-config roundtrip).

The installer also supports two env vars that the smoke test relies on — they're useful if you ever want to install the kit from a local checkout:

```bash
SDLC_KIT_LOCAL_SOURCE=/path/to/sdlc-kit bash install.sh   # skip the git clone
SDLC_KIT_ISSUE_PREFIX=LP SDLC_KIT_PREVIEW_PROVIDER=none \
  bash install.sh                                          # non-interactive prompts
```

## Known gotchas

These bit us during development. The kit handles all of them, but if you're hacking on it:

1. The Claude action **scrubs runner git auth** at the local repo level. Re-bind via `http.<url>.extraheader` (the included `rebind-auth.sh` helper does this).
2. Multi-job workflows: **each job needs its own `permissions:` block**. The `gate` job has `pull-requests: read` precisely for this reason.
3. The Claude action **refuses bot-triggered workflows** by default. The kit sets `allowed_bots: "*"` so `repository_dispatch`-triggered runs work.
4. Per-command `Bash(...)` allowlists for `claude-code-action` are whack-a-mole. The kit uses unrestricted `Bash` and relies on prompt-level guidance for safety.
5. Claude will **delete `.claude/` runtime state files** (like iteration counters) unless prompts explicitly forbid it. The kit's prompts include this rule.
6. Filing `gh issue create --label needs-spec` fires **both `issues:opened` AND `issues:labeled`** events. The kit's brainstorm Finalize step is idempotent so the second run exits cleanly.
7. If your app has API routes that import heavy modules (Playwright, etc.) at top level: convert them to **dynamic imports after the auth check**. Otherwise unauth requests trigger the full module graph load → 500 instead of 401.

## License

Same as the source project. Use freely.
