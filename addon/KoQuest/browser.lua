-- multi api compat
local compat = KoQuestCompat

-- default config
KoBrowser_fav = {["units"] = {}, ["objects"] = {}, ["items"] = {}, ["quests"] = {}}

local tooltip_limit = 5
local search_limit = 512

-- add database shortcuts
local items = KoDB["items"]["data"]
local units = KoDB["units"]["data"]
local objects = KoDB["objects"]["data"]
local refloot = KoDB["refloot"]["data"]
local quests = KoDB["quests"]["data"]
local zones = KoDB["zones"]["loc"]

local function ShowTooltip()
  if not this.tooltips then return end
  GameTooltip_SetDefaultAnchor(GameTooltip, this)
  GameTooltip:ClearLines()
  for k, v in pairs(this.tooltips) do
    if k == 1 then
      GameTooltip:AddLine(v, 1, 1, 1)
    else
      GameTooltip:AddLine(v)
    end
  end
  GameTooltip:Show()
end

local function EnableTooltips(frame, tooltips)
  frame.tooltips = tooltips
  frame:SetScript("OnEnter", ShowTooltip)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function ResultButtonEnter()
  this.tex:SetTexture(1,1,1,.1)

  -- quest
  if this.btype == "quests" then
    KoDatabase:ShowExtendedTooltip(this.id, GameTooltip, this, "ANCHOR_LEFT", -10, -5)

  -- item
  elseif this.btype == "items" then
    GameTooltip:SetOwner(this, "ANCHOR_LEFT", -10, -5)

    -- Emberveil: do not drive the native hyperlink resolver directly.
    -- Build a useful item tooltip from cached API/database information.
    local itemName, _, itemQuality, itemLevel, reqLevel, itemType, itemSubType = GetItemInfo(this.id)
    local displayName = itemName or this.name or UNKNOWN
    local qcolor = itemQuality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[itemQuality]

    if qcolor then
      GameTooltip:SetText(displayName, qcolor.r, qcolor.g, qcolor.b)
    else
      GameTooltip:SetText(displayName, 1, 1, 1)
    end

    GameTooltip:AddLine("ID: " .. tostring(this.id), .6, .6, .6)

    if itemType or itemSubType then
      local typeText = itemType or ""
      if itemSubType and itemSubType ~= "" then
        typeText = typeText .. (typeText ~= "" and " - " or "") .. itemSubType
      end
      if typeText ~= "" then GameTooltip:AddLine(typeText, .8, .8, .8) end
    end

    if reqLevel and tonumber(reqLevel) and tonumber(reqLevel) > 0 then
      GameTooltip:AddDoubleLine(
        (KoQuest_Loc["Required Level"] or "Required Level"),
        tostring(reqLevel), 1, 1, .8, 1, 1, 1)
    end

    if itemLevel and tonumber(itemLevel) and tonumber(itemLevel) > 0 then
      GameTooltip:AddDoubleLine("Item Level", tostring(itemLevel), 1, 1, .8, .8, .8, .8)
    end

    GameTooltip:Show()

  -- units / objects
  else
    local id = this.id
    local name = this.name
    local maps = {}
    GameTooltip:SetOwner(this, "ANCHOR_LEFT", -10, -5)
    GameTooltip:SetText(name, .3, 1, .8)
    if this.btype == "units" then
      local unitData = units[id]

      if unitData and unitData.lvl then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(KoQuest_Loc["Level"], unitData.lvl, 1,1,.8, 1,1,1)
      end

      local reactionStringA = "|c00ff0000" .. KoQuest_Loc["Hostile"] .. "|r"
      local reactionStringH = "|c00ff0000" .. KoQuest_Loc["Hostile"] .. "|r"
      if unitData and unitData.fac then
        if unitData.fac == "AH" then
          reactionStringA = "|c0000ff00" .. KoQuest_Loc["Friendly"] .. "|r"
          reactionStringH = "|c0000ff00" .. KoQuest_Loc["Friendly"] .. "|r"
        elseif unitData.fac == "A" then
          reactionStringA = "|c0000ff00" .. KoQuest_Loc["Friendly"] .. "|r"
        elseif unitData.fac == "H" then
          reactionStringH = "|c0000ff00" .. KoQuest_Loc["Friendly"] .. "|r"
        end
      end
      GameTooltip:AddLine("\n" .. KoQuest_Loc["Reaction"], 1,1,.8)
      GameTooltip:AddDoubleLine(KoQuest_Loc["Alliance"], reactionStringA, 1,1,1, 0,0,0)
      GameTooltip:AddDoubleLine(KoQuest_Loc["Horde"], reactionStringH, 1,1,1, 0,0,0)
    end
    GameTooltip:AddLine("\n" .. KoQuest_Loc["Location"], 1,1,.8)
    if KoDB[this.btype]["data"][id] and KoDB[this.btype]["data"][id]["coords"] then
      for _, data in pairs(KoDB[this.btype]["data"][id]["coords"]) do
        maps[data[3]] = maps[data[3]] or { count = 0 }
        maps[data[3]].count = maps[data[3]].count + 1
      end
    end

    local unknown = true
    for zone, obj in KoQuest:SortedPairs(maps, "count", nil) do
      GameTooltip:AddDoubleLine(( zone and KoMap:GetMapNameByID(zone) or UNKNOWN), obj.count, 1,1,1, .3,1,.8)
      unknown = nil
    end

    if unknown then
      GameTooltip:AddLine(UNKNOWN, 1,.5,.5)
    end

    GameTooltip:Show()
  end
end

local function ResultButtonUpdate()
  this.refreshCount = this.refreshCount + 1

  if not this.itemColor then
    -- Emberveil: poll GetItemInfo directly; do not force-load through GameTooltip.
    local _, _, itemQuality = GetItemInfo(this.id)
    if itemQuality then
      local r = ceil(ITEM_QUALITY_COLORS[itemQuality].r*255)
      local g = ceil(ITEM_QUALITY_COLORS[itemQuality].g*255)
      local b = ceil(ITEM_QUALITY_COLORS[itemQuality].b*255)
      this.itemColor = "|c" .. string.format("ff%02x%02x%02x", r, g, b)
    end
  end

  if this.itemColor then
    local custom = KoQuest_server["items"][this.id] and " [|cff33ffcc!|r]" or ""
    this.text:SetText(this.itemColor .."|Hitem:"..this.id..KoQuestCompat.itemsuffix.."|h[".. this.name.."]|h|r"..custom)
    this.text:SetWidth(this.text:GetStringWidth())
  end

  if this.refreshCount > 10 or this.itemColor then
    this:SetScript("OnUpdate", nil)
  end
end

local function ResultButtonClick()
  local meta = { ["addon"] = "KODB" }

  if this.btype == "items" then
    local link = "item:"..this.id..KoQuestCompat.itemsuffix
    local text = ( this.itemColor or "|cffffffff" ) .."|H" .. link .. "|h["..this.name.."]|h|r"
    SetItemRef(link, text, arg1)
  elseif this.btype == "quests" then
    if IsShiftKeyDown() then
      KoQuestCompat.InsertQuestLink(this.id)
    elseif KoBrowser.selectState then
      local maps = KoDatabase:SearchQuest(this.name, meta)
      KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    else
      local maps = KoDatabase:SearchQuestID(this.id, meta)
      KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    end
  elseif this.btype == "units" then
    if KoBrowser.selectState then
      local maps = KoDatabase:SearchMob(this.name, meta)
      KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    else
      local maps = KoDatabase:SearchMobID(this.id, meta)
      KoMap:UpdateNodes()
      KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    end
  elseif this.btype == "objects" then
    if KoBrowser.selectState then
      local maps = KoDatabase:SearchObject(this.name, meta)
      KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    else
      local maps = KoDatabase:SearchObjectID(this.id, meta)
      KoMap:UpdateNodes()
      KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    end
  end
end

local function ResultButtonClickFav()
  local parent = this:GetParent()
  if KoBrowser_fav[parent.btype][parent.id] then
    KoBrowser_fav[parent.btype][parent.id] = nil
    this.icon:SetVertexColor(1,1,1,.1)
  else
    KoBrowser_fav[parent.btype][parent.id] = parent.name
    this.icon:SetVertexColor(1,1,1,1)
  end
end

local function ResultButtonLeave()
  if KoBrowser.selectState then
    KoBrowser.selectState = "clean"
  end

  if compat.mod(this:GetID(),2) == 1 then
    this.tex:SetTexture(1,1,1,.02)
  else
    this.tex:SetTexture(1,1,1,.04)
  end
  GameTooltip:Hide()
end

local function ResultButtonClickSpecial()
  local param = this:GetParent()[this.parameter]
  local meta = { ["addon"] = "KODB" }
  local maps = {}
  if this.buttonType == "O" or this.buttonType == "U" then
    if this.selectState then
      maps = KoDatabase:SearchItem(this:GetParent().name, meta)
    else
      maps = KoDatabase:SearchItemID(param, meta, nil, {[this.buttonType]=true})
    end
  elseif this.buttonType == "V" then
    maps = KoDatabase:SearchVendor(param, meta)
  end
  KoMap:UpdateNodes()
  KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
end

local function ResultButtonEnterSpecial()
  local id = this:GetParent().id
  local count = 0
  local skip = false

  GameTooltip:SetOwner(KoBrowser, "ANCHOR_CURSOR")

  -- unit
  if this.buttonType == "U" then
    if items[id]["U"] then
      GameTooltip:SetText(KoQuest_Loc["Looted from"], .3, 1, .8)
      for unitID, chance in pairs(items[id]["U"]) do
        count = count + 1
        if count > tooltip_limit then
          skip = true
        end
        if units[unitID] and not skip then
          local name = KoDB.units.loc[unitID]
          local zone = nil
          if units[unitID].coords and units[unitID].coords[1] then
            zone = units[unitID].coords[1][3]
          end
          GameTooltip:AddDoubleLine(name, ( zone and KoMap:GetMapNameByID(zone) or UNKNOWN), 1,1,1, .5,.5,.5)
        end
      end

      -- reference tables
      if items[id]["R"] then
        for ref, chance in pairs(items[id]["R"]) do
          if refloot[ref] and refloot[ref]["U"] then
            for unit in pairs(refloot[ref]["U"]) do
              count = count + 1
              if count > tooltip_limit then
                skip = true
              end
              if units[unit] and not skip then
                local name = KoDB.units.loc[unit]
                local zone = nil
                if units[unit].coords and units[unit].coords[1] then
                  zone = units[unit].coords[1][3]
                end
                GameTooltip:AddDoubleLine(name, ( zone and KoMap:GetMapNameByID(zone) or UNKNOWN), 1,1,1, .5,.5,.5)
              end
            end
          end
        end
      end
    end

  -- object
  elseif this.buttonType == "O" then
    if items[id]["O"] then
      GameTooltip:SetText(KoQuest_Loc["Looted from"], .3, 1, .8)
      for objectID, chance in pairs(items[id]["O"]) do
        count = count + 1
        if count > tooltip_limit then
          skip = true
        end
        if objects[objectID] and not skip then
          local name = KoDB.objects.loc[objectID] or objectID
          local zone = nil
          if objects[objectID].coords and objects[objectID].coords[1] then
            zone = objects[objectID].coords[1][3]
          end
          GameTooltip:AddDoubleLine(name, ( zone and KoMap:GetMapNameByID(zone) or UNKNOWN), 1,1,1, .5,.5,.5)
        end
      end

      -- reference tables
      if items[id]["R"] then
        for ref, chance in pairs(items[id]["R"]) do
          if refloot[ref] and refloot[ref]["O"] then
            for unit in pairs(refloot[ref]["O"]) do
              count = count + 1
              if count > tooltip_limit then
                skip = true
              end
              if objects[unit] and not skip then
                local name = KoDB.objects.loc[unit]
                local zone = nil
                if objects[unit].coords and objects[unit].coords[1] then
                  zone = objects[unit].coords[1][3]
                end
                GameTooltip:AddDoubleLine(name, ( zone and KoMap:GetMapNameByID(zone) or UNKNOWN), 1,1,1, .5,.5,.5)
              end
            end
          end
        end
      end
    end

  -- vendor
  elseif this.buttonType == "V" then
    if items[id]["V"] then
      GameTooltip:SetText(KoQuest_Loc["Sold by"], .3, 1, .8)
      for unitID, sellcount in pairs(items[id]["V"]) do
        count = count + 1
        if count > tooltip_limit then
          skip = true
        end
        if units[unitID] and not skip then
          local name = KoDB.units.loc[unitID]
          if sellcount ~= 0 then name = name .. " (" .. sellcount .. ")" end
          local zone = units[unitID].coords and units[unitID].coords[1] and units[unitID].coords[1][3]
          GameTooltip:AddDoubleLine(name, ( zone and KoMap:GetMapNameByID(zone) or UNKNOWN), 1,1,1, .5,.5,.5)
        end
      end
    end
  end

  if count > tooltip_limit then
    GameTooltip:AddLine("\n" .. KoQuest_Loc["and"] .. " " .. (count - tooltip_limit).." " .. KoQuest_Loc["others"],.8,.8,.8)
  end
  GameTooltip:Show()
end

local function ResultButtonLeaveSpecial()
  GameTooltip:Hide()
end

local function ResultButtonReload(self)
  self.idText:SetText("ID: " .. self.id)

  if KoQuest_config.showids == "1" then
    self.idText:Show()
  else
    self.idText:Hide()
  end

  self.itemColor = nil

  -- update faction
  if self.btype ~= "items" then
    self.factionA:Hide()
    self.factionH:Hide()

    local raceMask = KoDatabase:GetRaceMaskByID(self.id, self.btype)
    if (bit.band(77, raceMask) > 0)  or (raceMask == 0 and self.btype == "quests") then
      self.factionA:Show()
    end
    if (bit.band(178, raceMask) > 0)  or (raceMask == 0 and self.btype == "quests") then
      self.factionH:Show()
    end
  end

  -- activate fav buttons if needed
  if KoBrowser_fav and KoBrowser_fav[self.btype] and KoBrowser_fav[self.btype][self.id] then
    self.fav.icon:SetVertexColor(1,1,1,1)
  else
    self.fav.icon:SetVertexColor(1,1,1,.1)
  end

  -- actions by search type
  if self.btype == "quests" then
    self.name = KoDB[self.btype]["loc"][self.id]["T"]
    self.text:SetText("|cffffcc00|Hquest:0:0:0:0|h[" .. self.name .. "]|h|r")
  elseif self.btype == "units" or self.btype == "objects" then
    local level = KoDB[self.btype]["data"][self.id] and KoDB[self.btype]["data"][self.id]["lvl"] or ""
    if level and level ~= "" then level = " (" .. level .. ")" end
    self.text:SetText(self.name .. "|cffaaaaaa" .. level)

    if KoDB[self.btype]["data"][self.id] and KoDB[self.btype]["data"][self.id]["coords"] then
      self.text:SetTextColor(1,1,1)
    else
      self.text:SetTextColor(.5,.5,.5)
    end
  elseif self.btype == "items" then
    for _, key in ipairs({"U","O","V"}) do
      if items[self.id] and items[self.id][key] then
        self[key]:Show()
      else
        self[key]:Hide()
      end
    end

    self.text:SetText("|cffff5555[?] |cffffffff" .. self.name)

    self.refreshCount = 0
    self:SetScript("OnUpdate", ResultButtonUpdate)
  end

  self.text:SetWidth(self.text:GetStringWidth())
  self:Show()
end

local function ResultButtonCreate(i, resultType)
  local f = CreateFrame("Button", nil, KoBrowser.tabs[resultType].list)
  f:SetPoint("TOPLEFT", KoBrowser.tabs[resultType].list, "TOPLEFT", 10, -i*30 + 5)
  f:SetPoint("BOTTOMRIGHT", KoBrowser.tabs[resultType].list, "TOPRIGHT", 10, -i*30 - 15)
  f:Hide()
  f:SetID(i)

  f.btype = resultType
  f.KoResultButton = true

  f.tex = f:CreateTexture("BACKGROUND")
  f.tex:SetAllPoints(f)
  f.tex:SetTexture(1,1,1, ( compat.mod(i,2) == 1 and .02 or .04))

  -- text properties
  f.text = f:CreateFontString("Caption", "LOW", "GameFontWhite")
  f.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
  f.text:SetAllPoints(f)
  f.text:SetJustifyH("CENTER")
  f.idText = f:CreateFontString("ID", "LOW", "GameFontDisable")
  f.idText:SetPoint("LEFT", f, "LEFT", 30, 0)

  -- favourite button
  f.fav = CreateFrame("Button", nil, f)
  f.fav:SetHitRectInsets(-3,-3,-3,-3)
  f.fav:SetPoint("LEFT", 0, 0)
  f.fav:SetWidth(16)
  f.fav:SetHeight(16)
  f.fav.icon = f.fav:CreateTexture("OVERLAY")
  f.fav.icon:SetTexture(KoQuestConfig.path.."\\img\\fav")
  f.fav.icon:SetAllPoints(f.fav)

  -- faction icons
  if resultType ~= "items" then
    f.factionA = f:CreateTexture("OVERLAY")
    f.factionA:SetTexture(KoQuestConfig.path.."\\img\\icon_alliance")
    f.factionA:SetWidth(16)
    f.factionA:SetHeight(16)
    f.factionA:SetPoint("RIGHT", -5, 0)
    f.factionH = f:CreateTexture("OVERLAY")
    f.factionH:SetTexture(KoQuestConfig.path.."\\img\\icon_horde")
    f.factionH:SetWidth(16)
    f.factionH:SetHeight(16)
    f.factionH:SetPoint("RIGHT", -24, 0)
  end

  -- drop, loot, vendor buttons
  if resultType == "items" then
    local buttons = {
      ["U"] = { ["offset"] = -5,  ["icon"] = "icon_npc",    ["parameter"] = "id",   },
      ["O"] = { ["offset"] = -24, ["icon"] = "icon_object", ["parameter"] = "id",   },
      ["V"] = { ["offset"] = -43, ["icon"] = "icon_vendor", ["parameter"] = "name", },
    }

    for button, settings in pairs(buttons) do
      f[button] = CreateFrame("Button", nil, f)
      f[button]:SetHitRectInsets(-3,-3,-3,-3)
      f[button]:SetPoint("RIGHT", settings.offset, 0)
      f[button]:SetWidth(16)
      f[button]:SetHeight(16)

      f[button].buttonType = button
      f[button].parameter = settings.parameter

      f[button].icon = f[button]:CreateTexture("OVERLAY")
      f[button].icon:SetAllPoints(f[button])
      f[button].icon:SetTexture(KoQuestConfig.path.."\\img\\"..settings.icon)

      f[button]:SetScript("OnEnter", ResultButtonEnterSpecial)
      f[button]:SetScript("OnLeave", ResultButtonLeaveSpecial)
      f[button]:SetScript("OnClick", ResultButtonClickSpecial)
    end
  end

  -- bind functions
  f.Reload = ResultButtonReload
  f:SetScript("OnLeave", ResultButtonLeave)
  f:SetScript("OnEnter", ResultButtonEnter)
  f:SetScript("OnClick", ResultButtonClick)
  f.fav:SetScript("OnClick", ResultButtonClickFav)

  return f
end

local function SelectView(view)
  for id, frame in pairs(KoBrowser.tabs) do
    pfUI.api.SetButtonFontColor(frame.button, 1,1,1,.7)
    frame:Hide()
  end
  pfUI.api.SetButtonFontColor(view.button, .2,1,.8,1)
  view.button:Hide()
  view.button:Show()
  view:Show()
end

-- sets the browser result values when they change
local function RefreshView(i, key, caption)
  KoBrowser.tabs[key].list:Hide()
  KoBrowser.tabs[key].list:SetHeight(i * 30 )
  KoBrowser.tabs[key].list:Show()
  KoBrowser.tabs[key].list:GetParent():SetScrollChild(KoBrowser.tabs[key].list)
  KoBrowser.tabs[key].list:GetParent():SetVerticalScroll(0)

  if not KoBrowser.tabs[key].list.warn then
    KoBrowser.tabs[key].list.warn = KoBrowser.tabs[key].list:CreateFontString("Caption", "LOW", "GameFontWhite")
    KoBrowser.tabs[key].list.warn:SetTextColor(1,.2,.2,1)
    KoBrowser.tabs[key].list.warn:SetJustifyH("CENTER")
    KoBrowser.tabs[key].list.warn:SetPoint("TOP", 5, -5)
    KoBrowser.tabs[key].list.warn:SetText("!! |cffffffff" .. KoQuest_Loc["Too many entries. Results shown"] .. ": " .. search_limit .. "|r !!")
  end

  if i >= search_limit then
    KoBrowser.tabs[key].list.warn:Show()
  else
    KoBrowser.tabs[key].list.warn:Hide()
  end

  KoBrowser.tabs[key].button:SetText(KoQuest_Loc[caption] .. " " .. "|cffaaaaaa(" .. (i >= search_limit and "*" or i) .. ")")
  for j=i+1, table.getn(KoBrowser.tabs[key].buttons) do
    if KoBrowser.tabs[key].buttons[j] then
      KoBrowser.tabs[key].buttons[j]:Hide()
      KoBrowser.tabs[key].buttons[j].id = nil
      KoBrowser.tabs[key].buttons[j].name = nil
    end
  end
end

-- sets up all the browse windows and their activation buttons
local function CreateBrowseWindow(fname, name, parent, anchor, x, y)
  if not parent.tabs then parent.tabs = {} end
  parent.tabs[fname] = pfUI.api.CreateScrollFrame(name, parent)
  parent.tabs[fname]:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -65)
  parent.tabs[fname]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 45)
  parent.tabs[fname]:Hide()
  parent.tabs[fname].buttons = { }

  parent.tabs[fname].backdrop = CreateFrame("Frame", name .. "Backdrop", parent.tabs[fname])
  parent.tabs[fname].backdrop:SetFrameLevel(1)
  parent.tabs[fname].backdrop:SetPoint("TOPLEFT", parent.tabs[fname], "TOPLEFT", -5, 5)
  parent.tabs[fname].backdrop:SetPoint("BOTTOMRIGHT", parent.tabs[fname], "BOTTOMRIGHT", 5, -5)
  pfUI.api.CreateBackdrop(parent.tabs[fname].backdrop, nil, true)

  parent.tabs[fname].button = CreateFrame("Button", name .. "Button", parent)
  parent.tabs[fname].button:SetPoint(anchor, x, y)
  parent.tabs[fname].button:SetWidth(153)
  parent.tabs[fname].button:SetHeight(30)
  parent.tabs[fname].button:SetScript("OnClick", function()
    SelectView(parent.tabs[fname])
  end)

  if fname == "units" then
    EnableTooltips(parent.tabs[fname].button, {
      KoQuest_Loc["Units"],
      KoQuest_Loc["Display related creatures and NPCs"],
    })
  elseif fname == "objects" then
    EnableTooltips(parent.tabs[fname].button, {
      KoQuest_Loc["Objects"],
      KoQuest_Loc["Display related objects like ores, herbs, chests, etc."],
    })
  elseif fname == "items" then
    EnableTooltips(parent.tabs[fname].button, {
      KoQuest_Loc["Items"],
      KoQuest_Loc["Display related items"],
    })
  elseif fname == "quests" then
    EnableTooltips(parent.tabs[fname].button, {
      KoQuest_Loc["Quests"],
      KoQuest_Loc["Display related quests"],
    })
  end

  pfUI.api.SkinButton(parent.tabs[fname].button)
  parent.tabs[fname].list = pfUI.api.CreateScrollChild(name .. "Scroll", parent.tabs[fname])
  parent.tabs[fname].list:SetWidth(600)
end

-- browser window
KoBrowser = CreateFrame("Frame", "KoQuestBrowser", UIParent)
KoBrowser:Hide()
KoBrowser:SetWidth(640)
KoBrowser:SetHeight(480)
KoBrowser:SetPoint("CENTER", 0, 0)
KoBrowser:SetFrameStrata("FULLSCREEN_DIALOG")
KoBrowser:SetMovable(true)
KoBrowser:EnableMouse(true)
KoBrowser:RegisterEvent("PLAYER_ENTERING_WORLD")
KoBrowser:SetScript("OnEvent", function()
  -- show all favorites on login if configured
  if KoQuest_config.favonlogin == "1" then
    -- search units
    for id, name in pairs(KoBrowser_fav.units) do
      KoDatabase:SearchMobID(id)
    end

    -- search objects
    for id, name in pairs(KoBrowser_fav.objects) do
      KoDatabase:SearchObjectID(id)
    end

    -- search items
    for id, name in pairs(KoBrowser_fav.items) do
      KoDatabase:SearchItemID(id)
    end

    -- search quests
    for id, name in pairs(KoBrowser_fav.quests) do
      KoDatabase:SearchQuestID(id)
    end
  end
end)
KoBrowser:SetScript("OnMouseDown",function()
  this:StartMoving()
end)

KoBrowser:SetScript("OnMouseUp",function()
  this:StopMovingOrSizing()
end)

KoBrowser:SetScript("OnUpdate", function()
  -- multi-select handling
  if not this.selectState and IsControlKeyDown() and GetMouseFocus() and GetMouseFocus().KoResultButton then
    for id, frame in pairs(KoBrowser.tabs) do
      for id, button in pairs(frame.buttons) do
        if button.name == GetMouseFocus().name then
          button.tex:SetTexture(.3,1,.8,.4)
        end
      end
    end
    this.selectState = "active"

  elseif this.selectState and (this.selectState == "clean" or not IsControlKeyDown()) then
    for id, frame in pairs(KoBrowser.tabs) do
      for id, button in pairs(frame.buttons) do
        if compat.mod(button:GetID(),2) == 1 then
          button.tex:SetTexture(1,1,1,.02)
        else
          button.tex:SetTexture(1,1,1,.04)
        end
      end
    end
    this.selectState = nil
  end
end)

pfUI.api.CreateBackdrop(KoBrowser, nil, true, 0.75)
table.insert(UISpecialFrames, "KoQuestBrowser")

KoBrowser.title = KoBrowser:CreateFontString("Status", "LOW", "GameFontNormal")
KoBrowser.title:SetFontObject(GameFontWhite)
KoBrowser.title:SetPoint("TOP", KoBrowser, "TOP", 0, -8)
KoBrowser.title:SetJustifyH("LEFT")
KoBrowser.title:SetFont(pfUI.font_default, 14)
KoBrowser.title:SetText("|cff33ffccKo|rQuest")

KoBrowser.close = CreateFrame("Button", "KoQuestBrowserClose", KoBrowser)
KoBrowser.close:SetPoint("TOPRIGHT", -5, -5)
KoBrowser.close:SetHeight(20)
KoBrowser.close:SetWidth(20)
KoBrowser.close.texture = KoBrowser.close:CreateTexture("KoQuestionDialogCloseTex")
KoBrowser.close.texture:SetTexture(KoQuestConfig.path.."\\compat\\close")
KoBrowser.close.texture:ClearAllPoints()
KoBrowser.close.texture:SetVertexColor(1,.25,.25,1)
KoBrowser.close.texture:SetPoint("TOPLEFT", KoBrowser.close, "TOPLEFT", 4, -4)
KoBrowser.close.texture:SetPoint("BOTTOMRIGHT", KoBrowser.close, "BOTTOMRIGHT", -4, 4)
KoBrowser.close:SetScript("OnClick", function()
  this:GetParent():Hide()
end)
EnableTooltips(KoBrowser.close, {
  KoQuest_Loc["Close"],
  KoQuest_Loc["Hide browser window"],
})
pfUI.api.SkinButton(KoBrowser.close, 1, .5, .5)

KoBrowser.journal = CreateFrame("Button", "KoQuestJournalOpen", KoBrowser)
KoBrowser.journal:SetPoint("TOPRIGHT", -30, -5)
KoBrowser.journal:SetHeight(20)
KoBrowser.journal:SetWidth(20)
KoBrowser.journal.texture = KoBrowser.journal:CreateTexture("KoQuestionDialogCloseTex")
KoBrowser.journal.texture:SetTexture(KoQuestConfig.path.."\\img\\tracker_quests")
KoBrowser.journal.texture:ClearAllPoints()
KoBrowser.journal.texture:SetPoint("TOPLEFT", KoBrowser.journal, "TOPLEFT", 2, -2)
KoBrowser.journal.texture:SetPoint("BOTTOMRIGHT", KoBrowser.journal, "BOTTOMRIGHT", -2, 2)
KoBrowser.journal:SetScript("OnClick", function()
  if KoJournal:IsShown() then KoJournal:Hide() else KoJournal:Show() end
end)
EnableTooltips(KoBrowser.journal, {
  KoQuest_Loc["Journal"],
  KoQuest_Loc["Toggle completed quest browser"],
})
pfUI.api.SkinButton(KoBrowser.journal)

KoBrowser.clean = CreateFrame("Button", "KoQuestBrowserClean", KoBrowser)
KoBrowser.clean:SetPoint("TOPRIGHT", KoBrowser, "TOPRIGHT", -5, -30)
KoBrowser.clean:SetPoint("BOTTOMRIGHT", KoBrowser, "TOPRIGHT", 0, -55)
KoBrowser.clean:SetScript("OnClick", function()
  KoMap:DeleteNode("KODB")
  KoMap:UpdateNodes()
end)
KoBrowser.clean.text = KoBrowser.clean:CreateFontString("Caption", "LOW", "GameFontWhite")
KoBrowser.clean.text:SetAllPoints(KoBrowser.clean)
KoBrowser.clean.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
KoBrowser.clean.text:SetText(KoQuest_Loc["Clean Map"])
local width = KoBrowser.clean.text:GetStringWidth() > 90 and KoBrowser.clean.text:GetStringWidth() + 20 or 90
KoBrowser.clean:SetWidth(width)
EnableTooltips(KoBrowser.clean, {
  KoQuest_Loc["Clean Map"],
  KoQuest_Loc["Remove all manually searched objects from the map"],
})
pfUI.api.SkinButton(KoBrowser.clean)

CreateBrowseWindow("units", "KoQuestBrowserUnits", KoBrowser, "BOTTOMLEFT", 5, 5)
CreateBrowseWindow("objects", "KoQuestBrowserObjects", KoBrowser, "BOTTOMLEFT", 164, 5)
CreateBrowseWindow("items", "KoQuestBrowserItems", KoBrowser, "BOTTOMRIGHT", -164, 5)
CreateBrowseWindow("quests", "KoQuestBrowserQuests", KoBrowser, "BOTTOMRIGHT", -5, 5)

SelectView(KoBrowser.tabs["units"])

KoBrowser.input = CreateFrame("EditBox", "KoQuestBrowserSearch", KoBrowser)
KoBrowser.input:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
KoBrowser.input:SetFontObject("GameFontDisable")
KoBrowser.input:SetAutoFocus(false)
KoBrowser.input:SetText(KoQuest_Loc["Search"])
KoBrowser.input:SetJustifyH("LEFT")
KoBrowser.input:SetPoint("TOPLEFT", KoBrowser, "TOPLEFT", 5, -30)
KoBrowser.input:SetPoint("BOTTOMRIGHT", KoBrowser.clean, "BOTTOMLEFT", -5, 0)
KoBrowser.input:SetTextInsets(24,12,4,4)

KoBrowser.input.searchIcon = KoBrowser.input:CreateTexture("$parentSearchIcon", "OVERLAY")
KoBrowser.input.searchIcon:SetTexture(KoQuestConfig.path.."\\img\\tracker_search")
KoBrowser.input.searchIcon:SetHeight(14)
KoBrowser.input.searchIcon:SetWidth(14)
KoBrowser.input.searchIcon:SetVertexColor(0.6, 0.6, 0.6)
KoBrowser.input.searchIcon:SetPoint("LEFT", KoBrowser.input, "LEFT", 6, 0)

KoBrowser.input.clearButton = CreateFrame("Button", "$parentClearButton", KoBrowser.input)
KoBrowser.input.clearButton:Hide()
KoBrowser.input.clearButton:SetHeight(17)
KoBrowser.input.clearButton:SetWidth(17)
KoBrowser.input.clearButton:SetPoint("RIGHT", KoBrowser.input, "RIGHT", -3, 0)
KoBrowser.input.clearButton.texture = KoBrowser.input.clearButton:CreateTexture(nil, "ARTWORK")
KoBrowser.input.clearButton.texture:SetTexture(KoQuestConfig.path.."\\img\\tracker_close")
KoBrowser.input.clearButton.texture:SetHeight(17)
KoBrowser.input.clearButton.texture:SetWidth(17)
KoBrowser.input.clearButton.texture:SetAlpha(0.5)
KoBrowser.input.clearButton.texture:SetPoint("TOPLEFT", KoBrowser.input.clearButton, "TOPLEFT", 0, 0)
KoBrowser.input.clearButton:SetScript("OnEnter", function()
  this.texture:SetAlpha(1.0)
end)
KoBrowser.input.clearButton:SetScript("OnLeave", function()
  this.texture:SetAlpha(0.5)
end)
KoBrowser.input.clearButton:SetScript("OnMouseDown", function()
  if this:IsEnabled() then
    this.texture:SetPoint("TOPLEFT", this, "TOPLEFT", 1, -1)
  end
end)
KoBrowser.input.clearButton:SetScript("OnMouseUp", function()
  this.texture:SetPoint("TOPLEFT", this, "TOPLEFT", 0, 0)
end)
KoBrowser.input.clearButton:SetScript("OnClick", function()
  PlaySound("igMainMenuOptionCheckBoxOn")
  KoBrowser.input:SetText("")
  --[[
  If there is no focus, then the ClearFocus() method does not call the OnEditFocusLost script.
  In 1.12, there is no HasFocus() method, so there is no way to check for focus. therefore,
  for ease of implementation and to avoid double calling the OnEditFocusLost script, I use the
  SetFocus() method to accurately ensure that the OnEditFocusLost script is called.
  --]]
  KoBrowser.input:SetFocus()
  KoBrowser.input:ClearFocus()
end)

KoBrowser.input:SetScript("OnEscapePressed", function() this:ClearFocus() end)
KoBrowser.input:SetScript("OnEnterPressed", function() this:ClearFocus() end)
KoBrowser.input:SetScript("OnEditFocusGained", function()
  this:HighlightText()
  this:SetFontObject("GameFontWhite")
  this.searchIcon:SetVertexColor(1.0, 1.0, 1.0)
  if this:GetText() == KoQuest_Loc["Search"] then this:SetText("") end
  this.clearButton:Show()
end)

KoBrowser.input:SetScript("OnEditFocusLost", function()
  this:HighlightText(0, 0)
  this:SetFontObject("GameFontDisable")
  this.searchIcon:SetVertexColor(0.6, 0.6, 0.6)
  if this:GetText() == "" then
    this:SetText(KoQuest_Loc["Search"])
    this.clearButton:Hide()
  end
end)

-- This script updates all the search tabs when the search text changes
KoBrowser.input:SetScript("OnTextChanged", function()
  local text = this:GetText()
  if (text == KoQuest_Loc["Search"]) then text = "" end

  local custom = string.find(text, "^custom:")
  text = string.gsub(text, "^custom:", "")

  for _, caption in ipairs({"Units","Objects","Items","Quests"}) do
    local searchType = strlower(caption)

    local data = (strlen(text) >= 3 or custom) and KoDatabase:GetIDByName(text, searchType, true, custom) or KoBrowser_fav[searchType]

    local i = 0
    for id, text in pairs(data) do
      i = i + 1

      if i >= search_limit then break end
      KoBrowser.tabs[searchType].buttons[i] = KoBrowser.tabs[searchType].buttons[i] or ResultButtonCreate(i, searchType)
      KoBrowser.tabs[searchType].buttons[i].id = id
      KoBrowser.tabs[searchType].buttons[i].name = text
      KoBrowser.tabs[searchType].buttons[i]:Reload()
    end

    RefreshView(i, searchType, caption)
  end
end)

pfUI.api.CreateBackdrop(KoBrowser.input, nil, true)
