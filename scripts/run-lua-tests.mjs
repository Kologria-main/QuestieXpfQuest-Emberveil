import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { spawnSync } from "node:child_process";

const repo = path.resolve(import.meta.dirname, "..");
const cli = path.join(repo, "node_modules", "fengari-node-cli", "src", "lua-cli.js");
const tests = process.argv.slice(2);

if (!fs.existsSync(cli)) {
  console.error("fengari-node-cli is not installed; run pnpm install --frozen-lockfile.");
  process.exit(1);
}
if (!tests.length) {
  console.error("Usage: node scripts/run-lua-tests.mjs <test.lua> [...]");
  process.exit(1);
}

let failed = false;
for (const test of tests) {
  const result = spawnSync(process.execPath, [cli, test], {
    cwd: repo,
    encoding: "utf8",
    maxBuffer: 16 * 1024 * 1024,
  });

  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);

  // fengari-node-cli 0.1.0 reports Lua runtime errors on stderr but can still
  // exit zero. Require an explicit PASS marker as well as clean process state
  // so an assertion or stack trace cannot silently pass CI.
  if (result.error || result.status !== 0 || (result.stderr || "").trim()
      || !result.stdout.includes("PASS:")) {
    console.error(`FAIL: ${test}`);
    failed = true;
  }
}

if (failed) process.exit(1);
