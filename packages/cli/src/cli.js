import { parseArgs } from "node:util";

const COMMANDS = {
  install: () => import("./commands/install.js").then((m) => m.run),
  update:  () => import("./commands/update.js").then((m) => m.run),
  doctor:  () => import("./commands/doctor.js").then((m) => m.run),
  version: () => import("./commands/version.js").then((m) => m.run),
};

const USAGE = `Usage: claude-sdlc-kit <command> [options]

Commands:
  install   Install the kit into the current repo
  update    Refresh kit-managed files (SHA-tracked, preserves local edits)
  doctor    Diagnose the current install
  version   Print CLI and installed kit version

Run \`claude-sdlc-kit <command> --help\` for command-specific options.`;

export async function main(argv) {
  const [cmd, ...rest] = argv;
  if (!cmd || cmd === "--help" || cmd === "-h") {
    console.log(USAGE);
    return;
  }
  const loader = COMMANDS[cmd];
  if (!loader) {
    console.error(`Unknown command: ${cmd}\n`);
    console.error(USAGE);
    process.exit(2);
  }
  const run = await loader();
  await run(rest);
}
