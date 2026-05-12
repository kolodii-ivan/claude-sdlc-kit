You are running in a GitHub Actions iterate context (Mode B — address review feedback).

## Your task

A reviewer applied the `$TRIGGER_CHANGES_LABEL` label to a PR. The workflow has fetched all unresolved review threads via GraphQL and saved them to `$REVIEW_THREADS_PATH` as a JSON array. Each element has shape:

```json
{
  "id": "PRRT_xxx",
  "isResolved": false,
  "path": "src/components/Foo.tsx",
  "line": 42,
  "comments": {
    "nodes": [
      {"body": "<comment text>", "author": {"login": "<reviewer>"}}
    ]
  }
}
```

1. **Invoke the `superpowers:receiving-code-review` skill via the Skill tool.** This is REQUIRED — it ensures you evaluate each thread on technical merit rather than blindly agreeing.
2. Read the threads file at `$REVIEW_THREADS_PATH`.
3. For each thread, decide one of:
   - **Apply fix**: edit the relevant file, commit per the convention below.
   - **Push back**: reply on the thread (via `gh pr review --body "<reply>"`) explaining why the suggestion is technically incorrect or doesn't apply. Cite specifics.
4. After all threads addressed, exit cleanly. Working tree must be clean.

## Commit convention

`fix: <Subject> | GH-${ISSUE_NUMBER} #time <minutes>m`

(Use `refactor` instead of `fix` when the change is non-behavioral cleanup.)

## Constraints

- Use whatever standard shell tooling you need to navigate and edit the codebase (git, npm, npx, jest, playwright, node, find, grep, ls, etc.).
- The only `gh` command you may run is `gh pr review` (for push-back replies). Do NOT run other `gh` commands — the workflow handles label removal and summary comment.
- **Never** run `git push` — the workflow handles all pushes.
- **Do NOT modify, delete, or stage files under `.claude/`** — that directory holds workflow runtime state (iteration counters, prompts, config) owned by the SDLC kit. Even if a `wip:` commit looks like junk, leave it alone.
- **Never** mark threads as resolved programmatically. Reviewers do that manually.
- If you cannot determine how to address a thread, push back with "Unsure how to address this — please clarify" rather than committing a guess.

## Context supplied by workflow

- Review threads: `$REVIEW_THREADS_PATH`
- Issue number: `$ISSUE_NUMBER`
- PR number: `$PR_NUMBER`
- Branch: `$BRANCH_NAME`
- Default branch: `$DEFAULT_BRANCH`
