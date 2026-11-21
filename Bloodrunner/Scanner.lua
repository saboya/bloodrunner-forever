-- Blood of Heroes scanner: FOUND on world mouseover or explicit /br mark.

BloodRoute = BloodRoute or {}
local BR = BloodRoute
local isSecret = issecretvalue or function() return false end

local OBJECT_NAMES = {
  ["blood of heroes"] = true,
  ["blut von helden"] = true,
  ["sang des héros"] = true,
  ["sangre de héroes"] = true,
  ["sangre de heroes"] = true,
  ["sangue dos heróis"] = true,
  ["кровь героев"] = true,
  ["영웅의 피"] = true,
  ["英雄之血"] = true,
}

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff66ff66BloodRoute|r " .. tostring(msg))
end

local function NormalizeName(text)
  if isSecret(text) or type(text) ~= "string" then return "" end
  text = text:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return strtrim(text)
end

local function IsBloodObjectName(text)
  local name = NormalizeName(text)
  if OBJECT_NAMES[name] then return true end
  if strcmputf8i then
    for known in pairs(OBJECT_NAMES) do
      if strcmputf8i(name, known) == 0 then return true end
    end
  end
  return false
end

function BR:GetHBD()
  -- Use the active client's map geometry on Forever, not a library's cached bounds.
  if self.isForever then return nil end
  if self._hbdChecked then
    return self._hbd
  end
  self._hbdChecked = true
  self._hbd = nil
  if LibStub then
    self._hbd = LibStub("HereBeDragons-2.0", true)
      or LibStub("HereBeDragonsQuestie-2.0", true)
  end
  return self._hbd
end

function BR:GetPlayerMapXY()
  local HBD = self:GetHBD()
  if HBD and HBD.GetPlayerZonePosition then
    local x, y, mapID = HBD:GetPlayerZonePosition(true)
    if x and y and mapID then
      return mapID, x * 100, y * 100
    end
  end
  if not C_Map or not C_Map.GetBestMapForUnit then return nil end
  local mapID = C_Map.GetBestMapForUnit("player")
  if isSecret(mapID) or not mapID then return nil end
  local pos = C_Map.GetPlayerMapPosition(mapID, "player")
  if isSecret(pos) or not pos then return mapID end
  local x, y = pos:GetXY()
  if isSecret(x) or isSecret(y) or not x or not y then return mapID end
  return mapID, x * 100, y * 100
end

function BR:WorldPos(uiMapID, mx, my)
  local HBD = self:GetHBD()
  if HBD and HBD.GetWorldCoordinatesFromZone then
    local x, y, instance = HBD:GetWorldCoordinatesFromZone(mx / 100, my / 100, uiMapID)
    if x then return instance, x, y end
  end
  if not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return nil end
  local ok, continent, world = pcall(function()
    return C_Map.GetWorldPosFromMapPos(uiMapID, CreateVector2D(mx / 100, my / 100))
  end)
  if not ok or isSecret(continent) or isSecret(world) or not world then return nil end
  local north, west = world.x, world.y
  if isSecret(north) or isSecret(west) or not north or not west then return nil end
  -- C_Map returns north/west; use HBD's west/north convention internally.
  return continent, west, north
end

function BR:MapDeltaYards(mapID, dxPct, dyPct)
  local width, height
  if C_Map and C_Map.GetMapWorldSize then
    width, height = C_Map.GetMapWorldSize(mapID)
  end
  if not width or not height or width <= 0 or height <= 0 then
    width, height = 4000, 4000
  end
  return dxPct * width / 100, dyPct * height / 100
end

local function HBDAngle(deltaX, deltaY)
  local angle = math.atan2(-deltaX, deltaY)
  if angle > 0 then
    angle = (math.pi * 2) - angle
  else
    angle = -angle
  end
  return angle
end

function BR:VectorToNode(node)
  if not node then return nil end

  local mapID, mx, my = self:GetPlayerMapXY()
  if not mapID then return nil end
  if mapID ~= node.uiMapID then return nil, nil, true end
  if not mx or not my then return nil end

  local pInstance, px, py = self:WorldPos(mapID, mx, my)
  local nInstance, nx, ny = self:WorldPos(mapID, node.x, node.y)
  local west, north
  if pInstance and pInstance == nInstance and px and py and nx and ny then
    west, north = nx - px, ny - py
  else
    west, north = self:MapDeltaYards(mapID, mx - node.x, my - node.y)
  end

  return HBDAngle(west, north), math.sqrt(west * west + north * north), false
end

function BR:NodeKey(node)
  if not node then return "" end
  return string.format("%s:%.1f:%.1f", tostring(node.uiMapID), node.x or 0, node.y or 0)
end

function BR:PointsForCurrentMap()
  local mapID = self:GetPlayerMapXY()
  if not mapID then return nil, nil end
  local list = {}
  for _, key in ipairs({ "epl", "wpl" }) do
    local z = BloodRouteSpawns and BloodRouteSpawns[key]
    if z and z.uiMapID == mapID then
      for i, xy in ipairs(z.points or {}) do
        list[#list + 1] = {
          x = xy[1],
          y = xy[2],
          uiMapID = z.uiMapID,
          zone = key,
          zoneName = z.name,
          nr = i,
        }
      end
      return list, mapID
    end
  end
  return nil, mapID
end

function BR:IsSpawnAlreadyLogged(node)
  if not node or not BloodRouteDB or not BloodRouteDB.foundSpawns then return false end
  if not self.SpawnStorageKey then return false end
  local key = self:SpawnStorageKey(node.uiMapID, node.x, node.y)
  return BloodRouteDB.foundSpawns[key] ~= nil
end

function BR:FindClosestSpawn(maxYards, includeLogged)
  local points = self:PointsForCurrentMap()
  if not points then return nil end
  local best, bestDist = nil, maxYards or 40
  for _, node in ipairs(points) do
    if includeLogged or not self:IsSpawnAlreadyLogged(node) then
      local _, dist, wrong = self:VectorToNode(node)
      if not wrong and dist and dist <= bestDist then
        best, bestDist = node, dist
      end
    end
  end
  return best, bestDist
end

function BR:IsWorldBloodTooltip()
  if not GameTooltip or not GameTooltip:IsShown() then return false end
  if WorldMapFrame and WorldMapFrame:IsShown() then return false end

  if self.isForever then
    -- Read the world cursor directly, not the shared tooltip's current owner or text.
    local data = C_TooltipInfo and C_TooltipInfo.GetWorldCursor and C_TooltipInfo.GetWorldCursor()
    if isSecret(data) or not data or isSecret(data.type)
      or data.type ~= Enum.TooltipDataType.Object then return false end
    local lines = data.lines
    local first = not isSecret(lines) and lines and lines[1]
    return not isSecret(first) and first and IsBloodObjectName(first.leftText)
  end

  local okItem, itemName = pcall(function() return GameTooltip:GetItem() end)
  if okItem and itemName then return false end
  local okUnit, unit = pcall(function() return GameTooltip:GetUnit() end)
  if okUnit and unit then return false end

  local owner = GameTooltip:GetOwner()
  if owner then
    local oname = owner.GetName and owner:GetName() or ""
    local lower = strlower(oname)
    if string.find(lower, "questie", 1, true) then return false end
    if string.find(lower, "bloodroute", 1, true) then return false end
    if string.find(lower, "minimap", 1, true) then return false end
    if string.find(lower, "worldmap", 1, true) then return false end
    if string.find(lower, "container", 1, true) then return false end
    local p = owner
    while p do
      if Minimap and p == Minimap then return false end
      if WorldMapFrame and p == WorldMapFrame then return false end
      p = p.GetParent and p:GetParent()
    end
  end

  local fs = _G.GameTooltipTextLeft1
  local t = fs and fs:GetText()
  if not t then return false end
  return IsBloodObjectName(t)
end

function BR:TryConfirmFromTooltip()
  if self.disabled then return end
  local db = BloodRouteDB or {}
  if db.scanEnabled == false then return end
  if not self:IsWorldBloodTooltip() then return end

  local node, dist = self:FindClosestSpawn(30, true)
  if not node or not dist then return end

  self:AlertLiveNode(node, dist, "tooltip")
end

function BR:MarkFoundHere()
  if self.disabled then
    Print("BloodRoute is off. /br start to enable it.")
    return
  end
  local node, dist = self:FindClosestSpawn(25, true)
  if not node then
    Print("No spawn within 25 yd — stand on the puddle, then /br mark.")
    return
  end
  self:AlertLiveNode(node, dist, "manual")
end

function BR:PlayFoundSound()
  if BloodRouteDB and BloodRouteDB.scanSound == false then return end
  if SOUNDKIT and SOUNDKIT.RAID_WARNING then
    PlaySound(SOUNDKIT.RAID_WARNING, "Master")
  else
    PlaySoundFile("Sound\\Interface\\RaidWarning.ogg", "Master")
  end
end

function BR:AlertLiveNode(node, dist, source)
  source = source or "manual"

  local now = GetTime()
  if source == "tooltip" and self.scanHit and self:NodeKey(self.scanHit.node) == self:NodeKey(node) then
    self.scanHit.untilTime = now + 60
    return
  end

  self.scanHit = {
    node = node,
    dist = dist,
    confirmed = true,
    source = source,
    untilTime = now + 60,
  }

  self:PlayFoundSound()
  self:SetArrowGlow(true, true)
  self.scanTarget = node
  self.scanArrowOnly = not self.active

  Print(string.format("|cffff4400FOUND|r Blood of Heroes (%.0f yd) — loot or /br skip.", dist or 0))
  if UIErrorsFrame then
    UIErrorsFrame:AddMessage("Blood of Heroes FOUND — loot it!", 1.0, 0.2, 0.1)
  end
  if self.RecordFound then self:RecordFound(node) end
end

function BR:ClearScanHit()
  self.scanHit = nil
  self.nearHit = nil
  self.scanTarget = nil
  self.scanArrowOnly = false
  if self.arrow then self:SetArrowGlow(false) end
  if not self.active and self.arrow then
    self.arrow:Hide()
  end
end

function BR:StartScanner()
  if self._scanFrame then return end
  local f = CreateFrame("Frame")
  f.t = 0
  f:SetScript("OnUpdate", function(frame, elapsed)
    frame.t = frame.t + elapsed
    if frame.t < 0.15 then return end
    frame.t = 0
    BR:ScanTick()
  end)
  self._scanFrame = f

  if not self.isForever and GameTooltip and not self._tipHooked then
    self._tipHooked = true
    GameTooltip:HookScript("OnShow", function()
      BR:TryConfirmFromTooltip()
    end)
  end
end

function BR:StopScanner()
  if self._scanFrame then
    self._scanFrame:SetScript("OnUpdate", nil)
    self._scanFrame = nil
  end
  self:ClearScanHit()
end

function BR:ScanTick()
  if self.disabled then return end
  self:CheckRouteMap()

  -- Only live confirmation: world mouseover of the object (not spawn-coordinate proximity)
  self:TryConfirmFromTooltip()

  local hit = self.scanHit
  if not (hit and hit.confirmed) then
    return
  end

  local node = hit.node
  if not node then
    self:ClearScanHit()
    return
  end
  local _, dist = self:VectorToNode(node)
  if not dist or dist > 45 or (hit.untilTime and GetTime() > hit.untilTime) then
    self:ClearScanHit()
    if self.active then self:RetargetClosest(true, true) end
  end
end
