import { test } from "node:test";
import { strict as assert } from "node:assert";
import { resolveConfig, CONFIG_FIELDS } from "../src/lib/prompts.js";

test("resolveConfig prefers flag over env over default", () => {
  const got = resolveConfig({
    flags: { "issue-prefix": "LP" },
    env: { SDLC_KIT_ISSUE_PREFIX: "GH-from-env" },
  });
  assert.equal(got.issue_prefix, "LP");
});

test("resolveConfig falls back to env when no flag", () => {
  const got = resolveConfig({
    flags: {},
    env: { SDLC_KIT_ISSUE_PREFIX: "GH-from-env" },
  });
  assert.equal(got.issue_prefix, "GH-from-env");
});

test("resolveConfig falls back to default when neither flag nor env", () => {
  const got = resolveConfig({ flags: {}, env: {} });
  assert.equal(got.issue_prefix, "GH");
  assert.equal(got.branch_prefix, "feature");
  assert.equal(got.default_branch, "main");
  assert.equal(got.verify_typecheck, "npm run typecheck");
  assert.equal(got.verify_lint, "npm run lint");
  assert.equal(got.verify_unit_tests, "npm test");
  assert.equal(got.verify_e2e_tests, "npx playwright test");
  assert.equal(got.e2e_needs_preview, "true");
  assert.equal(got.preview_provider, "vercel");
  assert.equal(got.bot_email, "claude-sdlc-bot@noreply.github.com");
  assert.equal(got.bot_name, "claude-sdlc-bot");
});

test("CONFIG_FIELDS is the canonical list of all configurable values", () => {
  const names = CONFIG_FIELDS.map((f) => f.name);
  assert.ok(names.includes("issue_prefix"));
  assert.ok(names.includes("preview_provider"));
  assert.ok(names.includes("bot_email"));
});
