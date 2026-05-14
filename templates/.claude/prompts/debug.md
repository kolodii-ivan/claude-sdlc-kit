You are running in a GitHub Actions implement context (Debug phase).

## Your task

A verification step failed. The captured failure log is at `$FAILURE_LOG_PATH`.

1. Invoke the `superpowers:systematic-debugging` skill via the Skill tool.
2. Read the failure log and any relevant code.
3. Form a hypothesis. Write it to `/tmp/claude/hypothesis.md` (1–3 sentences). Update this file every time your hypothesis changes.
4. Apply a fix. Commit it using this exact commit convention:

   `fix: <Subject> | GH-${ISSUE_NUMBER} #time <minutes>m`

5. Exit.

## Constraints

- One commit per debug invocation. The workflow re-runs verification and re-invokes you if it still fails (capped — see workflow).
- Use standard shell tooling to navigate/inspect (git, npx, jest, playwright, node, find, grep, ls). Run the failing command locally to reproduce.
- **Never** run `git push` — the workflow handles all pushes.
- **Never** run `gh` commands — the workflow handles all PR/issue interactions.
- **Never** run `npm install`, `npm update`, `npm dedupe`, `npm audit fix`, or any command that writes to `package.json` / `package-lock.json`. Missing/extraneous deps are NOT the typical root cause of a verify failure — investigate the actual error first. If a real dependency change is truly required, exit without committing and the workflow will escalate.
- **Do NOT modify `package.json`, `package-lock.json`, `tsconfig.json`, or `eslint.config.*`** unless the failure log explicitly names one of those files as the broken source. Config files are stable infrastructure; the root cause of a test/typecheck failure is almost always in *application code*, not in build/test config.
- **Do NOT modify, delete, or stage files under `.claude/`** — that directory holds workflow runtime state (iteration counters, prompts, config) owned by the SDLC kit. Even if a `wip:` commit looks like junk, leave it alone.
- **Scope discipline:** make the minimum change that fixes the failure. Touch only the files implicated by the failure log. If you find yourself "also fixing" unrelated things, stop — those don't belong in this debug commit. If your change spans more than 2-3 files, you are probably over-correcting; reset and try a narrower fix.
- If you can't determine the root cause, write your best hypothesis to `/tmp/claude/hypothesis.md` and exit *without* committing. The workflow will surface your hypothesis in the stuck-comment so a human can pick up where you left off — that's a *valid outcome*, not a failure.

## Context supplied by workflow

- Failure log: `$FAILURE_LOG_PATH`
- Issue number: `$ISSUE_NUMBER`
- Branch: `$BRANCH_NAME`
