import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

export function sha256OfString(s) {
  return createHash("sha256").update(s).digest("hex");
}

export function sha256OfFile(path) {
  return sha256OfString(readFileSync(path));
}

// Paths are relative to the consumer repo root. .claude/config.yml is
// intentionally absent — it's consumer-owned and never touched on update.
export const KIT_MANAGED_PATHS = [
  ".claude/prompts/brainstorm.md",
  ".claude/prompts/plan.md",
  ".claude/prompts/implement.md",
  ".claude/prompts/debug.md",
  ".claude/prompts/respond.md",
  ".claude/prompts/address-feedback.md",
  ".claude/ui-routes.json",
  "scripts/screenshot-routes.mjs",
  ".github/workflows/claude-brainstorm.yml",
  ".github/workflows/claude-implement.yml",
  ".github/workflows/claude-iterate.yml",
];
