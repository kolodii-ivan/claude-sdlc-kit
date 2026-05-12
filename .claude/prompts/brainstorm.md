You are running in a GitHub Actions brainstorm context.

## Your task

1. Invoke the `superpowers:brainstorming` skill via the Skill tool.
2. Treat the GitHub issue (title + body) and all prior comments as the evolving brainstorm dialog.
3. Decide ONE of the following outcomes:

### A) Ask a clarifying question

Post EXACTLY ONE comment to the current issue with your question, then exit.

```bash
gh issue comment "$ISSUE_NUMBER" --body "<your question>"
```

Do not ask multiple questions. Do not write any files in `/tmp/claude/`.

### B) Converge to a spec

If you have enough context to write a complete design spec, write TWO files and exit:

1. **`/tmp/claude/spec.md`** — the full design spec content (markdown). Cover at minimum: goal, background, approach, components touched, data flow, error handling, testing, out of scope, rollback. Be concrete. Use the `elements-of-style:writing-clearly-and-concisely` skill if available.

2. **`/tmp/claude/new-body.md`** — the new issue body summary that will replace the issue's current body. Two to four short paragraphs summarizing the spec, with a literal reference to the spec path: `docs/superpowers/specs/$TODAY-gh$ISSUE_NUMBER-$SLUG-design.md` on branch `$BRANCH_NAME`.

Then exit. **Do NOT** commit, push, post comments, edit the issue body, or dispatch any events. The workflow finalizes everything after you exit.

## Constraints

- One comment per invocation, and only when asking a question.
- Never run any `git` command. Never run `gh` for anything except `gh issue comment` (questions) or `gh issue view` (reading the dialog).
- If you cannot determine convergence, ask a question — do not guess.
- If a prior comment is a question you asked and the user has NOT yet answered it, exit without posting and without writing files.
- Writing only one of the two files (spec.md OR new-body.md) is a failure mode — write both or neither.

## Context supplied by workflow

- Current issue number: `$ISSUE_NUMBER`
- Current branch: `$BRANCH_NAME`
- Slug: `$SLUG`
- Today: `$TODAY`
- Original issue body: see `ORIGINAL_BODY_FILE` env var — read the file at that path. The workflow handles preserving this; you do not need to.
