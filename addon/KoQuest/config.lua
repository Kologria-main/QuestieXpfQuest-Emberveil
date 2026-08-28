-- multi api compat
local compat = KoQuestCompat
local L = KoQuest_Loc

KoQuest_history = {}
KoQuest_colors = {}
KoQuest_config = {}

local reset = {
  config = function()
    local dialog = StaticPopupDialogs["KOQUEST_RESET"]
    dialog.text = L["Do you really want to reset the configuration?"]
    dialog.OnAccept = function()
      KoQuest_config = nil
      if KoQuestConfig and KoQuestConfig.EmberveilRefreshAfterReset then KoQuestConfig:EmberveilRefreshAfterReset() end
    end

    StaticPopup_Show("KOQUEST_RESET")
  end,
  history = function()
    local dialog = StaticPopupDialogs["KOQUEST_RESET"]
    dialog.text = L["Do you really want to reset the quest history?"]
    dialog.OnAccept = function()
      KoQuest_history = nil
      if KoQuestConfig and KoQuestConfig.EmberveilRefreshAfterReset then KoQuestConfig:EmberveilRefreshAfterReset() end
    end

    StaticPopup_Show("KOQUEST_RESET")
  end,
  cache = function()
    local dialog = StaticPopupDialogs["KOQUEST_RESET"]
    dialog.text = L["Do you really want to reset the caches?"]
    dialog.OnAccept = function()
      KoQuest_questcache = nil
      if KoQuestConfig and KoQuestConfig.EmberveilRefreshAfterReset then KoQuestConfig:EmberveilRefreshAfterReset() end
    end

    StaticPopup_Show("KOQUEST_RESET")
  end,
  everything = function()
    local dialog = StaticPopupDialogs["KOQUEST_RESET"]
    dialog.text = L["Do you really want to reset everything?"]
    dialog.OnAccept = function()
      KoQuest_config, KoBrowser_fav, KoQuest_history, KoQuest_colors, KoQuest_server, KoQuest_questcache = nil
      if KoQuestConfig and KoQuestConfig.EmberveilRefreshAfterReset then KoQuestConfig:EmberveilRefreshAfterReset() end
    end

    StaticPopup_Show("KOQUEST_RESET")
  end,
}

-- default config
KoQuest_defconfig = {
  { -- 1: All Quests; 2: Tracked; 3: Manual; 4: Hide
    config = "trackingmethod",
    text = nil, default = 1, type = nil
  },

  { text = L["General"],
    default = nil, type = "header" },
  { text = L["Enable World Map Menu"],
    default = "1", type = "checkbox", config = "worldmapmenu" },
  { text = L["Enable Minimap Button"],
    default = "1", type = "checkbox", config = "minimapbutton" },
  { text = L["Enable Quest Tracker"],
    default = "1", type = "checkbox", config = "showtracker" },
  { text = L["Enable Quest Log Buttons"],
    default = "1", type = "checkbox", config = "questlogbuttons" },
  { text = L["Enable Quest Link Support"],
    default = "1", type = "checkbox", config = "questlinks" },
  { text = L["Show Database IDs"],
    default = "0", type = "checkbox", config = "showids" },
  { text = L["Draw Favorites On Login"],
    default = "0", type = "checkbox", config = "favonlogin" },
  { text = L["Minimum Item Drop Chance"],
    default = "1", type = "text", config = "mindropchance" },
  { text = L["Show Tooltips"],
    default = "1", type = "checkbox", config = "showtooltips" },
  { text = L["Show Help On Tooltips"],
    default = "1", type = "checkbox", config = "tooltiphelp" },
  { text = L["Show Level On Quest Tracker"],
    default = "1", type = "checkbox", config = "trackerlevel" },
  { text = L["Show Level On Quest Log"],
    default = "0", type = "checkbox", config = "questloglevel" },

  { text = L["Questing"],
    default = nil, type = "header" },
  { text = L["Quest Tracker Visibility"],
    default = "0", type = "text", config = "trackeralpha" },
  { text = L["Quest Tracker Font Size"],
    default = "12", type = "text", config = "trackerfontsize", },
  { text = L["Quest Tracker Unfold Objectives"],
    default = "0", type = "checkbox", config = "trackerexpand" },
  { text = L["Quest Objective Spawn Points (World Map)"],
    default = "1", type = "checkbox", config = "showspawn" },
  { text = L["Quest Objective Spawn Points (Mini Map)"],
    default = "1", type = "checkbox", config = "showspawnmini" },
  { text = L["Quest Objective Icons (World Map)"],
    default = "1", type = "checkbox", config = "showcluster" },
  { text = L["Quest Objective Icons (Mini Map)"],
    default = "0", type = "checkbox", config = "showclustermini" },
  { text = L["Display Available Quest Givers"],
    default = "1", type = "checkbox", config = "allquestgivers" },
  { text = L["Allow Best-Effort Quest Givers (May Include Completed Quests)"],
    default = "1", type = "checkbox", config = "unverifiedquestgivers" },
  { text = L["Display Current Quest Givers"],
    default = "1", type = "checkbox", config = "currentquestgivers" },
  { text = L["Display Low Level Quest Givers"],
    default = "0", type = "checkbox", config = "showlowlevel" },
  { text = L["Display Level+3 Quest Givers"],
    default = "0", type = "checkbox", config = "showhighlevel" },
  { text = L["Display Event & Daily Quests"],
    default = "0", type = "checkbox", config = "showfestival" },

  { text = L["Map & Minimap"],
    default = nil, type = "header" },
  { text = L["Enable Minimap Nodes"],
    default = "1", type = "checkbox", config = "minimapnodes" },
  { text = L["Use Icons For Tracking Nodes"],
    default = "1", type = "checkbox", config = "trackingicons" },
  { text = L["Use Monochrome Cluster Icons"],
    default = "0", type = "checkbox", config = "clustermono" },
  { text = L["Use Cut-Out Minimap Node Icons"],
    default = "1", type = "checkbox", config = "cutoutminimap" },
  { text = L["Use Cut-Out World Map Node Icons"],
    default = "0", type = "checkbox", config = "cutoutworldmap" },
  { text = L["Color Map Nodes By Spawn"],
    default = "0", type = "checkbox", config = "spawncolors" },
  { text = L["World Map Node Transparency"],
    default = "1.0", type = "text", config = "worldmaptransp" },
  { text = L["Minimap Node Transparency"],
    default = "1.0", type = "text", config = "minimaptransp" },
  { text = L["Node Fade Transparency"],
    default = "0.3", type = "text", config = "nodefade" },
  { text = L["Highlight Nodes On Mouseover"],
    default = "1", type = "checkbox", config = "mouseover" },

  { text = L["Routes"],
    default = nil, type = "header" },
  { text = L["Show Route Between Objects"],
    default = "1", type = "checkbox", config = "routes" },
  { text = L["Include Unified Quest Locations"],
    default = "1", type = "checkbox", config = "routecluster" },
  { text = L["Include Quest Enders"],
    default = "1", type = "checkbox", config = "routeender" },
  { text = L["Include Quest Starters"],
    default = "0", type = "checkbox", config = "routestarter" },
  { text = L["Show Route On Minimap"],
    default = "0", type = "checkbox", config = "routeminimap" },

  { text = L["User Data"],
    default = nil, type = "header" },
  { text = L["Reset Configuration"],
    default = "1", type = "button", func = reset.config },
  { text = L["Reset Quest History"],
    default = "1", type = "button", func = reset.history },
  { text = L["Reset Cache"],
    default = "1", type = "button", func = reset.cache },
  { text = L["Reset Everything"],
    default = "1", type = "button", func = reset.everything },
}

StaticPopupDialogs["KOQUEST_RESET"] = {
  button1 = YES,
  button2 = NO,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
}

KoQuestConfig = CreateFrame("Frame", "KoQuestConfig", UIParent)
KoQuestConfig:Hide()
KoQuestConfig:SetWidth(280)
KoQuestConfig:SetHeight(550)
KoQuestConfig:SetPoint("CENTER", 0, 0)
KoQuestConfig:SetFrameStrata("HIGH")
KoQuestConfig:SetMovable(true)
KoQuestConfig:EnableMouse(true)
KoQuestConfig:SetClampedToScreen(true)
KoQuestConfig:RegisterEvent("ADDON_LOADED")
KoQuestConfig:SetScript("OnEvent", function()
  if arg1 == "KoQuest" or arg1 == "KoQuest-tbc" or arg1 == "KoQuest-wotlk" then
    KoQuestConfig:LoadConfig()
    KoQuestConfig:MigrateHistory()
    KoQuestConfig:CreateConfigEntries(KoQuest_defconfig)

    KoQuest_questcache = KoQuest_questcache or {}
    KoQuest_history = KoQuest_history or {}
    KoQuest_colors = KoQuest_colors or {}
    KoQuest_config = KoQuest_config or {}
    KoQuest_track = KoQuest_track or {}
    KoBrowser_fav = KoBrowser_fav or {["units"] = {}, ["objects"] = {}, ["items"] = {}, ["quests"] = {}}

    -- clear quest history on new characters
    if UnitXP("player") == 0 and UnitLevel("player") == 1 then
      KoQuest_history = {}
    end

    if KoBrowserIcon and KoQuest_config["minimapbutton"] == "0" then
      KoBrowserIcon:Hide()
    end
  end
end)

KoQuestConfig:SetScript("OnMouseDown", function()
  this:StartMoving()
end)

KoQuestConfig:SetScript("OnMouseUp", function()
  this:StopMovingOrSizing()
end)

KoQuestConfig:SetScript("OnShow", function()
  this:UpdateConfigEntries()
end)

KoQuestConfig.vpos = 40

pfUI.api.CreateBackdrop(KoQuestConfig, nil, true, 0.75)
table.insert(UISpecialFrames, "KoQuestConfig")

-- detect current addon path
local tocs = { "", "-master", "-tbc", "-wotlk" }
for _, name in pairs(tocs) do
  local current = string.format("KoQuest%s", name)
  local _, title = GetAddOnInfo(current)
  if title then
    KoQuestConfig.path = "Interface\\AddOns\\" .. current
    KoQuestConfig.version = tostring(GetAddOnMetadata(current, "Version"))
    break
  end
end

KoQuestConfig.title = KoQuestConfig:CreateFontString("Status", "LOW", "GameFontNormal")
KoQuestConfig.title:SetFontObject(GameFontWhite)
KoQuestConfig.title:SetPoint("TOP", KoQuestConfig, "TOP", 0, -8)
KoQuestConfig.title:SetJustifyH("LEFT")
KoQuestConfig.title:SetFont(pfUI.font_default, 14)
KoQuestConfig.title:SetText("|cff33ffccKo|rQuest " .. L["Config"])

KoQuestConfig.close = CreateFrame("Button", "KoQuestConfigClose", KoQuestConfig)
KoQuestConfig.close:SetPoint("TOPRIGHT", -5, -5)
KoQuestConfig.close:SetHeight(20)
KoQuestConfig.close:SetWidth(20)
KoQuestConfig.close.texture = KoQuestConfig.close:CreateTexture("KoQuestionDialogCloseTex")
KoQuestConfig.close.texture:SetTexture(KoQuestConfig.path.."\\compat\\close")
KoQuestConfig.close.texture:ClearAllPoints()
KoQuestConfig.close.texture:SetPoint("TOPLEFT", KoQuestConfig.close, "TOPLEFT", 4, -4)
KoQuestConfig.close.texture:SetPoint("BOTTOMRIGHT", KoQuestConfig.close, "BOTTOMRIGHT", -4, 4)

KoQuestConfig.close.texture:SetVertexColor(1,.25,.25,1)
pfUI.api.SkinButton(KoQuestConfig.close, 1, .5, .5)
KoQuestConfig.close:SetScript("OnClick", function()
  this:GetParent():Hide()
end)

KoQuestConfig.welcome = CreateFrame("Button", "KoQuestConfigWelcome", KoQuestConfig)
KoQuestConfig.welcome:SetWidth(160)
KoQuestConfig.welcome:SetHeight(28)
KoQuestConfig.welcome:SetPoint("BOTTOMLEFT", 10, 10)
KoQuestConfig.welcome:SetScript("OnClick", function() KoQuestConfig:Hide(); KoQuestInit:Show() end)
KoQuestConfig.welcome.text = KoQuestConfig.welcome:CreateFontString("Caption", "LOW", "GameFontWhite")
KoQuestConfig.welcome.text:SetAllPoints(KoQuestConfig.welcome)
KoQuestConfig.welcome.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
KoQuestConfig.welcome.text:SetText(L["Welcome Screen"])
pfUI.api.SkinButton(KoQuestConfig.welcome)

KoQuestConfig.save = CreateFrame("Button", "KoQuestConfigReload", KoQuestConfig)
KoQuestConfig.save:SetWidth(160)
KoQuestConfig.save:SetHeight(28)
KoQuestConfig.save:SetPoint("BOTTOMRIGHT", -10, 10)
KoQuestConfig.save:SetScript("OnClick", function()
  KoQuestConfig:ApplyEmberveilSettings(KoQuestConfig.emberveilNeedsRebuild == true)
  KoQuestConfig:Hide()
end)
KoQuestConfig.save.text = KoQuestConfig.save:CreateFontString("Caption", "LOW", "GameFontWhite")
KoQuestConfig.save.text:SetAllPoints(KoQuestConfig.save)
KoQuestConfig.save.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
KoQuestConfig.save.text:SetText(L["Save & Close"])
pfUI.api.SkinButton(KoQuestConfig.save)

function KoQuestConfig:LoadConfig()
  if not KoQuest_config then KoQuest_config = {} end

  -- beta1.19 changes the default from fail-closed to useful best effort.
  -- Emberveil exposes no character-wide completion getter, so the database and
  -- KoQuest's locally recorded completion history are the only passive source
  -- for quest-giver markers. Apply the new default once to existing installs;
  -- players can still turn the clearly labelled setting off afterwards.
  if KoQuest_config["availabilitydefaultv2"] ~= "1" then
    KoQuest_config["unverifiedquestgivers"] = "1"
    KoQuest_config["availabilitydefaultv2"] = "1"
  end

  for id, data in ipairs(KoQuest_defconfig) do
    if data.config and not KoQuest_config[data.config] then
      KoQuest_config[data.config] = data.default
    end
  end
end

function KoQuestConfig:MigrateHistory()
  if not KoQuest_history then return end

  local match = false

  for entry, data in pairs(KoQuest_history) do
    if type(entry) == "string" then
      for id in pairs(KoDatabase:GetIDByName(entry, "quests")) do
        KoQuest_history[id] = { 0, 0 }
        KoQuest_history[entry] = nil
        match = true
      end
    elseif data == true then
      KoQuest_history[entry] = { 0, 0 }
    elseif type(data) == "table" and not data[1] then
      KoQuest_history[entry] = { 0, 0 }
    end
  end

  if match == true then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccKo|cffffffffQuest|r: " .. L["Quest history migration completed."])
  end
end

local maxh, maxw = 0, 0
local width, height = 230, 22
local maxtext = 130
local configframes = {}
function KoQuestConfig:CreateConfigEntries(config)
  local count = 1

  for _, data in ipairs(config) do
    if data.type then
      -- basic frame
      local frame = CreateFrame("Frame", "KoQuestConfig" .. count, KoQuestConfig)
      configframes[data.text] = frame

      -- caption
      frame.caption = frame:CreateFontString("Status", "LOW", "GameFontWhite")
      frame.caption:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
      frame.caption:SetPoint("LEFT", 20, 0)
      frame.caption:SetJustifyH("LEFT")
      frame.caption:SetText(data.text)
      maxtext = max(maxtext, frame.caption:GetStringWidth())

      -- header
      if data.type == "header" then
        frame.caption:SetPoint("LEFT", 10, 0)
        frame.caption:SetTextColor(.3,1,.8)
        frame.caption:SetFont(pfUI.font_default, pfUI_config.global.font_size+2, "OUTLINE")

      -- checkbox
      elseif data.type == "checkbox" then
        frame.input = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        frame.input:SetNormalTexture("")
        frame.input:SetPushedTexture("")
        frame.input:SetHighlightTexture("")
        pfUI.api.CreateBackdrop(frame.input, nil, true)

        frame.input:SetWidth(16)
        frame.input:SetHeight(16)
        frame.input:SetPoint("RIGHT" , -20, 0)

        frame.input.config = data.config
        if KoQuest_config[data.config] == "1" then
          frame.input:SetChecked()
        end

        frame.input:SetScript("OnClick", function ()
          if this:GetChecked() then
            KoQuest_config[this.config] = "1"
          else
            KoQuest_config[this.config] = "0"
          end

          KoQuestConfig.emberveilNeedsRebuild = true
        end)
      elseif data.type == "text" then
        -- input field
        frame.input = CreateFrame("EditBox", nil, frame)
        frame.input:SetTextColor(.2,1,.8,1)
        frame.input:SetJustifyH("RIGHT")
        frame.input:SetTextInsets(5,5,5,5)
        frame.input:SetWidth(32)
        frame.input:SetHeight(16)
        frame.input:SetPoint("RIGHT", -20, 0)
        frame.input:SetFontObject(GameFontNormal)
        frame.input:SetAutoFocus(false)
        frame.input:SetScript("OnEscapePressed", function(self)
          this:ClearFocus()
        end)

        frame.input.config = data.config
        frame.input:SetText(KoQuest_config[data.config])

        frame.input:SetScript("OnTextChanged", function(self)
          KoQuest_config[this.config] = this:GetText()
          KoQuestConfig.emberveilNeedsRebuild = true
        end)

        pfUI.api.CreateBackdrop(frame.input, nil, true)
      elseif data.type == "button" and data.func then
        frame.input = CreateFrame("Button", nil, frame)
        frame.input:SetWidth(32)
        frame.input:SetHeight(16)
        frame.input:SetPoint("RIGHT", -20, 0)
        frame.input:SetScript("OnClick", data.func)
        frame.input.text = frame.input:CreateFontString("Caption", "LOW", "GameFontWhite")
        frame.input.text:SetAllPoints(frame.input)
        frame.input.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
        frame.input.text:SetText("OK")
        pfUI.api.SkinButton(frame.input)
      end

      -- increase size and zoom back due to blizzard backdrop reasons...
      if frame.input and pfUI.api.emulated then
        frame.input:SetWidth(frame.input:GetWidth()/.6)
        frame.input:SetHeight(frame.input:GetHeight()/.6)
        frame.input:SetScale(.8)
        if frame.input.SetTextInsets then
          frame.input:SetTextInsets(8,8,8,8)
        end
      end

      count = count + 1
    end
  end

  -- update sizes / positions
  width = maxtext + 100
  local column, row = 1, 0

  for _, data in ipairs(config) do
    if data.type then
      -- empty line for headers, next column for > 20 entries
      row = row + ( data.type == "header" and row > 1 and 2 or 1 )
      if row > 22 and data.type == "header" then
        column, row = column + 1, 1
      end

      -- update max size values
      maxw, maxh = max(maxw, column), max(maxh, row)

      -- align frames to sizings
      local spacer = (column-1)*20
      local x, y = (column-1)*width, -(row-1)*height
      local frame = configframes[data.text]
      frame:SetWidth(width)
      frame:SetHeight(height)
      frame:SetPoint("TOPLEFT", KoQuestConfig, "TOPLEFT", x + spacer + 10, y - 40)
    end
  end

  local spacer = (maxw-1)*20
  KoQuestConfig:SetWidth(maxw*width + spacer + 20)
  KoQuestConfig:SetHeight(maxh*height + 100)
end

function KoQuestConfig:UpdateConfigEntries()
  for _, data in ipairs(KoQuest_defconfig) do
    if data.type and configframes[data.text] then
      if data.type == "checkbox" then
        configframes[data.text].input:SetChecked((KoQuest_config[data.config] == "1" and true or nil))
      elseif data.type == "text" then
        configframes[data.text].input:SetText(KoQuest_config[data.config])
      end
    end
  end
end

-- =========================================================================
-- Emberveil settings application
-- =========================================================================
local function KoQuestEVClamp01(value, fallback)
  local n = tonumber(value)
  if not n then n = fallback end
  if n < 0 then n = 0 end
  if n > 1 then n = 1 end
  return n
end

local function KoQuestEVClampRange(value, fallback, minimum, maximum, whole)
  local n = tonumber(value)
  if not n then n = fallback end
  if n < minimum then n = minimum end
  if n > maximum then n = maximum end
  if whole then n = math.floor(n + 0.5) end
  return n
end

function KoQuestConfig:ApplyEmberveilSettings(rebuild)
  if type(KoQuest_config) ~= "table" then
    KoQuest_config = {}
    self:LoadConfig()
  end

  local worldAlpha = KoQuestEVClamp01(KoQuest_config["worldmaptransp"], 1.0)
  local miniAlpha = KoQuestEVClamp01(KoQuest_config["minimaptransp"], 1.0)
  local fadeAlpha = KoQuestEVClamp01(KoQuest_config["nodefade"], 0.3)
  local trackerAlpha = KoQuestEVClamp01(KoQuest_config["trackeralpha"], 0.0)
  local trackerFontSize = KoQuestEVClampRange(KoQuest_config["trackerfontsize"], 12, 8, 32, true)
  local minDropChance = KoQuestEVClampRange(KoQuest_config["mindropchance"], 1, 0, 100, false)

  KoQuest_config["worldmaptransp"] = tostring(worldAlpha)
  KoQuest_config["minimaptransp"] = tostring(miniAlpha)
  KoQuest_config["nodefade"] = tostring(fadeAlpha)
  KoQuest_config["trackeralpha"] = tostring(trackerAlpha)
  KoQuest_config["trackerfontsize"] = tostring(trackerFontSize)
  KoQuest_config["mindropchance"] = tostring(minDropChance)

  -- Apply alpha to nodes that already exist; new nodes read these config
  -- values through KoMap:BuildNode().
  if KoMap then
    if type(KoMap.pins) == "table" then
      for _, pin in pairs(KoMap.pins) do
        if pin then
          pin.defalpha = worldAlpha
          if pin.SetAlpha then pin:SetAlpha(worldAlpha) end
        end
      end
    end

    if type(KoMap.mpins) == "table" then
      for _, pin in pairs(KoMap.mpins) do
        if pin then
          pin.defalpha = miniAlpha
          if pin.SetAlpha then pin:SetAlpha(miniAlpha) end
        end
      end
    end
  end

  -- The facing bridge is deliberately disabled on Emberveil.
  KoQuest_config["arrow"] = "0"

  if rebuild then
    -- Only structural setting changes need a full quest-node rebuild.
    if KoQuest and KoQuest.ResetAll then
      KoQuest:ResetAll()
    elseif KoQuest then
      KoQuest.updateQuestLog = true
      KoQuest.updateQuestGivers = true
    end
  end

  if KoMap then
    KoMap.queue_update = GetTime() + .10
    if KoMap.UpdateMinimap then KoMap:UpdateMinimap() end
    if WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown()
        and KoMap.UpdateNodes then
      KoMap:UpdateNodes()
    end
  end

  self.emberveilNeedsRebuild = nil

  if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage(
      "|cff33ffccKoQuest:|r settings applied. They will persist on normal logout/exit.")
  end
end

function KoQuestConfig:EmberveilRefreshAfterReset()
  KoQuest_config = KoQuest_config or {}
  KoQuest_questcache = KoQuest_questcache or {}
  KoQuest_history = KoQuest_history or {}
  KoQuest_colors = KoQuest_colors or {}
  KoQuest_track = KoQuest_track or {}
  KoQuest_server = KoQuest_server or {}
  KoBrowser_fav = KoBrowser_fav or {
    ["units"] = {}, ["objects"] = {}, ["items"] = {}, ["quests"] = {}
  }

  self:LoadConfig()
  self:UpdateConfigEntries()
  self.emberveilNeedsRebuild = true
  self:ApplyEmberveilSettings(true)
end
do -- welcome/init popup dialog
  local config_stage = {
    mode = 2
  }

  local desaturate = function(texture, state)
    local supported = texture:SetDesaturated(state)
    if not supported then
      if state then
        texture:SetVertexColor(0.5, 0.5, 0.5)
      else
        texture:SetVertexColor(1.0, 1.0, 1.0)
      end
    end
  end

  -- create welcome/init window
  KoQuestInit = CreateFrame("Frame", "KoQuestInit", UIParent)
  KoQuestInit:Hide()
  KoQuestInit:SetWidth(400)
  KoQuestInit:SetHeight(270)
  KoQuestInit:SetMovable(true)
  KoQuestInit:EnableMouse(true)
  KoQuestInit:SetPoint("CENTER", 0, 0)
  KoQuestInit:RegisterEvent("PLAYER_ENTERING_WORLD")
  KoQuestInit:SetScript("OnMouseDown", function()
    this:StartMoving()
  end)

  KoQuestInit:SetScript("OnMouseUp", function()
    this:StopMovingOrSizing()
  end)

  KoQuestInit:SetScript("OnEvent", function()
    if KoQuest_config.welcome ~= "1" then
      KoQuestInit:Show()
    end
    this:UnregisterAllEvents()
  end)

  KoQuestInit:SetScript("OnShow", function()
    -- Re-read the current settings every time this screen is opened. This
    -- keeps the selected card accurate after changes in the full config UI.
    config_stage.mode = 2
    if KoQuest_config["showspawn"] == "0" and KoQuest_config["showcluster"] == "1" then
      config_stage.mode = 1
    elseif KoQuest_config["showspawn"] == "1" and KoQuest_config["showcluster"] == "0" then
      config_stage.mode = 3
    end

    -- reload ui elements
    desaturate(KoQuestInit[1].bg, true)
    desaturate(KoQuestInit[2].bg, true)
    desaturate(KoQuestInit[3].bg, true)
    desaturate(KoQuestInit[config_stage.mode].bg, false)
  end)

  pfUI.api.CreateBackdrop(KoQuestInit, nil, true, 0.85)

  -- welcome title
  KoQuestInit.title = KoQuestInit:CreateFontString("Status", "LOW", "GameFontWhite")
  KoQuestInit.title:SetPoint("TOP", KoQuestInit, "TOP", 0, -17)
  KoQuestInit.title:SetJustifyH("LEFT")
  KoQuestInit.title:SetText(L["Please select your preferred |cff33ffccKo|cffffffffQuest|r mode:"])

  -- questing mode
  local buttons = {
    { caption = L["Simple Markers"], texture = "\\img\\init\\simple", position = { "TOPLEFT", 10, -40 },
      tooltip = L["Only show cluster icons with summarized objective locations based on spawn points"] },
    { caption = L["Combined"], texture = "\\img\\init\\combined", position = { "TOP", 0, -40 },
      tooltip = L["Show cluster icons with summarized locations and also display all spawn points of each quest objective"] },
    { caption = L["Spawn Points"], texture = "\\img\\init\\spawns", position = { "TOPRIGHT", -10, -40 },
      tooltip = L["Display all spawn points of each quest objective and hide summarized cluster icons."] },
  }

  for i, button in ipairs(buttons) do
    KoQuestInit[i] = CreateFrame("Button", "KoQuestInitMode" .. i, KoQuestInit)
    KoQuestInit[i]:SetWidth(120)
    KoQuestInit[i]:SetHeight(160)
    KoQuestInit[i]:SetPoint(unpack(button.position))
    KoQuestInit[i]:SetID(i)

    KoQuestInit[i].bg = KoQuestInit[i]:CreateTexture(nil, "NORMAL")
    KoQuestInit[i].bg:SetWidth(200)
    KoQuestInit[i].bg:SetHeight(200)
    KoQuestInit[i].bg:SetPoint("CENTER", 0, 0)
    KoQuestInit[i].bg:SetTexture(KoQuestConfig.path..button.texture)

    KoQuestInit[i].caption = KoQuestInit:CreateFontString("Status", "LOW", "GameFontWhite")
    KoQuestInit[i].caption:SetPoint("TOP", KoQuestInit[i], "BOTTOM", 0, -5)
    KoQuestInit[i].caption:SetJustifyH("LEFT")
    KoQuestInit[i].caption:SetText(button.caption)

    pfUI.api.SkinButton(KoQuestInit[i])

    KoQuestInit[i]:SetScript("OnClick", function()
      desaturate(KoQuestInit[1].bg, true)
      desaturate(KoQuestInit[2].bg, true)
      desaturate(KoQuestInit[3].bg, true)
      desaturate(KoQuestInit[this:GetID()].bg, false)
      config_stage.mode = this:GetID()
    end)

    local OnEnter = KoQuestInit[i]:GetScript("OnEnter")
    KoQuestInit[i]:SetScript("OnEnter", function()
      if OnEnter then OnEnter() end
      GameTooltip_SetDefaultAnchor(GameTooltip, this)

      GameTooltip:SetText(this.caption:GetText())
      GameTooltip:AddLine(buttons[this:GetID()].tooltip, 1, 1, 1, true)
      GameTooltip:SetWidth(100)
      GameTooltip:Show()
    end)

    local OnLeave = KoQuestInit[i]:GetScript("OnLeave")
    KoQuestInit[i]:SetScript("OnLeave", function()
      if OnLeave then OnLeave() end
      GameTooltip:Hide()
    end)
  end

  -- save button
  KoQuestInit.save = CreateFrame("Button", nil, KoQuestInit)
  KoQuestInit.save:SetWidth(100)
  KoQuestInit.save:SetHeight(24)
  KoQuestInit.save:SetPoint("BOTTOMRIGHT", -10, 10)
  KoQuestInit.save.text = KoQuestInit.save:CreateFontString("Caption", "LOW", "GameFontWhite")
  KoQuestInit.save.text:SetAllPoints(KoQuestInit.save)
  KoQuestInit.save.text:SetText(L["Save & Close"])

  pfUI.api.SkinButton(KoQuestInit.save)

  KoQuestInit.save:SetScript("OnClick", function()
    -- write current config
    if config_stage.mode == 1 then
      KoQuest_config["showspawn"] = "0"
      KoQuest_config["showspawnmini"] = "0"
      KoQuest_config["showcluster"] = "1"
      KoQuest_config["showclustermini"] = "1"
    elseif config_stage.mode == 2 then
      KoQuest_config["showspawn"] = "1"
      KoQuest_config["showspawnmini"] = "1"
      KoQuest_config["showcluster"] = "1"
      KoQuest_config["showclustermini"] = "0"
    elseif config_stage.mode == 3 then
      KoQuest_config["showspawn"] = "1"
      KoQuest_config["showspawnmini"] = "1"
      KoQuest_config["showcluster"] = "0"
      KoQuest_config["showclustermini"] = "0"
    end

    -- Emberveil does not expose trustworthy facing data. Keep the legacy
    -- value disabled instead of offering a control that cannot work safely.
    KoQuest_config["arrow"] = "0"

    -- save welcome flag and reload
    KoQuest_config["welcome"] = "1"
    KoQuestConfig:ApplyEmberveilSettings(true)
    KoQuestInit:Hide()
  end)
end
