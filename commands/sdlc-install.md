---
description: Install the Claude SDLC kit into the current repo
---

You are about to install the Claude SDLC kit into the user's current repo.

Run this command (capture stdout/stderr and show it to the user):

```bash
npx --yes @kolodii-ivan/claude-sdlc-kit install $ARGUMENTS
```

If `npx` is not available, fall back to:

```bash
node $(npm root -g)/@kolodii-ivan/claude-sdlc-kit/bin/cli.js install $ARGUMENTS
```

After install completes, remind the user of the next steps the CLI printed (secret setup, repo permissions, git commit).
