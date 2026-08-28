-- multi api compat
local compat = KoQuestCompat
local collapsed = {}

local function tablesize(tbl)
  local count = 0
  for _ in pairs(tbl) do count = count + 1 end
  return count
end

local function OnUpdate()
  if not this.column and KoQuestEV_MouseIsOverDisabled(this) then
    this.remove:Show()
    this.bg:Show()
  else
    this.remove:Hide()
    this.bg:Hide()
  end
end

local function OnEnter()
  if this.id then
    -- show extended quest tooltip
    KoDatabase:ShowExtendedTooltip(this.id, GameTooltip, this, "ANCHOR_LEFT", 0, -10)

    -- add level of completion
    if KoQuest_history[this.id] and KoQuest_history[this.id][2] then
      local level = KoQuest_history[this.id][2]
      local color = KoQuestCompat.GetDifficultyColor(level)
      GameTooltip:AddLine("|cffffffff" .. KoQuest_Loc["Completed Level"] .. ": |r" .. level, color.r, color.g, color.b)
    end
    GameTooltip:Show()
  end
end

local function OnLeave()
  GameTooltip:Hide()
end

local function OnClick()
  if this.id and IsShiftKeyDown() then
    if tonumber(this.id) then
      KoQuestCompat.InsertQuestLink(this.id)
    else
      KoQuestCompat.InsertQuestLink(0, this.id)
    end
  elseif this.id then
    local maps = KoDatabase:SearchQuestID(this.id, meta)
    KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
  elseif this.column then
    collapsed[this.column] = not collapsed[this.column]
    this.remove.view:ReloadJournal()
  end
end

local function RemoveOnClick()
  if this.entry.id then
    KoQuest_history[this.entry.id] = nil
    this.view:ReloadJournal()
  end
end

local function CreateEntry(self, index)
  if self[index] then return end

  self[index] = CreateFrame("Button", nil, self)
  self[index]:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(index-1)*19-10)
  self[index]:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -(index-1)*19-10)
  self[index]:SetHeight(18)

  self[index]:SetScript("OnEnter", OnEnter)
  self[index]:SetScript("OnLeave", OnLeave)
  self[index]:SetScript("OnClick", OnClick)
  self[index]:SetScript("OnUpdate", OnUpdate)

  self[index].text = self[index]:CreateFontString("Caption", "LOW", "GameFontWhite")
  self[index].text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
  self[index].text:SetPoint("TOPLEFT", self[index], "TOPLEFT", 10, 0)
  self[index].text:SetPoint("BOTTOMRIGHT", self[index], "BOTTOMRIGHT", -10, 0)
  self[index].text:SetJustifyH("LEFT")

  self[index].bg = self[index]:CreateTexture(nil, "BACKGROUND")
  self[index].bg:SetAllPoints(self[index].text)
  self[index].bg:SetTexture(1,1,1,.02)

  self[index].remove = CreateFrame("Button", nil, self[index])
  self[index].remove:SetPoint("RIGHT", -5, 0)
  self[index].remove:SetHeight(20)
  self[index].remove:SetWidth(20)
  self[index].remove:SetScript("OnClick", RemoveOnClick)
  self[index].remove.entry = self[index]
  self[index].remove.view = self
  self[index].remove.texture = self[index].remove:CreateTexture("KoQuestionDialogCloseTex")
  self[index].remove.texture:SetTexture(KoQuestConfig.path.."\\compat\\close")
  self[index].remove.texture:ClearAllPoints()
  self[index].remove.texture:SetVertexColor(1,.25,.25,1)
  self[index].remove.texture:SetPoint("TOPLEFT", self[index].remove, "TOPLEFT", 4, -4)
  self[index].remove.texture:SetPoint("BOTTOMRIGHT", self[index].remove, "BOTTOMRIGHT", -4, 4)
end

local function UpdateEntry(self, index)
  if self[index].column then
    self[index].text:SetText((collapsed[self[index].column] and "|cff338855" or "|cff33ffcc")..self[index].column)
    self[index]:Show()
  elseif self[index].id then
    local qid = tonumber(self[index].id) or UNKNOWN
    local name = KoDB["quests"]["loc"][self[index].id] and KoDB["quests"]["loc"][self[index].id]["T"] or self[index].id
    local log = KoQuest_history[self[index].id][1]
    local level = KoQuest_history[self[index].id][2]
    self[index].text:SetText("  |cffffffff" .. date("%H:%M:%S", log) .. "  |cffffcc00[" .. (name or UNKNOWN) .. "]|cffaaaaaa (" .. qid ..")")
    self[index]:Show()
  else
    self[index]:Hide()
  end
end

local journal = {}
local function ReloadJournal(self)
  local self = self or this

  local index = 1
  local maxcolumns = 24
  local lastcolumn, column

  for questid, data in KoQuest:SortedPairs(KoQuest_history, 1) do
    column = data[1] == 0 and UNKNOWN or date("%A, %B %d (%Y)", data[1])

    if column ~= lastcolumn then -- add columns to the view
      lastcolumn = column
      journal[index] = journal[index] or { }
      journal[index].column = column
      journal[index].id = nil
      index = index + 1
    end

    if not collapsed[column] then -- add regular entries
      journal[index] = journal[index] or { }
      journal[index].column = nil
      journal[index].id = questid
      index = index + 1
    end
  end

  for index=index, table.getn(journal) do
    journal[index] = nil
  end

  -- push offset into limits
  self.offset = self.offset or 0
  self.offset = min(table.getn(journal) - maxcolumns + 1, self.offset)
  self.offset = max(0, self.offset)

  -- draw journal into view
  for id = 1, maxcolumns do
    CreateEntry(self, id)
    self[id].id = journal[id+self.offset] and journal[id+self.offset].id or nil
    self[id].column = journal[id+self.offset] and journal[id+self.offset].column or nil
    UpdateEntry(self, id)
  end
end

-- browser window
KoJournal = CreateFrame("Frame", "KoQuestJournal", UIParent)
KoJournal:Hide()
KoJournal:SetWidth(340)
KoJournal:SetHeight(520)
KoJournal:SetPoint("RIGHT", -80, 0)
KoJournal:SetFrameStrata("FULLSCREEN_DIALOG")
KoJournal:SetMovable(true)
KoJournal:EnableMouse(true)
KoJournal:SetScript("OnMouseDown",function()
  this:StartMoving()
end)

KoJournal:SetScript("OnMouseUp",function()
  this:StopMovingOrSizing()
end)

pfUI.api.CreateBackdrop(KoJournal, nil, true, 0.75)
table.insert(UISpecialFrames, "KoQuestJournal")

KoJournal.title = KoJournal:CreateFontString("Status", "LOW", "GameFontNormal")
KoJournal.title:SetFontObject(GameFontWhite)
KoJournal.title:SetPoint("TOP", KoJournal, "TOP", 0, -8)
KoJournal.title:SetJustifyH("LEFT")
KoJournal.title:SetFont(pfUI.font_default, 14)
KoJournal.title:SetText("|cff33ffccKo|rQuest " .. KoQuest_Loc["Journal"])

KoJournal.close = CreateFrame("Button", "KoQuestJournalClose", KoJournal)
KoJournal.close:SetPoint("TOPRIGHT", -5, -5)
KoJournal.close:SetHeight(20)
KoJournal.close:SetWidth(20)
KoJournal.close:SetScript("OnClick", function() this:GetParent():Hide() end)
KoJournal.close.texture = KoJournal.close:CreateTexture("KoQuestionDialogCloseTex")
KoJournal.close.texture:SetTexture(KoQuestConfig.path.."\\compat\\close")
KoJournal.close.texture:ClearAllPoints()
KoJournal.close.texture:SetVertexColor(1,.25,.25,1)
KoJournal.close.texture:SetPoint("TOPLEFT", KoJournal.close, "TOPLEFT", 4, -4)
KoJournal.close.texture:SetPoint("BOTTOMRIGHT", KoJournal.close, "BOTTOMRIGHT", -4, 4)
pfUI.api.SkinButton(KoJournal.close, 1, .5, .5)

KoJournal.entries = CreateFrame("Button", "KoQuestJournalEntries", KoJournal)
KoJournal.entries.ReloadJournal = ReloadJournal
KoJournal.entries:EnableMouseWheel(true)
KoJournal.entries:SetPoint("TOPLEFT", KoJournal, "TOPLEFT", 10, -35)
KoJournal.entries:SetPoint("BOTTOMRIGHT", KoJournal, "BOTTOMRIGHT", -10, 10)
KoJournal.entries:SetScript("OnMouseWheel", function()
  this.offset = this.offset and this.offset - arg1 or 0
  this:ReloadJournal()
end)

KoJournal.entries:SetScript("OnClick", KoJournal.entries.ReloadJournal)
KoJournal.entries:SetScript("OnUpdate", function()
  if ( this.tick or 1) > GetTime() then return else this.tick = GetTime() + 1 end
  this:ReloadJournal()
end)

pfUI.api.CreateBackdrop(KoJournal.entries)
