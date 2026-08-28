-- Executes the real compatibility layer against a minimal Emberveil/WoW mock.
-- This is a development test and is never loaded by the game client.

getfenv = function() return _G end
UIParent = {}
QuestDifficultyColor = {}

local scenario = {
  complete = nil,
  objectives = {},
  objectiveCount = 0,
  titleError = false,
  objectiveError = false,
  entries = 1,
  rows = nil,
}

KoQuestCompat = {
  GetQuestLogTitle = function(id)
    if scenario.titleError then error("simulated title API failure") end
    local row = scenario.rows and scenario.rows[id]
    if row then
      return row.title, row.level, row.tag, row.header, row.collapsed, row.complete
    end
    return "Test Quest", 10, nil, nil, nil, scenario.complete
  end,
}

function GetPlayerMapPosition() return 0.5, 0.5 end
function SetMapToCurrentZone() end
function GetQuestLogSelection() return 1 end
function UnitLevel() return 10 end
function GetQuestGreenRange() return 5 end
function GetTime() return 100 end
function time() return 100 end
function GetNumQuestLogEntries() return scenario.entries end

function GetNumQuestLeaderBoards()
  return scenario.objectiveCount
end

function GetQuestLogLeaderBoard(index)
  if scenario.objectiveError then error("simulated objective API failure") end
  local done = scenario.objectives[index]
  return "Objective: 1/1", "Item", done
end

function CreateFrame()
  local frame = {}
  function frame:RegisterEvent() end
  function frame:SetScript() end
  return frame
end

local function assertEqual(actual, expected, name)
  if actual ~= expected then
    error(name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

dofile("addon/KoQuest/compat/emberveil.lua")

scenario.complete = 1
scenario.objectives = {}
scenario.objectiveCount = 0
assertEqual(KoQuestEV:GetQuestLogEntryState(1), "complete", "explicit completion")

scenario.complete = -1
scenario.objectives = { 1, 1 }
scenario.objectiveCount = 2
assertEqual(select(6, KoQuestCompat.GetQuestLogTitle(1)), -1, "failed flag preservation")
assertEqual(KoQuestEV:GetQuestLogEntryState(1), "failed", "explicit failure")
assertEqual(KoQuestEV:IsQuestLogEntryComplete(1), false, "failed is not complete")
assertEqual(KoQuestEV:IsQuestLogEntryFailed(1), true, "failed predicate")

scenario.complete = nil
scenario.objectives = { 1, 1 }
scenario.objectiveCount = 2
assertEqual(KoQuestEV:GetQuestLogEntryState(1), "incomplete",
  "finished counters do not override quest-level state")

scenario.complete = nil
scenario.objectives = { 1, nil }
scenario.objectiveCount = 2
assertEqual(KoQuestEV:GetQuestLogEntryState(1), "incomplete", "unfinished objective")

scenario.complete = nil
scenario.objectives = {}
scenario.objectiveCount = 0
assertEqual(KoQuestEV:GetQuestLogEntryState(1), "incomplete", "zero-objective quest")

scenario.complete = 0
assertEqual(select(6, KoQuestCompat.GetQuestLogTitle(1)), nil, "numeric zero normalization")
assertEqual(KoQuestEV:GetQuestLogEntryState(1), "incomplete", "numeric zero is incomplete")

assertEqual(KoQuestEV.CleanQuestLogTitle("|cffffcc00[24+] |r[15G5] Weapons of Choice"),
  "Weapons of Choice", "localized level-prefix cleanup")
assertEqual(KoQuestEV.CleanQuestLogTitle("[Story] A Genuine Title"),
  "[Story] A Genuine Title", "genuine bracketed title preservation")

CT_QuestLevels_oldGetQuestLogTitle = function()
  return "[24] Dynamic Original", 24, nil, nil, nil, nil
end
assertEqual(KoQuestCompat.GetQuestLogTitle(1), "Dynamic Original",
  "late CT_QuestLevels getter resolution")
CT_QuestLevels_oldGetQuestLogTitle = nil

scenario.complete = nil
scenario.titleError = true
scenario.objectives = { 1 }
scenario.objectiveCount = 1
assertEqual(KoQuestEV:GetQuestLogEntryState(1), "incomplete", "title API failure is fail-closed")
scenario.titleError = false

scenario.objectiveError = true
assertEqual(KoQuestEV:GetQuestLogEntryState(1), "incomplete", "objective API failure is fail-closed")
scenario.objectiveError = false

assertEqual(KoQuestEV:GetQuestLogEntryState(0), "incomplete", "invalid quest index")

scenario.entries = 3
scenario.rows = {
  { title = "Zone", header = true, collapsed = true },
  { title = "Visible Quest", level = 10 },
  { title = "Another Zone", header = true, collapsed = false },
}
local entries, quests, completeSnapshot = KoQuestEV:GetQuestLogCounts()
assertEqual(entries, 3, "visible row count")
assertEqual(quests, 1, "visible quest count")
assertEqual(completeSnapshot, false, "collapsed header marks snapshot incomplete")

local hiddenQuest = { title = "Hidden Quest", qlogid = 2, state = "track|state=incomplete" }
local currentQuest = { title = "Visible Quest", qlogid = 2, state = "|state=incomplete" }
local previous = { [101] = hiddenQuest, [102] = currentQuest }
local current = { [102] = currentQuest }
KoQuestEV:PreserveHiddenQuestLog(previous, current, false)
assertEqual(current[101], hiddenQuest, "collapsed snapshot preserves hidden quest")
local completeCurrent = { [102] = currentQuest }
KoQuestEV:PreserveHiddenQuestLog(previous, completeCurrent, true)
assertEqual(completeCurrent[101], nil, "complete snapshot permits removal")
scenario.entries = 1
scenario.rows = nil

-- Available quest starters require character-wide history, not merely the
-- completions observed since this addon was installed.
KoQuest = {
  resetCount = 0,
  ResetAll = function(self) self.resetCount = self.resetCount + 1 end,
}
KoMap = {}
KoQuest_history = { [7] = { 1, 10 } }
KoQuest_config = { unverifiedquestgivers = "0" }

assertEqual(KoQuestEV:CanRenderAvailableQuests(), false, "initial available-quest gate")
KoQuestEV:UseLocalQuestHistory("test-local-only")
assertEqual(KoQuestEV.questStateReady, true, "local history permits active rendering")
assertEqual(KoQuestEV.questHistoryAuthoritative, false, "local history is not authoritative")
assertEqual(KoQuestEV:CanRenderAvailableQuests(), false, "local-only history fails closed")
assertEqual(KoQuestEV.availableQuestMode, "strict-hidden", "strict available-quest mode")
KoQuest_config.unverifiedquestgivers = "1"
assertEqual(KoQuestEV:CanRenderAvailableQuests(), true, "explicit opt-in enables best-effort markers")
assertEqual(KoQuestEV.availableQuestMode, "local-best-effort", "opt-in best-effort availability mode")
KoQuest_config.unverifiedquestgivers = "0"

KoQuest.questlog = {}
KoQuest_confirmedAvailable = {}
KoDatabase = {
  GetIDByName = function(_, title)
    if title == "The People's Militia" then return { [12] = true } end
    if title == "Ambiguous Quest" then return { [20] = true, [21] = true } end
    return {}
  end,
}
assertEqual(KoQuestEV:ConfirmAvailableQuestTitle("The People's Militia", "QUEST_DETAIL"), true,
  "client-confirmed quest is recorded")
assertEqual(KoQuestEV:IsClientConfirmedAvailableQuest(12), true,
  "strict mode permits exact client-confirmed quest")
assertEqual(KoQuestEV:HasClientConfirmedAvailableQuests(), true,
  "confirmed quest presence is detected")
assertEqual(KoQuestEV:ConfirmAvailableQuestTitle("Ambiguous Quest", "QUEST_DETAIL"), false,
  "ambiguous dialog title fails closed")
KoQuest_history[12] = { 1, 10 }
assertEqual(KoQuestEV:IsClientConfirmedAvailableQuest(12), false,
  "completed client-confirmed quest is removed")
assertEqual(KoQuest_confirmedAvailable[12], nil,
  "completed client-confirmed quest does not persist")
KoQuest_history[12] = nil

assertEqual(KoQuestEV:AcceptCompletedQuestSnapshot({ [7] = true, [42] = true }, "test-server"), true,
  "server snapshot accepted")
assertEqual(KoQuestEV.questHistoryAuthoritative, true, "server history is authoritative")
assertEqual(KoQuestEV:CanRenderAvailableQuests(), true, "server history enables available starters")
assertEqual(KoQuest_history[42] ~= nil, true, "server completion is recorded")

assertEqual(KoQuestEV:RecordQuestRemoval(88, "track|state=complete1done", false), "complete",
  "explicitly complete removal")
assertEqual(KoQuest_history[88] ~= nil, true, "explicit completion extends local history")
assertEqual(KoQuestEV:CanRenderAvailableQuests(), false,
  "removal returns to strict mode when no server history API exists")

KoQuestEV:UseLocalQuestHistory("test-after-removal")
KoQuest_history[99] = { 1, 10 }
assertEqual(KoQuestEV:RecordQuestRemoval(99, "|state=failed1done", false), "uncertain",
  "failed removal is not completion")
assertEqual(KoQuest_history[99], nil, "failed removal clears false completion")

KoQuest_history[100] = { 1, 10 }
assertEqual(KoQuestEV:RecordQuestRemoval(100, "|state=incomplete1todo", true), "abandoned",
  "abandoned removal")
assertEqual(KoQuest_history[100], nil, "abandonment is not completion")

assertEqual(KoQuestEV:RecordQuestRemoval(101, "|state=incomplete", false, true), "complete",
  "documented reward call closes fast-turn-in race")
assertEqual(KoQuest_history[101] ~= nil, true, "rewarded quest extends local history")
assertEqual(KoQuestEV:AcceptCompletedQuestSnapshot({ [7] = true }, "test-stale-server"), true,
  "stale server snapshot accepted safely")
assertEqual(KoQuest_history[101] ~= nil, true, "session-confirmed turn-in survives stale snapshot")

print("PASS: canonical quest state and completed-history gate scenarios passed.")
