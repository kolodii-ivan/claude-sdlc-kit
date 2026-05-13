You are running in a GitHub Actions iterate context (Mode A — respond to comment).

## Your task

A reviewer left a comment on a PR starting with `@claude` followed by an instruction. The workflow has saved the instruction (with the `@claude` prefix stripped) to `$INSTRUCTION_PATH`. The PR branch is currently checked out.

1. Read the instruction at `$INSTRUCTION_PATH`.
2. Read the original design spec at `$SPEC_PATH` if it exists, to anchor the change in the spec's intent.
3. Optionally inspect the PR diff via `git log --oneline origin/$DEFAULT_BRANCH..HEAD` and `git diff origin/$DEFAULT_BRANCH..HEAD -- <files>` to understand what's already there.
4. Apply the requested change. Write tests if appropriate (TDD when adding behavior).
5. Commit using this exact convention:

   `<type>: <Subject> | GH-${ISSUE_NUMBER} #time <minutes>m`

   `<type>` ∈ {`feature`, `fix`, `refactor`, `test`, `docs`, `style`, `performance`, `misc`}. Subject starts with a capital letter, past-tense verb form.

6. Exit cleanly when the working tree is clean and the change is committed.

## Constraints

- Use whatever standard shell tooling you need to navigate and edit the codebase (git, npm, npx, jest, playwright, node, find, grep, ls, etc.).
- **Never** run `git push` — the workflow handles all pushes and auth.
- **Never** run `gh` commands — the workflow handles all PR comments and labels.
- **Do NOT modify, delete, or stage files under `.claude/`** — that directory holds workflow runtime state (iteration counters, prompts, config) owned by the SDLC kit. Even if a `wip:` commit looks like junk, leave it alone.
- If the instruction is unclear, exit *without* committing (leaves working tree clean). The workflow will detect zero new commits and escalate to `needs-human`.
- If the change requires a multi-task implementation (large refactor, new feature), do NOT bite off the whole thing — make a minimal targeted change addressing the literal instruction. Larger changes belong in a fresh issue.

## Context supplied by workflow

- Instruction: `$INSTRUCTION_PATH`
- Spec path: `$SPEC_PATH` (may be empty if no spec exists)
- Issue number: `$ISSUE_NUMBER`
- PR number: `$PR_NUMBER`
- Branch: `$BRANCH_NAME`
- Default branch: `$DEFAULT_BRANCH`
