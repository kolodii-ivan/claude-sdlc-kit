import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { readManifest } from "../lib/manifest.js";
import { repoRoot } from "../lib/target.js";
import { log } from "../lib/log.js";

export async function run() {
  const here = dirname(fileURLToPath(import.meta.url));
  const pkg = JSON.parse(readFileSync(join(here, "../../package.json"), "utf8"));
  const installed = readManifest(repoRoot());

  log.plain(`@kolodii-ivan/claude-sdlc-kit CLI:  ${pkg.version}`);
  log.plain(`Installed kit (in this repo):     ${installed?.version ?? "not installed"}`);
  if (installed) log.plain(`Pin:                              ${installed.pin}`);
}
