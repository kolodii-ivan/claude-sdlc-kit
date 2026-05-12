#!/usr/bin/env node
//
// Screenshot a list of routes against a base URL and write a PR comment markdown file.
// Usage: node scripts/screenshot-routes.mjs <base_url> <routes_file> <out_dir>

import fs from "node:fs/promises";
import path from "node:path";
import { chromium } from "playwright";

const [, , baseUrl, routesFile, outDir] = process.argv;

if (!baseUrl || !routesFile || !outDir) {
  console.error("Usage: screenshot-routes.mjs <base_url> <routes_file> <out_dir>");
  process.exit(2);
}

await fs.mkdir(outDir, { recursive: true });

const routes = JSON.parse(await fs.readFile(routesFile, "utf8"));
if (!Array.isArray(routes) || routes.length === 0) {
  console.error(`${routesFile} must contain a non-empty JSON array of paths.`);
  process.exit(2);
}

const slugify = (route) =>
  route === "/" ? "home" : route.replace(/^\//, "").replace(/[^a-z0-9]+/gi, "-").toLowerCase();

const browser = await chromium.launch();
const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
const page = await context.newPage();

const captured = [];

for (const route of routes) {
  const target = new URL(route, baseUrl).toString();
  const slug = slugify(route);
  const outPath = path.join(outDir, `${slug}.png`);
  console.log(`Capturing ${target} → ${outPath}`);
  try {
    await page.goto(target, { waitUntil: "networkidle", timeout: 30_000 });
    await page.screenshot({ path: outPath, fullPage: true });
    captured.push({ route, slug });
  } catch (err) {
    console.error(`Failed to capture ${target}: ${err.message}`);
    captured.push({ route, slug, error: err.message });
  }
}

await browser.close();

console.log(`Wrote ${captured.length} screenshots to ${outDir}`);
const failed = captured.filter((c) => c.error);
if (failed.length > 0) {
  console.error(`${failed.length} routes failed to capture:`);
  for (const f of failed) {
    console.error(`  ${f.route}: ${f.error}`);
  }
  process.exit(1);
}
