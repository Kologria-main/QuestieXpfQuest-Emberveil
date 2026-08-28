-- multi api compat
local compat = KoQuestCompat

SLASH_KOQUESTDB1, SLASH_KOQUESTDB2 = "/kodb", "/koquestdb"
SlashCmdList["KOQUESTDB"] = function(input, editbox)
  local params = {}
  local meta = { ["addon"] = "KODB" }

  if (input == "" or input == nil) then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccKoQuest|r (v" .. KoQuestConfig.version .. "):")
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff lock |cffcccccc - " .. KoQuest_Loc["Lock map tracker"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff tracker |cffcccccc - " .. KoQuest_Loc["Show map tracker"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff journal |cffcccccc - " .. KoQuest_Loc["Show quest journal"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff show |cffcccccc - " .. KoQuest_Loc["Show database interface"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff config |cffcccccc - " .. KoQuest_Loc["Show configuration interface"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff locale |cffcccccc - " .. KoQuest_Loc["Display addon locales"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff track <list>|cffcccccc - " .. KoQuest_Loc["Show available tracking lists"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff unit <unit> |cffcccccc - " .. KoQuest_Loc["Search unit"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff object <gameobject> |cffcccccc - " .. KoQuest_Loc["Search object"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff item <item> |cffcccccc - " .. KoQuest_Loc["Search loot"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff vendor <item> |cffcccccc - " .. KoQuest_Loc["Search item vendors"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff quest <questname> |cffcccccc - " .. KoQuest_Loc["Show specific quest"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff quests |cffcccccc - " .. KoQuest_Loc["Show all quests on map"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff clean |cffcccccc - " .. KoQuest_Loc["Clean Map"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff reset |cffcccccc - " .. KoQuest_Loc["Reset Map"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff scan |cffcccccc - " .. KoQuest_Loc["Scan the server for custom items"])
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc/kodb|cffffffff query |cffcccccc - " .. KoQuest_Loc["Query the server for completed quests"])
    return
  end

  local commandlist = { }
  local command

  for command in compat.gfind(input, "[^ ]+") do
    table.insert(commandlist, command)
  end

  local arg1, arg2 = commandlist[1], ""

  -- handle whitespace mob- and item names correctly
  for i in pairs(commandlist) do
    if (i ~= 1) then
      arg2 = arg2 .. commandlist[i]
      if (commandlist[i+1] ~= nil) then
        arg2 = arg2 .. " "
      end
    end
  end

  -- argument: debug
  if (arg1 == "debug") then
    KoQuest_config.debug = not KoQuest_config.debug
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccKo|cffffffffQuest Debug Mode: " .. ( KoQuest_config.debug and "|cff33ff33ON" or "|cffff3333OFF" ))
    KoQuest:Debug("Debug Mode Changed")
    return
  end

  -- argument: item
  if (arg1 == "item") then
    local maps = KoDatabase:SearchItem(arg2, meta, "LOWER")
    KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    return
  end

  -- argument: vendor
  if (arg1 == "vendor") then
    local maps = KoDatabase:SearchVendor(arg2, meta, "LOWER")
    KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    return
  end

  -- argument: unit
  if (arg1 == "unit") then
    local maps = KoDatabase:SearchMob(arg2, meta, "LOWER")
    KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    return
  end

  -- argument: object
  if (arg1 == "object") then
    local maps = KoDatabase:SearchObject(arg2, meta, "LOWER")
    KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    return
  end

  -- argument: quest
  if (arg1 == "quest") then
    local maps = KoDatabase:SearchQuest(arg2, meta, "LOWER")
    KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    return
  end

  -- argument: quests
  if (arg1 == "quests") then
    local maps = KoDatabase:SearchQuests(meta)
    KoMap:UpdateNodes()
    return
  end

  -- argument: track
  if (arg1 == "track" or arg1 == "meta") then
    local list = commandlist[2]

    -- show available lists
    if not list or list == "" then
      local available = nil
      for list in pairs(KoDB["meta"]) do
        available = (available and available .. ", " or "") .. "\"|cff33ffcc"..list.."|r\""
      end

      DEFAULT_CHAT_FRAME:AddMessage(string.format(KoQuest_Loc["Available tracking targets are: %s. Or type \"|cff33ffcc/kodb track clean|r\" to untrack all."], available))
      return
    end

    -- clean all tracking results
    if commandlist[2] == "clean" then
      for list in pairs(KoDB["meta"]) do
        KoDatabase:TrackMeta(list, false)
      end

      return
    end

    -- load arguments into state
    local state = {
      min = commandlist[3],
      max = commandlist[4],
      faction = commandlist[3],
    }

    -- read skill for auto mines
    if (list == "mines" and commandlist[3] == "auto") then
      state.max = KoDatabase:GetPlayerSkill(186) or 0
      state.min = state.max - 100
    end

    -- read skill for auto herbs
    if (list == "herbs" and commandlist[3] == "auto") then
      state.max = KoDatabase:GetPlayerSkill(182) or 0
      state.min = state.max - 100
    end

    -- clean specific list
    if commandlist[3] == "clean" then
      state = nil
    end

    -- perform tracking
    local maps = KoDatabase:TrackMeta(list, state)
    KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    return
  end

  -- warn about deprecated arguments
  local deprecated = {
    ["chests"] = true, ["taxi"] = true, ["flights"] = true, ["rares"] = true, ["mines"] = true, ["herbs"] = true
  }

  if deprecated[arg1] then
    DEFAULT_CHAT_FRAME:AddMessage(string.format(KoQuest_Loc["|cffffcc00WARNING:|r The command \"|cff33ffcc/kodb %s|r\" is deprecated and will be removed soon. Please use the \"|cff33ffcc/kodb track %s|r\" instead to achieve the same functionality."], arg1, arg1))
  end

  -- argument: chests (deprecated)
  if (arg1 == "chests") then
    local state = true

    if commandlist[2] == "clean" then
      state = nil
    end

    local maps = KoDatabase:TrackMeta("chests", state)
    KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    return
  end

  -- argument: taxi (deprecated)
  if (arg1 == "flights" or arg1 == "taxi") then
    local state = {
      faction = commandlist[2],
    }

    if commandlist[2] == "clean" then
      state = nil
    end

    local maps = KoDatabase:TrackMeta("flight", state)
    KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    return
  end

  -- argument: rares (deprecated)
  if (arg1 == "rares") then
    local state = {
      min = commandlist[2],
      max = commandlist[3],
    }

    if commandlist[2] == "clean" then
      state = nil
    end

    local maps = KoDatabase:TrackMeta("rares", state)
    KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    return
  end

  -- argument: mines (deprecated)
  if (arg1 == "mines") then
    local state = {
      min = commandlist[2],
      max = commandlist[3],
    }

    if (arg2 == "auto") then
      state.max = KoDatabase:GetPlayerSkill(186) or 0
      state.min = state.max - 100
    end

    if commandlist[2] == "clean" then
      state = nil
    end

    state = commandlist[2] == "clean" and nil or state
    local maps = KoDatabase:TrackMeta("mines", state)
    KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    return
  end

  -- argument: herbs (deprecated)
  if (arg1 == "herbs") then
    local state = {
      min = commandlist[2],
      max = commandlist[3],
    }

    if (arg2 == "auto") then
      state.max = KoDatabase:GetPlayerSkill(182) or 0
      state.min = state.max - 100
    end

    if commandlist[2] == "clean" then
      state = nil
    end

    state = commandlist[2] == "clean" and nil or state
    local maps = KoDatabase:TrackMeta("herbs", state)
    KoMap:ShowMapID(KoDatabase:GetBestMap(maps))
    return
  end

  -- argument: clean
  if (arg1 == "clean") then
    KoMap:DeleteNode("KODB")
    KoMap:UpdateNodes()
    return
  end

  -- argument: reset
  if (arg1 == "reset") then
    KoQuest:ResetAll()
    return
  end

  -- argument: show
  if (arg1 == "show") then
    if KoBrowser then KoBrowser:Show() end
    return
  end

  -- argument: tracker
  if (arg1 == "tracker") then
    if KoQuest.tracker then KoQuest.tracker:Show() end
    return
  end

  -- argument: lock
  if (arg1 == "lock") then
    KoQuest_config.lock = not KoQuest_config.lock
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccKo|cffffffffQuest Tracker: " .. ( KoQuest_config.lock and "Locked" or "Unlocked" ))
    return
  end

  -- argument: journal
  if (arg1 == "journal") then
    if KoJournal then KoJournal:Show() end
    return
  end

  -- argument: arrow
  if (arg1 == "arrow") then
    KoQuest_config["arrow"] = "0"
    if KoQuest.route and KoQuest.route.arrow then KoQuest.route.arrow:Hide() end
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccKo|cffffffffQuest: Route arrows are unavailable on Emberveil because the client does not expose trustworthy facing data.")
    return
  end

  -- argument: show
  if (arg1 == "config") then
    if KoQuestConfig then KoQuestConfig:Show() end
    return
  end

  -- argument: locale
  if (arg1 == "locale") then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc" .. KoQuest_Loc["Locales"] .. "|r:" .. KoDatabase.dbstring)
    return
  end

  -- argument: scan
  if (arg1 == "scan") then
    KoDatabase:ScanServer()
    return
  end

    -- argument: query
  if (arg1 == "query") then
    KoDatabase:QueryServer()
    return
  end

  -- argument: <text>
  if (type(arg1)=="string") then
    if KoBrowser then
      KoBrowser:Show()
      KoBrowser.input:SetText((string.gsub(string.format("%s %s",arg1,arg2),"^%s*(.-)%s*$", "%1")))
    end
    return
  end
end
