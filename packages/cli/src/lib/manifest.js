import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";

export const MANIFEST_PATH = ".claude/.kit-manifest.json";

export function readManifest(repoRoot) {
  const p = join(repoRoot, MANIFEST_PATH);
  if (!existsSync(p)) return null;
  return JSON.parse(readFileSync(p, "utf8"));
}

export function writeManifest(repoRoot, data) {
  const p = join(repoRoot, MANIFEST_PATH);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, JSON.stringify(data, null, 2) + "\n", "utf8");
}
