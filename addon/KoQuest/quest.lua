-- multi api compat
local compat = KoQuestCompat
local _, _, _, client = GetBuildInfo()
client = client or 11200
local _G = client == 11200 and getfenv(0) or _G

KoQuest = CreateFrame("Frame")
KoQuest.icons = {}

if client >= 30300 then
  KoQuest.dburl = "https://www.wowhead.com/wotlk/quest="
elseif client >= 20400 then
  KoQuest.dburl = "https://www.wowhead.com/tbc/quest="
else
  KoQuest.dburl = "https://www.wowhead.com/classic/quest="
end

function KoQuest:Debug(msg)
  -- only show debug output if enabled
  if not KoQuest_config.debug and KoQuest.debugwin then
    KoQuest.debugwin:Hide()
    return
  elseif not KoQuest_config.debug then
    return
  end

  if not KoQuest.debugwin then
    KoQuest.debugwin = CreateFrame("ScrollingMessageFrame", nil, UIParent)
    KoQuest.debugwin:SetWidth(320)
    KoQuest.debugwin:SetHeight(320)
    KoQuest.debugwin:SetPoint("RIGHT", -42, 0)
    KoQuest.debugwin:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    KoQuest.debugwin:SetFading(false)
    KoQuest.debugwin:SetMaxLines(150)
    KoQuest.debugwin:SetJustifyH("RIGHT")
    KoQuest.debugwin:SetJustifyV("CENTER")
  end

  KoQuest.debugwin:AddMessage(msg)
  KoQuest.debugwin:Show()
end

function KoQuest:SortedPairs(t, index, reverse)
  -- collect the keys
  local keys = {}
  for k, v in pairs(t) do
    if v then keys[table.getn(keys)+1] = k end
  end

  local order
  if reverse then
    order = function(t,a,b) return t[a][index] < t[b][index] end
  else
    order = function(t,a,b) return t[a][index] > t[b][index] end
  end
  table.sort(keys, function(a,b) return order(t, a, b) end)

  -- return the iterator function
  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], t[keys[i]]
    end
  end
end

KoQuest.queue = {}
KoQuest.abandon = ""
KoQuest.questlog = {}
KoQuest.questlog_tmp = {}
KoQuest.questGiverDirty = false
KoQuest.updateQuestGiversAt = nil

local function tsize(tbl)
  if not tbl or not type(tbl) == "table" then return 0 end
  local c = 0
  for _ in pairs(tbl) do c = c + 1 end
  return c
end

local skillstate = ""
KoQuest:RegisterEvent("QUEST_WATCH_UPDATE")
KoQuest:RegisterEvent("QUEST_LOG_UPDATE")
KoQuest:RegisterEvent("QUEST_FINISHED")
KoQuest:RegisterEvent("PLAYER_LEVEL_UP")
KoQuest:RegisterEvent("PLAYER_ENTERING_WORLD")
KoQuest:RegisterEvent("SKILL_LINES_CHANGED")
KoQuest:RegisterEvent("ADDON_LOADED")
KoQuest:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == "KoQuest" or arg1 == "KoQuest-tbc" or arg1 == "KoQuest-wotlk" then
      KoQuest:AddQuestLogIntegration()
      KoQuest:AddWorldMapIntegration()
      this.lock = GetTime() + 10
    else
      return
    end
  elseif event == "SKILL_LINES_CHANGED" then
    local skills = ""
    for i=0, GetNumSkillLines() do
      skills = skills .. (GetSkillLineInfo(i) or "")
    end

    -- update quest givers when new skills or
    -- professions became available
    if skills ~= skillstate then
      KoQuest.updateQuestGivers = true
      skillstate = skills
    end
  elseif event == "PLAYER_LEVEL_UP" or event == "PLAYER_ENTERING_WORLD" then
    KoQuest.updateQuestGivers = true
  else
    KoQuest.updateQuestLog = true
  end

  if event == "QUEST_LOG_UPDATE" then
    -- lock initial scan during incoming events
    if this.lock and this.lock > GetTime() then
      this.lock = GetTime() + 1.5
    end
  end
end)

KoQuest:SetScript("OnUpdate", function()
  if this.lock and this.lock > GetTime() then return end
  if not KoDatabase.localized then return end

  if ( this.tick or .05) > GetTime() then return else this.tick = GetTime() + .05 end

  -- check questlog each second
  if ( this.qlogtick or 1) < GetTime() then
    if KoQuest:UpdateQuestlog() then
      KoQuest:Debug("Update Quest|cff33ffcc Log|r [|cffff3333Tick|r]")
    end
    this.qlogtick = GetTime() + 1
  end

  if this.updateQuestLog == true and tsize(this.queue) == 0 then
    KoQuest:Debug("Update Quest|cff33ffcc Log")
    KoQuest:UpdateQuestlog()
    this.updateQuestLog = false
  end

  if this.updateQuestGivers == true
      and (not this.updateQuestGiversAt or GetTime() >= this.updateQuestGiversAt) then
    KoQuest:Debug("Update Quest|cff33ffcc Givers")
    if KoQuest_config["trackingmethod"] ~= 4 and
      KoQuest_config["allquestgivers"] == "1"
    then
      local meta = { ["addon"] = "KOQUEST" }
      KoDatabase:SearchQuests(meta)
    end
    this.updateQuestGivers = false
    this.updateQuestGiversAt = nil
  end

  if tsize(this.queue) == 0 then return end

  -- process queue
  for id, entry in pairs(this.queue) do

    -- remove quest
    if entry[4] == "REMOVE" then
      KoQuest:Debug("|cffff5555Remove Quest: " .. entry[1] .. " (" .. entry[2] .. ")")

      -- A disappearing quest is not automatically complete. Preserve local
      -- history only when its last canonical state was explicitly complete,
      -- and request a fresh character-wide snapshot when Emberveil exposes it.
      local abandoned = entry[1] == KoQuest.abandon
      local rewarded = entry[1] == KoQuest.rewarded
        and KoQuest.rewardedAt
        and GetTime() - KoQuest.rewardedAt <= 10
      -- Only a reward/abandon changes quest-giver availability in a way that
      -- requires a global availability reconciliation. A newly accepted quest
      -- already has its starter removed directly below, so rescanning the entire
      -- quest database on acceptance only delays objective rendering.
      if abandoned or rewarded then
        KoQuest.questGiverDirty = true
      end
      if KoQuestEV and KoQuestEV.RecordQuestRemoval then
        KoQuestEV:RecordQuestRemoval(entry[2], entry[5], abandoned, rewarded)
      elseif abandoned then
        KoQuest_history[entry[2]] = nil
      elseif rewarded or (type(entry[5]) == "string"
          and string.find(entry[5], "|state=complete", 1, true)) then
        KoQuest_history[entry[2]] = { time(), UnitLevel("player") }
      else
        KoQuest_history[entry[2]] = nil
      end

      if KoQuest_config["trackingmethod"] ~= 4 then
        -- delete nodes by title
        KoMap:DeleteNode("KOQUEST", entry[1])

        -- also delete nodes by quest ids for servers with different names
        if entry[2] and KoDB["quests"]["loc"][entry[2]] and KoDB["quests"]["loc"][entry[2]].T then
          KoMap:DeleteNode("KOQUEST", KoDB["quests"]["loc"][entry[2]].T)
        end
      end

      KoQuest.abandon = ""
      if rewarded then
        KoQuest.rewarded = ""
        KoQuest.rewardedAt = nil
      end
    else
      if entry[4] == "NEW" then
        KoQuest:Debug("|cff55ff55New Quest: " .. entry[1] .. " (" .. entry[2] .. ")")
      else
        KoQuest:Debug("|cffffff55Update Quest: " .. entry[1] .. " (" .. entry[2] .. ")")
      end

      -- update quest nodes
      if KoQuest_config["trackingmethod"] ~= 4 then
        -- delete node by title
        KoMap:DeleteNode("KOQUEST", entry[1])

        -- delete nodes by quest ids for servers with different names
        if entry[2] and KoDB["quests"]["loc"][entry[2]] and KoDB["quests"]["loc"][entry[2]].T then
          KoMap:DeleteNode("KOQUEST", KoDB["quests"]["loc"][entry[2]].T)
        end

        -- skip quest objective detection on manual and tacked mode
        if KoQuest_config["trackingmethod"] ~= 3 and
          (KoQuest_config["trackingmethod"] ~= 2 or IsQuestWatched(entry[3]))
        then
          local meta = { ["addon"] = "KOQUEST", ["qlogid"] = entry[3] }
          KoDatabase:SearchQuestID(entry[2], meta)
        end
      end
    end

    -- The minimap uses a spatial cache. Quest events can arrive before the
    -- NEW/RELOAD/REMOVE node transaction is finished, so invalidate and render
    -- only after the node mutation above. This prevents a stale-cache rebuild
    -- from adding visible latency after accepting a quest.
    if KoQuestEV and KoQuestEV.NotifyQuestNodesChanged then
      KoQuestEV:NotifyQuestNodesChanged(entry[4])
    end

    -- remove entry from queue
    KoQuest.queue[id] = nil

    -- only return when other entries exist
    -- otherwise, continue and update questgivers
    for id, entry in pairs(this.queue) do
      return
    end
  end

  -- A quest accept/remove can change which starters are available. Objective
  -- progress RELOADs do not, so do not rescan the entire quest database on
  -- every kill/loot update.
  if tsize(this.queue) == 0 then
    this.updateQuestLog = true
    if KoQuestEV and KoQuestEV.EnsureActiveQuestNodes then
      KoQuestEV:EnsureActiveQuestNodes("queue-drained")
    end
    if KoQuest.questGiverDirty then
      this.updateQuestGivers = true
      this.updateQuestGiversAt = GetTime() + .65
      KoQuest.questGiverDirty = false
    end
  end
end)

local questlog_flip, questlog_flop = {}, {}
function KoQuest:UpdateQuestlog()
  -- initialize flip flop if not yet defined
  KoQuest.questlog_tmp = KoQuest.questlog_tmp or questlog_flip

  local numEntries = 0
  local snapshotComplete = true
  if KoQuestEV and KoQuestEV.GetQuestLogCounts then
    numEntries, _, snapshotComplete = KoQuestEV:GetQuestLogCounts()
  elseif type(GetNumQuestLogEntries) == "function" then
    numEntries = tonumber(GetNumQuestLogEntries()) or 0
  end
  if numEntries < 0 then numEntries = 0 end

  local change = nil

  -- Emberveil documents GetNumQuestLogEntries() as the visible row count.
  -- Iterate exactly those rows instead of relying on Vanilla's undocumented
  -- second return or a fixed 40-row scan.
  for qlogid=1,numEntries do
    local title, _, _, header, _, complete = compat.GetQuestLogTitle(qlogid)
    local objectives = GetNumQuestLeaderBoards(qlogid)
    local watched, questid, state

    if title and not header then
      questid = KoDatabase:GetQuestIDs(qlogid)
      questid = questid and tonumber(questid[1]) or title
      watched = IsQuestWatched(qlogid)
      state = watched and "track" or ""
      local evState = "incomplete"
      if KoQuestEV and KoQuestEV.GetQuestLogEntryState then
        evState = KoQuestEV:GetQuestLogEntryState(qlogid)
      elseif complete == -1 then
        evState = "failed"
      elseif complete == true or complete == 1 then
        evState = "complete"
      end
      state = state .. "|state=" .. evState

      -- build state string
      if objectives then
        for i=1, objectives, 1 do
          local text, _, done = GetQuestLogLeaderBoard(i, qlogid)
          state = state .. i .. (done and "done" or "todo")
        end
      end

      -- add new quest to the questlog
      if not KoQuest.questlog[questid] then
        table.insert(KoQuest.queue, { title, questid, qlogid, "NEW" })
        KoQuest.questlog_tmp[questid] = {
          title = title,
          qlogid = qlogid,
          state = state,
        }
        change = true
      elseif KoQuest.questlog[questid].qlogid ~= qlogid then
        table.insert(KoQuest.queue, { title, questid, qlogid, "RELOAD" })
        KoQuest.questlog_tmp[questid] = KoQuest.questlog[questid]
        KoQuest.questlog_tmp[questid].qlogid = qlogid
        KoQuest.questlog_tmp[questid].state = state
        change = true
      elseif KoQuest.questlog[questid].state ~= state then
        table.insert(KoQuest.queue, { title, questid, qlogid, "RELOAD" })
        KoQuest.questlog_tmp[questid] = KoQuest.questlog[questid]
        KoQuest.questlog_tmp[questid].qlogid = qlogid
        KoQuest.questlog_tmp[questid].state = state
        change = true
      else
        KoQuest.questlog_tmp[questid] = KoQuest.questlog[questid]
      end

    end
  end

  -- A collapsed header makes GetNumQuestLogEntries expose only visible rows.
  -- Preserve hidden quests and never turn their temporary absence into REMOVE
  -- events, completion history, or deleted map nodes.
  if snapshotComplete == false then
    if KoQuestEV and KoQuestEV.PreserveHiddenQuestLog then
      KoQuestEV:PreserveHiddenQuestLog(
        KoQuest.questlog, KoQuest.questlog_tmp, snapshotComplete)
    else
      for questid, data in pairs(KoQuest.questlog) do
        if not KoQuest.questlog_tmp[questid] then
          KoQuest.questlog_tmp[questid] = data
        end
      end
    end
  end

  -- quest removal events (only when every log row is visible)
  for questid, data in pairs(KoQuest.questlog) do
    if snapshotComplete ~= false and not KoQuest.questlog_tmp[questid] then
      table.insert(KoQuest.queue, { data.title, questid, nil, "REMOVE", data.state })
      change = true
    end
  end

  -- set questlog to current flip flop
  KoQuest.questlog = KoQuest.questlog_tmp

  -- switch tmp to the other flip flop
  if KoQuest.questlog_tmp == questlog_flip then
    KoQuest.questlog_tmp = questlog_flop
  else
    KoQuest.questlog_tmp = questlog_flip
  end

  -- clear next temporary questlog entries
  for k, v in pairs(KoQuest.questlog_tmp) do
    KoQuest.questlog_tmp[k] = nil
  end

  return change
end

function KoQuest:ResetAll()
  -- force reload all quests
  KoMap:DeleteNode("KOQUEST")
  KoQuest.questlog = {}
  KoQuest.updateQuestLog = true
  KoQuest.updateQuestGivers = true
  KoQuest.updateQuestGiversAt = nil
end

-- register popup dialog to copy urls
StaticPopupDialogs["KOQUEST_URLCOPY"] = {
  text = "|cff33ffccKo|cffffffffQuest " .. KoQuest_Loc["Online Search"],
  button1 = "Close",
  hasEditBox = 1,
  hasWideEditBox = 1,
  timeout = 0,
  exclusive = 1,
  whileDead = 1,
  hideOnEscape = 1,
  OnShow = function()
    local editBox = _G[this:GetName().."WideEditBox"]
    editBox:SetText(StaticPopupDialogs["KOQUEST_URLCOPY"].data)
    editBox:HighlightText()
  end,
  OnHide = function()
    _G[this:GetName().."WideEditBox"]:SetText("")
  end,
  EditBoxOnEnterPressed = function()
    this:GetParent():Hide()
  end,
  EditBoxOnEscapePressed = function()
    this:GetParent():Hide()
  end,
  EditBoxOnTextChanged = function()
    this:SetText(StaticPopupDialogs["KOQUEST_URLCOPY"].data)
    this:HighlightText()
  end,
}

function KoQuest:AddQuestLogIntegration()
  if KoQuest_config["questlogbuttons"] ==  "0" then return end

  local dockFrame = EQL3_QuestLogDetailScrollChildFrame or ShaguQuest_QuestLogDetailScrollChildFrame or QuestLogDetailScrollChildFrame
  local dockTitle = EQL3_QuestLogDescriptionTitle or ShaguQuest_QuestLogDescriptionTitle or KoQuestCompat.QuestLogDescriptionTitle

  dockTitle:SetHeight(dockTitle:GetHeight() + 30)
  dockTitle:SetJustifyV("BOTTOM")

  KoQuest.buttonOnline = KoQuest.buttonOnline or CreateFrame("Button", "KoQuestOnline", dockFrame)
  KoQuest.buttonOnline:SetWidth(18)
  KoQuest.buttonOnline:SetHeight(15)
  KoQuest.buttonOnline:SetPoint("TOPRIGHT", dockFrame, "TOPRIGHT", -12, -10)
  KoQuest.buttonOnline:SetScript("OnClick", function()
    if pfUI and pfUI.chat then
      pfUI.chat.urlcopy.text:SetText(KoQuest.dburl .. (this:GetID() or 0))
      pfUI.chat.urlcopy:Show()
    else
      StaticPopupDialogs["KOQUEST_URLCOPY"].data = KoQuest.dburl .. (this:GetID() or 0)
      local dialog = StaticPopup_Show("KOQUEST_URLCOPY")
      _G[dialog:GetName().."Button1"]:ClearAllPoints()
      _G[dialog:GetName().."Button1"]:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 16)
      _G[dialog:GetName().."WideEditBox"]:SetScript('OnTextChanged', StaticPopup_EditBoxOnTextChanged)
      dialog:SetWidth(420)
    end
  end)

  KoQuest.buttonOnline.txt = KoQuest.buttonOnline:CreateFontString("KoQuestIDButton", "HIGH", "GameFontWhite")
  KoQuest.buttonOnline.txt:SetAllPoints(KoQuest.buttonOnline)
  KoQuest.buttonOnline.txt:SetJustifyH("RIGHT")
  KoQuest.buttonOnline.txt:SetText("|cff000000[|cffaa2222?|cff000000]")

  KoQuest.buttonLanguage = KoQuest.buttonLanguage or CreateFrame("Button", "KoQuestLanguage", dockFrame)
  KoQuest.buttonLanguage:SetWidth(75)
  KoQuest.buttonLanguage:SetHeight(15)
  KoQuest.buttonLanguage:SetPoint("RIGHT", KoQuest.buttonOnline, "LEFT", 0, 0)

  KoQuest.buttonLanguage.txt = KoQuest.buttonLanguage:CreateFontString("KoQuestIDButton", "HIGH", "GameFontWhite")
  KoQuest.buttonLanguage.txt:SetAllPoints(KoQuest.buttonLanguage)
  KoQuest.buttonLanguage.txt:SetJustifyH("RIGHT")
  KoQuest.buttonLanguage.txt:SetText("|cff000000[|cff333333" .. KoQuest_Loc["Translate"] .. "|cff000000]")

  KoQuest.buttonLanguage:SetScript("OnClick", function()
    UIDropDownMenu_Initialize(self, function()
      local func = function() KoQuest_config.translate = this.value end
      local info = {}
      info.text = "|cffaaaaaa" .. KoQuest_Loc["Reset Language"]
      info.value = nil
      info.func = func
      UIDropDownMenu_AddButton(info);

      for loc, caption in pairs(KoDB.locales) do
        local info = {}
        info.text = caption
        info.value = loc
        info.func = func
        UIDropDownMenu_AddButton(info);
      end
    end)
    ToggleDropDownMenu(1, nil, self, "cursor", 3, -3)
  end)

  KoQuest.buttonLanguage:SetScript("OnUpdate", function()
    local id = KoQuest.buttonOnline:GetID()
    local lang = KoQuest_config.translate

    if this.translate ~= KoQuest_config.translate then
      KoQuest.buttonLanguage.txt:SetText("|cff000000[|cff3333ff" .. (KoDB.locales[KoQuest_config.translate] or "|cff333333" .. KoQuest_Loc["Translate"]) .. "|cff000000]")
      this.translate = KoQuest_config.translate
      QuestLog_UpdateQuestDetails(true)
      return
    end

    if id and KoDB["quests"][lang] and KoDB["quests"][lang][id] then
      local QuestLogQuestTitle = EQL3_QuestLogQuestTitle or KoQuestCompat.QuestLogQuestTitle
      local QuestLogObjectivesText = EQL3_QuestLogObjectivesText or KoQuestCompat.QuestLogObjectivesText
      local QuestLogQuestDescription = EQL3_QuestLogQuestDescription or KoQuestCompat.QuestLogQuestDescription
      local QuestLogDetailScrollFrame = EQL3_QuestLogDetailScrollFrame or QuestLogDetailScrollFrame

      QuestLogQuestTitle:SetText(KoDatabase:FormatQuestText(KoDB["quests"][lang][id]["T"]))
      QuestLogObjectivesText:SetText(KoDatabase:FormatQuestText(KoDB["quests"][lang][id]["O"]))
      QuestLogQuestDescription:SetText(KoDatabase:FormatQuestText(KoDB["quests"][lang][id]["D"]))
      QuestLogDetailScrollFrame:UpdateScrollChildRect()
    end
  end)

  KoQuest.buttonShow = KoQuest.buttonShow or CreateFrame("Button", "KoQuestShow", dockFrame, "UIPanelButtonTemplate")
  KoQuest.buttonShow:SetWidth(70)
  KoQuest.buttonShow:SetHeight(20)
  KoQuest.buttonShow:SetText(KoQuest_Loc["Show"])
  KoQuest.buttonShow:SetPoint("TOP", dockTitle, "TOP", -110, 0)
  KoQuest.buttonShow:SetScript("OnClick", function()
    local questIndex = GetQuestLogSelection()
    local questids = KoDatabase:GetQuestIDs(questIndex)
    local title, _, _, header, _, complete = compat.GetQuestLogTitle(questIndex)
    local id = questids and tonumber(questids[1])
    if header or not id then return end

    local maps, meta = {}, { ["addon"] = "KOQUEST", ["qlogid"] = questIndex }
    maps = KoDatabase:SearchQuestID(id, meta, maps)
    KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
  end)

  KoQuest.buttonHide = KoQuest.buttonHide or CreateFrame("Button", "KoQuestHide", dockFrame, "UIPanelButtonTemplate")
  KoQuest.buttonHide:SetWidth(70)
  KoQuest.buttonHide:SetHeight(20)
  KoQuest.buttonHide:SetText(KoQuest_Loc["Hide"])
  KoQuest.buttonHide:SetPoint("TOP", dockTitle, "TOP", -37, 0)
  KoQuest.buttonHide:SetScript("OnClick", function()
    local questIndex = GetQuestLogSelection()
    local title, _, _, header, _, complete = compat.GetQuestLogTitle(questIndex)
    if header then return end

    KoMap:DeleteNode("KOQUEST", title)
  end)

  KoQuest.buttonClean = KoQuest.buttonClean or CreateFrame("Button", "KoQuestClean", dockFrame, "UIPanelButtonTemplate")
  KoQuest.buttonClean:SetWidth(70)
  KoQuest.buttonClean:SetHeight(20)
  KoQuest.buttonClean:SetText(KoQuest_Loc["Clean"])
  KoQuest.buttonClean:SetPoint("TOP", dockTitle, "TOP", 37, 0)
  KoQuest.buttonClean:SetScript("OnClick", function()
    KoMap:DeleteNode("KOQUEST")
  end)

  KoQuest.buttonReset = KoQuest.buttonReset or CreateFrame("Button", "KoQuestReset", dockFrame, "UIPanelButtonTemplate")
  KoQuest.buttonReset:SetWidth(70)
  KoQuest.buttonReset:SetHeight(20)
  KoQuest.buttonReset:SetText(KoQuest_Loc["Reset"])
  KoQuest.buttonReset:SetPoint("TOP", dockTitle, "TOP", 110, 0)
  KoQuest.buttonReset:SetScript("OnClick", function()
    KoQuest:ResetAll()
  end)

  -- use pfUI buttons in native mode
  if not pfUI.api.emulated then
    pfUI.api.SkinButton(KoQuest.buttonShow)
    pfUI.api.SkinButton(KoQuest.buttonHide)
    pfUI.api.SkinButton(KoQuest.buttonClean)
    pfUI.api.SkinButton(KoQuest.buttonReset)
  end
end

function KoQuest:AddWorldMapIntegration()
  if KoQuest_config["worldmapmenu"] ==  "0" then return end

  -- Quest Display Selection
  KoQuest.mapButton = CreateFrame("Frame", "KoQuestMapDropdown", WorldMapButton, "UIDropDownMenuTemplate")
  KoQuest.mapButton:ClearAllPoints()
  KoQuest.mapButton:SetPoint("TOPRIGHT" , 0, -10)
  KoQuest.mapButton:SetScript("OnShow", function()
    KoQuest.mapButton.current = tonumber(KoQuest_config["trackingmethod"])
    KoQuest.mapButton:UpdateMenu()
  end)

  KoQuest.mapButton.point = "TOPLEFT"
  KoQuest.mapButton.relativePoint = "BOTTOMLEFT"

  function KoQuest.mapButton:UpdateMenu()
    local function CreateEntries()
      local info = {}
      info.text = KoQuest_Loc["All Quests"]
      info.checked = false
      info.func = function()
        UIDropDownMenu_SetSelectedID(KoQuest.mapButton, this:GetID(), 0)
        KoQuest_config["trackingmethod"] = this:GetID()
        KoQuest:ResetAll()
      end
      UIDropDownMenu_AddButton(info)

      local info = {}
      info.text = KoQuest_Loc["Tracked Quests"]
      info.checked = false
      info.func = function()
        UIDropDownMenu_SetSelectedID(KoQuest.mapButton, this:GetID(), 0)
        KoQuest_config["trackingmethod"] = this:GetID()
        KoQuest:ResetAll()
      end
      UIDropDownMenu_AddButton(info)

      local info = {}
      info.text = KoQuest_Loc["Manual Selection"]
      info.checked = false
      info.func = function()
        UIDropDownMenu_SetSelectedID(KoQuest.mapButton, this:GetID(), 0)
        KoQuest_config["trackingmethod"] = this:GetID()
        KoQuest:ResetAll()
      end
      UIDropDownMenu_AddButton(info)

      local info = {}
      info.text = KoQuest_Loc["Hide Quests"]
      info.checked = false
      info.func = function()
        UIDropDownMenu_SetSelectedID(KoQuest.mapButton, this:GetID(), 0)
        KoQuest_config["trackingmethod"] = this:GetID()
        KoQuest:ResetAll()
      end
      UIDropDownMenu_AddButton(info)
    end

    UIDropDownMenu_Initialize(KoQuest.mapButton, CreateEntries)
    if client >= 30300 then
      UIDropDownMenu_SetWidth(KoQuest.mapButton, 120)
      UIDropDownMenu_SetButtonWidth(KoQuest.mapButton, 125)
      UIDropDownMenu_JustifyText(KoQuest.mapButton, "RIGHT")
    else
      UIDropDownMenu_SetWidth(120, KoQuest.mapButton)
      UIDropDownMenu_SetButtonWidth(125, KoQuest.mapButton)
      UIDropDownMenu_JustifyText("RIGHT", KoQuest.mapButton)
    end
    UIDropDownMenu_SetSelectedID(KoQuest.mapButton, KoQuest.mapButton.current)
  end
end

-- [[ Hook UI Functions ]] --
-- Set certain events on quest watch
local pfHookRemoveQuestWatch = RemoveQuestWatch
RemoveQuestWatch = function(questIndex)
  local ret = pfHookRemoveQuestWatch(questIndex)

  if questIndex then
    local title, _, _, header, _, complete = compat.GetQuestLogTitle(questIndex)
    KoMap:DeleteNode("KOQUEST", title)
  end

  KoQuest.updateQuestLog = true
  KoQuest.updateQuestGivers = true

  return ret
end

-- Set certain events on quest unwatch
local pfHookAddQuestWatch = AddQuestWatch
AddQuestWatch = function(questIndex)
  local ret = pfHookAddQuestWatch(questIndex)
  KoQuest.updateQuestLog = true
  KoQuest.updateQuestGivers = true
  return ret
end

-- Save the abandoned questname to remove from history
local HookAbandonQuest = AbandonQuest
AbandonQuest = function()
  KoQuest.abandon = GetAbandonQuestName()
  HookAbandonQuest()
end

-- Capture the quest title at the one documented API call that actually awards
-- the reward. This closes the short race where a player can turn in a quest
-- before the once-per-second log scan observes its complete state.
local HookGetQuestReward = GetQuestReward
if type(HookGetQuestReward) == "function" then
  GetQuestReward = function(index)
    local title = type(GetTitleText) == "function" and GetTitleText() or nil
    HookGetQuestReward(index)

    if type(title) == "string" and title ~= "" then
      KoQuest.rewarded = title
      KoQuest.rewardedAt = GetTime()
    end
  end
end

local function UpdateQuestLevel(button, id)
  local title, level, tag, header = compat.GetQuestLogTitle(id)
  if header or not title then return end
  button:SetText(" [" .. ( level or "??" ) .. ( tag and "+" or "") .. "] " .. title)
  if not QuestLogTitleButton_Resize then return end
  QuestLogTitleButton_Resize(button)
end

-- Update quest id button
local pfHookQuestLog_Update = QuestLog_Update
QuestLog_Update = function()
  pfHookQuestLog_Update()

  if KoQuest_config["questloglevel"] == "1" then
    if client >= 30300 then
      for i, button in pairs(QuestLogScrollFrame.buttons) do
        UpdateQuestLevel(button, button:GetID())
      end
    else
      for i=1, QUESTS_DISPLAYED, 1 do
        UpdateQuestLevel(_G["QuestLogTitle"..i], i + FauxScrollFrame_GetOffset(QuestLogListScrollFrame))
      end
    end
  end

  if KoQuest_config["questlogbuttons"] ==  "1" then
    local questids = KoDatabase:GetQuestIDs(GetQuestLogSelection())
    if questids and questids[1] and tonumber(questids[1]) and KoQuest.questlog[questids[1]] then
      KoQuest.buttonOnline:SetID(questids[1])
      KoQuest.buttonOnline:Show()
      KoQuest.buttonLanguage:Show()
      -- enable buttons
      KoQuest.buttonShow:Enable()
      KoQuest.buttonHide:Enable()

      if KoQuest_config.showids == "1" then
        KoQuest.buttonOnline.txt:SetText("|cff000000[|cffaa2222id: " .. questids[1] .. "|cff000000]")
        KoQuest.buttonOnline:SetWidth(KoQuest.buttonOnline.txt:GetStringWidth())
      end
    else
      KoQuest.buttonOnline:Hide()
      KoQuest.buttonLanguage:Hide()
      -- disable buttons
      KoQuest.buttonShow:Disable()
      KoQuest.buttonHide:Disable()
    end
  end
end

-- attach the new function to the scroll frame
if QuestLogScrollFrame then
  QuestLogScrollFrame.update = QuestLog_Update
end

-- refresh language and url on quest selection
local pfHookQuestLogTitleButton_OnClick = QuestLogTitleButton_OnClick
QuestLogTitleButton_OnClick = function(self, button)
  pfHookQuestLogTitleButton_OnClick(self, button)
  QuestLog_Update()
end

if not GetQuestLink then -- Allow to send questlinks from questlog
  local pfHookQuestLogTitleButton_OnClick = QuestLogTitleButton_OnClick
  QuestLogTitleButton_OnClick = function(button)
    local scrollFrame = EQL3_QuestLogListScrollFrame or ShaguQuest_QuestLogListScrollFrame or QuestLogListScrollFrame
    local questIndex = this:GetID() + FauxScrollFrame_GetOffset(scrollFrame)
    local questName, questLevel = compat.GetQuestLogTitle(questIndex)
    local questids = KoDatabase:GetQuestIDs(questIndex)
    local questid = questids and tonumber(questids[1]) or 0

    if IsShiftKeyDown() and not this.isHeader and ChatFrameEditBox:IsVisible() then
      KoQuestCompat.InsertQuestLink(questid, questName)
      QuestLog_SetSelection(questIndex)
      QuestLog_Update()
      return
    end

    pfHookQuestLogTitleButton_OnClick(button)
  end

  -- Patch ItemRef to display Questlinks
  local KoQuestHookSetItemRef = SetItemRef
  SetItemRef = function(link, text, button)
    local isQuest, _, id    = string.find(link, "quest:(%d+):.*")
    local isQuest2, _, _   = string.find(link, "quest2:.*")

    if isQuest or isQuest2 then
      if IsShiftKeyDown() and ChatFrameEditBox:IsVisible() then
        ChatFrameEditBox:Insert(text)
        return
      end

      if ItemRefTooltip:IsShown() and ItemRefTooltip.KoQuestText == text then
        HideUIPanel(ItemRefTooltip)
        return
      end

      ShowUIPanel(ItemRefTooltip)
      ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")

      local hasTitle, _, questTitle = string.find(text, ".*|h%[(.*)%]|h.*")

      id = tonumber(id)

      if not id or id == 0 then
        for scanID, data in pairs(KoDB["quests"]["loc"]) do
          if data.T == questTitle then
            id = scanID
            break
          end
        end
      end

      -- read and set title
      if id and id > 0 and KoDB["quests"]["loc"][id] then
        local questlevel = tonumber(KoDB["quests"]["data"][id]["lvl"])
        local color = KoQuestCompat.GetDifficultyColor(questlevel)
        ItemRefTooltip:AddLine(KoDB["quests"]["loc"][id].T, color.r, color.g, color.b)
      elseif hasTitle then
        ItemRefTooltip:AddLine(questTitle, 1,1,0)
      end

      -- scan for active quests
      local queststate = KoQuest_history[id] and 2 or 0
      queststate = KoQuest.questlog[id] and 1 or queststate

      if queststate == 0 then
        ItemRefTooltip:AddLine(KoQuest_Loc["You don't have this quest."] .. "\n\n", 1, .5, .5)
      elseif queststate == 1 then
        ItemRefTooltip:AddLine(KoQuest_Loc["You are on this quest."] .. "\n\n", 1, 1, .5)
      elseif queststate == 2 then
        ItemRefTooltip:AddLine(KoQuest_Loc["You already did this quest."] .. "\n\n", .5, 1, .5)
      end

      -- add database entries if existing
      if KoDB["quests"]["loc"][id] then
        if KoDB["quests"]["loc"][id]["O"] then
          ItemRefTooltip:AddLine(KoDatabase:FormatQuestText(KoDB["quests"]["loc"][id]["O"]), 1,1,1,true)
        end

        if KoDB["quests"]["loc"][id]["O"] and KoDB["quests"]["loc"][id]["D"] then
          ItemRefTooltip:AddLine(" ", 0,0,0)
        end

        if KoDB["quests"]["loc"][id]["D"] then
          ItemRefTooltip:AddLine(KoDatabase:FormatQuestText(KoDB["quests"]["loc"][id]["D"]), .8,.8,.8,true)
        end

        if KoDB["quests"]["data"][id]["lvl"] or KoDB["quests"]["data"][id]["min"] then
          ItemRefTooltip:AddLine(" ", 0,0,0)
        end

        if KoDB["quests"]["data"][id]["min"] then
          local questlevel = tonumber(KoDB["quests"]["data"][id]["min"])
          local color = KoQuestCompat.GetDifficultyColor(questlevel)
          ItemRefTooltip:AddLine("|cffffffff" .. KoQuest_Loc["Required Level"] .. ": |r" .. questlevel, color.r, color.g, color.b)
        end

        if KoDB["quests"]["data"][id]["lvl"] then
          local questlevel = tonumber(KoDB["quests"]["data"][id]["lvl"])
          local color = KoQuestCompat.GetDifficultyColor(questlevel)
          ItemRefTooltip:AddLine("|cffffffff" .. KoQuest_Loc["Quest Level"] .. ": |r" .. questlevel, color.r, color.g, color.b)
        end
      end

      ItemRefTooltip:Show()
    else
      KoQuestHookSetItemRef(link, text, button)
    end
    ItemRefTooltip.KoQuestText = text
  end
else
  -- patch itemref to show known quest levels on tbc
  local KoQuestHookSetItemRef = SetItemRef
  SetItemRef = function(link, text, button)
    KoQuestHookSetItemRef(link, text, button)

    -- skip modifier clicks
    if IsAltKeyDown() or IsControlKeyDown() or IsShiftKeyDown() then return end

    local quest, _, id = string.find(link, "quest:(%d+):.*")
    if not quest then return end
    id = tonumber(id)

    -- adjust text color to level color
    if id and id > 0 and KoDB["quests"]["loc"][id] then
      local questlevel = tonumber(KoDB["quests"]["data"][id]["lvl"])
      local color = KoQuestCompat.GetDifficultyColor(questlevel)
      ItemRefTooltipTextLeft1:SetTextColor(color.r, color.g, color.b)
    end

    -- add quest levels to tooltip
    if KoDB["quests"]["loc"][id] then
      ItemRefTooltip:AddLine(" ")

      if KoDB["quests"]["data"][id]["min"] then
        local questlevel = tonumber(KoDB["quests"]["data"][id]["min"])
        local color = KoQuestCompat.GetDifficultyColor(questlevel)
        ItemRefTooltip:AddLine("|cffffffff" .. KoQuest_Loc["Required Level"] .. ": |r" .. questlevel, color.r, color.g, color.b)
      end

      if KoDB["quests"]["data"][id]["lvl"] then
        local questlevel = tonumber(KoDB["quests"]["data"][id]["lvl"])
        local color = KoQuestCompat.GetDifficultyColor(questlevel)
        ItemRefTooltip:AddLine("|cffffffff" .. KoQuest_Loc["Quest Level"] .. ": |r" .. questlevel, color.r, color.g, color.b)
      end
    end

    ItemRefTooltip:Show()
  end
end
