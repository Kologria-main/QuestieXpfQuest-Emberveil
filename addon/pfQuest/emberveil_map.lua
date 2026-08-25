-- KoQuest for Emberveil / pfQuest map engine
-- v2.0.0-beta1.20
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
EV.questRenderReason = nil

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
EV.mapContextBootstrapAttempted = false
EV.mapContextProbeAttempted = false
EV.mapContextProbe = nil
EV.mapContextProbeCount = 0
EV.location = EV.location or {}
EV.positionFreshSeconds = 2.0

-- Thomas's measured Emberveil runtime evidence confirms the Vanilla outdoor
-- span at zoom 0 keeps a world-anchored marker glued while walking. The client
-- exposes neither IsIndoors nor IsOutdoors, and ZONE_CHANGED_INDOORS does not
-- prove that the minimap switched to an indoor scale. Therefore only the
-- verified outdoor row is safe; selecting the unmeasurable indoor row causes
-- the exact drift seen outdoors at Sentinel Tower.
EV.minimapEnvironment = 1
EV.minimapEnvironmentSource = "verified-outdoor-only"
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
  miniInterval = 0.05,
  miniBaseInterval = 0.05,
  miniTransitionInterval = 0.05,
  miniLowFpsInterval = 0.05,
  fpsNow = 0,
  fpsAvg = 0,
  fpsMin = nil,
  fpsSamples = 0,
  fpsNextAt = nil,
  transitionUntil = nil,
  worldRuns = 0,
  worldSkips = 0,
  worldNodeTotal = 0,
  worldNodeRendered = 0,
  worldNodeSuppressed = 0,
  worldDenseMode = false,
  worldObjectiveSource = 0,
  worldObjectiveRendered = 0,
  worldObjectiveCellSize = 0,
}
EV.minimapNextAt = nil
EV.minimapForceNext = true
EV.minimapNodeCache = EV.minimapNodeCache or {
  mapID = nil,
  entries = {},
  grid = {},
  cellSize = 2.5,
  dirty = true,
  reason = "init",
  generation = 0,
}
EV.worldMapNextAt = nil
EV.worldMapForceNext = true
EV.worldMapWasShown = false
EV.worldNodeCache = EV.worldNodeCache or {
  mapID = nil,
  generation = nil,
  entries = {},
  objectiveSource = 0,
  objectiveRendered = 0,
  objectiveCellSize = 0,
}
EV.locationRefreshSeconds = 0.25

local function chat(msg)
  if EV.Chat then
    EV.Chat(msg)
  elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccKoQuest:|r " .. tostring(msg))
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

  -- Keep projection at the measured 20 Hz cadence. Slowing to 4-7 Hz under
  -- load made pins visibly lag behind the moving minimap texture. The hot path
  -- below now caches visual metadata, so a normal movement tick only performs
  -- bounded spatial math and point updates.
  perf.miniInterval = perf.miniBaseInterval or 0.05
end

function EV:ResetFramerateStats(reason)
  local perf = self.perf
  perf.fpsNow = 0
  perf.fpsAvg = 0
  perf.fpsMin = nil
  perf.fpsSamples = 0
  perf.fpsNextAt = GetTime() + 1.0
  perf.fpsResetReason = reason or "runtime-ready"
end

function EV:MarkMinimapNodeCacheDirty(reason)
  self.minimapNodeCache = self.minimapNodeCache or {
    mapID = nil, entries = {}, grid = {}, cellSize = 2.5,
    dirty = true, reason = "init", generation = 0,
  }
  self.minimapNodeCache.dirty = true
  self.minimapNodeCache.reason = reason or "unknown"
  self.minimapForceNext = true
end

-- Called after a quest node transaction (NEW/RELOAD/REMOVE), not merely when
-- the game event fires. This ordering is important: rebuilding the spatial
-- cache before SearchQuestID finishes would cache the old node set and make
-- accepted-quest objectives appear late.
function EV:NotifyQuestNodesChanged(reason)
  local now = GetTime()
  self:MarkMinimapNodeCacheDirty("quest-nodes:" .. tostring(reason or "changed"))
  self.worldMapForceNext = true
  self.minimapForceNext = true
  self.questRenderReason = reason or "changed"

  -- One coalesced near-immediate render. Multiple quest-log events and several
  -- nodes belonging to the same quest collapse into the same frame deadline.
  local due = now + .01
  if not self.questRenderNudgeAt or due < self.questRenderNudgeAt then
    self.questRenderNudgeAt = due
  end
end

function EV:GetMinimapNodeCache(mapID)
  local cache = self.minimapNodeCache
  if not cache then
    cache = {
      mapID = nil, entries = {}, grid = {}, cellSize = 2.5,
      dirty = true, reason = "init", generation = 0,
    }
    self.minimapNodeCache = cache
  end

  if cache.mapID == mapID and not cache.dirty then return cache end

  local entries = {}
  local grid = {}
  local cellSize = cache.cellSize or 2.5

  if pfMap and type(pfMap.nodes) == "table" and mapID then
    for addon, data in pairs(pfMap.nodes) do
      local bucket = type(data) == "table" and data[mapID] or nil
      if type(bucket) == "table" then
        for coords, node in pairs(bucket) do
          local _, _, sx, sy = string.find(coords, "(.*)|(.*)")
          local x, y = tonumber(sx), tonumber(sy)
          if x and y then
            local entry = {
              addon = addon,
              node = node,
              x = x,
              y = y,
              key = tostring(addon) .. "|" .. tostring(mapID) .. "|" .. tostring(coords),
            }
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

-- Fast path used by the minimap projector. The world map is hidden here, so
-- Emberveil's current map context is the player's verified parent zone. This
-- mirrors Thomas's successful 0.05-second world-anchor probe without repeating
-- the full zone/map discovery chain on every movement sample.
function EV:CaptureMinimapPlayerPosition()
  if self:IsWorldMapShown() then return false end

  local loc = self:RefreshLocationContext()
  local mapID = loc.parentMapID or self:GetMapIDByZoneName(loc.realZone)
  if not mapID then
    self.player.positionSource = "minimap-zone-unmapped"
    return false
  end

  local x, y = QuestieEV_SafeGetPlayerMapPosition("player")
  if not (Num(x) and Num(y) and x > 0 and x <= 1 and y > 0 and y <= 1) then
    self.player.positionSource = "minimap-position-unavailable"
    return false
  end

  if self.player.mapID and self.player.mapID ~= mapID then
    self:MarkMinimapNodeCacheDirty("fast-position-map-change")
  end

  self.player.mapID = mapID
  self.player.zone = loc.realZone
  self.player.x = x
  self.player.y = y
  self.player.updated = GetTime()
  self.player.positionSource = "minimap-fast-zone"
  self.player.contextKey = tostring(mapID) .. "|" .. tostring(loc.realZone)
  return true
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
    pfQuest_config["qev_minimap_environment"] = "1"
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
  -- Indoor scale selection is not observable on Emberveil. Preserve the only
  -- measured row instead of treating a zone event name as scale evidence.
  local changed = self.minimapEnvironment ~= 1
  self.minimapEnvironment = 1
  self.minimapEnvironmentSource = "verified-outdoor-only"
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
  self.minimapEnvironment = 1
  self.minimapEnvironmentSource = "verified-outdoor-only"
  return 1
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

-- Emberveil sometimes returns nil from both parent-zone APIs after /reload and
-- leaves the mapping subsystem at the same 0/0/nil signature as a genuine
-- world view. SetMapToCurrentZone normally resolves that cold state, but the
-- live Sentinel Tower case proved it can also be a no-op when the parent text
-- itself is missing. In that narrow, proven-outdoor state, probe the client's
-- own concrete zone views while the world map is hidden. A candidate is
-- accepted only when the selected cid/mid maps to a known pfQuest zone AND the
-- native player projection is non-zero on that exact view. No subzone-name
-- guessing is involved.
function EV:BeginHiddenZoneProbe(reason)
  if self.mapContextProbe or self.mapContextProbeAttempted then return false end
  if self:IsWorldMapShown() then return false end

  local loc = self:RefreshLocationContext(true)
  if loc.inInstance ~= false then
    self.mapContextPrimeLastResult =
      "zone-probe-blocked-instance:" .. tostring(loc.instanceType)
    return false
  end

  local raw = self._rawSetMapZoom
  if type(raw) ~= "function" or type(GetMapZones) ~= "function" then
    self.mapContextPrimeLastResult = "zone-probe-api-missing"
    return false
  end

  local continentCount = 2
  if type(GetMapContinents) == "function" then
    local values = { pcall(GetMapContinents) }
    if values[1] then
      table.remove(values, 1)
      if table.getn(values) > 0 then continentCount = table.getn(values) end
    end
  end

  local candidates = {}
  self.mapContextProbe = {
    candidates = candidates,
    index = 1,
    nextAt = GetTime(),
    reason = reason or "unknown",
  }
  self.mapContextProbeAttempted = true
  self.mapContextPrimeBusy = true

  for cid = 1, continentCount do
    local okZoom = pcall(raw, cid)
    if okZoom then
      local zones = { pcall(GetMapZones, cid) }
      if zones[1] then
        table.remove(zones, 1)
        self.mapZoneCache[cid] = zones
        for mid, name in pairs(zones) do
          local mapID = self:GetMapIDByZoneName(name)
          if type(mid) == "number" and mapID then
            candidates[table.getn(candidates) + 1] = {
              cid = cid,
              mid = mid,
              name = name,
              mapID = mapID,
              nodeScore = self:CountNodesForMap(mapID),
            }
          end
        end
      end
    end
  end

  -- Active-quest zones are overwhelmingly the most likely current maps and
  -- are already available by the time this post-startup recovery runs. Probe
  -- them first, while preserving the exact coordinate-verification gate. This
  -- turns Westfall's cold start from 42 native map switches into one and avoids
  -- a burst of unnecessary map loads; characters with no nodes still receive
  -- the complete fallback scan.
  table.sort(candidates, function(a, b)
    local aScore = tonumber(a.nodeScore) or 0
    local bScore = tonumber(b.nodeScore) or 0
    if aScore ~= bScore then return aScore > bScore end
    if a.cid ~= b.cid then return a.cid < b.cid end
    return a.mid < b.mid
  end)

  self.mapContextPrimeBusy = false
  if table.getn(candidates) == 0 then
    self.mapContextProbe = nil
    self.mapContextPrimeLastResult = "zone-probe-no-candidates"
    return false
  end

  self.mapContextPrimeLastResult =
    "zone-probe-running:" .. tostring(table.getn(candidates))
  self.mapContextPrimeLastReason = reason or "unknown"
  return true
end

function EV:ProcessHiddenZoneProbe(limit)
  local probe = self.mapContextProbe
  if not probe then return false end

  if self:IsWorldMapShown() then
    -- The player always wins. Abort without changing their visible selection,
    -- and allow a fresh hidden-only attempt after they close the map.
    self.mapContextProbe = nil
    self.mapContextProbeAttempted = false
    self.mapContextPrimeLastResult = "zone-probe-aborted-world-map-visible"
    return false
  end

  local raw = self._rawSetMapZoom
  if type(raw) ~= "function" then
    self.mapContextProbe = nil
    self.mapContextPrimeLastResult = "zone-probe-api-missing"
    return false
  end

  limit = tonumber(limit) or 2
  local processed = 0
  while processed < limit do
    local candidate = probe.candidates[probe.index]
    if not candidate then
      self.mapContextProbe = nil
      self.mapContextPrimeLastResult =
        "zone-probe-no-match:" .. tostring(table.getn(probe.candidates))
      -- Leave no unrelated zone selected after a failed scan.
      self.mapContextPrimeBusy = true
      pcall(raw, 0)
      self.mapContextPrimeBusy = false
      return false
    end

    probe.index = probe.index + 1
    processed = processed + 1
    self.mapContextPrimeBusy = true
    local ok = pcall(raw, candidate.cid, candidate.mid)
    self.mapContextPrimeBusy = false
    self.mapContextProbeCount = (self.mapContextProbeCount or 0) + 1

    if ok then
      local selectedID, selectedName, selectedCID, selectedMID, _, viewKind =
        self:GetSelectedMapID()
      local x, y = QuestieEV_SafeGetPlayerMapPosition("player")
      if selectedID == candidate.mapID
          and selectedCID == candidate.cid
          and selectedMID == candidate.mid
          and (viewKind == "zone" or viewKind == "zone-fallback")
          and Num(x) and Num(y) and x > 0 and x <= 1 and y > 0 and y <= 1 then
        local zoneName = selectedName or candidate.name
        self.location.parentZone = zoneName
        self.location.parentMapID = candidate.mapID
        self.location.realZone = zoneName
        self.location.parentSource = "hidden-zone-probe"
        self.location.updated = GetTime()

        self.player.mapID = candidate.mapID
        self.player.zone = zoneName
        self.player.x = x
        self.player.y = y
        self.player.updated = GetTime()
        self.player.positionSource = "hidden-zone-probe"
        self.player.contextKey = tostring(candidate.mapID) .. "|" .. tostring(zoneName)

        self.mapContextProbe = nil
        self.mapContextPrimeLastResult =
          "zone-probe-resolved:" .. tostring(zoneName)
        self:MarkMinimapNodeCacheDirty("zone-probe-resolved")
        self.worldMapForceNext = true
        self.renderPrimeRequested = true
        self:ResetFramerateStats("zone-probe-resolved")
        return true
      end
    end
  end

  probe.nextAt = GetTime() + .10
  return nil
end

function EV:PrimeHiddenPlayerMapContext(reason)
  local now = GetTime()
  local urgentRestore = reason == "world-map-close"

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
      and now < self.mapContextPrimeCooldownUntil
      and not urgentRestore then
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

  -- Emberveil can return nil from both GetZoneText() and GetRealZoneText()
  -- after /reload while still returning only a subzone such as
  -- "Sentinel Tower". In that exact outdoor state there is no parent name to
  -- resolve, but SetMapToCurrentZone() is the authoritative bootstrap API: it
  -- selects the player's real zone without guessing that the subzone is a map.
  -- Permit that bootstrap only when IsInInstance() explicitly proved false.
  -- Unknown, dungeon, and raid contexts remain fail-closed.
  local bootstrapUnresolvedOutdoor =
    (not realZone or realZone == "" or not playerMapID)
    and loc.inInstance == false

  if (not realZone or realZone == "" or not playerMapID)
      and not bootstrapUnresolvedOutdoor then
    self.mapContextPrimeLastResult = "player-zone-unresolved"
    return false
  end

  local selectedID, _, _, _, _, viewKind = self:GetSelectedMapID()

  if bootstrapUnresolvedOutdoor and self.mapContextBootstrapAttempted then
    return self:BeginHiddenZoneProbe(reason or "unresolved-outdoor")
  end

  if not bootstrapUnresolvedOutdoor
      and selectedID == playerMapID
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
  self.mapContextPrimeCooldownUntil = now
    + (urgentRestore and .20 or (bootstrapUnresolvedOutdoor and .20 or 2.0))
  self.mapContextPrimeLastReason = reason or "unknown"

  local ok = pcall(raw)

  self.mapContextPrimeBusy = false

  if not ok then
    self.mapContextPrimeLastResult = "native-call-error"
    return false
  end

  self.mapContextPrimeCount = (self.mapContextPrimeCount or 0) + 1
  if bootstrapUnresolvedOutdoor then
    self.mapContextBootstrapAttempted = true
  end
  self.mapContextPrimeLastResult = bootstrapUnresolvedOutdoor
    and ("native-bootstrap-current-zone:" .. tostring(viewKind))
    or ("native-current-zone:" .. tostring(viewKind))

  -- Let Azeroth finish the map switch, then recapture and prime the minimap.
  self.renderPrimeRequested = true
  self.mapContextPrimeAt = now
    + (urgentRestore and .05 or (bootstrapUnresolvedOutdoor and .25 or .15))
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
    unverifiedquestgivers = "0",
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
  -- This marker deliberately communicates position only. Emberveil exposes no
  -- trustworthy facing value, so a directional arrow would show false data.
  -- Keep the neutral ring large and above quest summaries so it cannot look
  -- clipped/broken when several nodes overlap the player at a quest hub.
  f:SetWidth(30)
  f:SetHeight(30)
  f:SetFrameLevel(500)
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
local function IsWorldSummaryNode(node)
  if type(node) ~= "table" then return false end
  for _, meta in pairs(node) do
    if type(meta) == "table" and (meta.texture or meta.cluster) then
      return true
    end
  end
  return false
end

-- Dense questing zones can contain more than a thousand objective spawn
-- points. Hiding every individual point kept the map fast, but also removed
-- the small coloured, hoverable pfQuest circles players rely on. Keep those
-- real Button nodes (and their full tooltips) while coalescing only points
-- that occupy the same small world-map area. This bounds frame/texture count
-- without replacing interactive nodes with a decorative texture layer.
local WORLD_OBJECTIVE_PIN_BUDGET = 320
local WORLD_OBJECTIVE_GRID_STEPS = {
  .75, 1, 1.25, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10,
  12.5, 16, 20, 25, 33, 50, 100,
}

local function GetWorldObjectiveIdentity(node)
  local parts = {}

  for title, meta in pairs(node) do
    local itemParts = {}
    if type(meta) == "table" and type(meta.item) == "table" then
      for _, item in ipairs(meta.item) do
        itemParts[table.getn(itemParts) + 1] = tostring(item)
      end
      table.sort(itemParts)
    end

    parts[table.getn(parts) + 1] = table.concat({
      tostring(title),
      tostring(type(meta) == "table" and meta.questid or ""),
      tostring(type(meta) == "table" and meta.spawnid or ""),
      tostring(type(meta) == "table" and meta.spawntype or ""),
      table.concat(itemParts, ","),
    }, "~")
  end

  table.sort(parts)
  return table.concat(parts, ";")
end

local function BuildWorldObjectiveBuckets(entries, cellSize)
  local buckets = {}
  local count = 0

  for _, entry in ipairs(entries) do
    local cx = math.floor(entry.x / cellSize)
    local cy = math.floor(entry.y / cellSize)
    -- Never merge unrelated spawns merely because their circles overlap.
    -- Keeping the quest/spawn/item identity in the bucket key preserves the
    -- exact tooltip meaning while still folding repeated coordinates for the
    -- same objective into a bounded number of buttons.
    local identity = GetWorldObjectiveIdentity(entry.node)
    local key = identity .. "|" .. tostring(cx) .. "|" .. tostring(cy)
    local bucket = buckets[key]

    if not bucket then
      bucket = {
        addon = "PFQUEST",
        node = {},
        x = entry.x,
        y = entry.y,
        sourceKey = entry.key,
        key = "objective|" .. key,
      }
      buckets[key] = bucket
      count = count + 1
    end

    -- Display a real database coordinate, never the mathematical centre of a
    -- bucket. The deterministic lowest source key keeps the chosen location
    -- stable across refreshes while every visible circle remains truthful.
    if entry.key < bucket.sourceKey then
      bucket.x = entry.x
      bucket.y = entry.y
      bucket.sourceKey = entry.key
    end

    -- A combined pfMap node may contain several quest/objective titles.
    -- Preserve one complete metadata record for each title so NodeEnter keeps
    -- the same quest-aware tooltip behaviour as an ungrouped spawn point.
    for title, meta in pairs(entry.node) do
      if bucket.node[title] == nil then bucket.node[title] = meta end
    end
  end

  local grouped = {}
  for _, bucket in pairs(buckets) do
    grouped[table.getn(grouped) + 1] = bucket
  end

  table.sort(grouped, function(a, b) return a.key < b.key end)
  return grouped, count
end

function EV:GetWorldRenderEntries(mapID, denseMode)
  local nodeCache = self:GetMinimapNodeCache(mapID)
  local generation = nodeCache.generation or 0
  local cache = self.worldNodeCache

  if cache and cache.mapID == mapID and cache.generation == generation
      and cache.denseMode == denseMode then
    return cache
  end

  cache = {
    mapID = mapID,
    generation = generation,
    denseMode = denseMode,
    entries = {},
    objectiveSource = 0,
    objectiveRendered = 0,
    objectiveCellSize = 0,
  }

  local objectives = {}
  for _, entry in ipairs(nodeCache.entries) do
    if denseMode and entry.addon == "PFQUEST" and not IsWorldSummaryNode(entry.node) then
      objectives[table.getn(objectives) + 1] = entry
    else
      cache.entries[table.getn(cache.entries) + 1] = entry
    end
  end

  cache.objectiveSource = table.getn(objectives)

  if denseMode and cache.objectiveSource > 0 then
    local budget = WORLD_OBJECTIVE_PIN_BUDGET - table.getn(cache.entries)
    if budget < 64 then budget = 64 end
    local grouped = objectives
    local chosenSize = 0

    for _, cellSize in ipairs(WORLD_OBJECTIVE_GRID_STEPS) do
      local candidate, candidateCount = BuildWorldObjectiveBuckets(objectives, cellSize)
      grouped = candidate
      chosenSize = cellSize
      if candidateCount <= budget then break end
    end

    for _, entry in ipairs(grouped) do
      cache.entries[table.getn(cache.entries) + 1] = entry
    end
    cache.objectiveRendered = table.getn(grouped)
    cache.objectiveCellSize = chosenSize
  else
    cache.objectiveRendered = cache.objectiveSource
  end

  self.worldNodeCache = cache
  return cache
end

-- Switching the native world map between zone and continent views can mutate
-- the shared material behind already-cached minimap textures. UpdateNode's
-- metadata cache then sees no logical change and leaves a hollow/black pin in
-- place. Invalidate only on the map-close transition; the next bounded
-- minimap pass recreates the intended texture and vertex colour once.
function EV:InvalidateMinimapPinVisuals(reason)
  if pfMap and type(pfMap.mpins) == "table" then
    for _, pin in pairs(pfMap.mpins) do
      if pin then
        pin.qevVisualKey = nil
        pin.qevX = nil
        pin.qevY = nil
        if pin.tex and pin.tex.SetTexture then pin.tex:SetTexture(nil) end
        if pin.pic and pin.pic.Hide then pin.pic:Hide() end
        if pin.hl and pin.hl.Hide then pin.hl:Hide() end
        if pin.Hide then pin:Hide() end
      end
    end
  end

  self.minimapForceNext = true
  self.minimapNextAt = nil
  self.minimapVisualResetReason = reason or "unknown"
  self.minimapVisualResetCount = (self.minimapVisualResetCount or 0) + 1
end

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
  local totalNodes = EV:CountNodesForMap(map)
  local denseMode = totalNodes > 450
  local renderedNodes = 0
  local suppressedNodes = 0

  EV.perf.worldNodeTotal = totalNodes
  EV.perf.worldDenseMode = denseMode

  if pfQuest.tracker and pfQuest.tracker.Reset then
    pfQuest.tracker.Reset()
  end
  if pfQuest.route and pfQuest.route.Reset then
    pfQuest.route:Reset()
  end

  if map then
    local renderCache = EV:GetWorldRenderEntries(map, denseMode)
    for _, entry in ipairs(renderCache.entries) do
      local addon = entry.addon
      local node = entry.node
      if not pfMap.pins[i] then
        pfMap.pins[i] = pfMap:BuildNode("pfMapPin" .. i, WorldMapButton)
      end

      pfMap:UpdateNode(pfMap.pins[i], node, color)

      local x = entry.x
      local y = entry.y

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
            for title, trackerEntry in pairs(pfMap.pins[i].node) do
              pfQuest.tracker.ButtonAdd(title, trackerEntry)
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
        renderedNodes = renderedNodes + 1
      end
    end

    suppressedNodes = renderCache.objectiveSource - renderCache.objectiveRendered
    EV.perf.worldObjectiveSource = renderCache.objectiveSource
    EV.perf.worldObjectiveRendered = renderCache.objectiveRendered
    EV.perf.worldObjectiveCellSize = renderCache.objectiveCellSize
  else
    EV.perf.worldObjectiveSource = 0
    EV.perf.worldObjectiveRendered = 0
    EV.perf.worldObjectiveCellSize = 0
  end

  for j = i, table.getn(pfMap.pins) do
    if pfMap.pins[j] then
      pfMap.pins[j]:Hide()
    end
  end

  EV.perf.worldNodeRendered = renderedNodes
  EV.perf.worldNodeSuppressed = suppressedNodes

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

  if EV:IsWorldMapShown() then
    EV.worldMapWasShown = true
    perf.miniMapHiddenSkips = (perf.miniMapHiddenSkips or 0) + 1
    return
  end

  if EV.worldMapWasShown then
    EV.worldMapWasShown = false
    EV:InvalidateMinimapPinVisuals("world-map-close")
    -- GetPlayerMapPosition is relative to the currently selected world-map
    -- surface. If the player closed a continent or another zone, restore the
    -- native current-zone context before sampling coordinates; otherwise
    -- continent UVs get mislabeled as Westfall and only a few wrong pins show.
    EV:PrimeHiddenPlayerMapContext("world-map-close")
    EV:ScheduleMinimapProjection(.08, "world-map-close")
    return
  end

  local interval = perf.miniInterval or perf.miniBaseInterval or .05
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

  -- The verified runtime probe kept a world-anchored marker glued by sampling
  -- the player every 0.05 seconds. Refresh the lightweight coordinate here;
  -- the slower driver tick remains responsible for full map-context recovery.
  EV:CaptureMinimapPlayerPosition()
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
  local cellSize = nodeCache.cellSize or 2.5
  if not Num(cellSize) or cellSize <= 0 then cellSize = 2.5 end
  local maxCell = math.floor(100 / cellSize)
  local maxDx = visibleRadius / math.abs(xDraw)
  local maxDy = visibleRadius / math.abs(yDraw)
  -- The floor-bounded rectangle already contains every cell intersecting the
  -- circle's axis-aligned bounds. The old extra one-cell border expanded a
  -- Westfall query from 29 visible pins to 211 candidates at 20 Hz.
  local minCx = math.floor((xPlayer - maxDx) / cellSize)
  local maxCx = math.floor((xPlayer + maxDx) / cellSize)
  local minCy = math.floor((yPlayer - maxDy) / cellSize)
  local maxCy = math.floor((yPlayer + maxDy) / cellSize)

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
            local visualKey = tostring(entry.key)
              .. "|" .. tostring(nodeCache.generation)
              .. "|" .. tostring(color)
              .. "|" .. tostring(pfQuest_config["cutoutminimap"])
              .. "|" .. tostring(pfQuest_config["showclustermini"])
              .. "|" .. tostring(pfQuest_config["showspawnmini"])

            -- UpdateNode rebuilds highlight tables, textures, colors, layers,
            -- scripts, and sizes. Those values are static while walking, so
            -- refresh them only when a pin is rebound or the cache/config
            -- generation changes. Movement then becomes cheap point math.
            if pin.qevVisualKey ~= visualKey or pin.qevNode ~= entry.node then
              pfMap:UpdateNode(pin, entry.node, color, "minimap", distance)
              pin.qevVisualKey = visualKey
              pin.qevNode = entry.node
            end
            pin.hl:Hide()

            if pfQuest_config["showclustermini"] == "0" and pin.cluster then
              pin:Hide()
            elseif pfQuest_config["showspawnmini"] == "0"
                and entry.addon == "PFQUEST"
                and not pin.texture then
              pin:Hide()
            else
              -- Suppress sub-pixel coordinate noise while stationary. Real
              -- movement still updates at the measured 20 Hz cadence.
              if not pin.qevX or not pin.qevY
                  or math.abs(pin.qevX - xPos) >= .20
                  or math.abs(pin.qevY - yPos) >= .20 then
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", pfMap.drawlayer, "CENTER", xPos, -yPos)
                pin.qevX = xPos
                pin.qevY = yPos
              end
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
    if pfMap.mpins[j] and pfMap.mpins[j]:IsShown() then
      pfMap.mpins[j]:Hide()
      pfMap.mpins[j].qevX = nil
      pfMap.mpins[j].qevY = nil
    end
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

function EV:GetActiveQuestNodeCoverage()
  local nodeQuestIDs = {}
  local addonNodes = pfMap and pfMap.nodes and pfMap.nodes["PFQUEST"] or nil
  if type(addonNodes) == "table" then
    for _, mapNodes in pairs(addonNodes) do
      if type(mapNodes) == "table" then
        for _, combinedNode in pairs(mapNodes) do
          if type(combinedNode) == "table" then
            for _, meta in pairs(combinedNode) do
              local questid = type(meta) == "table" and tonumber(meta.questid) or nil
              if questid then nodeQuestIDs[questid] = true end
            end
          end
        end
      end
    end
  end

  local active, covered, missing = 0, 0, {}
  if pfQuest and type(pfQuest.questlog) == "table" then
    for questid, data in pairs(pfQuest.questlog) do
      active = active + 1
      local numericID = tonumber(questid)
      if numericID and nodeQuestIDs[numericID] then
        covered = covered + 1
      else
        missing[table.getn(missing) + 1] = {
          id = numericID,
          key = questid,
          title = type(data) == "table" and data.title or tostring(questid),
          qlogid = type(data) == "table" and data.qlogid or nil,
          state = type(data) == "table" and data.state or nil,
        }
      end
    end
  end

  return active, covered, missing
end

EV.activeNodeAuditTried = EV.activeNodeAuditTried or {}
function EV:EnsureActiveQuestNodes(reason)
  if not self.questStateReady or not pfDatabase
      or type(pfDatabase.SearchQuestID) ~= "function" then return 0 end

  local _, coveredBefore, missing = self:GetActiveQuestNodeCoverage()
  local attempted = 0
  for _, item in pairs(missing) do
    if item.id and item.qlogid then
      local fingerprint = tostring(item.qlogid) .. "|" .. tostring(item.state)
      if self.activeNodeAuditTried[item.id] ~= fingerprint then
        self.activeNodeAuditTried[item.id] = fingerprint
        pcall(pfDatabase.SearchQuestID, pfDatabase, item.id, {
          ["addon"] = "PFQUEST",
          ["qlogid"] = item.qlogid,
        })
        attempted = attempted + 1
      end
    end
  end

  local _, coveredAfter = self:GetActiveQuestNodeCoverage()
  local repaired = math.max((coveredAfter or 0) - (coveredBefore or 0), 0)
  if repaired > 0 then
    self:NotifyQuestNodesChanged("active-audit:" .. tostring(reason or "unknown"))
  elseif attempted > 0 then
    self.activeNodeAuditUnresolved = (self.activeNodeAuditUnresolved or 0) + attempted
  end
  return repaired
end

function EV:Diagnostic()
  local mapID, mapName, cid, mid, mapInfo, viewKind = self:GetSelectedMapID()
  local p = self.player
  local entries, quests, snapshotComplete = 0, 0, true
  if self.GetQuestLogCounts then
    entries, quests, snapshotComplete = self:GetQuestLogCounts()
  elseif type(GetNumQuestLogEntries) == "function" then
    entries = tonumber(GetNumQuestLogEntries()) or 0
  end

  chat("v" .. tostring(self.version)
    .. " engine=" .. tostring(self.engine)
    .. " dbLocalized=" .. tostring(pfDatabase and pfDatabase.localized))

  local loc = self:RefreshLocationContext()
  local activeNodeQuests, coveredNodeQuests, missingNodeQuests =
    self:GetActiveQuestNodeCoverage()
  local missingTitles = {}
  for index = 1, math.min(table.getn(missingNodeQuests), 3) do
    missingTitles[index] = tostring(missingNodeQuests[index].title)
  end

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
    .. " probes=" .. tostring(self.mapContextProbeCount or 0)
    .. " reason=" .. tostring(self.mapContextPrimeLastReason))

  chat("quests=" .. tostring(quests)
    .. " entries=" .. tostring(entries)
    .. " selectedNodes=" .. tostring(self:CountNodesForMap(mapID))
    .. " currentNodes=" .. tostring(self:CountNodesForMap(p.mapID)))

  chat("questState ready=" .. tostring(self.questStateReady)
    .. " sync=" .. tostring(self.questSyncSource)
    .. " availability=" .. tostring(self.availableQuestMode)
    .. " historyAuthoritative=" .. tostring(self.questHistoryAuthoritative)
    .. " availableGivers=" .. tostring(self:CanRenderAvailableQuests())
    .. " clientConfirmed=" .. tostring(CountTable(pfQuest_confirmedAvailable))
    .. " logSnapshot=" .. tostring(snapshotComplete and "complete" or "collapsed")
    .. " cleanedTitles=" .. tostring(self.decoratedQuestTitleReads or 0)
    .. " completed=" .. tostring(self.questSyncCount)
    .. " history=" .. tostring(CountTable(pfQuest_history))
    .. " liveQuestlog=" .. tostring(pfQuest and CountTable(pfQuest.questlog) or 0))

  chat("activeNodes covered=" .. tostring(coveredNodeQuests)
    .. "/" .. tostring(activeNodeQuests)
    .. " missing=" .. tostring(table.concat(missingTitles, ", "))
    .. " unresolvedAudits=" .. tostring(self.activeNodeAuditUnresolved or 0))

  chat("render worldVisible=" .. tostring(VisibleCount(pfMap and pfMap.pins))
    .. " miniVisible=" .. tostring(VisibleCount(pfMap and pfMap.mpins))
    .. " minimapPolicy=" .. tostring(self.minimapPolicy)
    .. " env=" .. tostring(self.minimapEnvironment)
    .. "/" .. tostring(self.minimapEnvironmentSource)
    .. " playerMarker=" .. tostring(self.playerMarker and self.playerMarker:IsShown())
    .. " nativeArrowHidden=" .. tostring(self.nativeWorldArrowsHidden)
    .. " visualResets=" .. tostring(self.minimapVisualResetCount or 0)
    .. "/" .. tostring(self.minimapVisualResetReason or "none"))

  local perf = self.perf or {}
  chat("perf miniRuns=" .. tostring(perf.miniRuns or 0)
    .. " skips=" .. tostring(perf.miniSkips or 0)
    .. " mapHiddenSkips=" .. tostring(perf.miniMapHiddenSkips or 0)
    .. " interval=" .. tostring(perf.miniInterval or 0)
    .. " fps=" .. tostring(perf.fpsNow or 0)
    .. " fpsAvg=" .. tostring(perf.fpsAvg or 0)
    .. " fpsMin=" .. tostring(perf.fpsMin or 0)
    .. " fpsReset=" .. tostring(perf.fpsResetReason or "startup"))

  chat("perf cacheNodes=" .. tostring(perf.miniCachedNodes or 0)
    .. " candidates=" .. tostring(perf.miniCandidates or 0)
    .. " cacheBuilds=" .. tostring(perf.miniCacheBuilds or 0)
    .. " generation=" .. tostring(perf.miniCacheGeneration or 0)
    .. " cacheReason=" .. tostring(perf.miniLastCacheReason)
    .. " worldRuns=" .. tostring(perf.worldRuns or 0)
    .. " worldSkips=" .. tostring(perf.worldSkips or 0)
    .. " worldDense=" .. tostring(perf.worldDenseMode)
    .. " worldNodes=" .. tostring(perf.worldNodeRendered or 0)
    .. "/" .. tostring(perf.worldNodeTotal or 0)
    .. " suppressed=" .. tostring(perf.worldNodeSuppressed or 0)
    .. " objectives=" .. tostring(perf.worldObjectiveRendered or 0)
    .. "/" .. tostring(perf.worldObjectiveSource or 0)
    .. " grid=" .. tostring(perf.worldObjectiveCellSize or 0))

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
  msg = string.gsub(msg, "^/koquest%s*", "")
  msg = string.gsub(msg, "^koquest%s*", "")

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
    chat("commands: /koquest | /koquest force | /koquest sync | /koquest map (legacy: /qev)")
  end
end

SLASH_QUESTIEEV1 = "/qev"
SLASH_QUESTIEEV2 = "/koquest"
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
  local okQuestDetail = pcall(driver.RegisterEvent, driver, "QUEST_DETAIL")
  EV.questDetailEventRegistered = okQuestDetail and true or false
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
    EV.mapContextProbe = nil
    EV.minimapProjectionAt = nil
    EV.location = {}
    EV.mapContextBootstrapAttempted = false
    EV.mapContextProbeAttempted = false
    EV.mapContextProbe = nil
    EV.mapContextProbeCount = 0
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
    EV.mapContextBootstrapAttempted = false
    EV.mapContextProbeAttempted = false
    EV.mapContextProbe = nil
    EV.mapContextProbeCount = 0
    EV:MarkMinimapNodeCacheDirty("player-entering-world")
    EV.worldMapForceNext = true
    EV.renderPrimeRequested = true
    EV.mapContextPrimeAt = EV.startupReadyAt + 1.0
    chat("character entered world; stable-core map startup begins in 4 seconds.")
    return
  end

  if not EV.inWorld then return end

  if event == "QUEST_DETAIL" then
    -- GetTitleText is the documented, unprotected quest-packet getter. Never
    -- call protected nearest-interaction helpers from addon Lua: build 2286 can
    -- terminate the UE process instead of returning a recoverable Lua error.
    local title = nil
    if type(GetTitleText) == "function" then
      local ok, value = pcall(GetTitleText)
      if ok and type(value) == "string" and value ~= "" then title = value end
    end
    if title and EV.ConfirmAvailableQuestTitle then
      EV:ConfirmAvailableQuestTitle(title, "QUEST_DETAIL")
    end
    return
  end

  -- Large-area changes can happen around Hearthstones/instances. Clear the
  -- cached position and let Emberveil establish its own map context naturally.
  if event == "ZONE_CHANGED_NEW_AREA" then
    EV.mapRuntimeReady = false
    EV.mapRuntimeReadyAt = GetTime() + 1.50
    EV:InvalidatePlayerPosition(true, "new-area")
    EV.location = {}
    EV.mapContextBootstrapAttempted = false
    EV.mapContextProbeAttempted = false
    EV.mapContextProbe = nil
    EV.mapContextProbeCount = 0
    this.captureAt = EV.mapRuntimeReadyAt
    EV:MarkMinimapNodeCacheDirty("zone-changed-new-area")
    EV.worldMapForceNext = true
    EV.renderPrimeRequested = true
    EV.mapContextPrimeAt = EV.mapRuntimeReadyAt + .50
    return
  end

  if event == "ZONE_CHANGED" then
    EV.minimapOutdoorEventCount = (EV.minimapOutdoorEventCount or 0) + 1
    EV:SetMinimapEnvironment(1, "ZONE_CHANGED", false)
    EV:RefreshLocationContext(true)
    EV:ScheduleMinimapProjection(.08, "ZONE_CHANGED")
    this.captureAt = GetTime() + .10
    return
  end

  if event == "ZONE_CHANGED_INDOORS" then
    EV.minimapIndoorEventCount = (EV.minimapIndoorEventCount or 0) + 1
    -- This event name is not an indoor-scale oracle on Emberveil. Sentinel
    -- Tower fires it outdoors; forcing the indoor span there makes pins drift.
    EV:SetMinimapEnvironment(1, "ZONE_CHANGED_INDOORS", false)
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

    if not EV.mapContextPrimeBusy
        and not EV.mapContextProbe
        and not EV:IsWorldMapShown() then
      EV.mapContextPrimeAt = GetTime() + .20
    end
    return
  end

  if event == "QUEST_LOG_UPDATE"
      or event == "QUEST_WATCH_UPDATE"
      or event == "QUEST_FINISHED" then
    -- Ask pfQuest to reconcile the quest log immediately. Cache invalidation is
    -- intentionally deferred until the node transaction completes; otherwise
    -- the minimap can rebuild a stale cache before NEW objectives are inserted.
    if pfQuest then pfQuest.updateQuestLog = true end
    EV.worldMapForceNext = true
    EV.minimapForceNext = true

    -- Fallback only. Normal NEW/RELOAD/REMOVE processing calls
    -- NotifyQuestNodesChanged() and schedules a ~10 ms render after mutation.
    local fallback = GetTime() + .18
    if not EV.questRenderNudgeAt or fallback < EV.questRenderNudgeAt then
      EV.questRenderNudgeAt = fallback
    end
    return
  end

  this.captureAt = GetTime() + .25
end)

driver:SetScript("OnUpdate", function()
  if not EV.inWorld then return end

  local now = GetTime()

  if EV.mapRuntimeReadyAt and now < EV.mapRuntimeReadyAt then
    return
  elseif EV.mapRuntimeReadyAt then
    EV.mapRuntimeReadyAt = nil
    EV.mapRuntimeReady = true
  end

  if EV.startupReadyAt and now < EV.startupReadyAt then return end
  if EV.startupReadyAt then EV.startupReadyAt = nil end

  EV:SampleFramerate(now)

  if EV.mapContextProbe
      and now >= (EV.mapContextProbe.nextAt or 0) then
    EV:ProcessHiddenZoneProbe(2)
  end

  -- Quest node changes are rare and user-visible, so service their coalesced
  -- render deadline before the 200 ms maintenance throttle. This adds only a
  -- timestamp comparison to normal frames, while accepted quests can appear on
  -- the minimap/world map on the next frame after SearchQuestID finishes.
  if EV.questRenderNudgeAt and now >= EV.questRenderNudgeAt then
    EV.questRenderNudgeAt = nil

    if pfMap then
      pfMap.queue_update = now
      if pfMap.UpdateMinimap then pfMap:UpdateMinimap() end
      if EV:IsWorldMapShown() and pfMap.UpdateNodes then pfMap:UpdateNodes() end
    end
  end

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
