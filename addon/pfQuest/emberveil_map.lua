-- Questie Emberveil / pfQuest map engine
-- v2.0.0-beta1.15
--
-- Design:
--   * pfQuest database + quest parser
--   * direct normalized world-map node placement
--   * direct minimap-distance placement (NO Astrolabe)
--   * player position cached independently from the currently browsed map
--   * native Emberveil world-map player model hidden/replaced

QuestieEV = QuestieEV or {}
local EV = QuestieEV
local _G = getfenv(0)

EV.player = EV.player or {
  mapID = nil,
  zone = nil,
  x = nil,
  y = nil,
  updated = 0,
}

EV.mapZoneCache = EV.mapZoneCache or {}
EV.nativeWorldArrowsHidden = EV.nativeWorldArrowsHidden or 0
EV.lastSelectedKey = nil
EV.readyForced = false
EV.forceDiagAt = nil
EV.inWorld = false
EV.startupReadyAt = nil
EV.mapRuntimeReady = false
EV.mapRuntimeReadyAt = nil
EV.renderPrimeRequested = EV.renderPrimeRequested or false
EV.renderPrimeAt = nil
EV.renderPrimeUntil = nil
EV.questRenderNudgeAt = nil

-- Hidden world-map context recovery.
-- Azeroth documents GetPlayerMapPosition() as coordinates on the currently
-- viewed map. After login/reload that hidden view can remain on "world" (0/0),
-- producing no usable zone position until the stock world map is opened once.
EV.mapContextPrimeAt = nil
EV.mapContextPrimeCooldownUntil = nil
EV.mapContextPrimeCount = 0
EV.mapContextPrimeLastResult = "not-run"
EV.mapContextPrimeLastReason = nil
EV.mapContextPrimeBusy = false
EV.location = EV.location or {}
EV.positionFreshSeconds = 2.0

-- pfQuest's pinned minimap scale tables use:
--   0 = indoor scale
--   1 = outdoor scale
-- Azeroth DOES NOT register the Vanilla minimapZoom/minimapInsideZoom CVars;
-- GetCVar() returns "0" for those unknown names. Never use those CVars here.
local qevSavedMinimapEnvironment = type(pfQuest_config) == "table"
  and tonumber(pfQuest_config["qev_minimap_environment"]) or nil
if qevSavedMinimapEnvironment ~= 0 and qevSavedMinimapEnvironment ~= 1 then
  qevSavedMinimapEnvironment = 1
end
EV.minimapEnvironment = qevSavedMinimapEnvironment
EV.minimapEnvironmentSource = type(pfQuest_config) == "table"
  and pfQuest_config["qev_minimap_environment"] ~= nil
  and "saved" or "default-outdoor"
EV.minimapPolicy = "uninitialized"
EV.minimapLastEnvironmentEventAt = nil
EV.minimapLastAuthoritativeEnvironmentAt = nil
EV.minimapZoomEventCount = 0
EV.minimapIndoorEventCount = 0
EV.minimapOutdoorEventCount = 0
EV.minimapZoneEventCount = 0
EV.minimapZoomEventRegistered = false
EV.zoneIndoorsEventRegistered = false
EV.lastObservedMinimapZoom = nil
EV.minimapProjectionAt = nil
EV.minimapProjectionReason = nil

EV.perf = EV.perf or {
  miniCalls = 0,
  miniRuns = 0,
  miniSkips = 0,
  miniMapHiddenSkips = 0,
  miniCachedNodes = 0,
  miniCandidates = 0,
  miniCacheBuilds = 0,
  miniCacheGeneration = 0,
  miniLastCacheReason = "init",
  miniInterval = 0.10,
  miniBaseInterval = 0.10,
  miniTransitionInterval = 0.25,
  miniLowFpsInterval = 0.20,
  fpsNow = 0,
  fpsAvg = 0,
  fpsMin = nil,
  fpsSamples = 0,
  fpsNextAt = nil,
  transitionUntil = nil,
  worldRuns = 0,
  worldSkips = 0,
}
EV.minimapNextAt = nil
EV.minimapForceNext = true
EV.minimapNodeCache = EV.minimapNodeCache or {
  mapID = nil,
  entries = {},
  grid = {},
  cellSize = 5,
  dirty = true,
  reason = "init",
  generation = 0,
}
EV.worldMapNextAt = nil
EV.worldMapForceNext = true
EV.locationRefreshSeconds = 0.25

local function chat(msg)
  if EV.Chat then
    EV.Chat(msg)
  elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccQuestie EV:|r " .. tostring(msg))
  end
end

local function Num(v)
  return type(v) == "number" and v == v
end

local function CleanText(value)
  if type(value) ~= "string" then return nil end
  value = string.gsub(value, "^%s+", "")
  value = string.gsub(value, "%s+$", "")
  return value ~= "" and value or nil
end

local function SafeGlobalText(name)
  local fn = _G and _G[name] or nil
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn)
  return ok and CleanText(value) or nil
end

local function CountTable(t)
  if type(t) ~= "table" then return 0 end
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

local function VisibleCount(t)
  if type(t) ~= "table" then return 0 end
  local n = 0
  for _, f in pairs(t) do
    if f and f.IsShown and f:IsShown() then
      n = n + 1
    end
  end
  return n
end

function EV:SampleFramerate(now)
  local perf = self.perf
  now = now or GetTime()

  if perf.fpsNextAt and now < perf.fpsNextAt then return end
  perf.fpsNextAt = now + 1.0

  local fps = nil
  if type(GetFramerate) == "function" then
    local ok, value = pcall(GetFramerate)
    if ok and Num(value) and value > 0 then fps = value end
  end

  if not fps then return end

  perf.fpsNow = fps
  perf.fpsSamples = (perf.fpsSamples or 0) + 1
  if not perf.fpsAvg or perf.fpsAvg <= 0 then
    perf.fpsAvg = fps
  else
    perf.fpsAvg = perf.fpsAvg * 0.85 + fps * 0.15
  end
  if not perf.fpsMin or fps < perf.fpsMin then perf.fpsMin = fps end

  -- GetFramerate() is a documented rolling engine FPS average. When the client
  -- is already under load, reduce Questie's heavy minimap cadence instead of
  -- competing for additional frame time.
  local interval = perf.miniBaseInterval or 0.10
  if fps < 30 then
    interval = 0.25
  elseif fps < 45 then
    interval = 0.20
  elseif fps < 60 then
    interval = 0.14
  end

  if perf.transitionUntil and now < perf.transitionUntil then
    interval = math.max(interval, perf.miniTransitionInterval or 0.16)
  end

  perf.miniInterval = interval
end

function EV:MarkMinimapNodeCacheDirty(reason)
  self.minimapNodeCache = self.minimapNodeCache or {
    mapID = nil, entries = {}, grid = {}, cellSize = 5,
    dirty = true, reason = "init", generation = 0,
  }
  self.minimapNodeCache.dirty = true
  self.minimapNodeCache.reason = reason or "unknown"
  self.minimapForceNext = true
end

function EV:GetMinimapNodeCache(mapID)
  local cache = self.minimapNodeCache
  if not cache then
    cache = {
      mapID = nil, entries = {}, grid = {}, cellSize = 5,
      dirty = true, reason = "init", generation = 0,
    }
    self.minimapNodeCache = cache
  end

  if cache.mapID == mapID and not cache.dirty then return cache end

  local entries = {}
  local grid = {}
  local cellSize = cache.cellSize or 5

  if pfMap and type(pfMap.nodes) == "table" and mapID then
    for addon, data in pairs(pfMap.nodes) do
      local bucket = type(data) == "table" and data[mapID] or nil
      if type(bucket) == "table" then
        for coords, node in pairs(bucket) do
          local _, _, sx, sy = string.find(coords, "(.*)|(.*)")
          local x, y = tonumber(sx), tonumber(sy)
          if x and y then
            local entry = { addon = addon, node = node, x = x, y = y }
            entries[table.getn(entries) + 1] = entry

            local cx = math.floor(x / cellSize)
            local cy = math.floor(y / cellSize)
            local key = cx * 1000 + cy
            if not grid[key] then grid[key] = {} end
            grid[key][table.getn(grid[key]) + 1] = entry
          end
        end
      end
    end
  end

  cache.mapID = mapID
  cache.entries = entries
  cache.grid = grid
  cache.dirty = false
  cache.generation = (cache.generation or 0) + 1

  self.perf.miniCachedNodes = table.getn(entries)
  self.perf.miniCacheBuilds = (self.perf.miniCacheBuilds or 0) + 1
  self.perf.miniCacheGeneration = cache.generation
  self.perf.miniLastCacheReason = cache.reason or "unknown"
  cache.reason = nil
  return cache
end

-- Compatibility helper for diagnostics/older beta code.
function EV:GetMinimapNodeEntries(mapID)
  return self:GetMinimapNodeCache(mapID).entries
end

function EV:RefreshLocationContext(force)
  local now = GetTime()
  if not force
      and self.location
      and self.location.updated
      and self.location.realZone
      and now - self.location.updated >= 0
      and now - self.location.updated < (self.locationRefreshSeconds or .25) then
    return self.location
  end

  self.location = self.location or {}

  local previousParent = CleanText(self.location.parentZone)
    or CleanText(self.location.realZone)
  local previousMapID = self.location.parentMapID

  local rawZone = SafeGlobalText("GetZoneText")
  local rawRealZone = SafeGlobalText("GetRealZoneText")
  local apiZone = rawRealZone or rawZone
  local subZone = SafeGlobalText("GetSubZoneText")
  local miniZone = SafeGlobalText("GetMinimapZoneText")

  local parentZone = nil
  local parentMapID = nil
  local parentSource = "unresolved"

  local apiMapID = self:GetMapIDByZoneName(apiZone)
  if apiZone and apiMapID then
    parentZone = apiZone
    parentMapID = apiMapID
    parentSource = "zone-api"
  elseif previousParent and previousMapID
      and self:GetMapIDByZoneName(previousParent) == previousMapID then
    -- Several Emberveil interiors temporarily expose only a building/subzone
    -- name while GetZoneText/GetRealZoneText are blank. Preserve the last
    -- verified outdoor parent until a new authoritative zone is available.
    parentZone = previousParent
    parentMapID = previousMapID
    parentSource = "sticky-parent"
  elseif self.player and self.player.zone and self.player.mapID
      and self:GetMapIDByZoneName(self.player.zone) == self.player.mapID then
    parentZone = self.player.zone
    parentMapID = self.player.mapID
    parentSource = "player-cache"
  elseif not self:IsWorldMapShown() then
    -- After /reload the stock map may already be on the correct hidden zone
    -- even before zone-name APIs become ready. Accept it only when the selected
    -- map is concrete and actually projects a valid player coordinate.
    local selectedID, selectedName, _, _, _, viewKind = self:GetSelectedMapID()
    local x, y = QuestieEV_SafeGetPlayerMapPosition("player")
    if selectedID and selectedName
        and (viewKind == "zone" or viewKind == "zone-fallback")
        and Num(x) and Num(y) and x > 0 and x <= 1 and y > 0 and y <= 1 then
      parentZone = selectedName
      parentMapID = selectedID
      parentSource = "hidden-selected-zone"
    end
  end

  local inInstance, instanceType = false, "none"
  if type(IsInInstance) == "function" then
    local ok, inside, kind = pcall(IsInInstance)
    if ok then
      if inside == nil and kind == nil then
        -- Azeroth documents "no values" when the current map DBC row is
        -- unknown. Treat that as an unknown context, never as proven outdoor.
        inInstance = nil
        instanceType = "unknown-map"
      else
        inInstance = inside == true
        instanceType = type(kind) == "string" and kind or (inside and "unknown" or "none")
      end
    else
      inInstance = nil
      instanceType = "api-error"
    end
  end

  self.location.zone = rawZone
  self.location.rawRealZone = rawRealZone
  self.location.realZone = parentZone or apiZone
  self.location.parentZone = parentZone
  self.location.parentMapID = parentMapID
  self.location.parentSource = parentSource
  self.location.subZone = subZone
  self.location.minimapZone = miniZone
  self.location.inInstance = inInstance
  self.location.instanceType = instanceType
  self.location.updated = GetTime()

  return self.location
end

function EV:InvalidatePlayerPosition(clearIdentity, reason)
  self.player.x = nil
  self.player.y = nil
  self.player.updated = 0
  self.player.positionSource = reason or "invalidated"
  self.player.contextKey = nil

  if clearIdentity then
    self.player.mapID = nil
    self.player.zone = nil
  end
end

function EV:IsPlayerPositionFresh()
  local p = self.player
  if not p or not p.mapID or not Num(p.x) or not Num(p.y) then return false end
  if p.x <= 0 or p.x > 1 or p.y <= 0 or p.y > 1 then return false end

  local age = GetTime() - (p.updated or 0)
  return age >= 0 and age <= (self.positionFreshSeconds or 2.0)
end

-- =========================================================================
-- Minimap indoor/outdoor scale tracking
-- =========================================================================
-- The pinned pfQuest scale tables are [0]=INDOOR and [1]=OUTDOOR.
--
-- Azeroth's supplied API explicitly documents that indoor/outdoor zoom values
-- are stored internally by the Minimap widget, but its registered legacy CVar
-- list DOES NOT include minimapZoom/minimapInsideZoom. GetCVar() returns "0"
-- for unknown names, so Vanilla's CVar probing trick is invalid on this client.
--
-- We therefore never mutate Minimap zoom to discover the environment.
-- Environment is driven by the Vanilla map events:
--   ZONE_CHANGED          -> outdoor subzone
--   ZONE_CHANGED_INDOORS  -> indoor subzone
-- MINIMAP_UPDATE_ZOOM only schedules a projection refresh; it never guesses or
-- toggles environment state. Related events are coalesced before rendering.
-- The last known state is persisted through /reload.
function EV:PersistMinimapEnvironment()
  if type(pfQuest_config) == "table" then
    pfQuest_config["qev_minimap_environment"] = tostring(self.minimapEnvironment == 0 and 0 or 1)
  end
end

function EV:ScheduleMinimapProjection(delay, reason)
  local due = GetTime() + (tonumber(delay) or .08)
  if not self.minimapProjectionAt or due > self.minimapProjectionAt then
    self.minimapProjectionAt = due
  end
  self.minimapProjectionReason = reason or "event"
  self.perf.transitionUntil = GetTime() + 1.25
end

function EV:SetMinimapEnvironment(environment, source, authoritative)
  environment = tonumber(environment)
  if environment ~= 0 and environment ~= 1 then return false end

  local changed = self.minimapEnvironment ~= environment
  self.minimapEnvironment = environment
  self.minimapEnvironmentSource = source or "event"
  self.minimapLastEnvironmentEventAt = GetTime()
  if authoritative then
    self.minimapLastAuthoritativeEnvironmentAt = self.minimapLastEnvironmentEventAt
  end

  if changed then
    self:ScheduleMinimapProjection(.08, source or "environment")
  end

  self:PersistMinimapEnvironment()
  return changed
end

function EV:GetMinimapEnvironment()
  local env = tonumber(self.minimapEnvironment)
  if env ~= 0 and env ~= 1 then
    env = 1
    self.minimapEnvironment = env
    self.minimapEnvironmentSource = "default-outdoor"
  end
  return env
end

function EV:GetMapIDByZoneName(name)
  if not name or not pfMap or not pfMap.GetMapIDByName then return nil end
  local ok, mapID = pcall(pfMap.GetMapIDByName, pfMap, name)
  return ok and mapID or nil
end

function EV:GetSelectedMapID()
  if not pfMap then return nil, nil, nil, nil, nil, "unknown" end

  local cid, mid, mapInfo = nil, nil, nil
  if type(GetCurrentMapContinent) == "function" then
    local ok, value = pcall(GetCurrentMapContinent)
    if ok then cid = tonumber(value) end
  end
  if type(GetCurrentMapZone) == "function" then
    local ok, value = pcall(GetCurrentMapZone)
    if ok then mid = tonumber(value) end
  end
  if type(GetMapInfo) == "function" then
    local ok, value = pcall(GetMapInfo)
    if ok then mapInfo = value end
  end

  -- Zone-local pfQuest coordinates are valid ONLY on a concrete zone map.
  if cid and cid > 0 and mid and mid > 0 then
    if not self.mapZoneCache[cid] then
      local zones = type(GetMapZones) == "function" and { pcall(GetMapZones, cid) } or {}
      if zones[1] then
        table.remove(zones, 1)
        self.mapZoneCache[cid] = zones
      else
        self.mapZoneCache[cid] = {}
      end
    end

    local name = self.mapZoneCache[cid][mid]
    local mapID = name and self:GetMapIDByZoneName(name) or nil

    if mapID then
      return mapID, name, cid, mid, mapInfo, "zone"
    end

    -- Emberveil may expose a zone index whose GetMapZones ordering differs
    -- from Vanilla. Fall back to the player's real zone ONLY while a zone
    -- index is selected; never do this on continent/world views.
    local realZone = SafeGlobalText("GetRealZoneText") or SafeGlobalText("GetZoneText")
    local playerMapID = self:GetMapIDByZoneName(realZone)
    if playerMapID and self.player and self.player.mapID == playerMapID then
      return playerMapID, realZone, cid, mid, mapInfo, "zone-fallback"
    end

    return nil, name, cid, mid, mapInfo, "zone-unresolved"
  end

  if cid and cid > 0 and (not mid or mid == 0) then
    return nil, nil, cid, mid, mapInfo, "continent"
  end

  return nil, nil, cid, mid, mapInfo, "world"
end

function EV:IsWorldMapShown()
  if not WorldMapFrame or type(WorldMapFrame.IsShown) ~= "function" then return false end
  local ok, shown = pcall(WorldMapFrame.IsShown, WorldMapFrame)
  return ok and shown and true or false
end

function EV:PrimeHiddenPlayerMapContext(reason)
  local now = GetTime()

  if self.mapContextPrimeBusy then
    self.mapContextPrimeLastResult = "busy"
    return false
  end

  if not self.inWorld or not self.mapRuntimeReady then
    self.mapContextPrimeLastResult = "runtime-not-ready"
    return false
  end

  -- Never change what the player is actively browsing.
  if self:IsWorldMapShown() then
    self.mapContextPrimeLastResult = "world-map-visible"
    return false
  end

  if self.mapContextPrimeCooldownUntil
      and now < self.mapContextPrimeCooldownUntil then
    self.mapContextPrimeLastResult = "cooldown"
    return false
  end

  local loc = self:RefreshLocationContext()

  -- Dungeon/raid minimaps require a real floor-aware coordinate surface.
  -- Do not force outdoor zone state over an instance.
  if loc.inInstance and
      (loc.instanceType == "party" or loc.instanceType == "raid") then
    self.mapContextPrimeLastResult =
      "blocked-instance:" .. tostring(loc.instanceType)
    return false
  end

  local realZone = loc.realZone
  local playerMapID = loc.parentMapID or self:GetMapIDByZoneName(realZone)

  if not realZone or realZone == "" or not playerMapID then
    self.mapContextPrimeLastResult = "player-zone-unresolved"
    return false
  end

  local selectedID, _, _, _, _, viewKind = self:GetSelectedMapID()

  if selectedID == playerMapID
      and (viewKind == "zone" or viewKind == "zone-fallback") then
    self.mapContextPrimeLastResult = "already-current-zone"
    return true
  end

  local raw = self._rawSetCurrentZone
  if type(raw) ~= "function" then
    self.mapContextPrimeLastResult = "api-missing"
    return false
  end

  -- Rate-limit BEFORE invoking the native bridge. If WORLD_MAP_UPDATE fires
  -- synchronously/re-entrantly, it cannot recurse into another native call.
  self.mapContextPrimeBusy = true
  self.mapContextPrimeCooldownUntil = now + 2.0
  self.mapContextPrimeLastReason = reason or "unknown"

  local ok = pcall(raw)

  self.mapContextPrimeBusy = false

  if not ok then
    self.mapContextPrimeLastResult = "native-call-error"
    return false
  end

  self.mapContextPrimeCount = (self.mapContextPrimeCount or 0) + 1
  self.mapContextPrimeLastResult =
    "native-current-zone:" .. tostring(viewKind)

  -- Let Azeroth finish the map switch, then recapture and prime the minimap.
  self.renderPrimeRequested = true
  self.mapContextPrimeAt = now + .15
  return true
end

function EV:CapturePlayerPosition(force)
  if not pfMap then return false end

  local loc = self:RefreshLocationContext()
  local realZone = loc.realZone
  local mapID = loc.parentMapID or self:GetMapIDByZoneName(realZone)

  if not mapID then
    self.player.positionSource = "zone-unmapped"
    return false
  end

  local selectedID, selectedName, cid, mid, mapInfo, viewKind =
    self:GetSelectedMapID()

  -- GetPlayerMapPosition is documented as coordinates on the CURRENTLY VIEWED
  -- map. Never store those UVs under the player's zone mapID unless the viewed
  -- map is the same concrete map. This prevents continent/other-zone UVs from
  -- corrupting minimap placement after map browsing.
  local sameConcreteMap =
    selectedID ~= nil
    and selectedID == mapID
    and (viewKind == "zone" or viewKind == "zone-fallback")

  if not sameConcreteMap then
    self.player.positionSource = "view-mismatch:" .. tostring(viewKind)
    return false
  end

  local x, y = QuestieEV_SafeGetPlayerMapPosition("player")
  if not (Num(x) and Num(y) and (x > 0 or y > 0)
      and x > 0 and x <= 1 and y > 0 and y <= 1) then
    self.player.positionSource =
      loc.inInstance and "instance-position-unavailable" or "position-unavailable"
    return false
  end

  self.player.mapID = mapID
  self.player.zone = realZone
  self.player.x = x
  self.player.y = y
  self.player.updated = GetTime()
  self.player.positionSource =
    loc.inInstance and ("instance:" .. tostring(loc.instanceType)) or "zone"
  self.player.contextKey = tostring(mapID) .. "|" .. tostring(realZone)
  self.location.parentZone = realZone
  self.location.parentMapID = mapID
  return true
end

function EV:ApplyKnownGoodConfig()
  if type(pfQuest_config) ~= "table" then return end

  -- beta1.6: compatibility defaults are defaults, NOT policy.
  -- Never overwrite a user's saved setting merely because Questie is running.
  local defaults = {
    trackingmethod = 1,
    showtooltips = "1",
    showspawn = "1",
    showspawnmini = "1",
    showcluster = "1",
    minimapnodes = "1",
    allquestgivers = "1",
    currentquestgivers = "1",
    worldmaptransp = "1.0",
    minimaptransp = "1.0",
    nodefade = "0.3",
    routeminimap = "0",
  }

  for key, value in pairs(defaults) do
    if pfQuest_config[key] == nil or pfQuest_config[key] == "" then
      pfQuest_config[key] = value
    end
  end

  -- Facing is still not safely exposed by Emberveil, so the route arrow is the
  -- only setting that remains compatibility-locked.
  pfQuest_config["arrow"] = "0"
end

-- Hide the broken/stale native WorldMap player model. We replace it with a
-- normal Frame/Texture whose visibility is tied to the selected map identity.
function EV:HideNativeWorldPlayerArrow()
  -- Alpha2 crash-safety:
  -- Do NOT enumerate or introspect Emberveil's WorldMapFrame children/models.
  -- Those objects are backed by Unreal bridge userdata rather than original
  -- Vanilla FrameXML objects and can cause a native access violation.
  self.nativeWorldArrowsHidden = 0
end

function EV:BuildPlayerMarker()
  if self.playerMarker or not WorldMapButton then return end

  local f = CreateFrame("Frame", "QuestieEVWorldPlayerMarker", WorldMapButton)
  f:SetWidth(22)
  f:SetHeight(22)
  f:SetFrameLevel(250)
  f:Hide()

  local tex = f:CreateTexture(nil, "OVERLAY")
  tex:SetAllPoints(f)
  tex:SetTexture((pfQuestConfig and pfQuestConfig.path or "Interface\\AddOns\\pfQuest") .. "\\img\\player_ev")
  f.texture = tex

  self.playerMarker = f
end

function EV:UpdatePlayerMarker()
  self:BuildPlayerMarker()
  if not self.playerMarker then return end

  if not self:IsWorldMapShown() then
    self.playerMarker:Hide()
    return
  end

  local selectedID = self:GetSelectedMapID()
  local p = self.player

  if not selectedID or not p.mapID or selectedID ~= p.mapID
      or not Num(p.x) or not Num(p.y)
      or p.x <= 0 or p.x > 1 or p.y <= 0 or p.y > 1 then
    self.playerMarker:Hide()
    return
  end

  local w = WorldMapButton:GetWidth()
  local h = WorldMapButton:GetHeight()
  if not Num(w) or not Num(h) or w <= 0 or h <= 0 then
    self.playerMarker:Hide()
    return
  end

  self.playerMarker:ClearAllPoints()
  self.playerMarker:SetPoint("CENTER", WorldMapButton, "TOPLEFT", p.x * w, -p.y * h)
  self.playerMarker:Show()
end

-- =========================================================================
-- WORLD MAP: direct pfQuest nodes, but map selection resolved by zone name.
-- =========================================================================
function pfMap:UpdateNodes()
  if type(pfQuest_config) ~= "table" then return end
  local evNow = GetTime()
  if not EV.worldMapForceNext and EV.worldMapNextAt and evNow < EV.worldMapNextAt then
    EV.perf.worldSkips = (EV.perf.worldSkips or 0) + 1
    return
  end
  EV.worldMapForceNext = false
  EV.worldMapNextAt = evNow + .08
  EV.perf.worldRuns = (EV.perf.worldRuns or 0) + 1

  if EV.questStateReady == false then
    for _, pin in pairs(pfMap.pins) do
      if pin and pin.Hide then pin:Hide() end
    end
    EV:UpdatePlayerMarker()
    return
  end

  local color = pfQuest_config["spawncolors"] == "1" and "spawn" or "title"
  local map = EV:GetSelectedMapID()
  local i = 1

  if pfQuest.tracker and pfQuest.tracker.Reset then
    pfQuest.tracker.Reset()
  end
  if pfQuest.route and pfQuest.route.Reset then
    pfQuest.route:Reset()
  end

  if map then
    for addon, data in pairs(pfMap.nodes) do
      if data[map] then
        for coords, node in pairs(data[map]) do
          if not pfMap.pins[i] then
            pfMap.pins[i] = pfMap:BuildNode("pfMapPin" .. i, WorldMapButton)
          end

          pfMap:UpdateNode(pfMap.pins[i], node, color)

          local _, _, sx, sy = string.find(coords, "(.*)|(.*)")
          local x = tonumber(sx)
          local y = tonumber(sy)

          if x and y then
            if pfQuest.route and pfQuest.route.AddPoint and (
                (pfQuest_config["routecluster"] == "1" and pfMap.pins[i].layer >= 9) or
                (pfQuest_config["routeender"] == "1" and pfMap.pins[i].layer == 4) or
                (pfQuest_config["routestarter"] == "1" and pfMap.pins[i].layer == 1 and pfMap.pins[i].texture) or
                (pfQuest_config["routestarter"] == "1" and pfMap.pins[i].layer == 2) or
                pfMap.pins[i].arrow == true
              ) then
              pfQuest.route:AddPoint({ x, y, pfMap.pins[i] })
            end

            if pfQuest_config["showcluster"] == "0" and pfMap.pins[i].cluster then
              pfMap.pins[i]:Hide()
            elseif pfQuest_config["showspawn"] == "0"
                and addon == "PFQUEST"
                and not pfMap.pins[i].texture then
              pfMap.pins[i]:Hide()
            else
              if pfQuest.tracker and pfQuest.tracker.ButtonAdd then
                for title, entry in pairs(pfMap.pins[i].node) do
                  pfQuest.tracker.ButtonAdd(title, entry)
                end
              end

              local w = WorldMapButton:GetWidth()
              local h = WorldMapButton:GetHeight()

              pfMap.pins[i]:ClearAllPoints()
              pfMap.pins[i]:SetPoint(
                "CENTER",
                WorldMapButton,
                "TOPLEFT",
                x / 100 * w,
                -y / 100 * h
              )
              pfMap.pins[i]:Show()
            end

            i = i + 1
          end
        end
      end
    end
  end

  for j = i, table.getn(pfMap.pins) do
    if pfMap.pins[j] then pfMap.pins[j]:Hide() end
  end

  EV:UpdatePlayerMarker()
end

-- =========================================================================
-- MINIMAP: current real zone + cached real player coordinates.
-- Distant objectives are clipped by actual minimap radius.
-- =========================================================================
function pfMap:UpdateMinimap()
  if type(pfQuest_config) ~= "table" then return end
  local now = GetTime()
  local perf = EV.perf
  perf.miniCalls = (perf.miniCalls or 0) + 1

  -- MINIMAP_UPDATE_ZOOM is for indoor/outdoor scaling and deliberately does
  -- not fire for +/- zoom buttons. Poll the documented zoom index so manual
  -- zoom changes force an immediate pin re-projection without changing the
  -- indoor/outdoor state.
  local observedZoom = nil
  if Minimap and type(Minimap.GetZoom) == "function" then
    local okZoom, value = pcall(Minimap.GetZoom, Minimap)
    if okZoom and Num(value) then observedZoom = value end
  end
  if observedZoom ~= nil and observedZoom ~= EV.lastObservedMinimapZoom then
    if EV.lastObservedMinimapZoom ~= nil then
      perf.manualZoomChanges = (perf.manualZoomChanges or 0) + 1
    end
    EV.lastObservedMinimapZoom = observedZoom
    EV:ScheduleMinimapProjection(.08, "observed-zoom")
  end

  if EV.minimapProjectionAt then
    if now < EV.minimapProjectionAt then
      perf.miniSkips = (perf.miniSkips or 0) + 1
      return
    end

    EV.minimapProjectionAt = nil
    EV.minimapForceNext = true
    EV.minimapNextAt = nil
  end

  if EV:IsWorldMapShown() and not EV.minimapForceNext then
    perf.miniMapHiddenSkips = (perf.miniMapHiddenSkips or 0) + 1
    return
  end

  local interval = perf.miniInterval or perf.miniBaseInterval or .10
  if not EV.minimapForceNext and EV.minimapNextAt and now < EV.minimapNextAt then
    perf.miniSkips = (perf.miniSkips or 0) + 1
    return
  end

  EV.minimapForceNext = false
  EV.minimapNextAt = now + interval
  perf.miniRuns = (perf.miniRuns or 0) + 1

  if EV.questStateReady == false then
    for _, pin in pairs(pfMap.mpins) do
      if pin and pin.Hide then pin:Hide() end
    end
    return
  end

  if pfQuest_config["minimapnodes"] == "0" then
    for _, pin in pairs(pfMap.mpins) do pin:Hide() end
    return
  end

  local p = EV.player
  if not p.mapID or not Num(p.x) or not Num(p.y) then
    EV:CapturePlayerPosition(false)
    p = EV.player
  end

  if not p.mapID or not Num(p.x) or not Num(p.y) then
    EV.minimapPolicy = "hidden-no-player-position:" .. tostring(p.positionSource)
    for _, pin in pairs(pfMap.mpins) do pin:Hide() end
    return
  end

  local loc = EV:RefreshLocationContext()

  if not EV:IsPlayerPositionFresh() then
    EV.minimapPolicy = "hidden-stale-position:" .. tostring(p.positionSource)
    for _, pin in pairs(pfMap.mpins) do pin:Hide() end
    return
  end

  -- The supplied Azeroth API exposes instance identity but no floor-aware
  -- dungeon-map coordinate API. Do not project outdoor/zone UVs onto a party
  -- or raid interior where the coordinates may be wrong.
  if loc.instanceType == "unknown-map" or loc.instanceType == "api-error" then
    EV.minimapPolicy = "hidden-instance-context-" .. tostring(loc.instanceType)
    for _, pin in pairs(pfMap.mpins) do pin:Hide() end
    return
  end

  if loc.inInstance and (loc.instanceType == "party" or loc.instanceType == "raid") then
    EV.minimapPolicy = "hidden-instance-" .. tostring(loc.instanceType)
    for _, pin in pairs(pfMap.mpins) do pin:Hide() end
    return
  end

  local mZoom = observedZoom
  if mZoom == nil and pfMap.drawlayer and type(pfMap.drawlayer.GetZoom) == "function" then
    local okZoom, value = pcall(pfMap.drawlayer.GetZoom, pfMap.drawlayer)
    if okZoom and Num(value) then mZoom = value end
  end
  local environment = EV:GetMinimapEnvironment()
  local zoomTable = pfMap.minimap_zoom and pfMap.minimap_zoom[environment]
  local mapZoom = zoomTable and zoomTable[mZoom] or nil
  local sizeData = pfMap.minimap_sizes and pfMap.minimap_sizes[p.mapID] or nil

  EV.minimapPolicy =
    loc.inInstance and ("mapped-instance-" .. tostring(loc.instanceType))
    or ("zone-env" .. tostring(environment))

  if not Num(mapZoom) or mapZoom <= 0 or not sizeData
      or not Num(sizeData[1]) or not Num(sizeData[2])
      or sizeData[1] <= 0 or sizeData[2] <= 0 then
    EV.minimapPolicy = "hidden-no-map-scale"
    for _, pin in pairs(pfMap.mpins) do pin:Hide() end
    return
  end

  local xPlayer = p.x * 100
  local yPlayer = p.y * 100

  local xScale = mapZoom / sizeData[1]
  local yScale = mapZoom / sizeData[2]

  if not Num(xScale) or not Num(yScale) or xScale <= 0 or yScale <= 0 then return end

  local okWidth, drawWidth = pcall(pfMap.drawlayer.GetWidth, pfMap.drawlayer)
  local okHeight, drawHeight = pcall(pfMap.drawlayer.GetHeight, pfMap.drawlayer)
  if not okWidth or not okHeight or not Num(drawWidth) or not Num(drawHeight)
      or drawWidth <= 16 or drawHeight <= 16 then
    EV.minimapPolicy = "hidden-invalid-draw-layer"
    for _, pin in pairs(pfMap.mpins) do pin:Hide() end
    return
  end

  local xDraw = drawWidth / xScale / 100
  local yDraw = drawHeight / yScale / 100
  if not Num(xDraw) or not Num(yDraw) or xDraw == 0 or yDraw == 0 then return end
  local color = pfQuest_config["spawncolors"] == "1" and "spawn" or "title"

  local i = 1
  local nodeCache = EV:GetMinimapNodeCache(p.mapID)

  if not pfMap:HasMinimap(p.mapID) then
    for j = 1, table.getn(pfMap.mpins) do
      if pfMap.mpins[j] then pfMap.mpins[j]:Hide() end
    end
    return
  end

  local radius = drawWidth / 2
  local visibleRadius = radius - 8
  if visibleRadius <= 0 then return end
  local visibleRadiusSq = visibleRadius * visibleRadius

  -- Spatially query only grid cells that can intersect the minimap circle.
  -- This keeps dense zones from scanning hundreds/thousands of remote quest
  -- nodes every movement tick.
  local cellSize = nodeCache.cellSize or 5
  if not Num(cellSize) or cellSize <= 0 then cellSize = 5 end
  local maxCell = math.floor(100 / cellSize)
  local maxDx = visibleRadius / math.abs(xDraw)
  local maxDy = visibleRadius / math.abs(yDraw)
  local minCx = math.floor((xPlayer - maxDx) / cellSize) - 1
  local maxCx = math.floor((xPlayer + maxDx) / cellSize) + 1
  local minCy = math.floor((yPlayer - maxDy) / cellSize) - 1
  local maxCy = math.floor((yPlayer + maxDy) / cellSize) + 1

  if minCx < 0 then minCx = 0 end
  if minCy < 0 then minCy = 0 end
  if maxCx > maxCell then maxCx = maxCell end
  if maxCy > maxCell then maxCy = maxCell end

  local candidates = 0
  for cx = minCx, maxCx do
    for cy = minCy, maxCy do
      local bucket = nodeCache.grid[cx * 1000 + cy]
      if bucket then
        for idx = 1, table.getn(bucket) do
          local entry = bucket[idx]
          candidates = candidates + 1
          local xPos = (entry.x - xPlayer) * xDraw
          local yPos = (entry.y - yPlayer) * yDraw
          local distanceSq = xPos * xPos + yPos * yPos

          if distanceSq < visibleRadiusSq then
            local distance = sqrt(distanceSq)
            if not pfMap.mpins[i] then
              pfMap.mpins[i] = pfMap:BuildNode("pfMiniMapPinEV" .. i, pfMap.drawlayer)
            end

            local pin = pfMap.mpins[i]
            pfMap:UpdateNode(pin, entry.node, color, "minimap", distance)
            pin.hl:Hide()

            if pfQuest_config["showclustermini"] == "0" and pin.cluster then
              pin:Hide()
            elseif pfQuest_config["showspawnmini"] == "0"
                and entry.addon == "PFQUEST"
                and not pin.texture then
              pin:Hide()
            else
              pin:ClearAllPoints()
              pin:SetPoint("CENTER", pfMap.drawlayer, "CENTER", xPos, -yPos)
              pin:Show()
            end
            i = i + 1
          end
        end
      end
    end
  end

  perf.miniCandidates = candidates

  for j = i, table.getn(pfMap.mpins) do
    if pfMap.mpins[j] and pfMap.mpins[j]:IsShown() then pfMap.mpins[j]:Hide() end
  end
end

function EV:CountNodesForMap(mapID)
  if not mapID or not pfMap or type(pfMap.nodes) ~= "table" then return 0 end
  local n = 0
  for _, data in pairs(pfMap.nodes) do
    if type(data) == "table" and type(data[mapID]) == "table" then
      for _ in pairs(data[mapID]) do n = n + 1 end
    end
  end
  return n
end

function EV:Diagnostic()
  local mapID, mapName, cid, mid, mapInfo, viewKind = self:GetSelectedMapID()
  local p = self.player
  local entries, quests = GetNumQuestLogEntries()

  chat("v" .. tostring(self.version)
    .. " engine=" .. tostring(self.engine)
    .. " dbLocalized=" .. tostring(pfDatabase and pfDatabase.localized))

  local loc = self:RefreshLocationContext()

  chat("player zone=" .. tostring(p.zone)
    .. " mapID=" .. tostring(p.mapID)
    .. " xy=" .. tostring(p.x) .. "," .. tostring(p.y)
    .. " age=" .. tostring(p.updated and (GetTime() - p.updated) or nil)
    .. " source=" .. tostring(p.positionSource))

  chat("location zone=" .. tostring(loc.realZone)
    .. " parentSource=" .. tostring(loc.parentSource)
    .. " sub=" .. tostring(loc.subZone)
    .. " minimap=" .. tostring(loc.minimapZone)
    .. " instance=" .. tostring(loc.inInstance)
    .. "/" .. tostring(loc.instanceType))

  local rawX, rawY = nil, nil
  if type(QuestieEV_SafeGetPlayerMapPosition) == "function" then
    rawX, rawY = QuestieEV_SafeGetPlayerMapPosition("player")
  end

  chat("selected raw=" .. tostring(cid) .. "/" .. tostring(mid)
    .. " view=" .. tostring(viewKind)
    .. " mapInfo=" .. tostring(mapInfo)
    .. " zone=" .. tostring(mapName)
    .. " mapID=" .. tostring(mapID))

  chat("runtimeReady=" .. tostring(self.mapRuntimeReady)
    .. " inWorld=" .. tostring(self.inWorld)
    .. " rawXY=" .. tostring(rawX) .. "," .. tostring(rawY)
    .. " prime=" .. tostring(self.renderPrimeRequested or self.renderPrimeAt ~= nil))

  chat("mapContextPrime=" .. tostring(self.mapContextPrimeLastResult)
    .. " count=" .. tostring(self.mapContextPrimeCount or 0)
    .. " reason=" .. tostring(self.mapContextPrimeLastReason))

  chat("quests=" .. tostring(quests)
    .. " entries=" .. tostring(entries)
    .. " selectedNodes=" .. tostring(self:CountNodesForMap(mapID))
    .. " currentNodes=" .. tostring(self:CountNodesForMap(p.mapID)))

  chat("questState ready=" .. tostring(self.questStateReady)
    .. " sync=" .. tostring(self.questSyncSource)
    .. " historyAuthoritative=" .. tostring(self.questHistoryAuthoritative)
    .. " availableGivers=" .. tostring(self:CanRenderAvailableQuests())
    .. " completed=" .. tostring(self.questSyncCount)
    .. " history=" .. tostring(CountTable(pfQuest_history))
    .. " liveQuestlog=" .. tostring(pfQuest and CountTable(pfQuest.questlog) or 0))

  chat("render worldVisible=" .. tostring(VisibleCount(pfMap and pfMap.pins))
    .. " miniVisible=" .. tostring(VisibleCount(pfMap and pfMap.mpins))
    .. " minimapPolicy=" .. tostring(self.minimapPolicy)
    .. " env=" .. tostring(self.minimapEnvironment)
    .. "/" .. tostring(self.minimapEnvironmentSource)
    .. " playerMarker=" .. tostring(self.playerMarker and self.playerMarker:IsShown())
    .. " nativeArrowHidden=" .. tostring(self.nativeWorldArrowsHidden))

  local perf = self.perf or {}
  chat("perf miniRuns=" .. tostring(perf.miniRuns or 0)
    .. " skips=" .. tostring(perf.miniSkips or 0)
    .. " mapHiddenSkips=" .. tostring(perf.miniMapHiddenSkips or 0)
    .. " interval=" .. tostring(perf.miniInterval or 0)
    .. " fps=" .. tostring(perf.fpsNow or 0)
    .. " fpsAvg=" .. tostring(perf.fpsAvg or 0)
    .. " fpsMin=" .. tostring(perf.fpsMin or 0))

  chat("perf cacheNodes=" .. tostring(perf.miniCachedNodes or 0)
    .. " candidates=" .. tostring(perf.miniCandidates or 0)
    .. " cacheBuilds=" .. tostring(perf.miniCacheBuilds or 0)
    .. " generation=" .. tostring(perf.miniCacheGeneration or 0)
    .. " cacheReason=" .. tostring(perf.miniLastCacheReason)
    .. " worldRuns=" .. tostring(perf.worldRuns or 0)
    .. " worldSkips=" .. tostring(perf.worldSkips or 0))

  local qevZoom = nil
  if Minimap and type(Minimap.GetZoom) == "function" then
    local ok, value = pcall(Minimap.GetZoom, Minimap)
    if ok then qevZoom = value end
  end
  chat("minimap scale env=" .. tostring(self.minimapEnvironment)
    .. "/" .. tostring(self.minimapEnvironmentSource)
    .. " zoom=" .. tostring(qevZoom)
    .. " events out=" .. tostring(self.minimapOutdoorEventCount or 0)
    .. " in=" .. tostring(self.minimapIndoorEventCount or 0)
    .. " zoom=" .. tostring(self.minimapZoomEventCount or 0)
    .. " zone=" .. tostring(self.minimapZoneEventCount or 0)
    .. " registered=" .. tostring(self.minimapZoomEventRegistered)
    .. "/" .. tostring(self.zoneIndoorsEventRegistered))

  chat("framexml difficultyFallback=" .. tostring(self.difficultyColorFallback)
    .. " GetDifficultyColor=" .. tostring(type(GetDifficultyColor)))
end

function EV:ForceRefresh()
  self:ApplyKnownGoodConfig()

  if not self:CapturePlayerPosition(false) then
    self:PrimeHiddenPlayerMapContext("qev-force")
  end

  if self.questStateReady == false and self.RequestQuestStateSync then
    self:RequestQuestStateSync(false)
  end

  if pfQuest and pfQuest.ResetAll then
    pfQuest:ResetAll()
  else
    if pfQuest then
      pfQuest.updateQuestLog = true
      pfQuest.updateQuestGivers = true
    end
  end

  if pfMap then
    pfMap.queue_update = GetTime()
  end

  self:MarkMinimapNodeCacheDirty("qev-force")
  self.worldMapForceNext = true
  self.renderPrimeRequested = true
  self.forceDiagAt = GetTime() + 2.5
  chat("force refresh scheduled; rebuilding active quest data and verified available quest givers.")
end

local function Command(msg)
  if type(msg) ~= "string" then
    msg = type(arg1) == "string" and arg1 or ""
  end

  msg = string.lower(msg)
  msg = string.gsub(msg, "^%s+", "")
  msg = string.gsub(msg, "%s+$", "")
  msg = string.gsub(msg, "^/qev%s*", "")
  msg = string.gsub(msg, "^qev%s*", "")

  if msg == "force" or msg == "refresh" then
    EV:ForceRefresh()
  elseif msg == "sync" then
    if EV.RequestQuestStateSync then
      EV:RequestQuestStateSync(true)
      chat("completed-quest synchronization requested.")
    else
      chat("completed-quest synchronization is unavailable.")
    end
  elseif msg == "map" then
    if pfMap then pfMap:UpdateNodes() end
    EV:UpdatePlayerMarker()
    EV:Diagnostic()
  else
    EV:Diagnostic()
    chat("commands: /qev | /qev force | /qev sync | /qev map")
  end
end

SLASH_QUESTIEEV1 = "/qev"
SlashCmdList["QUESTIEEV"] = Command

-- Bootstrap / continuous player-map independence.
local driver = CreateFrame("Frame", "QuestieEVDriver", UIParent)
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("ZONE_CHANGED")
driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
driver:RegisterEvent("MINIMAP_ZONE_CHANGED")
driver:RegisterEvent("WORLD_MAP_UPDATE")

-- These are standard Vanilla map events. Register defensively because the
-- supplied Azeroth API reference documents native functions/widgets, not the
-- complete FrameXML event list.
if pcall and driver.RegisterEvent then
  local okZoom = pcall(driver.RegisterEvent, driver, "MINIMAP_UPDATE_ZOOM")
  EV.minimapZoomEventRegistered = okZoom and true or false
  local okIndoor = pcall(driver.RegisterEvent, driver, "ZONE_CHANGED_INDOORS")
  EV.zoneIndoorsEventRegistered = okIndoor and true or false
end
driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("QUEST_LOG_UPDATE")
driver:RegisterEvent("QUEST_WATCH_UPDATE")
driver:RegisterEvent("QUEST_FINISHED")

-- PLAYER_LEAVING_WORLD is optional on Emberveil; register defensively.
if pcall and driver.RegisterEvent then
  pcall(driver.RegisterEvent, driver, "PLAYER_LEAVING_WORLD")
end

driver:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 ~= "pfQuest" then return end
    EV:ApplyKnownGoodConfig()
    return
  end

  if event == "PLAYER_LEAVING_WORLD" then
    EV.inWorld = false
    EV.mapRuntimeReady = false
    EV.mapRuntimeReadyAt = nil
    EV:InvalidatePlayerPosition(true, "leaving-world")
    EV.renderPrimeAt = nil
    EV.renderPrimeUntil = nil
    EV.questRenderNudgeAt = nil
    EV.mapContextPrimeAt = nil
    EV.mapContextPrimeCooldownUntil = nil
    EV.mapContextPrimeBusy = false
    EV.minimapProjectionAt = nil
    EV.location = {}
    if EV.playerMarker and EV.playerMarker.Hide then EV.playerMarker:Hide() end
    return
  end

  if event == "PLAYER_ENTERING_WORLD" then
    EV.inWorld = true
    EV.mapRuntimeReady = false
    EV.startupReadyAt = GetTime() + 4.0
    EV.mapRuntimeReadyAt = EV.startupReadyAt
    this.captureAt = EV.startupReadyAt
    EV.location = {}
    EV:MarkMinimapNodeCacheDirty("player-entering-world")
    EV.worldMapForceNext = true
    EV.renderPrimeRequested = true
    EV.mapContextPrimeAt = EV.startupReadyAt + 1.0
    chat("character entered world; stable-core map startup begins in 4 seconds.")
    return
  end

  if not EV.inWorld then return end

  -- Large-area changes can happen around Hearthstones/instances. Clear the
  -- cached position and let Emberveil establish its own map context naturally.
  if event == "ZONE_CHANGED_NEW_AREA" then
    EV.mapRuntimeReady = false
    EV.mapRuntimeReadyAt = GetTime() + 1.50
    EV:InvalidatePlayerPosition(true, "new-area")
    EV.location = {}
    this.captureAt = EV.mapRuntimeReadyAt
    EV:MarkMinimapNodeCacheDirty("zone-changed-new-area")
    EV.worldMapForceNext = true
    EV.renderPrimeRequested = true
    EV.mapContextPrimeAt = EV.mapRuntimeReadyAt + .50
    return
  end

  if event == "ZONE_CHANGED" then
    EV.minimapOutdoorEventCount = (EV.minimapOutdoorEventCount or 0) + 1
    EV:SetMinimapEnvironment(1, "ZONE_CHANGED-outdoor", true)
    EV:RefreshLocationContext(true)
    EV:ScheduleMinimapProjection(.08, "ZONE_CHANGED")
    this.captureAt = GetTime() + .10
    return
  end

  if event == "ZONE_CHANGED_INDOORS" then
    EV.minimapIndoorEventCount = (EV.minimapIndoorEventCount or 0) + 1
    EV:SetMinimapEnvironment(0, "ZONE_CHANGED_INDOORS", true)
    EV:RefreshLocationContext(true)
    EV:ScheduleMinimapProjection(.08, "ZONE_CHANGED_INDOORS")
    this.captureAt = GetTime() + .10
    return
  end

  if event == "MINIMAP_UPDATE_ZOOM" then
    EV.minimapZoomEventCount = (EV.minimapZoomEventCount or 0) + 1
    local now = GetTime()

    -- A zoom event proves only that projection changed. It does not prove the
    -- direction of an indoor/outdoor transition, so never toggle state here.
    EV:ScheduleMinimapProjection(.08, "MINIMAP_UPDATE_ZOOM")

    this.captureAt = now + .08
    return
  end

  if event == "MINIMAP_ZONE_CHANGED" then
    EV.minimapZoneEventCount = (EV.minimapZoneEventCount or 0) + 1
    EV:RefreshLocationContext(true)
    EV:ScheduleMinimapProjection(.08, "MINIMAP_ZONE_CHANGED")
    this.captureAt = GetTime() + .12
    return
  end

  if event == "WORLD_MAP_UPDATE" then
    this.captureAt = GetTime() + .15

    if not EV:IsWorldMapShown() then
      EV.mapContextPrimeAt = GetTime() + .20
    end
    return
  end

  if event == "QUEST_LOG_UPDATE"
      or event == "QUEST_WATCH_UPDATE"
      or event == "QUEST_FINISHED" then
    EV:MarkMinimapNodeCacheDirty("quest-event:" .. tostring(event))
    EV.worldMapForceNext = true
    this.questRenderNudgeAt = GetTime() + .35
    return
  end

  this.captureAt = GetTime() + .25
end)

driver:SetScript("OnUpdate", function()
  if not EV.inWorld then return end

  local now = GetTime()
  EV:SampleFramerate(now)

  if EV.mapRuntimeReadyAt and now < EV.mapRuntimeReadyAt then
    return
  elseif EV.mapRuntimeReadyAt then
    EV.mapRuntimeReadyAt = nil
    EV.mapRuntimeReady = true
  end

  if EV.startupReadyAt and now < EV.startupReadyAt then return end
  if EV.startupReadyAt then EV.startupReadyAt = nil end

  if (this.tick or 0) > now then return end
  this.tick = now + .20

  -- One authoritative startup/reconciliation prime.
  --
  -- pfQuest normally keeps an initial ~10 second quest-log lock. Emberveil's
  -- map/player APIs are already stable after our 4 second gate, so once quest
  -- history is reconciled we can safely release that lock and rebuild the
  -- current quest state. We then drive UpdateMinimap directly for a few
  -- seconds, which removes the old "open world map once" dependency.
  if EV.renderPrimeRequested
      and EV.mapRuntimeReady
      and EV.questStateReady then
    EV.renderPrimeRequested = false
    EV.renderPrimeAt = now + .05
    EV.renderPrimeUntil = now + 5.0

    EV:MarkMinimapNodeCacheDirty("render-prime")
    EV.worldMapForceNext = true

    if pfQuest then
      pfQuest.lock = nil
      pfQuest.updateQuestLog = true
      pfQuest.updateQuestGivers = true

      if pfQuest.UpdateQuestlog then
        pcall(pfQuest.UpdateQuestlog, pfQuest)
      end
    end
  end

  if EV.renderPrimeAt and now >= EV.renderPrimeAt then
    EV:CapturePlayerPosition(false)

    if pfMap then
      pfMap.queue_update = now

      -- Always prime the minimap, even with WorldMapFrame closed.
      if pfMap.UpdateMinimap then
        pfMap:UpdateMinimap()
      end

      if EV:IsWorldMapShown() and pfMap.UpdateNodes then
        pfMap:UpdateNodes()
      end
    end

    if EV.renderPrimeUntil and now < EV.renderPrimeUntil then
      EV.renderPrimeAt = now + .25
    else
      EV.renderPrimeAt = nil
      EV.renderPrimeUntil = nil
    end
  end

  if this.questRenderNudgeAt and now >= this.questRenderNudgeAt then
    this.questRenderNudgeAt = nil

    if pfMap then
      pfMap.queue_update = now
      if pfMap.UpdateMinimap then pfMap:UpdateMinimap() end

      if EV:IsWorldMapShown() and pfMap.UpdateNodes then
        pfMap:UpdateNodes()
      end
    end
  end

  -- Hidden map-context recovery. This is the programmatic equivalent of the
  -- one manual world-map open/close that beta1.10 still required.
  if EV.mapContextPrimeAt and now >= EV.mapContextPrimeAt then
    EV.mapContextPrimeAt = nil
    EV:PrimeHiddenPlayerMapContext("scheduled")
  end

  local worldShownForPrime = EV:IsWorldMapShown()
  if not worldShownForPrime
      and EV.mapRuntimeReady
      and EV.player
      and type(EV.player.positionSource) == "string"
      and string.find(EV.player.positionSource, "^view%-mismatch:") then
    EV:PrimeHiddenPlayerMapContext("hidden-view-mismatch")
  end

  -- User configuration is never rewritten from the runtime tick.

  -- Alpha2 deliberately does NOT run the old pfQuest tooltip-hyperlink locale
  -- probe and does NOT auto-force a quest/map rebuild during login.
  if pfDatabase and not pfDatabase.localized then
    pfDatabase.localized = true
  end

  local shown = EV:IsWorldMapShown()

  if not shown then
    local captured = EV:CapturePlayerPosition(false)
    if captured and EV.mapContextPrimeLastResult == "not-run" then
      EV.mapContextPrimeLastResult = "natural-current-zone"
    end
  else
    local selectedID = EV:GetSelectedMapID()
    if selectedID and EV.player.mapID and selectedID == EV.player.mapID then
      EV:CapturePlayerPosition(false)
    end
  end

  if this.captureAt and now >= this.captureAt then
    this.captureAt = nil
    EV:CapturePlayerPosition(false)
  end

  local mapID, _, cid, mid, mapInfo = EV:GetSelectedMapID()
  local key = tostring(cid) .. ":" .. tostring(mid) .. ":" .. tostring(mapInfo) .. ":" .. tostring(mapID)

  if shown and key ~= EV.lastSelectedKey then
    EV.lastSelectedKey = key
    if pfMap then pfMap:UpdateNodes() end
  elseif not shown then
    EV.lastSelectedKey = nil
  end

  EV:UpdatePlayerMarker()

  if EV.forceDiagAt and now >= EV.forceDiagAt then
    EV.forceDiagAt = nil
    if pfMap then
      pfMap:UpdateNodes()
      pfMap:UpdateMinimap()
    end
    EV:UpdatePlayerMarker()
    EV:Diagnostic()
  end
end)

chat("pfQuest crash-safe map engine " .. EV.version .. " loaded.")
