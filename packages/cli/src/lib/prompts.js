import { createInterface } from "node:readline/promises";

export const CONFIG_FIELDS = [
  { name: "issue_prefix",      flag: "issue-prefix",      env: "SDLC_KIT_ISSUE_PREFIX",      label: "Issue prefix used in commit messages (GH, LP, etc.)", default: "GH" },
  { name: "branch_prefix",     flag: "branch-prefix",     env: "SDLC_KIT_BRANCH_PREFIX",     label: "Branch prefix",                                          default: "feature" },
  { name: "default_branch",    flag: "default-branch",    env: "SDLC_KIT_DEFAULT_BRANCH",    label: "Default branch",                                         default: "main" },
  { name: "verify_typecheck",  flag: "verify-typecheck",  env: "SDLC_KIT_VERIFY_TYPECHECK",  label: "Typecheck command",                                      default: "npm run typecheck" },
  { name: "verify_lint",       flag: "verify-lint",       env: "SDLC_KIT_VERIFY_LINT",       label: "Lint command",                                           default: "npm run lint" },
  { name: "verify_unit_tests", flag: "verify-unit-tests", env: "SDLC_KIT_VERIFY_UNIT_TESTS", label: "Unit test command",                                      default: "npm test" },
  { name: "verify_e2e_tests",  flag: "verify-e2e-tests",  env: "SDLC_KIT_VERIFY_E2E_TESTS",  label: "E2E test command",                                       default: "npx playwright test" },
  { name: "e2e_needs_preview", flag: "e2e-needs-preview", env: "SDLC_KIT_E2E_NEEDS_PREVIEW", label: "Require a live preview before e2e? (true|false)",        default: "true" },
  { name: "preview_provider",  flag: "preview-provider",  env: "SDLC_KIT_PREVIEW_PROVIDER",  label: "Preview provider (vercel|none|netlify|github-pages)",    default: "vercel" },
  { name: "bot_email",         flag: "bot-email",         env: "SDLC_KIT_BOT_EMAIL",         label: "Bot email used by workflow commits",                     default: "claude-sdlc-bot@noreply.github.com" },
  { name: "bot_name",          flag: "bot-name",          env: "SDLC_KIT_BOT_NAME",          label: "Bot name used by workflow commits",                      default: "claude-sdlc-bot" },
];

export function resolveConfig({ flags, env }) {
  const config = {};
  for (const f of CONFIG_FIELDS) {
    if (flags[f.flag] != null && flags[f.flag] !== "") {
      config[f.name] = flags[f.flag];
    } else if (env[f.env] != null && env[f.env] !== "") {
      config[f.name] = env[f.env];
    } else {
      config[f.name] = f.default;
    }
  }
  return config;
}

export async function promptInteractive(config, isTTY) {
  if (!isTTY) return config;
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  try {
    for (const f of CONFIG_FIELDS) {
      const answer = await rl.question(`  ${f.label} [${config[f.name]}]: `);
      if (answer.trim()) config[f.name] = answer.trim();
    }
  } finally {
    rl.close();
  }
  return config;
}
