import { test } from "node:test";
import { strict as assert } from "node:assert";
import { readManifest, writeManifest, MANIFEST_PATH } from "../src/lib/manifest.js";
import { mkdtempSync, rmSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("readManifest returns null when no manifest exists", () => {
  const dir = mkdtempSync(join(tmpdir(), "mfst-"));
  try {
    assert.equal(readManifest(dir), null);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("writeManifest then readManifest roundtrips", () => {
  const dir = mkdtempSync(join(tmpdir(), "mfst-"));
  try {
    const data = {
      version: "1.0.0",
      installed_at: "2026-05-13T14:22:00Z",
      kit_repo: "kolodii-ivan/claude-sdlc-kit",
      pin: "v1",
      files: { ".claude/prompts/plan.md": "sha256:abc" },
    };
    writeManifest(dir, data);
    assert.ok(existsSync(join(dir, MANIFEST_PATH)));
    const got = readManifest(dir);
    assert.deepEqual(got, data);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("writeManifest creates parent directories", () => {
  const dir = mkdtempSync(join(tmpdir(), "mfst-"));
  try {
    writeManifest(dir, { version: "1.0.0", files: {} });
    assert.ok(existsSync(join(dir, ".claude")));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
