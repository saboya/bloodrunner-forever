BloodRoute = BloodRoute or {}
local BR = BloodRoute

BloodRouteDB = BloodRouteDB or {}

local PREFIX = "|cff66ff66BloodRoute|r "

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

local function EnsureDB()
  BloodRouteDB = BloodRouteDB or {}
  if BloodRouteDB.mode == nil then BloodRouteDB.mode = "both" end
  if BloodRouteDB.arrivalYards == nil then BloodRouteDB.arrivalYards = 20 end
  if BloodRouteDB.scanEnabled == nil then BloodRouteDB.scanEnabled = true end
  if BloodRouteDB.scanYards == nil then BloodRouteDB.scanYards = 20 end
  -- Auto-arrive distance (20 yd)
  if BloodRouteDB.arriveYardsVersion ~= 3 then
    BloodRouteDB.scanYards = 20
    BloodRouteDB.arrivalYards = 20
    BloodRouteDB.arriveYardsVersion = 3
  end
  if BloodRouteDB.scanSound == nil then BloodRouteDB.scanSound = true end
  if BloodRouteDB.bloodsLooted == nil then BloodRouteDB.bloodsLooted = 0 end
  BloodRouteDB.foundSpawns = BloodRouteDB.foundSpawns or {}
  BloodRouteDB.spawnLootCounts = BloodRouteDB.spawnLootCounts or {}
  BloodRouteDB.arrowPos = BloodRouteDB.arrowPos or nil
  return BloodRouteDB
end

-- Lifetime counter: Blood of Heroes you personally picked up (SavedVariables).
function BR:GetBloodsLooted()
  local db = EnsureDB()
  return db.bloodsLooted or 0
end

function BR:SpawnLootKey(node)
  if not node then return nil end
  if self.SpawnStorageKey then
    return self:SpawnStorageKey(node.uiMapID, node.x, node.y)
  end
  return string.format("%d:%.1f:%.1f", node.uiMapID or 0, node.x or 0, node.y or 0)
end

function BR:GetSpawnLootCount(node)
  local key = self:SpawnLootKey(node)
  if not key then return 0 end
  local db = EnsureDB()
  return (db.spawnLootCounts and db.spawnLootCounts[key]) or 0
end

function BR:RecordSpawnLoot(node, qty)
  if not node then return 0 end
  qty = qty or 1
  local db = EnsureDB()
  db.spawnLootCounts = db.spawnLootCounts or {}
  local key = self:SpawnLootKey(node)
  db.spawnLootCounts[key] = (db.spawnLootCounts[key] or 0) + qty
  return db.spawnLootCounts[key]
end

function BR:RecordBloodPickup(qty)
  local db = EnsureDB()
  db.bloodsLooted = (db.bloodsLooted or 0) + qty
  return db.bloodsLooted
end

local function LootPattern(template)
  if not template then return nil end
  local pattern = { "^" }
  local from = 1
  local function literal(text) return (text:gsub("([^%w])", "%%%1")) end
  while true do
    local first, last, kind = template:find("%%[12%$]*([sd])", from)
    if not first then break end
    pattern[#pattern + 1] = literal(template:sub(from, first - 1))
    pattern[#pattern + 1] = kind == "d" and "(%d+)" or ".-"
    from = last + 1
  end
  pattern[#pattern + 1] = literal(template:sub(from)) .. "$"
  return table.concat(pattern)
end

local singleLoot = LootPattern(LOOT_ITEM_SELF)
local multiLoot = LootPattern(LOOT_ITEM_SELF_MULTIPLE)

local function PlayerBloodLootQuantity(msg)
  if (issecretvalue and issecretvalue(msg)) or type(msg) ~= "string" then return end
  if not msg:find("|Hitem:12938[:|]") then return end
  local count = multiLoot and tonumber(msg:match(multiLoot))
  if count and count > 0 then return count end
  if singleLoot and msg:match(singleLoot) then return 1 end
end

function BR:Start(mode)
  local db = EnsureDB()
  mode = mode or db.mode or "both"
  db.mode = mode

  self.disabled = false
  if self.StartScanner then self:StartScanner() end
  if self.arrow and not self.arrow:GetScript("OnUpdate") then
    self.arrow:SetScript("OnUpdate", function(frame, elapsed)
      BR:UpdateArrow(frame, elapsed)
    end)
  end

  local points = self:CollectPoints(mode)
  if #points == 0 then
    Print("No spawn points loaded.")
    return
  end

  -- Fresh run: clear "checked" progress so every stop is on the tour again.
  -- Keep FOUND map marks from earlier live hits.
  if self.ClearFound then
    self:ClearFound("checked")
  end

  local mapID, mx = self:GetPlayerMapXY()
  if mapID then
    local inZone = false
    for _, p in ipairs(points) do
      if p.uiMapID == mapID then inZone = true break end
    end
    if not inZone then
      Print("Outside the selected farm zone. The arrow will resume when you enter it.")
    end
  end

  -- Navigate to each spawn pin (not covering centers) so the arrow matches puddles on the ground
  self.remaining = {}
  for _, p in ipairs(points) do
    if not self:IsSpawnAlreadyLogged(p) then
      self.remaining[#self.remaining + 1] = {
        x = p.x,
        y = p.y,
        uiMapID = p.uiMapID,
        zone = p.zone,
        zoneName = p.zoneName,
        nr = p.nr,
      }
    end
  end

  local left = self:ResortFromPlayer()
  if left == 0 then
    self:Stop()
    Print("Nothing left (all FOUND). /br clearfound then /br start for a full run.")
    return
  end

  self.active = true
  self.scanArrowOnly = false
  self.totalWaypoints = left
  self._lastResortMap = mapID
  self._hadRoutePosition = mx ~= nil
  self:ShowArrow()

  local nextWp = self.route[1]
  local _, nd = self:VectorToNode(nextWp)
  local label = mode == "both" and "EPL+WPL" or string.upper(mode)
  Print(string.format(
    "Route (%s): |cffffff00%d spawns|r · closest unfinished · next |cffffff00%s|r.",
    label,
    left,
    nd and string.format("%.0f yd", nd) or (nextWp.zoneName or "position unavailable")
  ))
  Print("Arrow = next unfinished pin. Looting a blood saves that spawn's collect count.")
end

function BR:Stop()
  self.active = false
  self.route = nil
  self.remaining = nil
  self.index = 1
  if self.ClearScanHit then self:ClearScanHit() end
  self:HideArrow()
  Print("Route stopped. Scanner still on — /br quit to shut down fully.")
end

function BR:Quit()
  self.active = false
  self.disabled = true
  self.route = nil
  self.remaining = nil
  self.index = 1
  self.scanArrowOnly = false
  if self.ClearScanHit then self:ClearScanHit() end
  if self.StopScanner then self:StopScanner() end
  if self.arrow then
    self.arrow:SetScript("OnUpdate", nil)
    self.arrow:Hide()
  end
  self:RefreshMapPins()
  Print("BloodRoute |cffff6666off|r. Type |cffffff00/br start|r when you need it again.")
end

function BR:RetargetClosest(silent, force)
  if not self.active or not self.remaining then return 0 end
  -- Avoid mid-run target ping-pong right after arrive/skip
  if not force and self._lockTargetUntil and GetTime() < self._lockTargetUntil then
    return self.route and #self.route or 0
  end
  local prevKey = self.route and self.route[1] and self:NodeKey(self.route[1])
  -- Keep current stop unless something else is clearly closer (stops flicker / turn-arounds)
  local left = self:ResortFromPlayer({ stickyKey = (not force) and prevKey or nil, stickySlack = 60 })
  if left == 0 then
    Print("|cff00ff00All stops done!|r /br start to run again.")
    self:Stop()
    return 0
  end
  local nextWp = self.route and self.route[1]
  local newKey = nextWp and self:NodeKey(nextWp)
  if not silent and nextWp and newKey ~= prevKey then
    local _, nd = self:VectorToNode(nextWp)
    Print(string.format(
      "Closest unfinished: |cffffff00%s|r (%.1f, %.1f) · %d left · %s",
      nd and string.format("%.0f yd", nd) or "distance unavailable", nextWp.x, nextWp.y, left, nextWp.zoneName or ""
    ))
  end
  return left
end

function BR:CheckRouteMap()
  if not self.active then return end
  local mapID, mx = self:GetPlayerMapXY()
  local hasPosition = mx ~= nil
  if mapID ~= self._lastResortMap or (hasPosition and not self._hadRoutePosition) then
    self._lastResortMap = mapID
    self._hadRoutePosition = hasPosition
    self:RetargetClosest(true, true)
  else
    self._hadRoutePosition = hasPosition
  end
end

function BR:AdvanceNode(reason)
  if not self.active or not self.remaining then return end
  local prev = (self.route and self.route[self.index]) or self.remaining[1]
  local cover = (EnsureDB().scanYards) or 20

  if prev and self.RecordChecked then
    self:RecordChecked(prev)
  end

  if self.ClearScanHit then self:ClearScanHit() end

  -- Complete this stop (+ any others still inside cover range)
  local kept = {}
  for _, wp in ipairs(self.remaining) do
    local same = prev and self:NodeKey(wp) == self:NodeKey(prev)
    local close = prev and self.NodeDistanceYards and (self:NodeDistanceYards(prev, wp) <= cover)
    if same or close then
      if self.RecordChecked then self:RecordChecked(wp) end
    else
      kept[#kept + 1] = wp
    end
  end
  self.remaining = kept

  -- Fresh pick after arrive/skip (no sticky); lock so zone events don't immediately re-swap
  local left = self:ResortFromPlayer()
  self._lockTargetUntil = GetTime() + 2.5
  if self.arrow then
    self.arrow._targetKey = nil -- force arrow orientation snap next frame
  end
  if left == 0 then
    Print("|cff00ff00All stops done!|r /br start to run again.")
    self:Stop()
    return
  end
end

function BR:Skip()
  if not self.active then
    Print("No active route. /br start")
    return
  end
  self:AdvanceNode("skip")
end

local function DetectModeFromZone()
  -- Full farm by default; use /br epl or /br wpl for one zone only
  return "both"
end

SLASH_BLOODROUTE1 = "/bloodroute"
SLASH_BLOODROUTE2 = "/br"
SlashCmdList["BLOODROUTE"] = function(msg)
  msg = strtrim(strlower(msg or ""))
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  cmd = cmd or ""
  local db = EnsureDB()

  if cmd == "" or cmd == "help" then
    Print("|cffffff00/br start|r = EPL+WPL · |cffffff00/br epl|wpl|r · |cffffff00/br skip|stop|r")
    Print("|cffffff00/br quit|r = shut down · |cffffff00/br status|r · |cffffff00/br clearloot|r")
    Print("|cffffff00/br range 20|r")
    Print("|cffffff00/br mark|r = mark a puddle at your feet · |cffffff00/br clearfound|r = clear FOUND pins")
    return
  end

  if cmd == "start" then
    BR:Start(DetectModeFromZone())
  elseif cmd == "epl" then
    BR:Start("epl")
  elseif cmd == "wpl" then
    BR:Start("wpl")
  elseif cmd == "both" then
    BR:Start("both")
  elseif cmd == "quit" or cmd == "exit" or cmd == "off" then
    BR:Quit()
  elseif cmd == "stop" then
    BR:Stop()
  elseif cmd == "skip" or cmd == "next" then
    BR:Skip()
  elseif cmd == "reset" then
    BR:Stop()
    BR:Start(DetectModeFromZone())
  elseif cmd == "scan" then
    db.scanEnabled = not (db.scanEnabled ~= false)
    Print("Scanner " .. (db.scanEnabled and "|cff00ff00ON|r" or "|cffff0000OFF|r") .. ".")
    if not db.scanEnabled and BR.ClearScanHit then BR:ClearScanHit() end
  elseif cmd == "sound" then
    db.scanSound = not (db.scanSound ~= false)
    Print("Alert sound " .. (db.scanSound and "|cff00ff00ON|r" or "|cffff0000OFF|r") .. ".")
  elseif cmd == "range" then
    local n = tonumber(rest)
    if not n or n < 10 or n > 120 then
      Print("Usage: /br range 20")
      return
    end
    db.scanYards = math.floor(n)
    db.arrivalYards = db.scanYards
    Print("Scan/cover range: " .. db.scanYards .. " yd. /br start to rebuild.")
  elseif cmd == "found" or cmd == "status" then
    local looted = BR:GetBloodsLooted()
    Print(string.format("Blood of Heroes |cffff4400picked up|r (lifetime): |cffffff00%d|r", looted))
    local found, checked = 0, 0
    if BR.CountFound then found, checked = BR:CountFound() end
    Print(string.format("Map pins — |cff00ff00marked %d|r · checked %d", found, checked))
    if BR.active and BR.route and BR.route[1] then
      local n = BR.route[1]
      local _, d = BR:VectorToNode(n)
      Print(string.format(
        "Next: |cffffff00nr %s|r · %s at %.1f, %.1f (%d left) · %s",
        tostring(n.nr or "?"), d and string.format("%.0f yd", d) or "distance unavailable",
        n.x, n.y, #(BR.remaining or BR.route), n.zone or ""
      ))
    elseif not BR.active then
      Print("No active route. /br start")
    end
  elseif cmd == "clearloot" then
    db.bloodsLooted = 0
    db.spawnLootCounts = {}
    Print("Lifetime pickup counters reset (lifetime + per-spawn).")
  elseif cmd == "clearfound" then
    if BR.ClearFound then BR:ClearFound("found") end
    Print("Cleared FOUND map pins.")
  elseif cmd == "mark" then
    BR:MarkFoundHere()
  elseif cmd == "clearchecked" then
    if BR.ClearFound then BR:ClearFound("checked") end
    Print("Cleared checked map pins.")
  elseif cmd == "clearall" then
    if BR.ClearFound then BR:ClearFound() end
    Print("Cleared all map pins.")
  else
    Print("Unknown. /br help")
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_LOOT")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ZONE_CHANGED")
f:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if (...) == "Blizzard_WorldMap" then BR:SetupMapHooks() end
    return
  end
  if event == "PLAYER_LOGIN" then
    EnsureDB()
    if BR.StartScanner then BR:StartScanner() end
    if BR.SetupMapHooks then BR:SetupMapHooks() end
    local hbd = BR.GetHBD and BR:GetHBD()
    Print("Loaded. Nav: " .. (hbd and "|cff00ff00HereBeDragons|r" or "Blizzard map") .. "  ·  /br start")
    return
  end

  if event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" then
    BR:CheckRouteMap()
    return
  end

  if event == "CHAT_MSG_LOOT" then
    if BR.disabled then return end
    local qty = PlayerBloodLootQuantity(...)
    if not qty then return end

    local total = BR:RecordBloodPickup(qty)
    local node = BR.scanHit and BR.scanHit.node
    if node then
      local _, dist = BR:VectorToNode(node)
      if not dist or dist > 45 then node = nil end
    end
    if not node and BR.FindClosestSpawn then
      node = select(1, BR:FindClosestSpawn(60, true))
    end

    local atSpawn = 0
    if node and BR.RecordSpawnLoot then
      atSpawn = BR:RecordSpawnLoot(node, qty)
    end
    if node and BR.RecordFound then
      BR:RecordFound(node)
    end

    Print(string.format(
      "|cff00ff00+%d Blood of Heroes|r · this spawn: |cffffff00%d|r · lifetime: |cffffff00%d|r",
      qty, atSpawn, total
    ))

    BR:ClearScanHit()
    if BR.active and node then
      local current = BR.route and BR.route[BR.index]
      if current and BR:NodeKey(current) == BR:NodeKey(node) then
        BR:AdvanceNode("arrived")
      else
        BR:RetargetClosest(true, true)
      end
    end
  end
end)
