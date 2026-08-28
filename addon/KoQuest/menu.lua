do -- minimap icon
  KoQuestIcon = CreateFrame('Button', "KoQuestIcon", Minimap)
  KoQuestIcon:SetClampedToScreen(true)
  KoQuestIcon:SetMovable(true)
  KoQuestIcon:EnableMouse(true)
  KoQuestIcon:RegisterForDrag('LeftButton')
  KoQuestIcon:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

  KoQuestIcon:SetWidth(31)
  KoQuestIcon:SetHeight(31)
  KoQuestIcon:SetFrameLevel(9)
  KoQuestIcon:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
  KoQuestIcon:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)

  KoQuestIcon:SetScript("OnDragStart", function()
    if IsShiftKeyDown() then
      this:StartMoving()
    end
  end)

  KoQuestIcon:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
  end)

  KoQuestIcon:SetScript("OnClick", function()
    if KoQuestMenu:IsShown() then
      KoQuestMenu:Hide()
    else
      KoQuestMenu:Show()
    end
  end)

  KoQuestIcon:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, ANCHOR_BOTTOMLEFT)
    GameTooltip:SetText("|cff33ffccKo|rQuest", 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(KoQuest_Loc["Left-Click"], KoQuest_Loc["Shortcut Menu"], 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine(KoQuest_Loc["Shift-Click"], KoQuest_Loc["Move Button"], 1, 1, 1, 1, 1, 1)
    GameTooltip:Show()
  end)

  KoQuestIcon:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  KoQuestIcon:RegisterEvent("PLAYER_ENTERING_WORLD")
  KoQuestIcon:SetScript("OnEvent", function()
    if KoQuest_config["minimapbutton"] == "0" then
      this:Hide()
    else
      this:Show()
    end
  end)

  KoQuestIcon.icon = KoQuestIcon:CreateTexture(nil, 'BACKGROUND')
  KoQuestIcon.icon:SetWidth(20)
  KoQuestIcon.icon:SetHeight(20)
  KoQuestIcon.icon:SetTexture(KoQuestConfig.path..'\\img\\logo')
  KoQuestIcon.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  KoQuestIcon.icon:SetPoint('CENTER',1,1)

  KoQuestIcon.overlay = KoQuestIcon:CreateTexture(nil, 'OVERLAY')
  KoQuestIcon.overlay:SetWidth(53)
  KoQuestIcon.overlay:SetHeight(53)
  KoQuestIcon.overlay:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder')
  KoQuestIcon.overlay:SetPoint('TOPLEFT', 0,0)
end

do -- tracking menu
  local function MenuButtonEnter()
    this.title:SetTextColor(1,.8,0)
    this.highlight:Show()
  end

  local function MenuButtonLeave()
    this.title:SetTextColor(1,1,1)
    this.highlight:Hide()
  end

  local function MenuButtonClick()
    this.state = this.check and not this.check:GetChecked()

    if this.check then
      this.check:SetChecked(this.state)
    else
      this:GetParent():Hide()
    end

    if this.onclick then
      this.onclick(nil, this.name, this.state)
    end
  end

  local function CreateMenu(data, name)
    local top, width = 4, 0
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()

    pfUI.api.CreateBackdrop(frame, nil, nil, .75)

    for id, tracking in pairs(data) do
      -- data shortcuts
      local name = tracking[1]
      local title = tracking[2]
      local onclick = tracking[3]
      local checkbox = tracking[4]

      if not title then
        -- draw separator line
        local line = frame:CreateTexture()
        line:SetTexture(.25 ,.25, .25, .25)
        line:SetPoint("TOPLEFT", 4, -top-2)
        line:SetPoint("TOPRIGHT", -4, -top-2)
        line:SetHeight(2)
      else
        -- create menu button
        frame[name] = CreateFrame("Button", nil, frame)
        frame[name]:SetPoint("TOPLEFT", 0, -top)
        frame[name]:SetPoint("TOPRIGHT", 0, -top)
        frame[name]:SetHeight(16)
        frame[name]:SetScript("OnEnter", MenuButtonEnter)
        frame[name]:SetScript("OnLeave", MenuButtonLeave)
        frame[name]:SetScript("OnClick", MenuButtonClick)
        frame[name].onclick = onclick
        frame[name].name = name

        -- title
        frame[name].title = frame[name]:CreateFontString(nil, "NORMAL", "GameFontWhite")
        frame[name].title:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
        frame[name].title:SetPoint("LEFT", 22, 0)
        frame[name].title:SetJustifyH("LEFT")
        frame[name].title:SetText(title)

        -- icon
        frame[name].icon = frame[name]:CreateTexture(nil, "OVERLAY")
        frame[name].icon:SetWidth(14)
        frame[name].icon:SetHeight(14)
        frame[name].icon:SetPoint("RIGHT", -8, 0)
        frame[name].icon:SetTexture(KoQuestConfig.path.."\\img\\tracking\\"..name)

        -- hover
        frame[name].highlight = frame[name]:CreateTexture(nil, "OVERLAY")
        frame[name].highlight:SetPoint("TOPLEFT", 4, 0)
        frame[name].highlight:SetPoint("BOTTOMRIGHT", -4, 0)
        frame[name].highlight:SetTexture(1,1,1,.1)
        frame[name].highlight:Hide()

        -- checkbox (optional)
        if checkbox then
          frame[name].check = CreateFrame("CheckButton", nil, frame[name], "UICheckButtonTemplate")
          frame[name].check:SetNormalTexture("")
          frame[name].check:SetPushedTexture("")
          frame[name].check:SetHighlightTexture("")
          frame[name].check:SetPoint("LEFT", 10, 0)
          frame[name].check:SetWidth(20)
          frame[name].check:SetHeight(20)
          frame[name].check:SetScale(.6)
          frame[name].check:EnableMouse(false)
          pfUI.api.CreateBackdrop(frame[name].check, nil, true)
        end

        -- save maximum menu width
        width = math.max(width, frame[name].title:GetStringWidth() + 60)
      end

      -- set next entry position
      top = top + (title and 16 or 6)
    end

    -- update frame size
    frame:SetWidth(width)
    frame:SetHeight(top + 4)

    -- the usual menu hide events
    table.insert(UIMenus, name)
    frame:RegisterEvent("CURSOR_UPDATE")
    frame:SetScript("OnEvent", function() this:Hide() end)

    return frame
  end

  local function ToggleFrame(frame)
    if frame:IsShown() then frame:Hide() else frame:Show() end
  end

  local menu = {
    {"database", KoQuest_Loc["Database"], function(list, state) ToggleFrame(KoBrowser) end },
    {"-"},
    {"chests", KoQuest_Loc["Chests & Treasures"], KoDatabase.TrackMeta, true},
    {"herbs", KoQuest_Loc["Herbs & Flowers"], KoDatabase.TrackMeta, true},
    {"mines", KoQuest_Loc["Mines & Ores"], KoDatabase.TrackMeta, true},
    {"fish", KoQuest_Loc["Fishing Pools"], KoDatabase.TrackMeta, true},
    {"rares", KoQuest_Loc["Rare Mobs"], KoDatabase.TrackMeta, true},
    {"-"},
    {"auctioneer", KoQuest_Loc["Auctioneer"], KoDatabase.TrackMeta, true},
    {"banker", KoQuest_Loc["Banker"], KoDatabase.TrackMeta, true},
    {"battlemaster", KoQuest_Loc["Battlemaster"], KoDatabase.TrackMeta, true},
    {"flight", KoQuest_Loc["Flight Master"], KoDatabase.TrackMeta, true},
    {"innkeeper", KoQuest_Loc["Innkeeper"], KoDatabase.TrackMeta, true},
    {"mailbox", KoQuest_Loc["Mailbox"], KoDatabase.TrackMeta, true},
    {"meetingstone", KoQuest_Loc["Meeting Stones"], KoDatabase.TrackMeta, true},
    {"repair", KoQuest_Loc["Repair"], KoDatabase.TrackMeta, true},
    {"spirithealer", KoQuest_Loc["Spirit Healer"], KoDatabase.TrackMeta, true},
    {"stablemaster", KoQuest_Loc["Stable Master"], KoDatabase.TrackMeta, true},
    {"vendor", KoQuest_Loc["Vendor"], KoDatabase.TrackMeta, true},
    {"-"},
    {"journal", KoQuest_Loc["Quest Journal"], function(list, state) ToggleFrame(KoJournal) end},
    {"welcome", KoQuest_Loc["Welcome Screen"], function(list, state) ToggleFrame(KoQuestInit) end},
    {"settings", KoQuest_Loc["Settings"], function(list, state) ToggleFrame(KoQuestConfig) end }
  }

  KoQuestMenu = CreateMenu(menu, "KoQuestMenu")
  KoQuestMenu:SetScript("OnShow", function()
    -- create shortcuts
    local anchor = this.anchor or KoQuestIcon
    local config = KoQuest_track
    local frame = this

    -- read virtual anchor position
    local x, y = anchor:GetCenter()
    x = x * anchor:GetEffectiveScale() / UIParent:GetScale()
    y = y * anchor:GetEffectiveScale() / UIParent:GetScale()

    -- read virtual screen resolution
    local width = UIParent:GetWidth() / UIParent:GetScale()
    local height = UIParent:GetHeight() / UIParent:GetScale()

    -- calculate menu position on screen
    local h = y > height / 2 and "TOP" or "BOTTOM"
    local hp = y > height / 2 and -8 or 8
    local w = x > width / 2 and "RIGHT" or "LEFT"
    local wp = x > width / 2 and -8 or 8

    -- set frame position
    frame:ClearAllPoints()
    frame:SetPoint(h..w, anchor, "CENTER", wp, hp)

    -- align menu entries to config state
    for id, data in pairs(menu) do
      if frame[data[1]] and frame[data[1]].check then
        frame[data[1]].check:SetChecked(config[data[1]] and true or false)
      end
    end
  end)
end
