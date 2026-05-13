import { parseArgs } from "node:util";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join, dirname } from "node:path";
import { KIT_MANAGED_PATHS, sha256OfFile, sha256OfString } from "../lib/files.js";
import { readManifest, writeManifest } from "../lib/manifest.js";
import { applyPin } from "../lib/stubs.js";
import { findTemplatesDir, repoRoot } from "../lib/target.js";
import { log } from "../lib/log.js";

const HELP = `Usage: claude-sdlc-kit update [options]

Refreshes kit-managed files. Files modified locally are skipped unless --force.

Options:
  --force      Overwrite locally-modified files (after listing them)
  --dry-run    Print what would change without writing
  --pin <ref>  Switch the workflow pin (e.g. v1 → v2)`;

export async function run(argv) {
  const { values: flags } = parseArgs({
    args: argv,
    options: {
      force:   { type: "boolean" },
      "dry-run": { type: "boolean" },
      pin:     { type: "string" },
      help:    { type: "boolean" },
    },
    allowPositionals: false,
  });
  if (flags.help) { console.log(HELP); return; }

  const root = repoRoot();
  const manifest = readManifest(root);
  if (!manifest) {
    log.fail("No .claude/.kit-manifest.json — run `install` first.");
    process.exit(1);
  }

  const templatesDir = findTemplatesDir();
  const newPin = flags.pin || manifest.pin || "v1";
  const here = dirname(fileURLToPath(import.meta.url));
  const pkgJsonPath = join(here, "../../package.json");
  const newVersion = existsSync(pkgJsonPath)
    ? (JSON.parse(readFileSync(pkgJsonPath, "utf8")).version || "0.0.0")
    : "0.0.0";
  const newFiles = {};
  let modifiedCount = 0;
  let replacedCount = 0;
  let unchangedCount = 0;

  for (const rel of KIT_MANAGED_PATHS) {
    const dst = join(root, rel);
    const src = join(templatesDir, rel);
    if (!existsSync(src)) {
      log.fail(`Template missing: ${rel}`);
      process.exit(1);
    }
    let newContent = readFileSync(src);
    if (rel.startsWith(".github/workflows/")) {
      newContent = Buffer.from(applyPin(newContent.toString("utf8"), newPin), "utf8");
    }
    const newSha = sha256OfString(newContent);
    const shippedSha = manifest.files[rel];
    const currentSha = existsSync(dst) ? sha256OfFile(dst) : null;

    if (currentSha === newSha) {
      unchangedCount++;
      newFiles[rel] = newSha;
      continue;
    }

    if (currentSha === shippedSha || currentSha === null) {
      if (flags["dry-run"]) {
        log.info(`would update: ${rel}`);
      } else {
        mkdirSync(dirname(dst), { recursive: true });
        writeFileSync(dst, newContent);
        log.ok(`updated: ${rel}`);
      }
      newFiles[rel] = newSha;
      replacedCount++;
    } else {
      // Diverged from what we shipped → user modified it.
      if (flags.force) {
        if (flags["dry-run"]) {
          log.warn(`would force-overwrite (modified): ${rel}`);
        } else {
          writeFileSync(dst, newContent);
          log.warn(`force-overwrote (was modified): ${rel}`);
        }
        newFiles[rel] = newSha;
        replacedCount++;
      } else {
        log.warn(`skipped (modified locally): ${rel}`);
        newFiles[rel] = shippedSha;
        modifiedCount++;
      }
    }
  }

  if (!flags["dry-run"]) {
    writeManifest(root, {
      ...manifest,
      version: newVersion,
      installed_at: new Date().toISOString(),
      pin: newPin,
      files: newFiles,
    });
  }

  log.plain("");
  log.plain(`Summary: ${replacedCount} updated, ${unchangedCount} unchanged, ${modifiedCount} skipped.`);
  if (modifiedCount > 0 && !flags.force) {
    log.plain("Use --force to overwrite locally-modified files.");
  }
}
