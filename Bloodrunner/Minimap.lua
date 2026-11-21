-- Minimap menu: dispatch to the same commands as /br.
local BR = BloodRoute

local function Command(cmd)
  SlashCmdList.BLOODROUTE(cmd)
end

local function EditBox(dialog)
  return dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
end

local function ApplyRange(editBox)
  Command("range " .. editBox:GetText())
end

StaticPopupDialogs.BLOODROUTE_RANGE = {
  text = "BloodRoute scan and arrival range (10–120 yards)",
  button1 = ACCEPT,
  button2 = CANCEL,
  hasEditBox = 1,
  maxLetters = 3,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  OnShow = function(dialog)
    local box = EditBox(dialog)
    box:SetText(tostring(BloodRouteDB.scanYards))
    box:HighlightText()
    box:SetFocus()
  end,
  OnAccept = function(dialog) ApplyRange(EditBox(dialog)) end,
  EditBoxOnEnterPressed = function(box)
    ApplyRange(box)
    box:GetParent():Hide()
  end,
}

StaticPopupDialogs.BLOODROUTE_CONFIRM = {
  text = "%s?",
  button1 = YES,
  button2 = NO,
  timeout = 0,
  whileDead = 1,
  hideOnEscape = 1,
  OnAccept = function(_, command) Command(command) end,
}

local function OpenMenu(button)
  if not (MenuUtil and MenuUtil.CreateContextMenu) then
    Command("help")
    return
  end
  MenuUtil.CreateContextMenu(button, function(_, root)
    local function Action(menu, label, cmd)
      menu:CreateButton(label, function() Command(cmd) end)
    end
    local function Confirm(menu, label, cmd)
      menu:CreateButton(label, function()
        StaticPopup_Show("BLOODROUTE_CONFIRM", label, nil, cmd)
      end)
    end
    root:CreateTitle("BloodRoute")
    local start = root:CreateButton("Start route")
    Action(start, "Both Plaguelands", "start")
    Action(start, "Eastern Plaguelands", "epl")
    Action(start, "Western Plaguelands", "wpl")
    Action(root, "Skip stop", "skip")
    Action(root, "Stop route", "stop")
    Action(root, "Reset route", "reset")
    Action(root, "Mark puddle here", "mark")
    Action(root, "Show status", "status")

    local options = root:CreateButton("Options")
    options:CreateCheckbox("Mouseover scanner", function() return BloodRouteDB.scanEnabled ~= false end,
      function() Command("scan") end)
    options:CreateCheckbox("Alert sound", function() return BloodRouteDB.scanSound ~= false end,
      function() Command("sound") end)
    options:CreateButton("Set scan range…", function() StaticPopup_Show("BLOODROUTE_RANGE") end)
    Action(options, "Quit addon", "quit")
    Action(options, "Show slash command help", "help")

    local clear = root:CreateButton("Clear saved data")
    Confirm(clear, "Clear FOUND pins", "clearfound")
    Confirm(clear, "Clear checked stops", "clearchecked")
    Confirm(clear, "Clear FOUND and checked stops", "clearall")
    Confirm(clear, "Reset lifetime loot counts", "clearloot")
  end)
end

function BR:SetupMinimap()
  if self.minimapButton or not Minimap then return end
  local button = CreateFrame("Button", "BloodRouteMinimapButton", Minimap)
  self.minimapButton = button
  button:SetSize(30, 30)
  button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetTexture(self.bloodIcon)
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  local ring = button:CreateTexture(nil, "OVERLAY")
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  ring:SetSize(50, 50)
  ring:SetPoint("TOPLEFT")
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local function Place()
    local angle = BloodRouteDB.minimapAngle or math.rad(225)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
      math.cos(angle) * (Minimap:GetWidth() / 2 + 5), math.sin(angle) * (Minimap:GetHeight() / 2 + 5))
  end
  Place()
  Minimap:HookScript("OnSizeChanged", Place)
  button:SetScript("OnDragStart", function(b)
    GameTooltip:Hide()
    b:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      if not mx or not my then return end
      local x, y = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      BloodRouteDB.minimapAngle = math.atan2(y / scale - my, x / scale - mx)
      Place()
    end)
  end)
  button:SetScript("OnDragStop", function(b) b:SetScript("OnUpdate", nil) end)
  button:SetScript("OnHide", function(b) b:SetScript("OnUpdate", nil) end)
  button:SetScript("OnClick", function(b, mouseButton)
    GameTooltip:Hide()
    if mouseButton == "RightButton" then
      Command("start")
    else
      OpenMenu(b)
    end
  end)
  button:SetScript("OnEnter", function(b)
    GameTooltip:SetOwner(b, "ANCHOR_LEFT")
    GameTooltip:AddLine("BloodRoute")
    GameTooltip:AddLine("Left-click: commands · Right-click: start EPL + WPL", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag to move", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end
