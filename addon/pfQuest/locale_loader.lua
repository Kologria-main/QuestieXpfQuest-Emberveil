-- KoQuest locale database loader
--
-- Keep English in the core addon as a guaranteed fallback. Every other
-- database is shipped as a load-on-demand sibling addon, so startup parses
-- only enUS and the game client's active locale.

local EV = QuestieEV
local required = { "items", "units", "objects", "quests", "zones", "professions" }

EV.localePacks = {
  ["deDE"] = "pfQuest_Locale_deDE",
  ["esES"] = "pfQuest_Locale_esES",
  ["frFR"] = "pfQuest_Locale_frFR",
  ["koKR"] = "pfQuest_Locale_koKR",
  ["ptBR"] = "pfQuest_Locale_ptBR",
  ["ruRU"] = "pfQuest_Locale_ruRU",
  ["zhCN"] = "pfQuest_Locale_zhCN",
  ["zhTW"] = "pfQuest_Locale_zhTW",
}

local function HasCompleteLocale(locale)
  if type(locale) ~= "string" or type(pfDB) ~= "table" then return false end

  for _, database in pairs(required) do
    if type(pfDB[database]) ~= "table"
        or type(pfDB[database][locale]) ~= "table" then
      return false
    end
  end

  return true
end

local function ClearPartialLocale(locale)
  if locale == "enUS" or type(pfDB) ~= "table" then return end

  for _, database in pairs(required) do
    if type(pfDB[database]) == "table" then
      pfDB[database][locale] = nil
    end
  end
end

local function SetStartupStatus(locale, loaded, pack, status, detail)
  EV.localeRequested = locale
  EV.localeLoaded = loaded
  EV.localePack = pack
  EV.localeStatus = status
  EV.localeError = detail
  EV.localeFallback = loaded ~= locale and loaded or nil
end

function EV:LoadLocaleDatabase(locale, purpose)
  locale = type(locale) == "string" and locale or "enUS"
  purpose = purpose or "runtime"

  local startup = purpose == "startup"
  local pack = self.localePacks[locale]
  self.localeLastRequested = locale
  self.localeLastPurpose = purpose
  self.localeLastPack = pack
  self.localeLastError = nil

  if locale == "enUS" then
    if HasCompleteLocale("enUS") then
      self.localeLastLoaded = "enUS"
      self.localeLastStatus = "core"
      if startup then SetStartupStatus(locale, "enUS", nil, "core", nil) end
      return true
    end

    self.localeLastStatus = "failed"
    self.localeLastError = "INCOMPLETE_ENUS"
    if startup then SetStartupStatus(locale, nil, nil, "failed", self.localeLastError) end
    return false, self.localeLastError
  end

  if not pack then
    if not HasCompleteLocale("enUS") then
      self.localeLastLoaded = nil
      self.localeLastStatus = "failed"
      self.localeLastError = "INCOMPLETE_ENUS"
      if startup then
        SetStartupStatus(locale, nil, nil, "failed", self.localeLastError)
      end
      return false, self.localeLastError
    end

    self.localeLastLoaded = "enUS"
    self.localeLastStatus = "fallback"
    self.localeLastError = "UNSUPPORTED_LOCALE"
    if startup then
      SetStartupStatus(locale, "enUS", nil, "fallback", self.localeLastError)
    end
    return false, self.localeLastError
  end

  if HasCompleteLocale(locale) then
    self.localeLastLoaded = locale
    self.localeLastStatus = "loaded"
    if startup then SetStartupStatus(locale, locale, pack, "loaded", nil) end
    return true
  end

  local loaded, loadError
  if type(LoadAddOn) == "function" then
    local ok, result, detail = pcall(LoadAddOn, pack)
    if ok then
      loaded = result
      loadError = detail
    else
      loadError = result
    end

    -- Emberveil can register a newly installed LoadOnDemand addon as disabled
    -- in the account AddOns.json. Enable and retry only the one locale the
    -- player actually requested; never wake the other seven packs.
    if not HasCompleteLocale(locale)
        and tostring(loadError) == "DISABLED"
        and type(EnableAddOn) == "function" then
      local enabled, enableError = pcall(EnableAddOn, pack)
      if enabled then
        self.localeLastAutoEnabled = pack
        local retryOK, retryResult, retryDetail = pcall(LoadAddOn, pack)
        if retryOK then
          loaded = retryResult
          loadError = retryDetail
        else
          loadError = retryResult
        end
      else
        loadError = enableError
      end
    end
  else
    loadError = "LOADADDON_UNAVAILABLE"
  end

  if HasCompleteLocale(locale) then
    self.localeLastLoaded = locale
    self.localeLastStatus = "loaded"
    if startup then SetStartupStatus(locale, locale, pack, "loaded", nil) end
    return true
  end

  -- A script error can leave only some of a locale's six tables assigned.
  -- Never let database.lua select a mixed/partial language pack.
  ClearPartialLocale(locale)

  if not HasCompleteLocale("enUS") then
    self.localeLastLoaded = nil
    self.localeLastStatus = "failed"
    self.localeLastError = "INCOMPLETE_ENUS"
    if startup then
      SetStartupStatus(locale, nil, pack, "failed", self.localeLastError)
    end
    return false, self.localeLastError
  end

  self.localeLastLoaded = "enUS"
  self.localeLastStatus = "fallback"
  self.localeLastError = loadError or (loaded and "INCOMPLETE_LOCALE" or "LOAD_FAILED")
  if startup then
    SetStartupStatus(locale, "enUS", pack, "fallback", self.localeLastError)
  end
  return false, self.localeLastError
end

local requested = "enUS"
if type(GetLocale) == "function" then
  local ok, locale = pcall(GetLocale)
  if ok and type(locale) == "string" then requested = locale end
end
-- The database historically uses enUS as the shared English key.
if requested == "enGB" then requested = "enUS" end

local loaded, detail = EV:LoadLocaleDatabase(requested, "startup")
if not loaded and requested ~= "enUS" and EV.Chat then
  EV.Chat("locale database " .. tostring(requested) .. " unavailable ("
    .. tostring(detail) .. "); using English.")
end
