# Claude SDLC Kit

[![npm](https://img.shields.io/npm/v/@kolodii-ivan/claude-sdlc-kit?label=npm)](https://www.npmjs.com/package/@kolodii-ivan/claude-sdlc-kit)
[![GitHub Release](https://img.shields.io/github/v/tag/kolodii-ivan/claude-sdlc-kit?label=tag)](https://github.com/kolodii-ivan/claude-sdlc-kit/tags)

**Turn any GitHub issue into a ready-for-review pull request, automatically.**

Claude SDLC Kit is a drop-in automation layer for software repos: file a `needs-spec` issue, and within minutes the repo runs a full design → plan → TDD → preview → e2e → screenshots cycle and hands you back a ready-for-review PR. Mid-PR you can comment `@claude tighten that loop` or apply a `needs-changes` label and the same machinery keeps iterating until you merge.

The kit is what you get when you bundle the workflows from an opinionated solo project (this is the kit extracted from [`kolodii-ivan/land-lab`](https://github.com/kolodii-ivan/land-lab)) into something any repo can install in ~one command. It is decidedly **not** a no-code SaaS — it runs entirely in your GitHub Actions, against your code, with your Claude subscription.

### What you get

```
issue (+ `needs-spec` label)
  ▼
claude-brainstorm  — Claude asks clarifying questions, commits a design spec
  ▼  (fires repository_dispatch: spec-ready)
claude-implement   — writes plan → drives TDD → opens draft PR → waits for preview → runs e2e → posts screenshots → flips PR to ready
  ▼
claude-iterate     — handles `@claude <instruction>` PR comments (Mode A)
                     and `needs-changes` PR labels (Mode B)
```

The kit ships **three things from one source of truth**:

1. **Reusable GitHub Actions workflows** — three of them, called by thin (~16-line) consumer-side stubs. Updates to the workflow logic ship via a version-pin bump in those stubs, not by re-copying YAML.
2. **An npm CLI** (`@kolodii-ivan/claude-sdlc-kit`) — installs/updates per-project files (prompts, config, scripts) with SHA-tracked manifest so your local edits to prompts survive future updates.
3. **A Claude Code plugin** — wraps the CLI as four slash commands: `/sdlc-install`, `/sdlc-update`, `/sdlc-doctor`, `/sdlc-version`. Works inside any Claude Code session.

### Powered by `superpowers`

Under the hood, every Claude invocation in the workflows loads the [`anthropics/claude-plugins-official:superpowers`](https://github.com/anthropics/claude-plugins-official) plugin and invokes specific skills inside it:

| Phase                | Skills invoked                                                                                       |
|----------------------|------------------------------------------------------------------------------------------------------|
| Brainstorm           | `superpowers:brainstorming` (clarifying questions → design spec)                                     |
| Implement (planning) | `superpowers:writing-plans` (turns the spec into a bite-sized, TDD-shaped implementation plan)       |
| Implement (coding)   | `superpowers:executing-plans`, `superpowers:test-driven-development` (red → green → refactor cycle)  |
| Debug                | `superpowers:systematic-debugging` (hypothesis-driven repair when verify or e2e fails)               |
| Iterate              | `superpowers:test-driven-development`, `superpowers:systematic-debugging` (same skills, PR scope)    |

This means the discipline isn't living in the kit's prompts — it's living in a well-maintained, version-pinned upstream library. The kit just orchestrates GitHub Actions around it.

---

## Full flow example — from issue to merged PR

Here's exactly what happened during the kit's own dogfood verification (real timestamps, real artifacts, run on a private Next.js repo):

**T+0:00** — You file a single issue:

```bash
gh issue create --title "Add /api/sdlc-ping endpoint" \
                --body "GET /api/sdlc-ping returns {ok: true, kit: \"claude-sdlc-kit\", at: <ISO timestamp>}. API-only, no UI changes." \
                --label needs-spec
```

**T+0:08** — `claude-brainstorm.yml` fires (`issues:labeled` event, `needs-spec` label):

- Posts a comment: *"Starting brainstorm on branch `feature/gh-78-add-api-sdlc-ping-endpoint`. I'll ask questions here; reply in this thread."*
- Invokes Claude with `superpowers:brainstorming`
- Claude inspects the issue body, decides it has enough context (no clarifying questions needed)
- Writes `docs/superpowers/specs/2026-05-13-gh78-add-api-sdlc-ping-endpoint-design.md` (the design spec)
- Commits + pushes to the feature branch
- Posts: *"Spec ready. Auto-advancing to implementation."*
- Fires `repository_dispatch` event `spec-ready` carrying the issue number + branch + slug

**T+1:30** — `claude-implement.yml` picks up the dispatch:

- Checks out the feature branch
- Sparse-checks-out the kit itself into `.kit/` (needs the rebind script + composite actions)
- Configures git identity (`pothuyjohn@gmail.com` / `claude-sdlc-bot`)
- Enforces iteration cap (`LIMIT_MAX_ITERATIONS: 5`) by writing `.claude/implement-iterations` and bumping it
- **Claude #1** (planner): invokes `superpowers:writing-plans` against the spec → writes `docs/superpowers/plans/2026-05-13-gh78-add-api-sdlc-ping-endpoint-plan.md` with bite-sized task steps, then commits
- **Claude #2** (implementer): invokes `superpowers:executing-plans` + `superpowers:test-driven-development` against the plan → writes `__tests__/api/sdlc-ping.test.ts` (failing tests), then `src/app/api/sdlc-ping/route.ts` (implementation), runs the tests locally, commits
- Runs `verify-local` (typecheck + lint + unit tests) — passes
- Opens draft PR #79 *"feature: Add /api/sdlc-ping endpoint | GH-78"*

**T+9:00** — Waits for the Vercel preview deploy to reach READY, then runs e2e:

- `npx playwright test` against the preview URL
- **Attempt 1 fails:** the project's own multi-select-filter test had a stale assertion unrelated to this PR
- **Claude #3** (debugger): invokes `superpowers:systematic-debugging` against the failure log → identifies that the test asserted `|A ∪ B| == |A| + |B|` (wrong when A ∩ B ≠ ∅), rewrites the assertion as `|A ∪ B| ≥ max(|A|, |B|) and ≤ |A| + |B|`, commits
- Re-waits preview, re-runs e2e
- **Attempt 2 passes** — 68 playwright tests green
- Generates screenshots (no UI routes affected → step no-ops)
- **Flips PR #79 from draft to ready**, posts a green-checkmark comment

**T+15:30** — You eyeball the PR, hit *Squash and merge*. Done.

If at any point you wanted to redirect (e.g., *"actually return `version` instead of `at`"*), commenting `@claude rename "at" to "version" and reformat as semver` triggers `claude-iterate.yml`, which applies the change, re-runs verification, and updates the PR — without you needing to checkout the branch.

If the kit gets stuck (e.g., debug exhausted iteration cap), it labels the issue/PR `needs-human` and posts a structured comment with the failure log and the hypothesis Claude was working from. No silent failures, no untrackable state.

---

## Install

You need: **Node ≥ 18.17**, **git**, **GitHub repo with Actions enabled**, **`gh` CLI authenticated**, and a Claude Max subscription (or compatible token).

### Option A — Claude Code plugin (recommended)

```
/plugin marketplace add kolodii-ivan/claude-sdlc-kit
/plugin install claude-sdlc-kit@claude-sdlc-kit
/sdlc-install
```

After `/sdlc-install` prompts for project config, follow the printed "next steps" to set repo secrets and Actions permissions.

### Option B — npm CLI directly

```bash
cd /path/to/your/repo
npx --yes @kolodii-ivan/claude-sdlc-kit install
```

Or pre-seed all values via flags (non-interactive, CI-friendly):

```bash
npx --yes @kolodii-ivan/claude-sdlc-kit install \
  --pin v1 \
  --issue-prefix GH \
  --branch-prefix feature \
  --default-branch main \
  --preview-provider vercel \
  --bot-email "ci-bot@noreply.github.com" \
  --bot-name "ci-bot"
```

Every flag also accepts an `SDLC_KIT_<UPPERCASE_NAME>` env var (e.g. `SDLC_KIT_ISSUE_PREFIX=LP`).

### What gets written to your repo

```
.github/workflows/
  claude-brainstorm.yml      # ~16-line stub → calls kit's reusable brainstorm.yml
  claude-implement.yml       # ~16-line stub
  claude-iterate.yml         # ~16-line stub
.claude/
  config.yml                 # consumer-owned; never touched by `update`
  ui-routes.json             # routes captured by the screenshot step (default: ["/"])
  prompts/                   # 6 Claude-facing prompt files; refreshed on update
  .kit-manifest.json         # tool-managed; tracks shipped file SHAs
scripts/
  screenshot-routes.mjs      # Playwright-based UI screenshot helper
```

Composite actions (`claude-sdlc-config`, `preview-wait-*`) are **not copied** — the reusable workflows reference them by absolute path so a single source of truth stays upstream.

---

## Required setup (one-time per repo)

```bash
gh secret set CLAUDE_CODE_OAUTH_TOKEN          # claude setup-token

# If preview.provider: vercel
gh secret set VERCEL_TOKEN
gh secret set VERCEL_PROJECT_ID
gh secret set VERCEL_AUTOMATION_BYPASS_SECRET  # only if you have Vercel deployment protection

# If your app needs runtime env in CI (Supabase shown as example)
gh secret set NEXT_PUBLIC_SUPABASE_URL
gh secret set NEXT_PUBLIC_SUPABASE_ANON_KEY
gh secret set SUPABASE_SERVICE_ROLE_KEY
```

**Settings → Actions → General → Workflow permissions:** ✅ *"Allow GitHub Actions to create and approve pull requests"*.

Or via CLI:

```bash
gh api -X PUT /repos/<owner>/<repo>/actions/permissions/workflow \
  -f default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=true
```

---

## Update

```bash
npx claude-sdlc-kit update              # safe — replaces unmodified files, skips locally-edited ones
npx claude-sdlc-kit update --dry-run    # show what would change without writing
npx claude-sdlc-kit update --force      # overwrite locally-edited files (after listing them)
npx claude-sdlc-kit update --pin v2     # bump to a new major when ready
npx claude-sdlc-kit doctor              # check install health + drift
npx claude-sdlc-kit version             # print CLI + installed kit version
```

Or via slash commands: `/sdlc-update`, `/sdlc-doctor`, `/sdlc-version`.

**How `update` decides what to replace:** for each kit-managed file, it computes three SHAs — the SHA we shipped you last time (in the manifest), the file's current SHA on disk, and the SHA we'd ship now. If `current == shipped` we replace; if they diverge we skip and report so you can review. Use `--force` if you want to overwrite anyway.

---

## Versioning

| Tag             | Meaning                                                   | Recommended for       |
|-----------------|-----------------------------------------------------------|-----------------------|
| `@v1`           | Rolling — latest stable `v1.x.y`                          | **Default**           |
| `@v1.2.3`       | Immutable point release                                   | Stable production     |
| `@latest`       | Latest stable on any major (GitHub "Latest" flag)         | npm registry default  |
| `@beta`         | Rolling — latest commit on `main`                         | Dogfooding only       |

Major bumps require explicit migration. `doctor` warns when your pinned major and installed CLI major disagree.

npm dist-tags mirror these (`@kolodii-ivan/claude-sdlc-kit@latest` / `@beta`).

---

## Using it

### File a new issue

```bash
gh issue create --title "Add /api/health endpoint" \
                --body "GET /api/health returns 200 with {ok: true}" \
                --label needs-spec
```

Within minutes:
1. **Brainstorm** posts a clarifying question (or commits the spec straight away)
2. After the spec lands, **implement** writes a plan, drives TDD, opens a draft PR, waits for Vercel preview, runs e2e, posts screenshots if the UI changed, and flips the PR to ready
3. Comment `@claude <instruction>` on the PR at any time → **iterate** applies the change and re-runs verification
4. Apply the `needs-changes` label to a PR with unresolved review threads → **iterate** addresses each thread

### Opt out per-issue or per-PR

Apply the `no-claude` label to anything you want the kit to ignore.

---

## Configuration reference

Everything in `.claude/config.yml`:

```yaml
project:
  issue_prefix: GH               # used in commit message format: "<type>: <Subject> | GH-<n> #time <m>m"
  branch_prefix: feature
  default_branch: main

verification:
  typecheck: "npm run typecheck"
  lint: "npm run lint"
  unit_tests: "npm test"
  e2e_tests: "npx playwright test"
  e2e_requires_preview: true     # if true and no preview ready, escalate

preview:
  provider: vercel               # vercel | none | netlify | github-pages
  wait_timeout_min: 10

limits:
  max_iterations: 5              # per branch — caps runaway loops
  wall_clock_hours: 2            # per workflow run
  stale_brainstorm_days: 7       # before closing an unanswered brainstorm
  brainstorm_max_invocations: 10

triggers:
  brainstorm_label: needs-spec
  changes_label: needs-changes
  skip_label: no-claude
  stuck_label: needs-human
```

---

## Preview providers

| Provider       | Status            | Required secrets                                              |
|----------------|-------------------|---------------------------------------------------------------|
| `vercel`       | working           | `VERCEL_TOKEN`, `VERCEL_PROJECT_ID` (+ bypass secret if used) |
| `none`         | working (no-op)   | none — falls back to localhost                                 |
| `netlify`      | stub — see action | `NETLIFY_TOKEN`, `NETLIFY_SITE_ID`                            |
| `github-pages` | stub — see action | none                                                          |

To swap providers, edit the `preview-wait-*` action referenced inside the kit's `.github/workflows/implement.yml`/`iterate.yml` (they're absolute `uses:` refs against the kit repo, so consumers don't need to change anything per-repo).

---

## Optional: Vercel deployment protection

If your Vercel project has Deployment Protection on, set up a Protection Bypass token (Vercel → Settings → Deployment Protection → Add) and store it as `VERCEL_AUTOMATION_BYPASS_SECRET`. Then in your `playwright.config.ts`:

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

---

## Verifying the kit itself

```bash
bash tests/run-all.sh
```

Runs four suites: CLI unit tests (`node --test`), install smoke (mktemp repo + full assertion matrix), update smoke (modify a prompt, run update, confirm skip + `--force` behavior), and load-config roundtrip.

Tools required on the host: `bash`, `git`, `ruby` (for YAML parse), `node`. Optional: `yq` (the load-config test skips cleanly if absent).

---

## Known gotchas

These bit us during development. The kit handles all of them — listing them here in case you're hacking on it.

1. **`claude-code-action@v1` scrubs runner git auth** at the local repo level. The kit re-binds via `http.<url>.extraheader` after every Claude invocation.
2. **Multi-job workflows: every job needs its own `permissions:` block** — defaults inherit minimal scope.
3. **Stub workflows MUST declare top-level `permissions:`** or GitHub fails the called reusable workflow at startup (caller's GITHUB_TOKEN can't grant more than it has).
4. **`uses:` inside a reusable workflow resolves against the CALLER's checkout** — the kit's workflows therefore reference composite actions by absolute path (`kolodii-ivan/claude-sdlc-kit/.github/actions/...@v1`), not relative.
5. **The rebind helper script** is fetched alongside the consumer's checkout via a sparse side-checkout into `.kit/` — the installer adds `/.kit` to your `.gitignore` automatically.
6. **`claude-code-action` refuses bot-triggered workflows by default.** The kit sets `allowed_bots: "*"` so `repository_dispatch`-triggered runs work.
7. **Per-command `Bash(...)` allowlists for `claude-code-action`** are whack-a-mole. The kit uses unrestricted `Bash` and relies on prompt-level guidance.
8. **Claude will delete `.claude/` runtime state files** (iteration counters, etc.) unless prompts explicitly forbid it. The kit's prompts include that rule.
9. **Filing `gh issue create --label needs-spec`** fires both `issues:opened` AND `issues:labeled` events — brainstorm's finalize step is idempotent so the second run exits cleanly.
10. **API routes that import heavy modules** (Playwright, etc.) at top level should switch to dynamic imports after the auth check — otherwise unauth requests trigger the full module graph and return 500 instead of 401.

---

## Releasing (maintainer-only)

- Push to `main` → `release.yml` publishes `@beta` to npm and force-updates the `beta` git tag.
- Tag `v1.x.y` → publishes `1.x.y` to npm, sets it as `latest`, and force-updates the `v1` rolling tag.
- Requires `NPM_TOKEN` secret on the kit repo with publish permission for `@kolodii-ivan/*`.

See `CHANGELOG.md` for release history.

---

## License

MIT.
