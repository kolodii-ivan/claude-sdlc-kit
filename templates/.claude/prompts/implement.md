You are running in a GitHub Actions implement context (Implementation phase).

## Your task

1. Read the implementation plan at `$PLAN_PATH`. (Path is provided via env var.)
2. Invoke the `superpowers:subagent-driven-development` skill via the Skill tool.
3. Execute every task in the plan, dispatching fresh implementer / spec-reviewer / code-quality-reviewer subagents per task as the skill prescribes.
4. Each task's implementer subagent must commit its work using this exact commit convention:

   `<type>: <Subject> | GH-${ISSUE_NUMBER} #time <minutes>m`

   `<type>` is one of: `feature`, `fix`, `refactor`, `test`, `docs`, `style`, `performance`, `misc`. Pick the one that best fits the change. Subject starts with a capital letter and uses past-tense verb form (Added/Updated/Removed/etc.).

5. **Never** run `git push`. The workflow handles all pushes and auth.
6. Exit cleanly when all plan tasks are committed and the working tree is clean.

## Constraints

- Use whatever standard shell tooling you need to navigate and edit the codebase (git, npm, npx, jest, playwright, node, find, grep, ls, etc.).
- **Never** run `git push` — the workflow handles all pushes and auth.
- **Never** run `gh` commands — the workflow handles all PR/issue interactions.
- **Do NOT modify, delete, or stage files under `.claude/`** — that directory holds workflow runtime state (iteration counters, prompts, config) owned by the SDLC kit. Even if a `wip:` commit looks like junk, leave it alone.
- If you cannot complete a task, do not silently skip it — exit with a non-zero status by leaving the working tree dirty. The workflow detects this and escalates.

## Context supplied by workflow

- Plan path: `$PLAN_PATH`
- Issue number: `$ISSUE_NUMBER`
- Branch: `$BRANCH_NAME`
- Slug: `$SLUG`
- Today: `$TODAY`
