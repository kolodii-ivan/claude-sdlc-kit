# Claude SDLC Kit

GitHub Actions workflows + Claude that take a GitHub issue from **filed → spec → plan → TDD-implemented → ready-for-review PR**, with `@claude` PR-comment iteration baked in.

```
issue (+ `needs-spec` label)
  → claude-brainstorm  — Claude asks clarifying questions, commits a spec
  → claude-implement   — writes plan, drives TDD, opens draft PR, runs e2e, posts screenshots, flips to ready
  → claude-iterate     — handles `@claude <instruction>` PR comments + `needs-changes` PR labels
```

## Install

**As a Claude Code plugin (recommended):**

```bash
/plugin install kolodii-ivan/claude-sdlc-kit
/sdlc-install
```

**As an npm CLI:**

```bash
cd /path/to/your/repo
npx --yes @kolodii-ivan/claude-sdlc-kit install
```

Either route writes:
- 3 thin stub workflows in `.github/workflows/` that call the kit's reusable workflows
- Editable per-project files in `.claude/` (prompts, config, ui-routes)
- A screenshot helper in `scripts/`
- `.claude/.kit-manifest.json` so future `update` runs know what's safe to refresh

## Update

```bash
npx claude-sdlc-kit update         # safe — skips files you edited
npx claude-sdlc-kit update --force # overwrite local edits
npx claude-sdlc-kit doctor         # health check
```

## Repo secrets (one-time)

```bash
gh secret set CLAUDE_CODE_OAUTH_TOKEN     # claude setup-token
gh secret set VERCEL_TOKEN                # if preview.provider = vercel
gh secret set VERCEL_PROJECT_ID
gh secret set VERCEL_AUTOMATION_BYPASS_SECRET   # if Vercel deployment protection
```

**Settings → Actions → General → Workflow permissions:** "Allow GitHub Actions to create and approve pull requests".

## Versioning

- `@v1` rolling tag — latest stable v1.x (default pin).
- `@v1.2.3` immutable — pin tighter if you want zero auto-updates.
- `@beta` rolling — latest commit on `main`. Used internally for dogfooding; not recommended for production repos.

Breaking changes bump the major: `update --force` after editing your stubs to `@v2`.

## Configuration

`.claude/config.yml` is consumer-owned (never touched by `update`). Defaults:

```yaml
project:
  issue_prefix: GH
  branch_prefix: feature
  default_branch: main

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
```

## Tests

```bash
bash tests/run-all.sh
```

Runs: CLI unit tests + install smoke + update smoke + load-config roundtrip.

## License

MIT.
