import { test } from "node:test";
import { strict as assert } from "node:assert";
import { applyPin, extractPin, STUB_PATHS } from "../src/lib/stubs.js";

test("applyPin replaces __PIN__ token", () => {
  const tpl = `uses: kolodii-ivan/claude-sdlc-kit/.github/workflows/brainstorm.yml@__PIN__`;
  assert.equal(
    applyPin(tpl, "v1"),
    `uses: kolodii-ivan/claude-sdlc-kit/.github/workflows/brainstorm.yml@v1`
  );
});

test("applyPin replaces every occurrence", () => {
  const tpl = `@__PIN__ then @__PIN__ again`;
  assert.equal(applyPin(tpl, "v1.2.3"), "@v1.2.3 then @v1.2.3 again");
});

test("extractPin reads the pin currently in a stub", () => {
  const stub = `name: x
on: { issues: { types: [opened] } }
jobs:
  brainstorm:
    uses: kolodii-ivan/claude-sdlc-kit/.github/workflows/brainstorm.yml@v1.2.3
    secrets: inherit`;
  assert.equal(extractPin(stub), "v1.2.3");
});

test("extractPin returns null when no kit reference present", () => {
  assert.equal(extractPin("name: x\non: push\njobs: {}"), null);
});

test("STUB_PATHS lists all three stub workflows", () => {
  assert.deepEqual(STUB_PATHS, [
    ".github/workflows/claude-brainstorm.yml",
    ".github/workflows/claude-implement.yml",
    ".github/workflows/claude-iterate.yml",
  ]);
});
