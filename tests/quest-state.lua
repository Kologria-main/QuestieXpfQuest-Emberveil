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
}

pfQuestCompat = {
  GetQuestLogTitle = function(id)
    if scenario.titleError then error("simulated title API failure") end
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

dofile("addon/pfQuest/compat/emberveil.lua")

scenario.complete = 1
scenario.objectives = {}
scenario.objectiveCount = 0
assertEqual(QuestieEV:GetQuestLogEntryState(1), "complete", "explicit completion")

scenario.complete = -1
scenario.objectives = { 1, 1 }
scenario.objectiveCount = 2
assertEqual(select(6, pfQuestCompat.GetQuestLogTitle(1)), -1, "failed flag preservation")
assertEqual(QuestieEV:GetQuestLogEntryState(1), "failed", "explicit failure")
assertEqual(QuestieEV:IsQuestLogEntryComplete(1), false, "failed is not complete")
assertEqual(QuestieEV:IsQuestLogEntryFailed(1), true, "failed predicate")

scenario.complete = nil
scenario.objectives = { 1, 1 }
scenario.objectiveCount = 2
assertEqual(QuestieEV:GetQuestLogEntryState(1), "incomplete",
  "finished counters do not override quest-level state")

scenario.complete = nil
scenario.objectives = { 1, nil }
scenario.objectiveCount = 2
assertEqual(QuestieEV:GetQuestLogEntryState(1), "incomplete", "unfinished objective")

scenario.complete = nil
scenario.objectives = {}
scenario.objectiveCount = 0
assertEqual(QuestieEV:GetQuestLogEntryState(1), "incomplete", "zero-objective quest")

scenario.complete = 0
assertEqual(select(6, pfQuestCompat.GetQuestLogTitle(1)), nil, "numeric zero normalization")
assertEqual(QuestieEV:GetQuestLogEntryState(1), "incomplete", "numeric zero is incomplete")

scenario.complete = nil
scenario.titleError = true
scenario.objectives = { 1 }
scenario.objectiveCount = 1
assertEqual(QuestieEV:GetQuestLogEntryState(1), "incomplete", "title API failure is fail-closed")
scenario.titleError = false

scenario.objectiveError = true
assertEqual(QuestieEV:GetQuestLogEntryState(1), "incomplete", "objective API failure is fail-closed")
scenario.objectiveError = false

assertEqual(QuestieEV:GetQuestLogEntryState(0), "incomplete", "invalid quest index")

-- Available quest starters require character-wide history, not merely the
-- completions observed since this addon was installed.
pfQuest = {
  resetCount = 0,
  ResetAll = function(self) self.resetCount = self.resetCount + 1 end,
}
pfMap = {}
pfQuest_history = { [7] = { 1, 10 } }

assertEqual(QuestieEV:CanRenderAvailableQuests(), false, "initial available-quest gate")
QuestieEV:UseLocalQuestHistory("test-local-only")
assertEqual(QuestieEV.questStateReady, true, "local history permits active rendering")
assertEqual(QuestieEV.questHistoryAuthoritative, false, "local history is not authoritative")
assertEqual(QuestieEV:CanRenderAvailableQuests(), false, "local history hides available starters")

assertEqual(QuestieEV:AcceptCompletedQuestSnapshot({ [7] = true, [42] = true }, "test-server"), true,
  "server snapshot accepted")
assertEqual(QuestieEV.questHistoryAuthoritative, true, "server history is authoritative")
assertEqual(QuestieEV:CanRenderAvailableQuests(), true, "server history enables available starters")
assertEqual(pfQuest_history[42] ~= nil, true, "server completion is recorded")

assertEqual(QuestieEV:RecordQuestRemoval(88, "track|state=complete1done", false), "complete",
  "explicitly complete removal")
assertEqual(pfQuest_history[88] ~= nil, true, "explicit completion extends local history")
assertEqual(QuestieEV:CanRenderAvailableQuests(), false, "removal invalidates snapshot until refresh")

QuestieEV:UseLocalQuestHistory("test-after-removal")
pfQuest_history[99] = { 1, 10 }
assertEqual(QuestieEV:RecordQuestRemoval(99, "|state=failed1done", false), "uncertain",
  "failed removal is not completion")
assertEqual(pfQuest_history[99], nil, "failed removal clears false completion")

pfQuest_history[100] = { 1, 10 }
assertEqual(QuestieEV:RecordQuestRemoval(100, "|state=incomplete1todo", true), "abandoned",
  "abandoned removal")
assertEqual(pfQuest_history[100], nil, "abandonment is not completion")

assertEqual(QuestieEV:RecordQuestRemoval(101, "|state=incomplete", false, true), "complete",
  "documented reward call closes fast-turn-in race")
assertEqual(pfQuest_history[101] ~= nil, true, "rewarded quest extends local history")
assertEqual(QuestieEV:AcceptCompletedQuestSnapshot({ [7] = true }, "test-stale-server"), true,
  "stale server snapshot accepted safely")
assertEqual(pfQuest_history[101] ~= nil, true, "session-confirmed turn-in survives stale snapshot")

print("PASS: canonical quest state and completed-history gate scenarios passed.")
