import { test } from "node:test";
import { strict as assert } from "node:assert";
import { sha256OfFile, sha256OfString, KIT_MANAGED_PATHS } from "../src/lib/files.js";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("sha256OfString returns hex digest", () => {
  assert.equal(
    sha256OfString("hello"),
    "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
  );
});

test("sha256OfFile matches sha256OfString for same content", () => {
  const dir = mkdtempSync(join(tmpdir(), "files-test-"));
  try {
    const p = join(dir, "x.txt");
    writeFileSync(p, "hello");
    assert.equal(sha256OfFile(p), sha256OfString("hello"));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("KIT_MANAGED_PATHS lists exactly the consumer-side files", () => {
  assert.ok(KIT_MANAGED_PATHS.includes(".claude/prompts/brainstorm.md"));
  assert.ok(KIT_MANAGED_PATHS.includes(".claude/prompts/plan.md"));
  assert.ok(KIT_MANAGED_PATHS.includes(".claude/prompts/implement.md"));
  assert.ok(KIT_MANAGED_PATHS.includes(".claude/prompts/debug.md"));
  assert.ok(KIT_MANAGED_PATHS.includes(".claude/prompts/respond.md"));
  assert.ok(KIT_MANAGED_PATHS.includes(".claude/prompts/address-feedback.md"));
  assert.ok(KIT_MANAGED_PATHS.includes(".claude/ui-routes.json"));
  assert.ok(KIT_MANAGED_PATHS.includes("scripts/screenshot-routes.mjs"));
  assert.ok(KIT_MANAGED_PATHS.includes(".github/workflows/claude-brainstorm.yml"));
  assert.ok(KIT_MANAGED_PATHS.includes(".github/workflows/claude-implement.yml"));
  assert.ok(KIT_MANAGED_PATHS.includes(".github/workflows/claude-iterate.yml"));
  assert.ok(!KIT_MANAGED_PATHS.includes(".claude/config.yml")); // consumer-owned
});
