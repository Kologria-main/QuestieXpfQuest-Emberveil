local datasets = { "items", "units", "objects", "quests", "zones", "professions" }
local locales = { "deDE", "esES", "frFR", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }
local function Length(list) return #list end

local function NewDatabase()
  local db = {}
  for _, dataset in pairs(datasets) do
    db[dataset] = { ["enUS"] = { [1] = dataset .. "-english" } }
  end
  return db
end

local function AssertLocaleCleared(locale)
  for _, dataset in pairs(datasets) do
    assert(pfDB[dataset][locale] == nil,
      "partial " .. locale .. " table survived for " .. dataset)
  end
end

pfDB = NewDatabase()
local requestedLocale = "koKR"
local loadMode = {}
local loadCalls = {}
local enableCalls = {}
local chat = {}

function GetLocale()
  return requestedLocale
end

function LoadAddOn(pack)
  local locale = string.match(pack or "", "pfQuest_Locale_(%a%a%u%u)$")
  assert(locale, "unexpected locale addon name: " .. tostring(pack))
  loadCalls[Length(loadCalls) + 1] = pack

  if loadMode[locale] == "disabled" then return nil, "DISABLED" end

  for index, dataset in pairs(datasets) do
    if loadMode[locale] ~= "partial" or index == 1 then
      pfDB[dataset][locale] = { [1] = locale .. "-" .. dataset }
    end
  end
  return true
end

function EnableAddOn(pack)
  local locale = string.match(pack or "", "pfQuest_Locale_(%a%a%u%u)$")
  assert(locale, "unexpected locale addon name: " .. tostring(pack))
  enableCalls[Length(enableCalls) + 1] = pack
  loadMode[locale] = nil
end

QuestieEV = {
  Chat = function(message)
    chat[Length(chat) + 1] = message
  end,
}

dofile("addon/pfQuest/locale_loader.lua")

assert(Length(loadCalls) == 1, "startup should load exactly one sibling locale")
assert(loadCalls[1] == "pfQuest_Locale_koKR", "startup loaded the wrong locale pack")
assert(QuestieEV.localeRequested == "koKR", "requested locale diagnostic is wrong")
assert(QuestieEV.localeLoaded == "koKR", "loaded locale diagnostic is wrong")
assert(QuestieEV.localeStatus == "loaded", "successful startup status is wrong")
assert(QuestieEV.localeFallback == nil, "successful startup reported a fallback")
assert(Length(chat) == 0, "successful startup emitted a warning")

for _, locale in pairs(locales) do
  if locale ~= "koKR" then AssertLocaleCleared(locale) end
end

local loaded, detail = QuestieEV:LoadLocaleDatabase("deDE", "translation")
assert(loaded and detail == nil, "on-demand translation locale did not load")
assert(pfDB.quests.deDE[1] == "deDE-quests", "translation locale data is missing")
assert(QuestieEV.localeRequested == "koKR", "translation load replaced startup diagnostics")

loadMode.frFR = "partial"
loaded, detail = QuestieEV:LoadLocaleDatabase("frFR", "translation")
assert(not loaded and detail == "INCOMPLETE_LOCALE", "partial pack did not fail closed")
AssertLocaleCleared("frFR")

loadMode.ptBR = "disabled"
local loadsBeforeDisabled = Length(loadCalls)
loaded, detail = QuestieEV:LoadLocaleDatabase("ptBR", "translation")
assert(loaded and detail == nil, "disabled active locale was not recovered")
assert(Length(enableCalls) == 1, "disabled locale was not enabled exactly once")
assert(enableCalls[1] == "pfQuest_Locale_ptBR", "wrong locale pack was enabled")
assert(Length(loadCalls) == loadsBeforeDisabled + 2,
  "disabled locale should perform one load and one retry")
assert(QuestieEV.localeLastAutoEnabled == "pfQuest_Locale_ptBR",
  "auto-enabled locale diagnostic is missing")

local callsBeforeUnsupported = Length(loadCalls)
loaded, detail = QuestieEV:LoadLocaleDatabase("itIT", "translation")
assert(not loaded and detail == "UNSUPPORTED_LOCALE", "unsupported locale fallback is wrong")
assert(Length(loadCalls) == callsBeforeUnsupported, "unsupported locale called LoadAddOn")

LoadAddOn = nil
loaded, detail = QuestieEV:LoadLocaleDatabase("ruRU", "translation")
assert(not loaded and detail == "LOADADDON_UNAVAILABLE", "missing API fallback is wrong")
AssertLocaleCleared("ruRU")

-- A failed active-locale load must retain complete English data, publish
-- diagnostics, and emit one actionable startup warning.
pfDB = NewDatabase()
requestedLocale = "zhCN"
chat = {}
EnableAddOn = nil
function LoadAddOn()
  return nil, "DISABLED"
end
QuestieEV = {
  Chat = function(message)
    chat[Length(chat) + 1] = message
  end,
}

dofile("addon/pfQuest/locale_loader.lua")

assert(QuestieEV.localeRequested == "zhCN", "failed startup requested locale is wrong")
assert(QuestieEV.localeLoaded == "enUS", "failed startup did not select English")
assert(QuestieEV.localeStatus == "fallback", "failed startup status is wrong")
assert(QuestieEV.localeError == "DISABLED", "failed startup reason is missing")
assert(QuestieEV.localeFallback == "enUS", "failed startup fallback is missing")
assert(Length(chat) == 1, "failed startup should emit one warning")
for _, dataset in pairs(datasets) do
  assert(pfDB[dataset].enUS[1] == dataset .. "-english", "English fallback was damaged")
end
AssertLocaleCleared("zhCN")

pfDB = NewDatabase()
pfDB.quests.enUS = nil
requestedLocale = "enUS"
QuestieEV = { Chat = function() error("broken English core should not claim a fallback") end }
dofile("addon/pfQuest/locale_loader.lua")
assert(QuestieEV.localeLoaded == nil, "incomplete English core was reported as loaded")
assert(QuestieEV.localeStatus == "failed", "incomplete English core did not fail")
assert(QuestieEV.localeError == "INCOMPLETE_ENUS", "incomplete English reason is wrong")

-- European English shares the core enUS database and must not request a
-- nonexistent sibling pack or warn the player.
pfDB = NewDatabase()
requestedLocale = "enGB"
loadCalls = {}
chat = {}
QuestieEV = {
  Chat = function(message)
    chat[Length(chat) + 1] = message
  end,
}
dofile("addon/pfQuest/locale_loader.lua")
assert(Length(loadCalls) == 0, "enGB attempted to load a sibling locale")
assert(QuestieEV.localeLoaded == "enUS", "enGB did not use the English core")
assert(QuestieEV.localeStatus == "core", "enGB did not report core locale status")
assert(Length(chat) == 0, "enGB emitted a fallback warning")

print("PASS: locale databases load on demand and fail closed to English.")
