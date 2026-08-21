import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import luaparse from "luaparse";

const repo = path.resolve(import.meta.dirname, "..");
const addon = path.join(repo, "addon", "pfQuest");
const expectedVersion = "2.0.0-beta1.15";
const failures = [];
let parsedLua = 0;
let totalFiles = 0;
let totalBytes = 0;

function fail(message) {
  failures.push(message);
}

function walk(directory) {
  const files = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const full = path.join(directory, entry.name);
    if (entry.isDirectory()) files.push(...walk(full));
    else if (entry.isFile()) files.push(full);
  }
  return files;
}

function rel(file, base = repo) {
  return path.relative(base, file).replaceAll("\\", "/");
}

function existsCaseInsensitive(candidate) {
  const absolute = path.resolve(candidate);
  const root = path.parse(absolute).root;
  const parts = absolute.slice(root.length).split(path.sep).filter(Boolean);
  let current = root;
  for (const part of parts) {
    if (!fs.existsSync(current)) return false;
    const match = fs.readdirSync(current).find((entry) => entry.toLowerCase() === part.toLowerCase());
    if (!match) return false;
    current = path.join(current, match);
  }
  return fs.existsSync(current);
}

if (!fs.existsSync(addon)) {
  console.error(`Missing addon source: ${addon}`);
  process.exit(1);
}

const files = walk(addon);
for (const file of files) {
  const stat = fs.statSync(file);
  totalFiles += 1;
  totalBytes += stat.size;
  if (stat.size >= 100 * 1024 * 1024) fail(`${rel(file)} is 100 MiB or larger`);

  const extension = path.extname(file).toLowerCase();
  if ([".exe", ".dll", ".cmd", ".bat", ".ps1", ".com", ".scr"].includes(extension)) {
    fail(`${rel(file)} contains executable content inside the runtime addon`);
  }

  if (extension === ".lua") {
    const source = fs.readFileSync(file, "utf8");
    try {
      luaparse.parse(source, {
        luaVersion: "5.1",
        comments: false,
        locations: true,
        scope: true,
      });
      parsedLua += 1;
    } catch (error) {
      fail(`${rel(file)} Lua 5.1 parse error: ${error.message}`);
    }
  }
}

const toc = path.join(addon, "pfQuest.toc");
const tocText = fs.readFileSync(toc, "utf8");
if (!tocText.includes(`## Version: EV-${expectedVersion}`)) {
  fail(`pfQuest.toc version is not EV-${expectedVersion}`);
}

for (const rawLine of tocText.split(/\r?\n/)) {
  const line = rawLine.trim();
  if (!line || line.startsWith("#")) continue;
  const candidate = path.join(addon, line.replaceAll("\\", path.sep));
  if (!existsCaseInsensitive(candidate)) fail(`pfQuest.toc references missing path: ${line}`);
}

for (const xml of files.filter((file) => path.extname(file).toLowerCase() === ".xml")) {
  const source = fs.readFileSync(xml, "utf8");
  if (!/^\s*<Ui\b[\s\S]*<\/Ui>\s*$/i.test(source)) fail(`${rel(xml)} is not a complete <Ui> document`);
  for (const match of source.matchAll(/<(?:Include|Script)\s+file="([^"]+)"\s*\/>/gi)) {
    const candidate = path.resolve(path.dirname(xml), match[1].replaceAll("\\", path.sep));
    if (!existsCaseInsensitive(candidate)) fail(`${rel(xml)} references missing path: ${match[1]}`);
  }
}

const sourceFiles = files
  .filter((file) => path.extname(file).toLowerCase() === ".lua")
  .map((file) => ({ file, source: fs.readFileSync(file, "utf8") }));

const forbidden = [
  [/(?:\.|:)GetChildren\s*\(/, "native child enumeration"],
  [/(?:\.|:)GetRegions\s*\(/, "native region enumeration"],
  [/\bForceQuit\s*\(/, "forced client termination"],
  [/(?:\.|:)SetHyperlink\s*\(/, "tooltip hyperlink bridge call"],
  [/\bMinimap\s*:\s*SetZoom\s*\(/, "native minimap mutation"],
  [/\bdebugprofilestop\s*\(/, "undocumented profiling API"],
  [/\bloadstring\s*\(/, "dynamic code execution"],
  [/\bRunScript\s*\(/, "dynamic script execution"],
  [/\bSendAddonMessage\s*\(/, "unsolicited addon-channel transmission"],
  [/\bSendChatMessage\s*\(/, "unsolicited chat transmission"],
];

for (const { file, source } of sourceFiles) {
  const codeOnly = source
    .split(/\r?\n/)
    .filter((line) => !line.trimStart().startsWith("--"))
    .join("\n");
  for (const [pattern, label] of forbidden) {
    if (pattern.test(codeOnly)) fail(`${rel(file)} contains forbidden ${label}`);
  }
}

const compat = fs.readFileSync(path.join(addon, "compat", "emberveil.lua"), "utf8");
const mapEngine = fs.readFileSync(path.join(addon, "emberveil_map.lua"), "utf8");
const quest = fs.readFileSync(path.join(addon, "quest.lua"), "utf8");
const tracker = fs.readFileSync(path.join(addon, "tracker.lua"), "utf8");
const database = fs.readFileSync(path.join(addon, "database.lua"), "utf8");

const contracts = [
  [compat.includes(`EV.version = "${expectedVersion}"`), "compatibility-layer version mismatch"],
  [compat.includes(`if complete == -1 then return "failed" end`), "failed quest state is not preserved"],
  [compat.includes(`return self:GetQuestLogEntryState(qlogid) == "complete"`), "canonical completion gate missing"],
  [compat.includes(`self.questHistoryAuthoritative = true`), "authoritative completed-history state missing"],
  [compat.includes(`function EV:RecordQuestRemoval`), "quest-removal reconciliation missing"],
  [database.includes(`not QuestieEV:CanRenderAvailableQuests()`), "available quests are not completion-gated"],
  [database.includes(`objectiveType == "gobject"`), "Emberveil game-object objective handling missing"],
  [database.includes(`renderEnder = false`), "premature active-quest ender markers are not gated"],
  [database.includes(`table.getn(results[best]) ~= 1`), "ambiguous quest-ID resolver is not fail-closed"],
  [!database.includes(`ttitle = data.T`), "active quest resolver still fuzzy-maps unknown titles"],
  [quest.includes(`"REMOVE", data.state`), "quest removal omits previous canonical state"],
  [quest.includes(`local HookGetQuestReward = GetQuestReward`), "fast quest-turn-in capture missing"],
  [quest.includes(`state = state .. "|state=" .. evState`), "quest fingerprint omits three-state status"],
  [tracker.includes(`local evFailed = evState == "failed"`), "tracker lacks failed-state rendering"],
  [mapEngine.includes(`EV:ScheduleMinimapProjection(.08, "MINIMAP_UPDATE_ZOOM")`), "zoom event is not debounced"],
  [!mapEngine.includes("ToggleMinimapEnvironment"), "zoom path can still toggle minimap environment"],
  [mapEngine.includes(`parentSource = "sticky-parent"`), "indoor parent-zone continuity is missing"],
];
for (const [passed, message] of contracts) if (!passed) fail(message);

if (failures.length) {
  console.error(`Validation failed with ${failures.length} problem(s):`);
  for (const problem of failures) console.error(`- ${problem}`);
  process.exit(1);
}

console.log(`PASS: ${parsedLua} Lua files parse as Lua 5.1.`);
console.log(`PASS: ${totalFiles} runtime files (${totalBytes} bytes) passed structure and safety checks.`);
console.log(`PASS: manifest references, version synchronization, and Emberveil safety contracts passed.`);
