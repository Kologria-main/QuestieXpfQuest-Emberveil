import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import luaparse from "luaparse";

const repo = path.resolve(import.meta.dirname, "..");
const addon = path.join(repo, "addon", "KoQuest");
const expectedVersion = "2.0.0-beta1.22";
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

const toc = path.join(addon, "KoQuest.toc");
const tocText = fs.readFileSync(toc, "utf8");
if (!tocText.includes(`## Version: EV-${expectedVersion}`)) {
  fail(`KoQuest.toc version is not EV-${expectedVersion}`);
}
const packageMetadata = JSON.parse(fs.readFileSync(path.join(repo, "package.json"), "utf8"));
if (packageMetadata.version !== expectedVersion) fail("package.json version mismatch");
for (const [file, pattern] of [
  [path.join(repo, "installer", "Install-Questie-Emberveil.ps1"), `$Version = '${expectedVersion}'`],
  [path.join(repo, "scripts", "build-release.ps1"), `[string]$Version = '${expectedVersion}'`],
  [path.join(repo, "INSTALL_KOQUEST_LINUX.sh"), `VERSION='${expectedVersion}'`],
]) {
  if (!fs.readFileSync(file, "utf8").includes(pattern)) fail(`${rel(file)} version mismatch`);
}

for (const rawLine of tocText.split(/\r?\n/)) {
  const line = rawLine.trim();
  if (!line || line.startsWith("#")) continue;
  const candidate = path.join(addon, line.replaceAll("\\", path.sep));
  if (!existsCaseInsensitive(candidate)) fail(`KoQuest.toc references missing path: ${line}`);
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

// The three requested client locales must contain every base-game lookup ID.
// Localized object tables may add region-specific records, but may not omit an
// enUS record because that would silently break title-to-ID matching.
const localizedDatasets = ["items", "units", "quests", "zones", "professions", "objects"];
const requestedLocales = ["ruRU", "zhCN", "zhTW"];
function topLevelNumericIds(file) {
  return new Set([...fs.readFileSync(file, "utf8").matchAll(/^  \[(\d+)\] =/gm)].map((match) => match[1]));
}
for (const dataset of localizedDatasets) {
  const baseIds = topLevelNumericIds(path.join(addon, "db", "enUS", `${dataset}.lua`));
  for (const locale of requestedLocales) {
    const localizedIds = topLevelNumericIds(path.join(addon, "db", locale, `${dataset}.lua`));
    const missing = [...baseIds].filter((id) => !localizedIds.has(id));
    if (missing.length) {
      fail(`${locale}/${dataset} omits ${missing.length} enUS record(s), first ID ${missing[0]}`);
    }
  }
}

const localesSource = fs.readFileSync(path.join(addon, "locales.lua"), "utf8");
for (const translation of [
  "允许尽力而为的任务发布者（可能包含已完成的任务）",
  "允許盡力而為的任務發布者（可能包含已完成的任務）",
  "Разрешить неточные маркеры квестодателей (могут включать завершённые задания)",
]) {
  if (!localesSource.includes(translation)) fail(`missing requested-locale safety setting: ${translation}`);
}

const forbidden = [
  [/(?:\.|:)GetChildren\s*\(/, "native child enumeration"],
  [/(?:\.|:)GetRegions\s*\(/, "native region enumeration"],
  [/\bForceQuit\s*\(/, "forced client termination"],
  [/(?:\.|:)SetHyperlink\s*\(/, "tooltip hyperlink bridge call"],
  [/\bMinimap\s*:\s*SetZoom\s*\(/, "native minimap mutation"],
  [/\bdebugprofilestop\s*\(/, "undocumented profiling API"],
  [/\bloadstring\s*\(/, "dynamic code execution"],
  [/\bRunScript\s*\(/, "dynamic script execution"],
  [/\bGetInteractObjectType\s*\(/, "protected nearest-interaction query"],
  [/\bHasNearestObjectToInteract\s*\(/, "protected nearest-interaction predicate"],
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

// KoQuest must coexist with upstream pfQuest. Legacy runtime globals, node
// buckets, frame names, and slash registrations would silently overwrite one
// another even if the addon directory itself were renamed.
const isolatedCode = sourceFiles
  .filter(({ file }) => !file.endsWith(path.join("compat", "pfUI.lua")))
  .map(({ source }) => source
    .split(/\r?\n/)
    .filter((line) => !line.trimStart().startsWith("--"))
    .join("\n")
    .replace(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g, ""))
  .join("\n");
for (const [pattern, label] of [
  [/\bpfQuest(?:Compat|Config|_config|_questcache|_history|_colors|_server|_track|_confirmedAvailable)?\b/, "pfQuest global"],
  [/\bpfDatabase\b/, "pfDatabase global"],
  [/\bpfBrowser\b/, "pfBrowser global"],
  [/\bpfJournal\b/, "pfJournal global"],
  [/\bpfMap\b/, "pfMap global"],
  [/\bpfDB\b/, "pfDB global"],
  [/\bQuestieEV\b/, "QuestieEV global"],
  [/\bPFQUEST\b/, "PFQUEST node bucket"],
  [/\bPFDB\b/, "PFDB node bucket"],
  [/SLASH_PFDB|SlashCmdList\["PFDB"\]/, "pfQuest slash-command registration"],
]) {
  if (pattern.test(isolatedCode)) fail(`runtime namespace still contains legacy ${label}`);
}

const compat = fs.readFileSync(path.join(addon, "compat", "emberveil.lua"), "utf8");
const mapEngine = fs.readFileSync(path.join(addon, "emberveil_map.lua"), "utf8");
const quest = fs.readFileSync(path.join(addon, "quest.lua"), "utf8");
const tracker = fs.readFileSync(path.join(addon, "tracker.lua"), "utf8");
const database = fs.readFileSync(path.join(addon, "database.lua"), "utf8");
const config = fs.readFileSync(path.join(addon, "config.lua"), "utf8");
const runtimeSettingConsumers = sourceFiles
  .filter(({ file }) => !file.endsWith(path.join("KoQuest", "config.lua")))
  .map(({ source }) => source)
  .join("\n");
for (const match of config.matchAll(/config\s*=\s*"([^"]+)"/g)) {
  if (!runtimeSettingConsumers.includes(match[1])) {
    fail(`visible setting has no runtime consumer outside config.lua: ${match[1]}`);
  }
}

const contracts = [
  [compat.includes(`EV.version = "${expectedVersion}"`), "compatibility-layer version mismatch"],
  [compat.includes(`if complete == -1 then return "failed" end`), "failed quest state is not preserved"],
  [compat.includes(`return self:GetQuestLogEntryState(qlogid) == "complete"`), "canonical completion gate missing"],
  [compat.includes(`self.questHistoryAuthoritative = true`), "authoritative completed-history state missing"],
  [compat.includes(`function EV:RecordQuestRemoval`), "quest-removal reconciliation missing"],
  [compat.includes(`function EV:ConfirmAvailableQuestTitle`), "client-confirmed available-quest path missing"],
  [compat.includes(`function EV:IsClientConfirmedAvailableQuest`), "client-confirmed quest filter missing"],
  [compat.includes(`return "strict-hidden"`), "strict completed-history availability mode missing"],
  [compat.includes(`KoQuest_config["unverifiedquestgivers"] == "1"`), "best-effort quest-giver control missing"],
  [compat.includes(`function EV:PreserveHiddenQuestLog`), "collapsed quest-log preservation missing"],
  [compat.includes(`function EV:DisableLegacyKoQuestFolder`), "legacy KoQuest folder guard missing"],
  [compat.includes(`pcall(DisableAddOn, "pfQuest")`), "legacy KoQuest folder is not disabled safely"],
  [database.includes(`not KoQuestEV:CanRenderAvailableQuests()`), "available quests are not completion-gated"],
  [database.includes(`objectiveType == "gobject"`), "Emberveil game-object objective handling missing"],
  [database.includes(`objectiveType = "unknown"`), "transient accepted-quest objective fallback missing"],
  [database.includes(`renderEnder = false`), "premature active-quest ender markers are not gated"],
  [database.includes(`table.getn(bestIDs) ~= 1`), "ambiguous quest-ID resolver is not fail-closed"],
  [!database.includes(`ttitle = data.T`), "active quest resolver still fuzzy-maps unknown titles"],
  [!database.includes(`GetQuestLink(`), "active quest resolver still depends on GetQuestLink"],
  [quest.includes(`"REMOVE", data.state`), "quest removal omits previous canonical state"],
  [quest.includes(`local HookGetQuestReward = GetQuestReward`), "fast quest-turn-in capture missing"],
  [quest.includes(`state = state .. "|state=" .. evState`), "quest fingerprint omits three-state status"],
  [quest.includes(`snapshotComplete ~= false`), "quest removals are not gated on a complete log snapshot"],
  [tracker.includes(`if snapshotComplete == false then return end`), "tracker does not preserve collapsed quests"],
  [tracker.includes(`local evFailed = evState == "failed"`), "tracker lacks failed-state rendering"],
  [database.includes(`GetBitByRace(race, raceID)`), "numeric race ID support missing"],
  [database.includes(`GetBitByClass(class, classID)`), "numeric class ID support missing"],
  [mapEngine.includes(`EV:ScheduleMinimapProjection(.08, "MINIMAP_UPDATE_ZOOM")`), "zoom event is not debounced"],
  [!mapEngine.includes("ToggleMinimapEnvironment"), "zoom path can still toggle minimap environment"],
  [mapEngine.includes(`EV.minimapEnvironmentSource = "verified-outdoor-only"`), "measured outdoor-only minimap scale policy missing"],
  [mapEngine.includes(`function EV:CaptureMinimapPlayerPosition()`), "20 Hz minimap position fast path missing"],
  [mapEngine.includes(`pin.qevVisualKey ~= visualKey`), "minimap visual metadata cache missing"],
  [mapEngine.includes(`local denseMode = totalNodes > 450`), "dense-zone world-map compaction missing"],
  [mapEngine.includes(`WORLD_OBJECTIVE_PIN_BUDGET = 240`), "world-map objective pin budget missing"],
  [mapEngine.includes(`perf.miniLowFpsInterval or 0.10`), "adaptive low-FPS minimap interval missing"],
  [mapEngine.includes(`if not pin:IsShown() then pin:Show() end`), "minimap visibility-state cache missing"],
  [mapEngine.includes(`function EV:GetWorldRenderEntries`), "hoverable world-map objective cache missing"],
  [mapEngine.includes(`bucket.node[title] = meta`), "world-map objective tooltips are not preserved"],
  [mapEngine.includes(`sourceKey = entry.key`), "world-map compaction does not preserve a real source coordinate"],
  [!mapEngine.includes(`bucket.xTotal / bucket.count`), "world-map objectives still use synthetic averaged coordinates"],
  [mapEngine.includes(`KoMap:BuildNode("KoMapPin" .. i, WorldMapButton)`), "world-map objectives are not real hoverable KoMap buttons"],
  [mapEngine.includes(`function EV:EnsureActiveQuestNodes`), "active quest-node self-heal missing"],
  [quest.includes(`KoQuestEV:EnsureActiveQuestNodes("queue-drained")`), "quest queue does not audit active nodes"],
  [mapEngine.includes(`parentSource = "sticky-parent"`), "indoor parent-zone continuity is missing"],
  [compat.includes(`EV._rawSetMapZoom`), "hidden-map zone-probe bridge missing"],
  [mapEngine.includes(`function EV:BeginHiddenZoneProbe`), "nil-zone cold-start probe missing"],
  [mapEngine.includes(`self.location.parentSource = "hidden-zone-probe"`), "zone probe does not establish a verified parent"],
  [mapEngine.includes(`nodeScore = self:CountNodesForMap(mapID)`), "zone probe does not prioritize active-quest maps"],
  [mapEngine.includes(`function EV:ResetFramerateStats`), "steady-state FPS diagnostics reset missing"],
  [mapEngine.includes(`f:SetWidth(30)`), "world-map player marker visibility hardening missing"],
  [mapEngine.includes(`cellSize = 2.5`), "minimap spatial grid is not tightened"],
  [mapEngine.includes(`function EV:InvalidateMinimapPinVisuals`), "map-close minimap visual reset missing"],
  [!mapEngine.includes(`RenderWorldDots`), "non-hoverable world-map dot layer is still present"],
  [config.includes(`default = "1", type = "checkbox", config = "unverifiedquestgivers"`), "available quest givers are not enabled by default"],
  [config.includes(`KoQuest_config["availabilitydefaultv2"]`), "available quest-giver upgrade migration missing"],
  [!config.includes(`config = "arrow"`), "unsupported Emberveil route arrow is still exposed in settings"],
  [!config.includes(`KoQuestInit.checkbox`), "unsupported route arrow is still exposed in the welcome screen"],
  [config.includes(`KoQuest_config["arrow"] = "0"`), "unsupported route arrow is not compatibility-locked"],
  [!fs.readFileSync(path.join(addon, "slashcmd.lua"), "utf8").includes(`KoQuest_config["arrow"] = "1"`), "slash command can still enable the unsupported route arrow"],
  [(config.match(/for _, data in ipairs\(config\)/g) || []).length === 2, "settings layout does not use deterministic array order"],
  [config.includes(`for i, button in ipairs(buttons) do`), "welcome mode cards do not use deterministic array order"],
  [config.includes(`CreateFrame("Button", "KoQuestInitMode" .. i, KoQuestInit)`), "welcome mode cards do not have unique frame names"],
  [config.includes(`KoQuestConfig:ApplyEmberveilSettings(true)`), "welcome screen does not use the validated settings application path"],
  [config.includes(`local trackerFontSize = KoQuestEVClampRange`), "tracker font size is not safely range-checked"],
  [config.includes(`local minDropChance = KoQuestEVClampRange`), "minimum drop chance is not safely range-checked"],
  [config.includes(`KoQuestConfig.emberveilNeedsRebuild = true`), "edited text settings do not request a runtime refresh"],
  [!mapEngine.includes(`math.floor((xPlayer - maxDx) / cellSize) - 1`), "minimap query retains an unnecessary border"],
];
for (const [passed, message] of contracts) if (!passed) fail(message);

if (failures.length) {
  console.error(`Validation failed with ${failures.length} problem(s):`);
  for (const problem of failures) console.error(`- ${problem}`);
  process.exit(1);
}

console.log(`PASS: ${parsedLua} Lua files parse as Lua 5.1.`);
console.log(`PASS: ${totalFiles} runtime files (${totalBytes} bytes) passed structure and safety checks.`);
console.log(`PASS: ruRU, zhCN, and zhTW contain every base enUS localized lookup ID.`);
console.log(`PASS: manifest references, version synchronization, and Emberveil safety contracts passed.`);
