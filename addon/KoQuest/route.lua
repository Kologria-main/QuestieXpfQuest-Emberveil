-- table.getn doesn't return sizes on tables that
-- are using a named index on which setn is not updated
local function tablesize(tbl)
  local count = 0
  for _ in pairs(tbl) do count = count + 1 end
  return count
end

function modulo(val, by)
  return val - math.floor(val/by)*by;
end

local function GetNearest(xstart, ystart, db, blacklist)
  local nearest = nil
  local best = nil

  for id, data in pairs(db) do
    if data[1] and data[2] and not blacklist[id] then
      local x,y = xstart - data[1], ystart - data[2]
      local distance = ceil(math.sqrt(x*x+y*y)*100)/100

      if not nearest or distance < nearest then
        nearest = distance
        best = id
      end
    end
  end

  if not best then return end

  blacklist[best] = true
  return db[best]
end

-- connection between objectives
local objectivepath = {}

-- connection between player and the first objective
local playerpath = {} -- worldmap
local mplayerpath = {} -- minimap

local function ClearPath(path)
  for id, tex in pairs(path) do
    tex.enable = nil
    tex:Hide()
  end
end

local function DrawLine(path,x,y,nx,ny,hl,minimap)
  local display = true
  local zoom = 1

  -- calculate minimap variables
  local xplayer, yplayer, xdraw, ydraw
  if minimap then
    -- player coords
    xplayer, yplayer = KoQuestEV_SafeGetPlayerMapPosition("player")
    xplayer, yplayer = xplayer * 100, yplayer * 100

    -- query minimap zoom/size data
    local mZoom = KoMap.drawlayer:GetZoom()
    local mapID = KoMap:GetMapIDByName(GetRealZoneText())
    local mapZoom = KoMap.minimap_zoom[KoMap.minimap_indoor()][mZoom]
    local mapWidth = KoMap.minimap_sizes[mapID] and KoMap.minimap_sizes[mapID][1] or 0
    local mapHeight = KoMap.minimap_sizes[mapID] and KoMap.minimap_sizes[mapID][2] or 0

    -- calculate drawlayer size
    xdraw = KoMap.drawlayer:GetWidth() / (mapZoom / mapWidth) / 100
    ydraw = KoMap.drawlayer:GetHeight() / (mapZoom / mapHeight) / 100
    zoom = (((mapZoom / mapWidth))+((mapZoom / mapHeight))) * 3
  end

  -- general
  local dx, dy = x - nx, y - ny
  local dots = ceil(math.sqrt(dx*1.5*dx*1.5+dy*dy)) / zoom

  for i=(minimap and 1 or 2), dots-(minimap and 1 or 2) do
    local xpos = nx + dx/dots*i
    local ypos = ny + dy/dots*i

    if minimap then
      -- adjust values to minimap
      xpos = ( xplayer - xpos ) * xdraw
      ypos = ( yplayer - ypos ) * ydraw

      -- check if dot should be visible
      if pfUI.minimap then
        display = ( abs(xpos) + 1 < KoMap.drawlayer:GetWidth() / 2 and abs(ypos) + 1 < KoMap.drawlayer:GetHeight()/2 ) and true or nil
      else
        local distance = sqrt(xpos * xpos + ypos * ypos)
        display = ( distance + 1 < KoMap.drawlayer:GetWidth() / 2 ) and true or nil
      end
    else
      -- adjust values to worldmap
      xpos = xpos / 100 * WorldMapButton:GetWidth()
      ypos = ypos / 100 * WorldMapButton:GetHeight()
    end

    if display then
      local nline = tablesize(path) + 1
      for id, tex in pairs(path) do
        if not tex.enable then nline = id break end
      end

      path[nline] = path[nline] or (minimap and KoMap.drawlayer or WorldMapButton.routes):CreateTexture(nil, "OVERLAY")
      path[nline]:SetWidth(4)
      path[nline]:SetHeight(4)
      path[nline]:SetTexture(KoQuestConfig.path.."\\img\\route")
      if hl and minimap then
        path[nline]:SetVertexColor(.6,.4,.2,.5)
      elseif hl then
        path[nline]:SetVertexColor(1,.8,.4,1)
      else
        path[nline]:SetVertexColor(.6,.4,.2,1)
      end

      path[nline]:ClearAllPoints()

      if minimap then -- draw minimap
        path[nline]:SetPoint("CENTER", KoMap.drawlayer, "CENTER", -xpos, ypos)
      else -- draw worldmap
        path[nline]:SetPoint("CENTER", WorldMapButton, "TOPLEFT", xpos, -ypos)
      end

      path[nline]:Show()
      path[nline].enable = true
    end
  end
end

KoQuest.route = CreateFrame("Frame", "KoQuestRoute", WorldFrame)
KoQuest.route.firstnode = nil
KoQuest.route.coords = {}

KoQuest.route.Reset = function(self)
  self.coords = {}
  self.firstnode = nil
end

KoQuest.route.AddPoint = function(self, tbl)
  table.insert(self.coords, tbl)
  self.firstnode = nil
end

local targetTitle, targetCluster, targetLayer, targetTexture = nil, nil, nil, nil
KoQuest.route.SetTarget = function(node, default)
  if node and ( node.title ~= targetTitle
    or node.cluster ~= targetCluster
    or node.layer ~= targetLayer
    or node.texture ~= targetTexture )
  then
    KoMap.queue_update = true
  end

  targetTitle = node and node.title or nil
  targetCluster = node and node.cluster or nil
  targetLayer = node and node.layer or nil
  targetTexture = node and node.texture or nil
end

KoQuest.route.IsTarget = function(node)
  if node then
    if targetTitle and targetTitle == node.title
      and targetCluster == node.cluster
      and targetLayer == node.layer
      and targetTexture == node.texture
    then
      return true
    end
  end
  return nil
end

local lastpos, completed = 0, 0
local function sortfunc(a,b) return a[4] < b[4] end
KoQuest.route:SetScript("OnUpdate", function()
  -- Route math used to call GetPlayerMapPosition() on every rendered frame and
  -- only throttle afterwards. On high-refresh clients that meant 120-240+
  -- bridge calls per second even though route output itself was capped at 20 Hz.
  -- Put the cap before the bridge call and do no player-position work at all
  -- when there are no route nodes.
  local now = GetTime()
  if (this.qevNextUpdate or 0) > now then return end
  this.qevNextUpdate = now + .05

  if not this.coords[1] then
    if this.qevHadRoute then
      ClearPath(objectivepath)
      ClearPath(playerpath)
      ClearPath(mplayerpath)
      if this.arrow and this.arrow.IsShown and this.arrow:IsShown() then
        this.arrow:Hide()
      end
      this.qevHadRoute = nil
    end
    return
  end
  this.qevHadRoute = true

  -- Do not calculate/repaint world-map route lines while the world map is
  -- closed. The old code kept sorting route points and redrawing the
  -- player-to-objective path during normal gameplay even though those textures
  -- were invisible. Keep working only when a visible consumer needs it: the
  -- world-map route, minimap route, or navigation arrow.
  local worldMapShown = WorldMapFrame and WorldMapFrame.IsShown and WorldMapFrame:IsShown()
  local worldRouteVisible = worldMapShown and KoQuest_config["routes"] ~= "0"
  local minimapRouteVisible = KoQuest_config["routeminimap"] == "1"
  local arrowVisible = KoQuest_config["arrow"] == "1"
  if not worldRouteVisible and not minimapRouteVisible and not arrowVisible then
    if not this.qevInactiveCleared then
      ClearPath(objectivepath)
      ClearPath(playerpath)
      ClearPath(mplayerpath)
      -- Force a fresh route draw if the world map is opened later.
      this.firstnode = nil
      this.qevInactiveCleared = true
    end
    return
  end
  this.qevInactiveCleared = nil

  local xplayer, yplayer = KoQuestEV_SafeGetPlayerMapPosition("player")
  local wrongmap = xplayer == 0 and yplayer == 0 and true or nil
  local curpos = xplayer + yplayer

  -- Recalculate stationary routes at most once per second. Movement is already
  -- capped above at 20 Hz, which is more than enough for route positioning.
  if ( this.tick or 5) > now and lastpos == curpos then return else this.tick = now + 1 end

  -- save current position
  lastpos = curpos

  -- update distances to player
  for id, data in pairs(this.coords) do
    if data[1] and data[2] then
      local x, y = (xplayer*100 - data[1])*1.5, yplayer*100 - data[2]
      this.coords[id][4] = ceil(math.sqrt(x*x+y*y)*100)/100
    end
  end

  -- sort all coords by distance only once per second
  if not this.recalculate or this.recalculate < now then
    table.sort(this.coords, sortfunc)

    -- order list on custom targets
    if targetTitle and this.coords[1] and not KoQuest.route.IsTarget(this.coords[1][3]) then
      local target = nil

      -- check for the old index of the target
      for id, data in pairs(this.coords) do
        if KoQuest.route.IsTarget(data[3]) then
          target = id
          break
        end
      end

      -- rearrange coordinates
      if target then
        local tmp = {}
        table.insert(tmp, this.coords[target])

        for id, data in pairs(this.coords) do
          if id ~= target then
            table.insert(tmp, this.coords[id])
          end
        end

        this.coords = tmp
      end
    end

    this.recalculate = now + 1
  end

  -- show arrow when route exists and is stable
  if not wrongmap and this.coords[1] and this.coords[1][4] and not this.arrow:IsShown() and KoQuest_config["arrow"] == "1" and GetTime() > completed + 1 then
    this.arrow:Show()
  end

  -- abort without any nodes or distances
  if not this.coords[1] or not this.coords[1][4] or KoQuest_config["routes"] == "0" then
    ClearPath(objectivepath)
    ClearPath(playerpath)
    ClearPath(mplayerpath)
    return
  end

  -- check first node for changes
  if this.firstnode ~= tostring(this.coords[1][1]..this.coords[1][2]) then
    this.firstnode = tostring(this.coords[1][1]..this.coords[1][2])

    -- recalculate objective paths
    local route = { [1] = this.coords[1] }
    local blacklist = { [1] = true }
    for i=2, table.getn(this.coords) do
      if route[i-1] then -- make sure the route was not blacklisted
        route[i] = GetNearest(route[i-1][1],route[i-1][2],this.coords, blacklist)
      end

      -- remove other item requirement gameobjects of same type from route
      if route[i] and route[i][3] and route[i][3].itemreq then
        for id, data in pairs(this.coords) do
          if not blacklist[id] and data[1] and data[2] and data[3]
            and data[3].itemreq and data[3].itemreq == route[i][3].itemreq
          then
            blacklist[id] = true
          end
        end
      end
    end

    ClearPath(objectivepath)
    for i, data in pairs(route) do
      if i > 1 then
        DrawLine(objectivepath, route[i-1][1],route[i-1][2],route[i][1],route[i][2])
      end
    end

    -- route calculation timestamp
    completed = GetTime()
  end

  if wrongmap then
    -- hide player-to-object path
    ClearPath(playerpath)
    ClearPath(mplayerpath)
  else
    -- draw player-to-object path
    ClearPath(playerpath)
    ClearPath(mplayerpath)
    DrawLine(playerpath,xplayer*100,yplayer*100,this.coords[1][1],this.coords[1][2],true)

    -- also draw minimap path if enabled
    if KoQuest_config["routeminimap"] == "1" then
      DrawLine(mplayerpath,xplayer*100,yplayer*100,this.coords[1][1],this.coords[1][2],true,true)
    end
  end
end)

KoQuest.route.drawlayer = CreateFrame("Frame", "KoQuestRouteDrawLayer", WorldMapButton)
KoQuest.route.drawlayer:SetFrameLevel(113)
KoQuest.route.drawlayer:SetAllPoints()

WorldMapButton.routes = CreateFrame("Frame", "KoQuestRouteDisplay", KoQuest.route.drawlayer)
WorldMapButton.routes:SetAllPoints()

KoQuest.route.arrow = CreateFrame("Frame", "KoQuestRouteArrow", UIParent)
KoQuest.route.arrow:SetPoint("CENTER", 0, -100)
KoQuest.route.arrow:SetWidth(48)
KoQuest.route.arrow:SetHeight(36)
KoQuest.route.arrow:SetClampedToScreen(true)
KoQuest.route.arrow:SetMovable(true)
KoQuest.route.arrow:EnableMouse(true)
KoQuest.route.arrow:RegisterForDrag('LeftButton')
KoQuest.route.arrow:SetScript("OnDragStart", function()
  if IsShiftKeyDown() then
    this:StartMoving()
  end
end)

KoQuest.route.arrow:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
end)

local invalid, lasttarget
local xplayer, yplayer, wrongmap, wrongmap
local xDelta, yDelta, dir, angle
local player, perc, column, row, xstart, ystart, xend, yend
local area, alpha, texalpha, color
local defcolor = "|cffffcc00"
local r, g, b

KoQuest.route.arrow:SetScript("OnUpdate", function()
  -- High-refresh displays do not need arrow texture/trigonometry at the full
  -- render rate. Cap this visual-only work to roughly 60 Hz; on <=60 FPS
  -- clients this does not reduce responsiveness at all.
  local now = GetTime()
  if (this.qevNextUpdate or 0) > now then return end
  this.qevNextUpdate = now + .016

  -- abort if the frame is not initialized yet
  if not this.parent then return end

  xplayer, yplayer = KoQuestEV_SafeGetPlayerMapPosition("player")
  wrongmap = xplayer == 0 and yplayer == 0 and true or nil
  target = this.parent.coords and this.parent.coords[1] and this.parent.coords[1][4] and this.parent.coords[1] or nil

  -- disable arrow on invalid map/route
  if not target or wrongmap or KoQuest_config["arrow"] == "0" then
    if invalid and invalid < GetTime() then
      this:Hide()
    elseif not invalid then
      invalid = GetTime() + 1
    end

    return
  else
    invalid = nil
  end

  -- arrow positioning stolen from TomTomVanilla.
  -- all credits to the original authors:
  -- https://github.com/cralor/TomTomVanilla
  xDelta = (target[1] - xplayer*100)*1.5
  yDelta = (target[2] - yplayer*100)
  dir = atan2(xDelta, -(yDelta))
  dir = dir > 0 and (math.pi*2) - dir or -dir
  if dir < 0 then dir = dir + 360 end
  angle = math.rad(dir)

  player = KoQuestCompat.GetPlayerFacing()
  angle = angle - player
  perc = math.abs(((math.pi - math.abs(angle)) / math.pi))
  r, g, b = pfUI.api.GetColorGradient(floor(perc*100)/100)
  cell = modulo(floor(angle / (math.pi*2) * 108 + 0.5), 108)
  column = modulo(cell, 9)
  row = floor(cell / 9)
  xstart = (column * 56) / 512
  ystart = (row * 42) / 512
  xend = ((column + 1) * 56) / 512
  yend = ((row + 1) * 42) / 512

  -- guess area based on node count
  area = target[3].priority and target[3].priority or 1
  area = max(1, area)
  area = min(20, area)
  area = (area / 10) + 1

  alpha = target[4] - area
  alpha = alpha > 1 and 1 or alpha
  alpha = alpha < .5 and .5 or alpha

  texalpha = (1 - alpha) * 2
  texalpha = texalpha > 1 and 1 or texalpha
  texalpha = texalpha < 0 and 0 or texalpha

  r, g, b = r + texalpha, g + texalpha, b + texalpha

  -- update arrow
  this.model:SetTexCoord(xstart,xend,ystart,yend)
  this.model:SetVertexColor(r,g,b)

  -- recalculate values on target change
  if target ~= lasttarget then
    -- calculate difficulty color
    color = defcolor
    if tonumber(target[3]["qlvl"]) then
      color = KoMap:HexDifficultyColor(tonumber(target[3]["qlvl"]))
    end

    -- update node texture
    if target[3].texture then
      this.texture:SetTexture(target[3].texture)

      if target[3].vertex and ( target[3].vertex[1] > 0
        or target[3].vertex[2] > 0
        or target[3].vertex[3] > 0 )
      then
        this.texture:SetVertexColor(unpack(target[3].vertex))
      else
        this.texture:SetVertexColor(1,1,1,1)
      end
    else
      this.texture:SetTexture(KoQuestConfig.path.."\\img\\node")
      this.texture:SetVertexColor(KoMap.str2rgb(target[3].title))
    end

    -- update arrow texts
    local level = target[3].qlvl and "[" .. target[3].qlvl .. "] " or ""
    this.title:SetText(color..level..target[3].title.."|r")
    local desc = target[3].description or ""
    if not pfUI or not pfUI.uf then
      this.description:SetTextColor(1,.9,.7,1)
      desc = string.gsub(desc, "ff33ffcc", "ffffffff")
    end
    this.description:SetText(desc.."|r.")
  end

  -- only refresh distance text on change
  local distance = floor(target[4]*10)/10
  if distance ~= this.distance.number then
    this.distance:SetText("|cffaaaaaa" .. KoQuest_Loc["Distance"] .. ": "..string.format("%.1f", distance))
    this.distance.number = distance
  end

  -- update transparencies
  this.texture:SetAlpha(texalpha)
  this.model:SetAlpha(alpha)
end)

KoQuest.route.arrow.texture = KoQuest.route.arrow:CreateTexture("KoQuestRouteNodeTexture", "OVERLAY")
KoQuest.route.arrow.texture:SetWidth(28)
KoQuest.route.arrow.texture:SetHeight(28)
KoQuest.route.arrow.texture:SetPoint("BOTTOM", 0, 0)

KoQuest.route.arrow.model = KoQuest.route.arrow:CreateTexture("KoQuestRouteArrow", "MEDIUM")
KoQuest.route.arrow.model:SetTexture(KoQuestConfig.path.."\\img\\arrow")
KoQuest.route.arrow.model:SetTexCoord(0,0,0.109375,0.08203125)
KoQuest.route.arrow.model:SetAllPoints()

KoQuest.route.arrow.title = KoQuest.route.arrow:CreateFontString("KoQuestRouteText", "HIGH", "GameFontWhite")
KoQuest.route.arrow.title:SetPoint("TOP", KoQuest.route.arrow.model, "BOTTOM", 0, -10)
KoQuest.route.arrow.title:SetFont(pfUI.font_default, pfUI_config.global.font_size+1, "OUTLINE")
KoQuest.route.arrow.title:SetTextColor(1,.8,0)
KoQuest.route.arrow.title:SetJustifyH("CENTER")

KoQuest.route.arrow.description = KoQuest.route.arrow:CreateFontString("KoQuestRouteText", "HIGH", "GameFontWhite")
KoQuest.route.arrow.description:SetPoint("TOP", KoQuest.route.arrow.title, "BOTTOM", 0, -2)
KoQuest.route.arrow.description:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
KoQuest.route.arrow.description:SetTextColor(1,1,1)
KoQuest.route.arrow.description:SetJustifyH("CENTER")

KoQuest.route.arrow.distance = KoQuest.route.arrow:CreateFontString("KoQuestRouteDistance", "HIGH", "GameFontWhite")
KoQuest.route.arrow.distance:SetPoint("TOP", KoQuest.route.arrow.description, "BOTTOM", 0, -2)
KoQuest.route.arrow.distance:SetFont(pfUI.font_default, pfUI_config.global.font_size-1, "OUTLINE")
KoQuest.route.arrow.distance:SetTextColor(.8,.8,.8)
KoQuest.route.arrow.distance:SetJustifyH("CENTER")

KoQuest.route.arrow.parent = KoQuest.route
