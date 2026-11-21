-- RXP-style navigation arrow for the current Blood of Heroes node.

BloodRoute = BloodRoute or {}
local BR = BloodRoute

function BR:SaveArrowPosition(frame)
  BloodRouteDB = BloodRouteDB or {}
  local point, _, relativePoint, x, y = frame:GetPoint(1)
  if not point then return end
  BloodRouteDB.arrowPos = {
    point = point,
    relativePoint = relativePoint or point,
    x = x or 0,
    y = y or 0,
  }
end

function BR:RestoreArrowPosition(frame)
  local pos = BloodRouteDB and BloodRouteDB.arrowPos
  frame:ClearAllPoints()
  if pos and pos.point and pos.x ~= nil and pos.y ~= nil then
    frame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.x, pos.y)
  else
    frame:SetPoint("TOP", UIParent, "TOP", 0, -90)
  end
end

function BR:CreateArrow()
  if self.arrow then
    if self.arrow.texture then
      self.arrow.texture:SetTexture("Interface\\AddOns\\Bloodrunner\\Media\\arrow")
      self.arrow.texture:SetVertexColor(1, 0.25, 0.15)
    end
    self.arrow:SetSize(32, 32)
    if self.arrow.glow then self.arrow.glow:Hide() end
    if self.arrow.glow2 then self.arrow.glow2:Hide() end
    if not self.arrow.skipBtn then
      self:EnsureSkipButton(self.arrow)
    else
      self.arrow.skipBtn:ClearAllPoints()
      self.arrow.skipBtn:SetPoint("LEFT", self.arrow, "RIGHT", 6, 0)
    end
    if self.arrow.hint then
      self.arrow.hint:SetText("Shift-drag | button to skip")
    end
    if not self.arrow.collectText then
      local collect = self.arrow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      collect:SetPoint("BOTTOM", self.arrow, "TOP", 0, 6)
      collect:SetJustifyH("CENTER")
      collect:SetTextColor(0.85, 0.85, 0.85)
      collect:Hide()
      self.arrow.collectText = collect
    end
    self.arrow:SetScript("OnDragStop", function(frame)
      frame:StopMovingOrSizing()
      BR:SaveArrowPosition(frame)
    end)
    return self.arrow
  end

  local af = CreateFrame("Frame", "BloodRouteArrow", UIParent)
  af:SetSize(32, 32)
  self:RestoreArrowPosition(af)
  af:SetFrameStrata("HIGH")
  af:SetMovable(true)
  af:EnableMouse(true)
  af:SetClampedToScreen(true)
  af:RegisterForDrag("LeftButton")
  af:SetScript("OnDragStart", function(frame)
    if IsShiftKeyDown() then frame:StartMoving() end
  end)
  af:SetScript("OnDragStop", function(frame)
    frame:StopMovingOrSizing()
    BR:SaveArrowPosition(frame)
  end)
  af:Hide()

  -- Directional arrow only (no outer glow square)
  local tex = af:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints()
  tex:SetTexture("Interface\\AddOns\\Bloodrunner\\Media\\arrow")
  tex:SetVertexColor(1, 0.25, 0.15)
  af.texture = tex

  -- Skip button (right of arrow) — same as /br skip
  local skip = CreateFrame("Button", "BloodRouteSkipButton", af)
  skip:SetSize(22, 22)
  skip:SetPoint("LEFT", af, "RIGHT", 6, 0)
  skip:SetFrameLevel(af:GetFrameLevel() + 2)
  skip:RegisterForClicks("LeftButtonUp")
  skip:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
  skip:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
  skip:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  skip:SetScript("OnClick", function()
    if BR.Skip then BR:Skip() end
  end)
  skip:SetScript("OnEnter", function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Skip stop", 1, 0.92, 0.4)
    GameTooltip:AddLine("Go to the next closest unfinished spawn.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  skip:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  skip:Hide()
  af.skipBtn = skip

  local text = af:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("TOP", af, "BOTTOM", 0, -4)
  text:SetJustifyH("CENTER")
  text:SetTextColor(1, 0.92, 0.4)
  af.text = text

  -- Brief "N collected" tip above the arrow when nearing a previously looted spawn
  local collect = af:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  collect:SetPoint("BOTTOM", af, "TOP", 0, 6)
  collect:SetJustifyH("CENTER")
  collect:SetTextColor(0.85, 0.85, 0.85)
  collect:Hide()
  af.collectText = collect

  local hint = af:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("TOP", text, "BOTTOM", 0, -1)
  hint:SetText("Shift-drag | button to skip")
  af.hint = hint

  af.orientation = 0
  af.lowerbound = math.pi / 64
  af.upperbound = 2 * math.pi - af.lowerbound
  af._arriveCD = 0
  af.glowAlpha = 0
  af.glowWant = 0
  af.glowConfirmed = false
  af.pulse = 0

  af:SetScript("OnUpdate", function(frame, elapsed)
    BR:UpdateArrow(frame, elapsed)
  end)

  self.arrow = af
  return af
end

function BR:EnsureSkipButton(af)
  if not af or af.skipBtn then return af and af.skipBtn end
  local skip = CreateFrame("Button", "BloodRouteSkipButton", af)
  skip:SetSize(22, 22)
  skip:SetPoint("LEFT", af, "RIGHT", 6, 0)
  skip:SetFrameLevel(af:GetFrameLevel() + 2)
  skip:RegisterForClicks("LeftButtonUp")
  skip:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
  skip:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
  skip:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  skip:SetScript("OnClick", function()
    if BR.Skip then BR:Skip() end
  end)
  skip:SetScript("OnEnter", function(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Skip stop", 1, 0.92, 0.4)
    GameTooltip:AddLine("Go to the next closest unfinished spawn.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  skip:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  skip:Hide()
  af.skipBtn = skip
  if af.hint then af.hint:SetText("Shift-drag | button to skip") end
  return skip
end

function BR:SetArrowGlow(on, confirmed)
  local af = self:CreateArrow()
  af.glowConfirmed = confirmed and true or false
  if on or self.active then
    af:Show()
  end
end

function BR:UpdateArrow(af, elapsed)
  if self.disabled then
    af:Hide()
    return
  end
  af._arriveCD = math.max(0, (af._arriveCD or 0) - elapsed)
  af.pulse = (af.pulse or 0) + elapsed

  -- Hide legacy outer glow if present
  if af.glow then af.glow:Hide() end
  if af.glow2 then af.glow2:Hide() end

  -- Soft red tint on the arrow only (no pulsing square behind it)
  if af.texture then
    if af.glowConfirmed then
      af.texture:SetVertexColor(1, 0.2, 0.1)
    else
      af.texture:SetVertexColor(1, 0.28, 0.16)
    end
  end

  -- Show skip only while a route is running
  if af.skipBtn then
    if self.active and not self.disabled then
      af.skipBtn:Show()
    else
      af.skipBtn:Hide()
    end
  end

  local scanYards = (BloodRouteDB and BloodRouteDB.scanYards) or 20

  -- Do not re-pick "closest" every second while moving — that caused arrow flicker
  -- and brief wrong targets (yards going up). Retarget only on arrive/skip/map change.

  local live = self.scanHit and self.scanHit.confirmed and self.scanHit.node
  local routeNode = (self.active and self.route and self.route[self.index]) or nil
  local node = live or routeNode or self.scanTarget

  if not node then
    if not self.active then
      af:Hide()
    end
    return
  end

  -- Snap rotation immediately when the guided node changes (no one-frame wrong facing)
  local nodeKey = self.NodeKey and self:NodeKey(node)
  if nodeKey and af._targetKey ~= nodeKey then
    af._targetKey = nodeKey
    af.orientation = nil
    af._dwellStart = nil
  end

  local facing = GetPlayerFacing and GetPlayerFacing()
  if issecretvalue and issecretvalue(facing) then facing = nil end
  local angle, dist, wrong = self:VectorToNode(node)

  if wrong or not angle then
    af:Show()
    if af.texture.SetRotation then af.texture:SetRotation(0) end
    af.orientation = nil
    af._dwellStart = nil
    af.texture:Hide()
    if af.collectText then af.collectText:Hide() end
    if wrong then
      af.text:SetText(string.format("|cffff6666Travel to %s|r\n%.1f, %.1f · %d left", node.zoneName or "?", node.x, node.y, self.route and #self.route or 0))
    else
      af.text:SetText(string.format("Waiting for position\n%s (%.1f, %.1f)", node.zoneName or "?", node.x, node.y))
    end
    return
  end

  af:Show()
  if not facing then
    af.orientation = nil
    af.texture:Hide()
  else
    af.texture:Show()
    local orientation = angle - facing
    local diff = af.orientation and (math.abs(orientation - af.orientation) % (2 * math.pi))
    if not diff or (diff > af.lowerbound and diff < af.upperbound) then
      af.orientation = orientation
      if af.texture.SetRotation then
        af.texture:SetRotation(orientation)
      end
    end
  end

  local yards = math.floor((dist or 0) + 0.5)
  local nrLabel = node.nr and string.format("nr %d", node.nr) or "?"

  -- Brief tip when approaching a spawn you already looted blood from
  if af.collectText and self.GetSpawnLootCount then
    local collected = self:GetSpawnLootCount(node)
    local approachYards = scanYards + 25
    local key = (self.SpawnLootKey and self:SpawnLootKey(node)) or nrLabel
    if collected > 0 and yards <= approachYards then
      if af._collectToastKey ~= key then
        af._collectToastKey = key
        af._collectToastUntil = GetTime() + 3.5
        local label = collected == 1 and "1 collected" or (tostring(collected) .. " collected")
        af.collectText:SetText("|cffcccccc" .. label .. "|r")
        af.collectText:Show()
      end
    elseif yards > approachYards + 5 then
      af._collectToastKey = nil
    end
    if af._collectToastUntil and GetTime() > af._collectToastUntil then
      af.collectText:Hide()
    end
  end

  if live then
    af.text:SetText(string.format(
      "|cffff4400FOUND|r  |cffffffff%d yd|r\n|cffff3300Loot it|r  ·  skip ▶\n|cffaaaaaa%s|r",
      yards,
      nrLabel
    ))
  elseif self.active and self.route then
    local left = #self.route
    local atStop = yards <= scanYards
    if atStop then
      af.text:SetText(string.format(
        "|cff66ff66At stop|r  |cffffffff%d yd|r   |cffffff00%s|r · %d left\n|cffaaaaaaEmpty? auto-next|r",
        yards,
        nrLabel,
        left
      ))
    else
      af.text:SetText(string.format(
        "|cff66ff66Blood of Heroes|r\n|cffffffff%d yd|r   |cffffff00%s|r · %d left",
        yards,
        nrLabel,
        left
      ))
    end
  else
    af.text:SetText(string.format(
      "|cff66ff66Blood of Heroes|r\n|cffffffff%d yd|r   |cffffff00%s|r",
      yards,
      nrLabel
    ))
  end

  -- Arrive → mark checked and go to next closest (no "nearby spawn" false alerts)
  local arriveAt = scanYards
  if self.active and routeNode and not live then
    if dist and dist <= arriveAt then
      af._dwellStart = af._dwellStart or GetTime()
      if (GetTime() - af._dwellStart) >= 0.6 and af._arriveCD <= 0 then
        af._arriveCD = 0.8
        af._dwellStart = nil
        self:AdvanceNode("arrived")
      end
    else
      af._dwellStart = nil
    end
  else
    af._dwellStart = nil
  end
end

function BR:ShowArrow()
  self:CreateArrow():Show()
end

function BR:HideArrow()
  if self.arrow and not self.scanHit then
    self.arrow:Hide()
  end
end
