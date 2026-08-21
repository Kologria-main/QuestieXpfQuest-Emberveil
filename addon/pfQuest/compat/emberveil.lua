-- Questie Emberveil / pfQuest engine
-- Early compatibility layer v2.0.0-beta1.18

QuestieEV = QuestieEV or {}
local EV = QuestieEV
EV.version = "2.0.0-beta1.18"
EV.engine = "pfQuest"
EV.sourceCommit = "104f35678ca39ab1fb78b655f815cc7016f5e0c8"

-- Emberveil: native MouseIsOver() against Unreal-backed UI bridge objects
-- is not safe enough for pfQuest's high-frequency hover polling.
function QuestieEV_MouseIsOverDisabled(frame)
  return false
end

local _G = getfenv(0)

-- beta1.8 stable-core policy:
-- Never force Emberveil's native map context from pfQuest.
--
-- IMPORTANT: the raw function is stored under a field name that does NOT
-- contain "GetPlayerMapPosition". This prevents installer call-rewriters from
-- ever rewriting the wrapper's own backing function again.
EV._rawPlayerMapPos = EV._rawPlayerMapPos or _G["GetPlayerMapPosition"]
EV._rawSetCurrentZone = EV._rawSetCurrentZone or _G["SetMapToCurrentZone"]

function QuestieEV_SafeGetPlayerMapPosition(unit)
  local fn = EV._rawPlayerMapPos

  if type(fn) ~= "function" then
    fn = _G and _G["GetPlayerMapPosition"] or nil
    EV._rawPlayerMapPos = fn
  end

  if type(fn) == "function" then
    local ok, x, y = pcall(fn, unit)
    if ok then
      return x or 0, y or 0
    end
  end

  return 0, 0
end

function QuestieEV_SafeSetMapToCurrentZone()
  -- Upstream pfQuest is NEVER allowed to drive Azeroth's native map state.
  -- beta1.11 uses EV._rawSetCurrentZone only from one tightly controlled,
  -- post-login/hidden-map recovery path in emberveil_map.lua.
  return false
end

EV.mapRuntimeReady = false
EV.mapRuntimeReadyAt = nil

-- Quest-state correctness gate. Until this becomes true, the map engine hides
-- PFQUEST quest markers instead of displaying potentially stale data.
EV.questStateReady = false
EV.questSyncPending = false
EV.questSyncWaiting = false
EV.questSyncDone = false
EV.questSyncSource = "pending"
EV.questSyncCount = 0
EV.questSyncDeadline = nil
EV.questSyncAt = nil
-- Emberveil does not currently expose a documented bulk completed-quest API.
-- Keep this flag for diagnostics: when false, available quest markers use
-- pfQuest's classic local-history model. That can include a previously
-- completed pre-install quest, but must NOT disable all live quest-giver
-- markers for the entire character.
EV.questHistoryAuthoritative = false
EV.availableQuestMode = "pending"
EV.sessionConfirmedCompletions = EV.sessionConfirmedCompletions or {}

local function chat(msg)
  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccQuestie EV:|r " .. tostring(msg))
  end
end
EV.Chat = chat

-- =========================================================================
-- FrameXML compatibility: GetDifficultyColor
-- =========================================================================
-- Azeroth's in-world native API reference does not expose GetDifficultyColor
-- because this is historically a FrameXML helper rather than a C API global.
-- Some Azeroth /reload paths can reach TargetFrame_CheckLevel before that
-- helper exists. Never overwrite a healthy FrameXML implementation; install
-- the exact Vanilla-style fallback only when the global is missing.
if type(QuestDifficultyColor) ~= "table" then
  QuestDifficultyColor = {}
end

QuestDifficultyColor["impossible"] =
  QuestDifficultyColor["impossible"] or { r = 1.00, g = 0.10, b = 0.10 }
QuestDifficultyColor["verydifficult"] =
  QuestDifficultyColor["verydifficult"] or { r = 1.00, g = 0.50, b = 0.25 }
QuestDifficultyColor["difficult"] =
  QuestDifficultyColor["difficult"] or { r = 1.00, g = 1.00, b = 0.00 }
QuestDifficultyColor["standard"] =
  QuestDifficultyColor["standard"] or { r = 0.25, g = 0.75, b = 0.25 }
QuestDifficultyColor["trivial"] =
  QuestDifficultyColor["trivial"] or { r = 0.50, g = 0.50, b = 0.50 }
QuestDifficultyColor["header"] =
  QuestDifficultyColor["header"] or { r = 0.70, g = 0.70, b = 0.70 }

if type(GetDifficultyColor) ~= "function" then
  function GetDifficultyColor(level)
    local targetLevel = tonumber(level) or 0
    local playerLevel = type(UnitLevel) == "function"
      and (tonumber(UnitLevel("player")) or 0) or 0
    local levelDiff = targetLevel - playerLevel
    local greenRange = type(GetQuestGreenRange) == "function"
      and (tonumber(GetQuestGreenRange()) or 0) or 0

    if levelDiff >= 5 then
      return QuestDifficultyColor["impossible"]
    elseif levelDiff >= 3 then
      return QuestDifficultyColor["verydifficult"]
    elseif levelDiff >= -2 then
      return QuestDifficultyColor["difficult"]
    elseif -levelDiff <= greenRange then
      return QuestDifficultyColor["standard"]
    else
      return QuestDifficultyColor["trivial"]
    end
  end

  EV.difficultyColorFallback = true
else
  EV.difficultyColorFallback = false
end

-- compat/client.lua is loaded immediately before this layer. If it captured a
-- nil FrameXML helper, repair pfQuest's private pointer as well.
if pfQuestCompat and type(pfQuestCompat.GetDifficultyColor) ~= "function"
    and type(GetDifficultyColor) == "function" then
  pfQuestCompat.GetDifficultyColor = GetDifficultyColor
end

-- Emberveil implements the Vanilla API surface, but some return conventions
-- differ. Force pfQuest's internal compatibility mode to the Vanilla branch.
if pfQuestCompat then
  pfQuestCompat.client = 11200
  pfQuestCompat.rotateMinimap = nil
end

-- Restore Vanilla's selected-quest semantics and normalize Emberveil's
-- capitalized objective types ("Item" -> "item", etc.).
--
-- Also normalize quest completion to the documented three-state convention:
--   1 = complete, -1 = failed, nil = incomplete.
-- A numeric 0 must NEVER be treated as complete just because Lua considers it
-- truthy, and -1 must never be collapsed into either complete or incomplete.
EV._rawCompatQuestLogTitle = EV._rawCompatQuestLogTitle or
  (pfQuestCompat and pfQuestCompat.GetQuestLogTitle)

if pfQuestCompat and type(EV._rawCompatQuestLogTitle) == "function" then
  pfQuestCompat.GetQuestLogTitle = function(id)
    local ok, title, level, tag, header, collapsed, complete =
      pcall(EV._rawCompatQuestLogTitle, id)

    if not ok then return nil, nil, nil, nil, nil, nil end

    if complete == true or complete == 1 then
      complete = 1
    elseif complete == -1 then
      complete = -1
    else
      complete = nil
    end
    return title, level, tag, header, collapsed, complete
  end
end

EV.nativeGetNumQuestLeaderBoards = EV.nativeGetNumQuestLeaderBoards or GetNumQuestLeaderBoards
EV.nativeGetQuestLogLeaderBoard = EV.nativeGetQuestLogLeaderBoard or GetQuestLogLeaderBoard

local function SelectedQuestIndex(questIndex)
  if questIndex == nil or questIndex == 0 then
    if type(GetQuestLogSelection) == "function" then
      local selected = GetQuestLogSelection()
      if selected and selected > 0 then
        return selected
      end
    end
  end
  return questIndex
end

if type(EV.nativeGetNumQuestLeaderBoards) == "function" then
  GetNumQuestLeaderBoards = function(questIndex)
    questIndex = SelectedQuestIndex(questIndex)
    local ok, result
    if questIndex ~= nil then
      ok, result = pcall(EV.nativeGetNumQuestLeaderBoards, questIndex)
    else
      ok, result = pcall(EV.nativeGetNumQuestLeaderBoards)
    end

    if ok and type(result) == "number" and result >= 0 then return result end
    return 0
  end
end

if type(EV.nativeGetQuestLogLeaderBoard) == "function" then
  GetQuestLogLeaderBoard = function(index, questIndex)
    questIndex = SelectedQuestIndex(questIndex)

    local ok, description, objectiveType, complete
    if questIndex ~= nil then
      ok, description, objectiveType, complete =
        pcall(EV.nativeGetQuestLogLeaderBoard, index, questIndex)
    else
      ok, description, objectiveType, complete =
        pcall(EV.nativeGetQuestLogLeaderBoard, index)
    end

    if not ok then return nil, nil, nil end

    if type(objectiveType) == "string" then
      objectiveType = string.lower(objectiveType)
    end

    complete = (complete == true or complete == 1) and 1 or nil
    return description, objectiveType, complete
  end
end

-- Canonical active-quest state used by all Emberveil patches.
--
-- Objective counters are deliberately not promoted to quest completion. A
-- quest may have required money, a hidden/scripted condition, or server-side
-- validation after every visible counter is done. Emberveil's documented
-- quest-level 1 is the only completion proof; -1 is failed and nil/other is
-- incomplete.
function EV:GetQuestLogEntryState(qlogid)
  if type(qlogid) ~= "number" or qlogid <= 0 then return "incomplete" end

  local complete = nil
  if type(self._rawCompatQuestLogTitle) == "function" then
    local ok, _, _, _, _, _, rawComplete =
      pcall(self._rawCompatQuestLogTitle, qlogid)
    if not ok then return "incomplete" end
    complete = rawComplete
  elseif pfQuestCompat and type(pfQuestCompat.GetQuestLogTitle) == "function" then
    local ok, _, _, _, _, _, rawComplete = pcall(pfQuestCompat.GetQuestLogTitle, qlogid)
    if not ok then return "incomplete" end
    complete = rawComplete
  end

  if complete == -1 then return "failed" end
  if complete == true or complete == 1 then
    return "complete"
  end
  return "incomplete"
end

function EV:IsQuestLogEntryComplete(qlogid)
  return self:GetQuestLogEntryState(qlogid) == "complete"
end

function EV:IsQuestLogEntryFailed(qlogid)
  return self:GetQuestLogEntryState(qlogid) == "failed"
end

-- pfQuest's original facing fallback reads a specific unnamed Minimap Model.
-- Emberveil does not currently expose a compatible facing object. Never allow
-- that optional feature to crash core quest/map rendering.
if pfQuestCompat then
  pfQuestCompat.GetPlayerFacing = function()
    return nil
  end
  pfQuestCompat.rotateMinimap = nil
end


-- =========================================================================
-- Authoritative completed-quest synchronization
-- =========================================================================
local function CountTableEntries(tbl)
  if type(tbl) ~= "table" then return 0 end
  local n = 0
  for _ in pairs(tbl) do n = n + 1 end
  return n
end

local function CompletedSnapshotToHistory(snapshot)
  if type(snapshot) ~= "table" then return nil, 0 end

  local history = {}
  local count = 0
  local now = type(time) == "function" and time() or 0
  local level = type(UnitLevel) == "function" and (UnitLevel("player") or 0) or 0
  local old = type(pfQuest_history) == "table" and pfQuest_history or {}

  -- Support both API shapes:
  --   [questID] = true
  -- and modern/sequential:
  --   [1] = questID, [2] = questID, ...
  for key, value in pairs(snapshot) do
    local qid = nil

    if (value == true or value == 1) and tonumber(key) then
      qid = tonumber(key)
    elseif tonumber(value) then
      qid = tonumber(value)
    end

    if qid and qid > 0 and not history[qid] then
      history[qid] = old[qid] or { now, level }
      count = count + 1
    end
  end

  return history, count
end

function EV:CanRenderAvailableQuests()
  -- Live availability must continue to work even when Emberveil lacks a
  -- character-wide completed-quest API. questStateReady means active/local
  -- quest state has been reconciled. questHistoryAuthoritative is diagnostic
  -- quality metadata, not a render kill-switch.
  return self.questStateReady == true
end

function EV:GetQuestLogCounts()
  local entries = 0
  if type(GetNumQuestLogEntries) == "function" then
    local ok, value = pcall(GetNumQuestLogEntries)
    if ok then entries = tonumber(value) or 0 end
  end

  if entries < 0 then entries = 0 end

  local quests = 0
  if pfQuestCompat and type(pfQuestCompat.GetQuestLogTitle) == "function" then
    for index = 1, entries do
      local ok, title, _, _, header =
        pcall(pfQuestCompat.GetQuestLogTitle, index)
      if ok and title and not header then quests = quests + 1 end
    end
  end

  return entries, quests
end

function EV:RebuildAuthoritativeQuestState(reason)
  if pfQuest and pfQuest.ResetAll then
    -- Upstream ResetAll deletes ALL PFQUEST nodes, clears its live questlog and
    -- schedules both active-objective and available-quest reconstruction.
    pfQuest:ResetAll()
  elseif pfQuest then
    pfQuest.questlog = {}
    pfQuest.updateQuestLog = true
    pfQuest.updateQuestGivers = true
  end

  if pfMap then
    pfMap.queue_update = GetTime() + .10
  end
  self.minimapNodeCache = self.minimapNodeCache or {
    mapID = nil, entries = {}, grid = {}, cellSize = 5,
    dirty = true, reason = "quest-reconcile", generation = 0
  }
  self.minimapNodeCache.dirty = true
  self.minimapNodeCache.reason = "quest-reconcile"
  self.minimapForceNext = true
  self.worldMapForceNext = true

  -- The map engine consumes this after both mapRuntimeReady and questStateReady.
  -- It guarantees the minimap is populated without requiring the player to
  -- open the world map once.
  self.renderPrimeRequested = true

  if self.Chat then
    self.Chat("quest state reconciled (" .. tostring(reason) .. ").")
  end
end

function EV:AcceptCompletedQuestSnapshot(snapshot, source)
  local history, count = CompletedSnapshotToHistory(snapshot)
  if type(history) ~= "table" then return false end

  -- A just-awarded quest is known complete even if a server getter briefly
  -- returns its pre-turn-in cache. Keep only those session confirmations the
  -- current server snapshot has not caught up with yet.
  local stillPending = {}
  for qid, record in pairs(self.sessionConfirmedCompletions or {}) do
    if not history[qid] then
      history[qid] = record
      stillPending[qid] = record
      count = count + 1
    end
  end
  self.sessionConfirmedCompletions = stillPending

  -- Server snapshot is authoritative for completed quest IDs. This prevents a
  -- fresh pfQuest install from offering quests that this character completed
  -- before pfQuest was installed.
  pfQuest_history = history

  self.questSyncCount = count
  self.questSyncSource = source or "server"
  self.questSyncPending = false
  self.questSyncWaiting = false
  self.questSyncDone = true
  self.questStateReady = true
  self.questHistoryAuthoritative = true
  self.availableQuestMode = "authoritative"
  self.questSyncDeadline = nil
  self.questSyncAt = nil

  self:RebuildAuthoritativeQuestState(self.questSyncSource)

  if self.Chat then
    self.Chat("completed-quest history synchronized: " ..
      tostring(count) .. " quest(s), source=" .. tostring(self.questSyncSource) .. ".")
  end

  return true
end

function EV:UseLocalQuestHistory(reason)
  pfQuest_history = type(pfQuest_history) == "table" and pfQuest_history or {}

  self.questSyncCount = CountTableEntries(pfQuest_history)
  self.questSyncSource = reason or "local-history"
  self.questSyncPending = false
  self.questSyncWaiting = false
  self.questSyncDone = true
  self.questStateReady = true
  self.questHistoryAuthoritative = false
  self.availableQuestMode = "local-best-effort"
  self.questSyncDeadline = nil
  self.questSyncAt = nil

  self:RebuildAuthoritativeQuestState(self.questSyncSource)

  if self.Chat then
    self.Chat("server completion snapshot unavailable; using classic local quest history (" ..
      tostring(self.questSyncCount) .. " recorded). Live quest-giver markers remain enabled.")
  end
end

-- A quest leaving the log is not proof that it was completed: it may have
-- been abandoned, failed, timed out, or disappeared during a transient API
-- update. Only the last canonical COMPLETE state may extend local history.
-- After every removal, invalidate the character-wide snapshot and request a
-- fresh one. Rendering remains fail-closed while that request is unresolved.
function EV:RecordQuestRemoval(questID, previousState, abandoned, rewarded)
  local id = tonumber(questID)
  if not id or id <= 0 then return "ignored" end

  pfQuest_history = type(pfQuest_history) == "table" and pfQuest_history or {}

  local explicitlyComplete = rewarded == true or (
    type(previousState) == "string"
      and string.find(previousState, "|state=complete", 1, true) ~= nil
  )

  if abandoned then
    pfQuest_history[id] = nil
    self.sessionConfirmedCompletions[id] = nil
  elseif explicitlyComplete then
    local now = type(time) == "function" and time() or 0
    local level = type(UnitLevel) == "function" and (UnitLevel("player") or 0) or 0
    pfQuest_history[id] = pfQuest_history[id] or { now, level }
    self.sessionConfirmedCompletions[id] = pfQuest_history[id]
  else
    pfQuest_history[id] = nil
    self.sessionConfirmedCompletions[id] = nil
  end

  self.questHistoryAuthoritative = false
  self:RequestQuestStateSync(true)

  if abandoned then return "abandoned" end
  if explicitlyComplete then return "complete" end
  return "uncertain"
end

function EV:ReadCompletedQuestSnapshot(source)
  local fn = _G and _G["GetQuestsCompleted"] or nil
  if type(fn) ~= "function" then return false end

  local ok, snapshot = pcall(fn)
  if ok and type(snapshot) == "table" then
    return self:AcceptCompletedQuestSnapshot(snapshot, source)
  end

  return false
end

function EV:RequestQuestStateSync(force)
  if self.questSyncDone and not force then
    self.questStateReady = true
    return
  end

  local getter = _G and _G["GetQuestsCompleted"] or nil
  local query = _G and _G["QueryQuestsCompleted"] or nil
  if type(getter) ~= "function" and type(query) ~= "function" then
    self:UseLocalQuestHistory("local-history-no-server-api")
    return
  end

  self.questStateReady = false
  self.questHistoryAuthoritative = false
  self.availableQuestMode = "sync-pending"
  self.questSyncPending = true
  self.questSyncWaiting = false
  self.questSyncAt = GetTime() + .75
  self.questSyncDeadline = GetTime() + 8.0

  if force then
    self.questSyncDone = false
    self.questSyncSource = "refresh-pending"
  end
end

local questSyncFrame = CreateFrame("Frame", "QuestieEVQuestStateSync", UIParent)
questSyncFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Not every 1.12-style client exposes this later quest-history event.
if pcall and questSyncFrame.RegisterEvent then
  pcall(questSyncFrame.RegisterEvent, questSyncFrame, "QUEST_QUERY_COMPLETE")
end

questSyncFrame:SetScript("OnEvent", function()
  if event == "PLAYER_ENTERING_WORLD" then
    if not EV.questSyncDone then
      EV:RequestQuestStateSync(false)
    else
      EV.questStateReady = true
    end
    return
  end

  if event == "QUEST_QUERY_COMPLETE" and EV.questSyncPending then
    if EV:ReadCompletedQuestSnapshot("QUEST_QUERY_COMPLETE") then
      return
    end
  end
end)

questSyncFrame:SetScript("OnUpdate", function()
  if not EV.questSyncPending then return end

  local now = GetTime()

  if EV.questSyncAt and now >= EV.questSyncAt and not EV.questSyncWaiting then
    EV.questSyncAt = nil

    local query = _G and _G["QueryQuestsCompleted"] or nil
    local getter = _G and _G["GetQuestsCompleted"] or nil

    if type(query) == "function" and type(getter) == "function" then
      local ok = pcall(query)
      if ok then
        EV.questSyncWaiting = true
      else
        -- The bulk getter may still be directly available.
        if EV:ReadCompletedQuestSnapshot("GetQuestsCompleted") then return end
        EV:UseLocalQuestHistory("local-history-query-error")
        return
      end
    elseif type(getter) == "function" then
      if EV:ReadCompletedQuestSnapshot("GetQuestsCompleted") then return end
      EV:UseLocalQuestHistory("local-history-getter-error")
      return
    else
      EV:UseLocalQuestHistory("local-history-no-server-api")
      return
    end
  end

  if EV.questSyncDeadline and now >= EV.questSyncDeadline then
    -- Query may have been throttled by the server. Read any cached result once.
    if EV:ReadCompletedQuestSnapshot("GetQuestsCompleted-timeout") then return end
    EV:UseLocalQuestHistory("local-history-timeout")
  end
end)


chat("pfQuest compatibility pre-layer " .. EV.version .. " loaded.")
