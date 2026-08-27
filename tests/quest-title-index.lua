local questLogTitles = {
  [1] = { "A Unique Quest", 10 },
  [2] = { "Another Quest", 20 },
  [3] = { "Server Renamed Quest", 30 },
  [4] = { "Duplicate Quest", 10 },
}

pfQuestCompat = {
  client = 11200,
  GetQuestLogTitle = function(index)
    local data = questLogTitles[index]
    if not data then return nil, nil, nil, true end
    return data[1], data[2], nil, false
  end,
}

function GetLocale() return "enUS" end
function GetQuestLogSelection() return 0 end
function SelectQuestLogEntry() end
function GetQuestLogQuestText() return "Preferred description", "Preferred objective" end
function UnitRace() return "Human", "Human", 1 end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function UnitFactionGroup() return "Alliance" end
function UnitName() return "Tester" end
function UnitSex() return 2 end
strlower = string.lower
max = math.max
table.getn = table.getn or function(value) return #value end
bit = { band = function(left, right) return left == right and right or 0 end }

UIParent = {}
function CreateFrame()
  local frame = {}
  function frame:RegisterEvent() end
  function frame:SetScript() end
  function frame:Show() end
  function frame:Hide() end
  function frame:UnregisterAllEvents() end
  return frame
end

pfDB = {
  ["areatrigger"] = { ["data"] = {} },
  ["items"] = { ["data"] = {}, ["enUS"] = { [1] = "Item" } },
  ["meta"] = {},
  ["meta-tbc"] = {},
  ["minimap"] = {},
  ["minimap-tbc"] = {},
  ["objects"] = { ["data"] = {}, ["enUS"] = { [1] = "Object" } },
  ["professions"] = { ["data"] = {}, ["enUS"] = { [1] = "Profession" } },
  ["quests"] = {
    ["data"] = {
      [101] = {},
      [102] = {},
      [103] = { ["lvl"] = 10 },
      [104] = { ["lvl"] = 20 },
    },
    ["enUS"] = {
      [101] = { ["T"] = "A Unique Quest", ["O"] = "", ["D"] = "" },
      [102] = { ["T"] = "Another Quest", ["O"] = "", ["D"] = "" },
      [103] = { ["T"] = "Duplicate Quest", ["O"] = "Preferred objective", ["D"] = "Preferred description" },
      [104] = { ["T"] = "Duplicate Quest", ["O"] = "Different objective", ["D"] = "Different description" },
    },
  },
  ["quests-itemreq"] = { ["data"] = {} },
  ["refloot"] = { ["data"] = {} },
  ["units"] = { ["data"] = {}, ["enUS"] = { [1] = "Unit" } },
  ["zones"] = { ["data"] = {}, ["enUS"] = { [1] = "Zone" } },
}

dofile("addon/pfQuest/database.lua")

local ids = pfDatabase:GetQuestIDs(1)
assert(ids[1] == 101, "first exact-title lookup returned the wrong quest")
assert(pfDatabase.questTitleIndexBuilds == 1, "first lookup did not build one index")
assert(pfDatabase.questTitleIndexEntries == 3, "title index has the wrong size")
assert(pfDatabase.questTitleIndexDuplicates == 1, "duplicate title count is wrong")
assert((pfDatabase.questTitleIndexHits or 0) == 0, "first lookup was incorrectly counted as a hit")

ids = pfDatabase:GetQuestIDs(2)
assert(ids[1] == 102, "second exact-title lookup returned the wrong quest")
assert(pfDatabase.questTitleIndexBuilds == 1, "second lookup rebuilt the index")
assert(pfDatabase.questTitleIndexHits == 1, "second lookup did not hit the index")

ids = pfDatabase:GetQuestIDs(3)
assert(ids[1] == "Server Renamed Quest", "unknown title did not fail closed")
assert(pfDatabase.questTitleIndexBuilds == 1, "unknown title rebuilt the index")
assert(pfDatabase.questTitleIndexHits == 2, "unknown title did not use the index")

ids = pfDatabase:GetQuestIDs(4)
assert(#ids == 1 and ids[1] == 103, "duplicate-title disambiguation changed")
assert(pfDatabase.questTitleIndexBuilds == 1, "duplicate lookup rebuilt the index")
assert(pfDatabase.questTitleIndexHits == 3, "duplicate lookup did not use the index")

pfDatabase.Reload()
ids = pfDatabase:GetQuestIDs(1)
assert(ids[1] == 101, "lookup failed after database reload")
assert(pfDatabase.questTitleIndexBuilds == 2, "database reload did not invalidate the index")

print("PASS: exact quest-title lookups build once and then use the lazy index.")
