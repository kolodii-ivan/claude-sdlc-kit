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
- Use whatever standard shell tooling you need to navigate and edit the codebase (git, npm, npx, jest, playwright, node, find, grep, ls, etc.).
- **Never** run `git push` — the workflow handles all pushes.
- **Never** run `gh` commands — the workflow handles all PR/issue interactions.
- **Do NOT modify, delete, or stage files under `.claude/`** — that directory holds workflow runtime state (iteration counters, prompts, config) owned by the SDLC kit. Even if a `wip:` commit looks like junk, leave it alone.
- If you can't determine the root cause, write your best hypothesis to `/tmp/claude/hypothesis.md` and exit *without* committing. The workflow will surface your hypothesis in the stuck-comment.

## Context supplied by workflow

- Failure log: `$FAILURE_LOG_PATH`
- Issue number: `$ISSUE_NUMBER`
- Branch: `$BRANCH_NAME`
