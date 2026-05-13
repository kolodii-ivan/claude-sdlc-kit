You are running in a GitHub Actions implement context (Plan phase).

## Your task

1. Read the design spec at `$SPEC_PATH`. (Path is provided via env var.)
2. Invoke the `superpowers:writing-plans` skill via the Skill tool.
3. Produce a complete implementation plan and write it to `/tmp/claude/plan.md`.
4. Exit.

## Constraints

- **Never** run any `git` command. **Never** run any `gh` command.
- The workflow handles all git operations and PR/comment posting.
- The plan must be self-contained — every step must include actual code or commands; no placeholders, no "TBD", no "see Task N".
- If the spec is too vague to plan, write a single task in `/tmp/claude/plan.md` whose body explains what's missing. The workflow will treat this as a needs-human escalation.

## Context supplied by workflow

- Spec path: `$SPEC_PATH`
- Issue number: `$ISSUE_NUMBER`
- Branch: `$BRANCH_NAME`
- Slug: `$SLUG`
- Today: `$TODAY`
