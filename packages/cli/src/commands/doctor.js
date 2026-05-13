import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { KIT_MANAGED_PATHS, sha256OfFile } from "../lib/files.js";
import { readManifest } from "../lib/manifest.js";
import { repoRoot } from "../lib/target.js";
import { log } from "../lib/log.js";

function ghCheck() {
  // spawnSync (not exec) so no shell parses arguments — no injection surface.
  const auth = spawnSync("gh", ["auth", "status"], { stdio: "ignore" });
  if (auth.status !== 0) {
    log.info("gh not authenticated or not installed — skipping secret check");
    return;
  }
  const list = spawnSync("gh", ["secret", "list"], { encoding: "utf8" });
  if (list.status !== 0) {
    log.info("gh secret list failed — skipping secret check");
    return;
  }
  if (list.stdout.includes("CLAUDE_CODE_OAUTH_TOKEN")) {
    log.ok("repo secret: CLAUDE_CODE_OAUTH_TOKEN set");
  } else {
    log.warn("repo secret missing: CLAUDE_CODE_OAUTH_TOKEN (run `gh secret set`)");
  }
}

export async function run() {
  const root = repoRoot();
  const manifest = readManifest(root);

  if (!manifest) {
    log.fail("No .claude/.kit-manifest.json — not installed.");
    process.exit(1);
  }

  log.plain(`Kit version (installed): ${manifest.version}`);
  log.plain(`Pin: ${manifest.pin}`);
  log.plain(`Installed at: ${manifest.installed_at}`);
  log.plain("");

  let drift = 0;
  for (const rel of KIT_MANAGED_PATHS) {
    const p = join(root, rel);
    if (!existsSync(p)) {
      log.fail(`missing: ${rel}`);
      drift++;
      continue;
    }
    const cur = sha256OfFile(p);
    const shipped = manifest.files[rel];
    if (cur === shipped) {
      log.ok(`unchanged: ${rel}`);
    } else {
      log.warn(`modified: ${rel}`);
      drift++;
    }
  }

  if (existsSync(join(root, ".claude/config.yml"))) {
    log.ok(".claude/config.yml present");
  } else {
    log.fail(".claude/config.yml missing");
    drift++;
  }

  ghCheck();

  log.plain("");
  log.plain(drift === 0 ? "All checks passed." : `${drift} issue(s) found.`);
  process.exit(drift === 0 ? 0 : 1);
}
