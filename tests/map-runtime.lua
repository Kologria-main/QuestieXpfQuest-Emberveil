-- Executes the real pfMap mutators and Emberveil cache/selection helpers against
-- a minimal WoW frame mock. This file is development-only and is never loaded
-- by the game client.

getfenv = function() return _G end
table.getn = table.getn or function(value) return #value end
unpack = unpack or table.unpack
min = math.min
max = math.max
abs = math.abs
sqrt = math.sqrt
strfind = string.find
strsub = string.sub
getglobal = function(name) return _G[name] end

local now = 0
function GetTime() return now end
function time() return math.floor(now) end
function GetFramerate() return 60 end
function GetNumAddOns() return 0 end
function GetAddOnInfo() return nil end
function GetCurrentMapContinent() return 1 end
function GetCurrentMapZone() return 1 end
function GetMapInfo() return "ZoneA" end
function GetMapContinents() return "ContinentA", "ContinentB" end
function GetMapZones(cid)
  if cid == 1 then return "Zone A", "Zone B" end
  return "Zone C", "Zone D"
end
function GetRealZoneText() return "Zone A" end
function GetZoneText() return "Zone A" end
function GetSubZoneText() return "" end
function GetMinimapZoneText() return "Zone A" end
function IsInInstance() return false, "none" end
function GetPlayerMapPosition() return .5, .5 end
function SetMapToCurrentZone() end
function SetMapZoom() end
function ToggleWorldMap() end
function GetQuestLogSelection() return 1 end
function GetQuestLogTitle() return "Test Quest" end
function IsShiftKeyDown() return false end
function UnitLevel() return 10 end

QuestieEV_SafeGetPlayerMapPosition = function() return .5, .5 end
QuestieEV_SafeSetMapToCurrentZone = function() end
QuestieEV_MouseIsOverDisabled = function() return false end

local frames = {}
local frameMethods = {}

local function NewFrame(name, parent)
  local frame = {
    name = name,
    parent = parent,
    scripts = {},
    shown = false,
    width = 200,
    height = 200,
    alpha = 1,
    zoom = 0,
  }

  setmetatable(frame, {
    __index = function(_, key)
      return frameMethods[key] or function() end
    end,
  })

  if name then
    frames[name] = frame
    _G[name] = frame
  end
  return frame
end

function frameMethods:RegisterEvent() end
function frameMethods:UnregisterAllEvents() end
function frameMethods:SetScript(kind, callback) self.scripts[kind] = callback end
function frameMethods:GetScript(kind) return self.scripts[kind] end
function frameMethods:CreateTexture(name) return NewFrame(name, self) end
function frameMethods:SetWidth(value) self.width = value end
function frameMethods:SetHeight(value) self.height = value end
function frameMethods:GetWidth() return self.width end
function frameMethods:GetHeight() return self.height end
function frameMethods:SetAlpha(value) self.alpha = value end
function frameMethods:GetAlpha() return self.alpha end
function frameMethods:SetTexture(value) self.texture = value end
function frameMethods:GetTexture() return self.texture end
function frameMethods:GetZoom() return self.zoom end
function frameMethods:GetName() return self.name end
function frameMethods:GetParent() return self.parent end
function frameMethods:Show() self.shown = true end
function frameMethods:Hide() self.shown = false end
function frameMethods:IsShown() return self.shown end

function CreateFrame(_, name, parent)
  return NewFrame(name, parent)
end

UIParent = NewFrame("UIParent")
WorldFrame = NewFrame("WorldFrame")
WorldMapFrame = NewFrame("WorldMapFrame")
WorldMapFrame.shown = true
WorldMapButton = NewFrame("WorldMapButton", WorldMapFrame)
WorldMapTooltip = NewFrame("WorldMapTooltip")
WorldMapPOIFrame = NewFrame("WorldMapPOIFrame")
WorldMapBlobFrame = NewFrame("WorldMapBlobFrame")
Minimap = NewFrame("Minimap")
GameTooltip = NewFrame("GameTooltip")

WorldMapQuestFrame_OnMouseUp = function() end
WorldMapFrame_ClearQuestPOIs = function() end
SlashCmdList = {}
UNKNOWN = "Unknown"
QuestieEV = { version = "test" }

pfQuestCompat = {
  client = 11200,
  mod = function(left, right) return left % right end,
}
pfQuestConfig = { path = "Interface\\AddOns\\pfQuest" }
pfQuest_colors = {}
pfQuest_config = {
  spawncolors = "0",
  minimapnodes = "1",
  showcluster = "1",
  showspawn = "1",
  showclustermini = "1",
  showspawnmini = "1",
  worldmaptransp = "1",
  minimaptransp = "1",
  cutoutworldmap = "0",
  cutoutminimap = "0",
  routecluster = "0",
  routeender = "0",
  routestarter = "0",
}
pfQuest_Loc = setmetatable({}, { __index = function(_, key) return key end })
pfQuest_history = {}
pfQuest = {
  icons = {},
  Debug = function() end,
  tracker = { Reset = function() end, ButtonAdd = function() end },
  route = { Reset = function() end },
}
pfDB = {
  minimap = {
    [1] = { 1000, 1000 },
    [2] = { 1000, 1000 },
  },
  zones = { loc = { [1] = "Zone A", [2] = "Zone B" } },
}
pfDatabase = {
  BuildQuestDescription = function() return "description" end,
}

local function AssertEqual(actual, expected, name)
  if actual ~= expected then
    error(name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

local function AssertTrue(value, name)
  if not value then error(name .. ": expected true", 2) end
end

local function AssertNear(actual, expected, name)
  if math.abs(actual - expected) > .000001 then
    error(name .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
  end
end

dofile("addon/pfQuest/map.lua")
local inheritedMapOnEvent = pfMap:GetScript("OnEvent")
dofile("addon/pfQuest/emberveil_map.lua")

local EV = QuestieEV
EV.questStateReady = true
EV.mapRuntimeReady = true
EV.inWorld = true

local function NodeMeta(title, x, y, item, addon)
  return {
    addon = addon or "PFDB",
    zone = 1,
    title = title,
    spawn = title .. " Spawn",
    spawnid = title,
    spawntype = "Unit",
    x = x,
    y = y,
    item = item,
  }
end

-- Structural mutations own cache invalidation. Duplicate no-ops do not advance
-- the revision, while an item-list mutation does.
pfMap:AddNode(NodeMeta("Node A", 10, 20, "Item 1"))
AssertEqual(pfMap.nodeRevision, 1, "first add advances node revision")

local cache1 = EV:GetMinimapNodeCache(1)
local generation1 = cache1.generation
local entries1 = cache1.entries
AssertEqual(table.getn(entries1), 1, "first cache contains added node")

local world1 = EV:GetWorldRenderEntries(1, false, cache1)
AssertEqual(table.getn(world1.entries), 1, "first world cache contains added node")

pfMap:AddNode(NodeMeta("Node A", 10, 20, "Item 1"))
AssertEqual(pfMap.nodeRevision, 1, "duplicate add preserves node revision")
AssertEqual(EV:GetMinimapNodeCache(1).generation, generation1,
  "duplicate add reuses cache generation")

pfMap:AddNode(NodeMeta("Node A", 10, 20, "Item 2"))
AssertEqual(pfMap.nodeRevision, 2, "item mutation advances node revision")
local cache2 = EV:GetMinimapNodeCache(1)
AssertEqual(cache2.generation, generation1 + 1, "item mutation rebuilds cache")
AssertTrue(cache2.entries ~= entries1, "cache rebuild replaces entries table")

pfMap:AddNode(NodeMeta("Node B", 30, 40, nil))
AssertEqual(pfMap.nodeRevision, 3, "second add advances node revision")
local cache3 = EV:GetMinimapNodeCache(1)
local world3 = EV:GetWorldRenderEntries(1, false, cache3)
AssertEqual(table.getn(world3.entries), 2, "same-map add reaches world cache")
AssertTrue(world3 ~= world1, "same-map add replaces world cache")

pfMap:DeleteNode("PFDB", "Node B")
AssertEqual(pfMap.nodeRevision, 4, "delete advances node revision")
local cache4 = EV:GetMinimapNodeCache(1)
local world4 = EV:GetWorldRenderEntries(1, false, cache4)
AssertEqual(table.getn(world4.entries), 1, "same-map delete leaves no stale world node")

pfMap:DeleteNode("PFDB", "Missing Node")
AssertEqual(pfMap.nodeRevision, 4, "missing delete preserves node revision")

-- Exercise dense compaction after one explicit structural revision. Every
-- rendered coordinate must remain a real source coordinate.
pfMap.nodes.PFQUEST = { [1] = {} }
local sourceCoordinates = {}
for index = 1, 500 do
  local x = ((index - 1) % 25) * 4 + 1
  local y = math.floor((index - 1) / 25) * 4 + 1
  local coords = tostring(x) .. "|" .. tostring(y)
  sourceCoordinates[coords] = true
  pfMap.nodes.PFQUEST[1][coords] = {
    ["Dense Objective"] = NodeMeta("Dense Objective", x, y, "Quest Item", "PFQUEST"),
  }
end
pfMap:MarkNodesChanged("test-dense-load")
local denseCache = EV:GetMinimapNodeCache(1)
local denseWorld = EV:GetWorldRenderEntries(1, true, denseCache)
AssertEqual(denseWorld.objectiveSource, 500, "dense source count")
AssertTrue(denseWorld.objectiveRendered <= 319, "dense objective budget")
AssertTrue(denseWorld.objectiveCellSize > 0, "dense grid selected")
for _, entry in ipairs(denseWorld.entries) do
  if entry.addon == "PFQUEST" then
    AssertTrue(sourceCoordinates[tostring(entry.x) .. "|" .. tostring(entry.y)],
      "dense entry uses source coordinate")
  end
end

-- A successful-but-empty zone-list response is transitional in Emberveil and
-- must not poison the continent cache for the rest of the session.
local inheritedGetMapZones = GetMapZones
local zoneListCalls = 0
GetMapZones = function(cid)
  zoneListCalls = zoneListCalls + 1
  if zoneListCalls == 1 then return end
  return inheritedGetMapZones(cid)
end
EV.mapZoneCache = {}
EV:GetSelectedMapID()
AssertEqual(EV.mapZoneCache[1], nil, "empty zone list is not cached")
EV:GetSelectedMapID()
AssertTrue(type(EV.mapZoneCache[1]) == "table", "settled zone list is cached")
GetMapZones = inheritedGetMapZones

-- A world-map render must wait for the Unreal-backed map button to have layout
-- and must not commit the selected key until pins were actually positioned.
pfMap.nodes = {}
pfMap:MarkNodesChanged("test-layout-clear")
EV.lastSelectedKey = nil
EV.worldMapNextAt = nil
EV.worldMapRefreshAt = nil
WorldMapButton.width = 0
WorldMapButton.height = 0
now = .001
AssertEqual(EV:RefreshWorldMapSelection(true, true), false,
  "zero-size world map defers render")
AssertEqual(EV.lastSelectedKey, nil, "deferred render does not commit selection")
AssertTrue(EV.worldMapRefreshAt ~= nil, "zero-size world map schedules retry")
local layoutRetryAt = EV.worldMapRefreshAt
WorldMapButton.width = 200
WorldMapButton.height = 200
now = layoutRetryAt + .001
AssertTrue(EV:ServiceWorldMapRefresh(now),
  "layout retry renders after map button settles")
AssertEqual(EV.lastSelectedKey, EV:GetWorldMapSelectionKey(),
  "successful layout retry commits selection")

-- Replace the expensive renderer with a throttle-aware spy to isolate final
-- selection scheduling while preserving the production 80 ms rejection rule.
local selection = { mapID = 1, name = "Zone A", cid = 1, mid = 1, info = "ZoneA" }
function EV:GetSelectedMapID()
  return selection.mapID, selection.name, selection.cid, selection.mid,
    selection.info, selection.mapID and "zone" or "continent"
end

local renders = {}
local rejected = 0
function pfMap:UpdateNodes()
  if not EV.worldMapForceNext and EV.worldMapNextAt and now < EV.worldMapNextAt then
    rejected = rejected + 1
    return false
  end
  EV.worldMapForceNext = false
  EV.worldMapNextAt = now + .08
  renders[table.getn(renders) + 1] = EV:GetWorldMapSelectionKey()
  return true
end

EV.worldMapNextAt = nil
EV.lastSelectedKey = nil
AssertTrue(EV:RefreshWorldMapSelection(false, true), "initial selection renders")
local keyA = EV:GetWorldMapSelectionKey()
AssertEqual(EV.lastSelectedKey, keyA, "initial key committed after render")

-- A -> continent -> A completes inside the active throttle. The pending event
-- still forces one final A render even though the final key equals the old key.
now = .01
selection = { mapID = nil, name = nil, cid = 1, mid = 0, info = "ContinentA" }
EV:RequestWorldMapRefresh(.05, "to-continent")
now = .02
selection = { mapID = 1, name = "Zone A", cid = 1, mid = 1, info = "ZoneA" }
EV:RequestWorldMapRefresh(.05, "back-to-a")
AssertNear(EV.worldMapRefreshAt, .07, "event burst keeps trailing deadline")
AssertEqual(EV:ServiceWorldMapRefresh(.069), false, "refresh waits for deadline")
AssertTrue(EV:ServiceWorldMapRefresh(.071), "same-key final selection renders")
AssertEqual(renders[table.getn(renders)], keyA, "same-key burst finishes on zone A")
AssertEqual(rejected, 0, "forced final render bypasses throttle")

-- The polling fallback also forces a changed key through an active throttle.
now = .07
selection = { mapID = 2, name = "Zone B", cid = 1, mid = 2, info = "ZoneB" }
AssertTrue(EV:RefreshWorldMapSelection(false, true), "changed-key fallback renders")
local keyB = EV:GetWorldMapSelectionKey()
AssertEqual(EV.lastSelectedKey, keyB, "changed key committed after render")
AssertEqual(renders[table.getn(renders)], keyB, "changed-key fallback finishes on B")
AssertEqual(rejected, 0, "changed-key fallback bypasses throttle")

-- Multiple native events coalesce into one render.
local beforeBurst = table.getn(renders)
now = .08
EV:RequestWorldMapRefresh(.05, "burst-1")
now = .09
EV:RequestWorldMapRefresh(.05, "burst-2")
now = .10
EV:RequestWorldMapRefresh(.05, "burst-3")
AssertEqual(EV:ServiceWorldMapRefresh(.131), false, "burst waits for trailing edge")
AssertTrue(EV:ServiceWorldMapRefresh(.151), "coalesced burst renders")
AssertEqual(table.getn(renders), beforeBurst + 1, "event burst renders once")
AssertEqual(EV:ServiceWorldMapRefresh(.20), false, "serviced burst has no retry")

-- Hidden-map service does no world work and clears the key so reopening the
-- same map is detected by the polling fallback.
WorldMapFrame.shown = false
now = .21
EV:RequestWorldMapRefresh(.05, "hidden")
local beforeHidden = table.getn(renders)
AssertEqual(EV:ServiceWorldMapRefresh(.261), false, "hidden map skips render")
AssertEqual(table.getn(renders), beforeHidden, "hidden map performs no world work")
AssertEqual(EV.lastSelectedKey, nil, "hidden map clears committed key")
WorldMapFrame.shown = true
now = .27
AssertTrue(EV:RefreshWorldMapSelection(false, true), "same map redraws after reopen")

-- The inherited map event must render immediately even inside the active 80 ms
-- throttle, then leave one trailing retry for the final native selection.
EV.worldMapRefreshAt = nil
EV.lastSelectedKey = EV:GetWorldMapSelectionKey()
local beforeEvent = table.getn(renders)
now = .30
event = "WORLD_MAP_UPDATE"
this = pfMap
inheritedMapOnEvent()
AssertEqual(table.getn(renders), beforeEvent + 1,
  "pfMap event immediately renders current selection")
AssertEqual(renders[table.getn(renders)], EV:GetWorldMapSelectionKey(),
  "immediate event render uses current selection")
now = .31
inheritedMapOnEvent()
AssertEqual(table.getn(renders), beforeEvent + 1,
  "immediate event burst is bounded for low-end hardware")
AssertNear(EV.worldMapRefreshAt, .43, "pfMap event schedules trailing refresh")

print("PASS: map cache, layout deferral, immediate refresh, and rapid selection scenarios passed.")
