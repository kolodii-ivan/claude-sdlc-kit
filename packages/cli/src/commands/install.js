import { parseArgs } from "node:util";
import { readFileSync, writeFileSync, mkdirSync, existsSync, appendFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join, dirname } from "node:path";
import { CONFIG_FIELDS, resolveConfig, promptInteractive } from "../lib/prompts.js";
import { KIT_MANAGED_PATHS, sha256OfString } from "../lib/files.js";
import { readManifest, writeManifest } from "../lib/manifest.js";
import { applyPin } from "../lib/stubs.js";
import { findTemplatesDir, repoRoot } from "../lib/target.js";
import { log } from "../lib/log.js";

const FLAG_OPTIONS = Object.fromEntries(
  CONFIG_FIELDS.map((f) => [f.flag, { type: "string" }])
);
FLAG_OPTIONS["pin"]  = { type: "string" };
FLAG_OPTIONS["help"] = { type: "boolean" };

const HELP = `Usage: claude-sdlc-kit install [options]

Installs kit templates into the current repo and writes .claude/.kit-manifest.json.

Options:
  --pin <ref>            Workflow pin (default: v1)
  --issue-prefix <s>     Issue prefix for commits (default: GH)
  --branch-prefix <s>    Branch prefix (default: feature)
  --default-branch <s>   Default branch (default: main)
  --preview-provider <s> Preview provider: vercel|none|netlify|github-pages (default: vercel)
  --bot-email <s>        Bot email used by workflow commits
  --bot-name <s>         Bot name used by workflow commits
  (also: --verify-typecheck/lint/unit-tests/e2e-tests, --e2e-needs-preview)

Every flag also accepts an SDLC_KIT_<UPPERCASE_NAME> env var (e.g. SDLC_KIT_ISSUE_PREFIX=LP).`;

export async function run(argv) {
  const { values: flags } = parseArgs({ args: argv, options: FLAG_OPTIONS, allowPositionals: false });
  if (flags.help) { console.log(HELP); return; }

  const root = repoRoot();

  if (readManifest(root)) {
    log.fail(".claude/.kit-manifest.json already exists — use `update` instead.");
    process.exit(1);
  }

  const config = await promptInteractive(
    resolveConfig({ flags, env: process.env }),
    process.stdin.isTTY && process.stdout.isTTY
  );

  const pin = flags.pin || "v1";
  const templatesDir = findTemplatesDir();
  log.info(`Templates: ${templatesDir}`);

  // 1) Write .claude/config.yml from template
  const tpl = readFileSync(join(templatesDir, ".claude/config.yml.template"), "utf8");
  const rendered = tpl.replaceAll("__ISSUE_PREFIX__", config.issue_prefix)
                      .replaceAll("__BRANCH_PREFIX__", config.branch_prefix)
                      .replaceAll("__DEFAULT_BRANCH__", config.default_branch)
                      .replaceAll("__VERIFY_TYPECHECK__", config.verify_typecheck)
                      .replaceAll("__VERIFY_LINT__", config.verify_lint)
                      .replaceAll("__VERIFY_UNIT_TESTS__", config.verify_unit_tests)
                      .replaceAll("__VERIFY_E2E_TESTS__", config.verify_e2e_tests)
                      .replaceAll("__E2E_NEEDS_PREVIEW__", config.e2e_needs_preview)
                      .replaceAll("__PREVIEW_PROVIDER__", config.preview_provider);
  const configPath = join(root, ".claude/config.yml");
  mkdirSync(dirname(configPath), { recursive: true });
  writeFileSync(configPath, rendered, "utf8");
  log.ok(`Wrote .claude/config.yml`);

  // 2) Copy kit-managed files and compute manifest
  const manifestFiles = {};
  for (const rel of KIT_MANAGED_PATHS) {
    const src = join(templatesDir, rel);
    const dst = join(root, rel);
    if (!existsSync(src)) {
      log.fail(`Template missing: ${rel}`);
      process.exit(1);
    }
    mkdirSync(dirname(dst), { recursive: true });
    let content = readFileSync(src);
    if (rel.startsWith(".github/workflows/")) {
      content = Buffer.from(applyPin(content.toString("utf8"), pin), "utf8");
    }
    writeFileSync(dst, content);
    manifestFiles[rel] = sha256OfString(content);
    log.ok(`Wrote ${rel}`);
  }

  // 3) Bot identity post-substitution in the reusable workflows is the kit's
  //    job — consumers don't see those workflow files. So nothing to do here
  //    beyond what's already in config.yml.

  // 4) Write manifest
  const here = dirname(fileURLToPath(import.meta.url));
  const pkgJsonPath = join(here, "../../package.json");
  const version = existsSync(pkgJsonPath)
    ? (JSON.parse(readFileSync(pkgJsonPath, "utf8")).version || "0.0.0")
    : "0.0.0";

  writeManifest(root, {
    version,
    installed_at: new Date().toISOString(),
    kit_repo: "kolodii-ivan/claude-sdlc-kit",
    pin,
    files: manifestFiles,
  });
  log.ok(`Wrote .claude/.kit-manifest.json`);

  // 5) Append .gitignore entries (best-effort)
  const gi = join(root, ".gitignore");
  if (existsSync(gi)) {
    const cur = readFileSync(gi, "utf8");
    for (const line of ["/test-results", "/playwright-report", "/.kit"]) {
      if (!cur.split("\n").includes(line)) {
        appendFileSync(gi, `\n${line}\n`);
        log.ok(`Appended ${line} to .gitignore`);
      }
    }
  }

  log.plain("");
  log.plain("Install complete. Next steps:");
  log.plain("  1. gh secret set CLAUDE_CODE_OAUTH_TOKEN");
  log.plain("  2. Settings → Actions → Workflow permissions: allow PR creation");
  log.plain("  3. git add .github .claude scripts .gitignore && git commit && git push");
}
