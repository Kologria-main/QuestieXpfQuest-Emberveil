import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import luaparse from "luaparse";

const repo = path.resolve(import.meta.dirname, "..");
const addonRoot = path.join(repo, "addon");
const addon = path.join(repo, "addon", "pfQuest");
const localePacks = ["deDE", "esES", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW"];
const managedAddonNames = ["pfQuest", ...localePacks.map((locale) => `pfQuest_Locale_${locale}`)];
const expectedVersion = "2.0.0-beta1.21";
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

if (!fs.existsSync(addonRoot)) {
  console.error(`Missing addon source: ${addonRoot}`);
  process.exit(1);
}

for (const addonName of managedAddonNames) {
  const directory = path.join(addonRoot, addonName);
  if (!fs.existsSync(directory)) fail(`missing managed addon folder: addon/${addonName}`);
}
const unexpectedAddonFolders = fs.readdirSync(addonRoot, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && !managedAddonNames.includes(entry.name));
for (const entry of unexpectedAddonFolders) fail(`unmanaged addon folder: addon/${entry.name}`);

const files = managedAddonNames
  .map((addonName) => path.join(addonRoot, addonName))
  .filter((directory) => fs.existsSync(directory))
  .flatMap(walk);
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
const packageMetadata = JSON.parse(fs.readFileSync(path.join(repo, "package.json"), "utf8"));
if (packageMetadata.version !== expectedVersion) fail("package.json version mismatch");
if (!packageMetadata.scripts?.validate?.includes("scripts/run-lua-tests.mjs")) {
  fail("Lua tests are not using the strict Fengari result wrapper");
}
for (const [file, pattern] of [
  [path.join(repo, "installer", "Install-Questie-Emberveil.ps1"), `$Version = '${expectedVersion}'`],
  [path.join(repo, "scripts", "build-release.ps1"), `[string]$Version = '${expectedVersion}'`],
  [path.join(repo, "scripts", "build-discord-release.ps1"), `[string]$Version = '${expectedVersion}'`],
  [path.join(repo, "INSTALL_KOQUEST_LINUX.sh"), `VERSION='${expectedVersion}'`],
]) {
  if (!fs.readFileSync(file, "utf8").includes(pattern)) fail(`${rel(file)} version mismatch`);
}

function runtimeTocLines(text) {
  return text.split(/\r?\n/).map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"));
}
function validateToc(addonName, text) {
  const directory = path.join(addonRoot, addonName);
  for (const line of runtimeTocLines(text)) {
    const candidate = path.join(directory, line.replaceAll("\\", path.sep));
    if (!existsCaseInsensitive(candidate)) fail(`${addonName}.toc references missing path: ${line}`);
  }
}

validateToc("pfQuest", tocText);
if (!runtimeTocLines(tocText).includes("init\\enUS.xml")) fail("pfQuest.toc does not load the English fallback");
for (const locale of localePacks) {
  if (runtimeTocLines(tocText).includes(`init\\${locale}.xml`)) {
    fail(`pfQuest.toc eagerly loads ${locale}`);
  }
  const addonName = `pfQuest_Locale_${locale}`;
  const localeTocPath = path.join(addonRoot, addonName, `${addonName}.toc`);
  if (!fs.existsSync(localeTocPath)) {
    fail(`missing locale TOC: ${rel(localeTocPath)}`);
    continue;
  }
  const localeToc = fs.readFileSync(localeTocPath, "utf8");
  if (!localeToc.includes(`## Version: EV-${expectedVersion}`)) fail(`${addonName}.toc version mismatch`);
  if (!/^## LoadOnDemand:\s*1\s*$/m.test(localeToc)) fail(`${addonName} is not load-on-demand`);
  if (!localeToc.includes(`## X-KoQuest-Locale: ${locale}`)) fail(`${addonName} locale metadata mismatch`);
  const localeRuntime = runtimeTocLines(localeToc);
  if (localeRuntime.length !== 1 || localeRuntime[0] !== `init\\${locale}.xml`) {
    fail(`${addonName} must load only its base locale XML`);
  }
  validateToc(addonName, localeToc);
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
    const localizedIds = topLevelNumericIds(path.join(addonRoot, `pfQuest_Locale_${locale}`, "db", locale, `${dataset}.lua`));
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

const compat = fs.readFileSync(path.join(addon, "compat", "emberveil.lua"), "utf8");
const localeLoader = fs.readFileSync(path.join(addon, "locale_loader.lua"), "utf8");
const map = fs.readFileSync(path.join(addon, "map.lua"), "utf8");
const mapEngine = fs.readFileSync(path.join(addon, "emberveil_map.lua"), "utf8");
const quest = fs.readFileSync(path.join(addon, "quest.lua"), "utf8");
const tracker = fs.readFileSync(path.join(addon, "tracker.lua"), "utf8");
const database = fs.readFileSync(path.join(addon, "database.lua"), "utf8");
const config = fs.readFileSync(path.join(addon, "config.lua"), "utf8");
const discordBuilder = fs.readFileSync(path.join(repo, "scripts", "build-discord-release.ps1"), "utf8");

const contracts = [
  [compat.includes(`EV.version = "${expectedVersion}"`), "compatibility-layer version mismatch"],
  [localeLoader.includes(`function EV:LoadLocaleDatabase`), "load-on-demand locale loader missing"],
  [localeLoader.includes(`pcall(LoadAddOn, pack)`), "locale packs are not safely loaded on demand"],
  [localeLoader.includes(`ClearPartialLocale(locale)`), "partial locale loads are not cleared"],
  [localeLoader.includes(`SetStartupStatus(locale, "enUS"`), "locale loader lacks explicit English fallback diagnostics"],
  [compat.includes(`if complete == -1 then return "failed" end`), "failed quest state is not preserved"],
  [compat.includes(`return self:GetQuestLogEntryState(qlogid) == "complete"`), "canonical completion gate missing"],
  [compat.includes(`self.questHistoryAuthoritative = true`), "authoritative completed-history state missing"],
  [compat.includes(`function EV:RecordQuestRemoval`), "quest-removal reconciliation missing"],
  [compat.includes(`function EV:ConfirmAvailableQuestTitle`), "client-confirmed available-quest path missing"],
  [compat.includes(`function EV:IsClientConfirmedAvailableQuest`), "client-confirmed quest filter missing"],
  [compat.includes(`return "strict-hidden"`), "strict completed-history availability mode missing"],
  [compat.includes(`pfQuest_config["unverifiedquestgivers"] == "1"`), "best-effort quest-giver control missing"],
  [compat.includes(`function EV:PreserveHiddenQuestLog`), "collapsed quest-log preservation missing"],
  [database.includes(`not QuestieEV:CanRenderAvailableQuests()`), "available quests are not completion-gated"],
  [database.includes(`objectiveType == "gobject"`), "Emberveil game-object objective handling missing"],
  [database.includes(`renderEnder = false`), "premature active-quest ender markers are not gated"],
  [database.includes(`table.getn(bestIDs) ~= 1`), "ambiguous quest-ID resolver is not fail-closed"],
  [database.includes(`local function GetQuestTitleMatch`), "lazy exact-title quest index missing"],
  [database.includes(`questTitleIndexSource ~= source`), "quest-title index does not track its locale source"],
  [!database.includes(`ttitle = data.T`), "active quest resolver still fuzzy-maps unknown titles"],
  [!database.includes(`GetQuestLink(`), "active quest resolver still depends on GetQuestLink"],
  [quest.includes(`"REMOVE", data.state`), "quest removal omits previous canonical state"],
  [quest.includes(`local HookGetQuestReward = GetQuestReward`), "fast quest-turn-in capture missing"],
  [quest.includes(`state = state .. "|state=" .. evState`), "quest fingerprint omits three-state status"],
  [quest.includes(`snapshotComplete ~= false`), "quest removals are not gated on a complete log snapshot"],
  [quest.includes(`QuestieEV:LoadLocaleDatabase(locale, "translation")`), "translation menu does not load locale packs on demand"],
  [tracker.includes(`if snapshotComplete == false then return end`), "tracker does not preserve collapsed quests"],
  [tracker.includes(`local evFailed = evState == "failed"`), "tracker lacks failed-state rendering"],
  [database.includes(`GetBitByRace(race, raceID)`), "numeric race ID support missing"],
  [database.includes(`GetBitByClass(class, classID)`), "numeric class ID support missing"],
  [mapEngine.includes(`EV:ScheduleMinimapProjection(.08, "MINIMAP_UPDATE_ZOOM")`), "zoom event is not debounced"],
  [!mapEngine.includes("ToggleMinimapEnvironment"), "zoom path can still toggle minimap environment"],
  [mapEngine.includes(`EV.minimapEnvironmentSource = "verified-outdoor-only"`), "measured outdoor-only minimap scale policy missing"],
  [mapEngine.includes(`function EV:CaptureMinimapPlayerPosition()`), "20 Hz minimap position fast path missing"],
  [mapEngine.includes(`pin.qevVisualKey ~= visualKey`), "minimap visual metadata cache missing"],
  [map.includes(`function pfMap:MarkNodesChanged`), "pfMap node revision hook missing"],
  [map.includes(`pfMap:MarkNodesChanged("add-node-item")`), "item mutation does not invalidate map caches"],
  [map.includes(`pfMap:MarkNodesChanged("delete-node")`), "node deletion does not invalidate map caches"],
  [mapEngine.includes(`cache.nodeRevision == nodeRevision`), "node cache ignores pfMap revision"],
  [mapEngine.includes(`function EV:RequestWorldMapRefresh`), "world-map event coalescing missing"],
  [mapEngine.includes(`function EV:ServiceWorldMapRefresh`), "world-map final-selection service missing"],
  [mapEngine.includes(`EV:RefreshWorldMapSelection(false, shown)`), "world-map selection fallback missing"],
  [mapEngine.includes(`local denseMode = totalNodes > 450`), "dense-zone world-map compaction missing"],
  [mapEngine.includes(`WORLD_OBJECTIVE_PIN_BUDGET = 320`), "world-map objective pin budget missing"],
  [mapEngine.includes(`function EV:GetWorldRenderEntries`), "hoverable world-map objective cache missing"],
  [mapEngine.includes(`bucket.node[title] = meta`), "world-map objective tooltips are not preserved"],
  [mapEngine.includes(`sourceKey = entry.key`), "world-map compaction does not preserve a real source coordinate"],
  [!mapEngine.includes(`bucket.xTotal / bucket.count`), "world-map objectives still use synthetic averaged coordinates"],
  [mapEngine.includes(`pfMap:BuildNode("pfMapPin" .. i, WorldMapButton)`), "world-map objectives are not real hoverable pfMap buttons"],
  [mapEngine.includes(`function EV:EnsureActiveQuestNodes`), "active quest-node self-heal missing"],
  [quest.includes(`QuestieEV:EnsureActiveQuestNodes("queue-drained")`), "quest queue does not audit active nodes"],
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
  [config.includes(`pfQuest_config["availabilitydefaultv2"]`), "available quest-giver upgrade migration missing"],
  [packageMetadata.scripts?.["build:discord"]?.includes("build-discord-release.ps1"), "Discord build command missing"],
  [discordBuilder.includes(`[long]$MaxBytes = 20000000`), "Discord archive lacks a strict 20 MB ceiling"],
  [discordBuilder.includes(`'-xr!assets'`), "Discord archive does not exclude repository-only assets"],
  [discordBuilder.includes(`'-m0=lzma2:d=64m'`), "Discord archive compression contract missing"],
  [discordBuilder.includes(`-ValidateOnly`), "Discord archive does not validate its extracted installer"],
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
