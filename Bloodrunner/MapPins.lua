-- Persist found / checked spawn areas and draw them on the world map.

BloodRoute = BloodRoute or {}
local BR = BloodRoute

local PIN_SIZE = 14
BR.bloodIcon = 134813 -- Interface/Icons/INV_Potion_33

local function EnsureFoundDB()
  BloodRouteDB = BloodRouteDB or {}
  BloodRouteDB.foundSpawns = BloodRouteDB.foundSpawns or {}
  return BloodRouteDB.foundSpawns
end

function BR:SpawnStorageKey(uiMapID, x, y)
  return string.format("%d:%.1f:%.1f", uiMapID or 0, x or 0, y or 0)
end

function BR:RecordSpawn(node, kind)
  if not node then return end
  kind = kind or "found" -- "found" | "checked"
  local db = EnsureFoundDB()
  local key = self:SpawnStorageKey(node.uiMapID, node.x, node.y)
  local prev = db[key]
  -- found upgrades checked; never downgrade found → checked
  if prev and prev.kind == "found" and kind == "checked" then
    return
  end
  db[key] = {
    x = node.x,
    y = node.y,
    uiMapID = node.uiMapID,
    zone = node.zone,
    zoneName = node.zoneName,
    kind = kind,
    t = time(),
  }
  -- Also mark every spawn this cover waypoint includes
  if node.covers then
    for _, c in ipairs(node.covers) do
      local ck = self:SpawnStorageKey(c.uiMapID, c.x, c.y)
      local p = db[ck]
      if not (p and p.kind == "found" and kind == "checked") then
        if not (p and p.kind == "found") then
          db[ck] = {
            x = c.x,
            y = c.y,
            uiMapID = c.uiMapID,
            zone = c.zone,
            zoneName = c.zoneName,
            kind = kind,
            t = time(),
          }
        end
      end
    end
  end
  self:RefreshMapPins()
end

function BR:RecordFound(node)
  self:RecordSpawn(node, "found")
end

function BR:RecordChecked(node)
  self:RecordSpawn(node, "checked")
end

function BR:RemoveFound(node)
  local db = EnsureFoundDB()
  local key = self:SpawnStorageKey(node.uiMapID, node.x, node.y)
  if not db[key] or db[key].kind ~= "found" then return end
  db[key] = nil
  self:RefreshMapPins()
end

function BR:ClearFound(kind)
  local db = EnsureFoundDB()
  if not kind then
    wipe(db)
  else
    for k, v in pairs(db) do
      if v.kind == kind then db[k] = nil end
    end
  end
  self:RefreshMapPins()
end

function BR:CountFound()
  local db = EnsureFoundDB()
  local found, checked = 0, 0
  for _, v in pairs(db) do
    if v.kind == "found" then
      found = found + 1
    else
      checked = checked + 1
    end
  end
  return found, checked
end

------------------------------------------------------------
-- World map pins (no external lib required)
------------------------------------------------------------

function BR:CreateMapPinTemplate()
  if self._pinPool then return end
  self._pinPool = {}
  self._activePins = {}
end

local function AcquirePin(self)
  self:CreateMapPinTemplate()
  local pin = table.remove(self._pinPool)
  if not pin then
    pin = CreateFrame("Button", nil, nil)
    pin:SetSize(PIN_SIZE, PIN_SIZE)
    pin.tex = pin:CreateTexture(nil, "OVERLAY")
    pin.tex:SetAllPoints()
    pin.tex:SetTexture(BR.bloodIcon)
    pin:EnableMouse(true)
    pin:RegisterForClicks("RightButtonUp")
    pin:SetScript("OnClick", function(f, button)
      if button ~= "RightButton" or not f.data then return end
      GameTooltip:Hide()
      BR:RemoveFound(f.data)
    end)
    pin:SetScript("OnEnter", function(f)
      GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
      local d = f.data
      if not d then return end
      if d.kind == "found" then
        GameTooltip:AddLine("Blood of Heroes FOUND", 0.2, 1, 0.3)
      else
        GameTooltip:AddLine("Spawn checked", 0.6, 0.8, 1)
      end
      GameTooltip:AddLine(string.format("%.1f, %.1f", d.x, d.y), 1, 1, 1)
      if d.zoneName then GameTooltip:AddLine(d.zoneName, 0.7, 0.7, 0.7) end
      GameTooltip:AddLine("Right-click to remove this pin.", 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    pin:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return pin
end

local function ReleasePin(self, pin)
  pin:Hide()
  pin:ClearAllPoints()
  pin:SetParent(nil)
  pin.data = nil
  self._pinPool[#self._pinPool + 1] = pin
end

function BR:RefreshMapPins()
  self:CreateMapPinTemplate()
  for _, pin in ipairs(self._activePins) do
    ReleasePin(self, pin)
  end
  wipe(self._activePins)

  if self.disabled or not WorldMapFrame or not WorldMapFrame:IsShown() then return end
  local mapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  if not mapID then return end

  local parent = WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas()
    or (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
  if not parent then return end

  local w, h = parent:GetWidth(), parent:GetHeight()
  if w <= 0 or h <= 0 then return end

  local db = EnsureFoundDB()
  for _, data in pairs(db) do
    -- Only mark live finds on the map (checked stops stay internal for the route)
    if data.uiMapID == mapID and data.kind == "found" then
      local pin = AcquirePin(self)
      pin:SetParent(parent)
      pin:SetFrameStrata("HIGH")
      pin.data = data
      -- Map % → pixel (WoW map: x left→right, y top→bottom)
      local px = (data.x / 100) * w
      local py = (data.y / 100) * h
      pin:ClearAllPoints()
      pin:SetPoint("CENTER", parent, "TOPLEFT", px, -py)
      pin:Show()
      self._activePins[#self._activePins + 1] = pin
    end
  end
end

function BR:SetupMapHooks()
  local map = WorldMapFrame
  if self._mapHooked or not map or not map.OnMapChanged then return end
  self._mapHooked = true

  hooksecurefunc(map, "OnMapChanged", function()
    BR:RefreshMapPins()
  end)

  map:HookScript("OnShow", function()
    C_Timer.After(0.05, function() BR:RefreshMapPins() end)
  end)

  local canvas = map.GetCanvas and map:GetCanvas()
    or (map.ScrollContainer and map.ScrollContainer.Child)
  if canvas then
    canvas:HookScript("OnSizeChanged", function() BR:RefreshMapPins() end)
  end
  self:RefreshMapPins()
end
