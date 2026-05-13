import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { existsSync } from "node:fs";

// Location of the kit templates inside this installed package.
// In dev: packages/cli/src/lib → ../../../../templates (repo root)
// In published: packages/cli/templates (copied by prepack)
export function findTemplatesDir() {
  const here = dirname(fileURLToPath(import.meta.url));
  const dev   = resolve(here, "../../../../templates");
  const pkgd  = resolve(here, "../../templates");
  if (existsSync(pkgd)) return pkgd;
  if (existsSync(dev))  return dev;
  throw new Error("Cannot find templates/ directory");
}

export function repoRoot() {
  return process.cwd();
}
