-- some abstraction to allow multi-client code
local _, _, _, client = GetBuildInfo()
client = client or 11200

local _G = client == 11200 and getfenv(0) or _G
local gfind = string.gmatch or string.gfind

KoQuestCompat = {}
KoQuestCompat.mod = mod or math.mod
KoQuestCompat.gfind = string.gmatch or string.gfind
KoQuestCompat.itemsuffix = client > 11200 and ":0:0:0:0:0:0:0" or ":0:0:0"
KoQuestCompat.rotateMinimap = client > 11200 and GetCVar("rotateMinimap") ~= "0" and true or nil
KoQuestCompat.client = client

-- addon-compat: use and cache the original function if CTMod overwrites global API calls
local GetQuestLogTitle = CT_QuestLevels_oldGetQuestLogTitle or GetQuestLogTitle

-- tbc+wotlk: change behaviour of later expansions to the vanilla one
KoQuestCompat.GetQuestLogTitle = function(id)
  local title, level, tag, group, header, collapsed, complete, daily, _
  if client <= 11200 then -- vanilla
    title, level, tag, header, collapsed, complete = GetQuestLogTitle(id)
  elseif client > 11200 then -- tbc & wotlk
    title, level, tag, group, header, collapsed, complete, daily = GetQuestLogTitle(id)
  end

  return title, level, tag, header, collapsed, complete
end

-- wotlk: changed from GetDifficultyColor to GetQuestDifficultyColor in 3.2
KoQuestCompat.GetDifficultyColor = GetQuestDifficultyColor or GetDifficultyColor

-- wotlk: changed from QuestWatchFrame to WatchFrame in 3.3
KoQuestCompat.QuestWatchFrame = QuestWatchFrame or WatchFrame

-- wotlk: changed questlog related frame names in 3.3
KoQuestCompat.QuestLogQuestTitle = QuestLogQuestTitle or QuestInfoTitleHeader
KoQuestCompat.QuestLogObjectivesText = QuestLogObjectivesText or QuestInfoObjectivesText
KoQuestCompat.QuestLogQuestDescription = QuestLogQuestDescription or QuestInfoDescriptionText
KoQuestCompat.QuestLogDescriptionTitle = QuestLogDescriptionTitle or QuestInfoDescriptionHeader

-- wotlk: disable builtin quest progress tooltips
if client >= 30300 then
  SetCVar("showQuestTrackingTooltips", 0)
end

-- vanilla+tbc+wotlk: base function to insert quest links to the chat
KoQuestCompat.InsertQuestLink = function(questid, name)
  local questid = questid or 0
  local fallback = name or UNKNOWN
  local level = KoDB["quests"]["data"][questid] and KoDB["quests"]["data"][questid]["lvl"] or 0
  local name = KoDB["quests"]["loc"][questid] and KoDB["quests"]["loc"][questid]["T"] or fallback
  local hex = pfUI.api.rgbhex(KoQuestCompat.GetDifficultyColor(level))

  ChatFrameEditBox:Show()
  if KoQuest_config["questlinks"] == "1" then
    ChatFrameEditBox:Insert(hex .. "|Hquest:" .. questid .. ":" .. level .. "|h[" .. name .. "]|h|r")
  else
    ChatFrameEditBox:Insert("[" .. name .. "]")
  end
end

-- Emberveil: Vanilla Minimap Model discovery is unsafe on Unreal-backed UI.
local minimaparrow = nil
KoQuestCompat.GetPlayerFacing = function()
  return nil
end
-- Emberveil: keep the client's own memory-exhaustion dialog untouched.
-- Upstream's Vanilla replacement enumerates native regions and invokes
-- ForceQuit(), neither of which is needed by the addon or safe to assume on
-- Unreal-backed UI bridge objects.

-- vanilla: add colors to quest links
if client <= 11200 then
  local ParseQuestLevels = function(frame, text, a1, a2, a3, a4, a5)
    if text then
      for oldhex, questid, level in gfind(text, "(|c%x+)|Hquest:(.-):(.-)|h") do
        local questid = tonumber(questid)
        local level = tonumber(level)

        if not level or level == 0 then
          level = KoDB["quests"]["data"][questid] and KoDB["quests"]["data"][questid]["lvl"] or 0
        end

        if level and level > 0 then
          local newhex = pfUI.api.rgbhex(KoQuestCompat.GetDifficultyColor(level))
          text = string.gsub(text, oldhex .. "|Hquest:"..questid, newhex.."|Hquest:"..questid)
        end
      end
    end

    frame.KoQuestHookAddMessage(frame, text, a1, a2, a3, a4, a5)
  end

  for i=1,NUM_CHAT_WINDOWS do
    _G["ChatFrame"..i].KoQuestHookAddMessage = _G["ChatFrame"..i].KoQuestHookAddMessage or _G["ChatFrame"..i].AddMessage
    _G["ChatFrame"..i].AddMessage = ParseQuestLevels
  end
end
