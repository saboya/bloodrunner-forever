-- Run from the workspace root: luajit tests/forever_smoke.lua [classic]
local classic = arg[1] == "classic"
WOW_PROJECT_ID = classic and 2 or 18
WOW_PROJECT_CAMELOT = 18
GetBuildInfo = function() return nil, nil, nil, classic and 11509 or 16001 end

local map, x, y, now, facing = 1423, 0, 0, 100, 0
local noPosition = false
local events = {}
local messages = {}
local function noop() end
local methods = {}
local function widget()
  return setmetatable({ scripts = {}, shown = true }, { __index = methods })
end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:GetScript(name) return self.scripts[name] end
function methods:HookScript(name, fn) self.scripts[name] = fn end
function methods:RegisterEvent(name) events[name] = self end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:SetTexture(texture) self.textureID = texture end
function methods:SetRotation(angle) self.angle = angle end
function methods:SetPoint(...) self.point = { ... } end
function methods:GetWidth() return 1000 end
function methods:GetHeight() return 500 end
function methods:GetMapID() return self.map end
function methods:GetCanvas() return self.canvas end
function methods:OnMapChanged() end
methods.CreateTexture = widget
methods.CreateFontString = widget
for _, name in ipairs({ "SetAllPoints", "SetSize", "EnableMouse", "RegisterForDrag", "RegisterForClicks",
  "SetClampedToScreen", "SetMovable", "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture",
  "SetFrameStrata", "SetFrameLevel", "SetTextColor", "SetJustifyH", "SetVertexColor",
  "SetParent", "ClearAllPoints", "HighlightText", "SetFocus" }) do methods[name] = noop end
function methods:GetFrameLevel() return 1 end

CreateFrame = widget
UIParent = widget()
Minimap = widget()
GameTooltip = widget()
GameTooltip:Hide()
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) messages[#messages + 1] = msg end }
SlashCmdList = {}
StaticPopupDialogs = {}
local popup
StaticPopup_Show = function(name, _, _, data)
  local dialog = widget()
  if classic then
    dialog.editBox = widget()
  else
    local box = widget()
    dialog.GetEditBox = function() return box end
  end
  local info = assert(StaticPopupDialogs[name])
  popup = { dialog = dialog, accept = function() info.OnAccept(dialog, data) end }
  if info.OnShow then info.OnShow(dialog) end
end
local menu
local function menuItem(action)
  local item = { action = action }
  function item:CreateTitle() end
  function item:CreateButton(label, callback)
    self[label] = menuItem(callback)
    return self[label]
  end
  function item:CreateCheckbox(label, selected, callback)
    local entry = self:CreateButton(label, callback)
    entry.selected = selected
    return entry
  end
  return item
end
MenuUtil = { CreateContextMenu = function(owner, build)
  menu = menuItem()
  build(owner, menu)
end }
Enum = { TooltipDataType = { Item = 0, Object = 4 } }
C_TooltipInfo = { GetWorldCursor = function() return GameTooltip.data end }
GetPlayerFacing = function() return facing end
GetTime = function() return now end
time = GetTime
strlower = string.lower
strtrim = function(s) return (s:match("^%s*(.-)%s*$")) end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
PlaySoundFile = noop
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %1$sx%2$d."
C_Timer = { After = function(_, fn) fn() end }
hooksecurefunc = function(obj, key, hook)
  local original = obj[key]
  obj[key] = function(...) original(...); hook(...) end
end

function CreateVector2D(a, b)
  return { x = a, y = b, GetXY = function(self) return self.x, self.y end }
end
C_Map = {
  GetBestMapForUnit = function() return map end,
  GetPlayerMapPosition = function() if not noPosition then return CreateVector2D(x / 100, y / 100) end end,
  GetMapWorldSize = function() return 4300, 2867 end,
  GetWorldPosFromMapPos = function(id, pos)
    -- Native vectors are north/west; 0 is a valid continent ID.
    return 0, CreateVector2D(4000 - 2867 * pos.y, -4300 * pos.x - (id == 1423 and 2400 or 0))
  end,
}

local toc = classic and "Bloodrunner.toc" or "Bloodrunner_Camelot.toc"
for line in io.lines("Bloodrunner/" .. toc) do
  if line:match("%.lua$") then dofile("Bloodrunner/" .. line) end
end
local BR = BloodRoute
local br = SlashCmdList.BLOODROUTE
local function event(name, ...)
  local f = assert(events[name], name)
  f:GetScript("OnEvent")(f, name, ...)
end
local function close(a, b) assert(math.abs(a - b) < 0.00001, tostring(a) .. " ~= " .. tostring(b)) end

assert(BR.isForever == (not classic))
local epl = BR:CollectPoints("epl")[1]
local wpl = BR:CollectPoints("wpl")[1]
close(epl.x, classic and 7.1 or 4.7417875352914)
close(epl.y, classic and 50.7 or 41.873047589883)
close(wpl.x, 35.9)
close(wpl.y, 57.4)
local eraX, eraY = BR:ToEraMapXY(1423, epl.x, epl.y)
close(eraX, 7.1)
close(eraY, 50.7)

event("PLAYER_LOGIN")
local minimap = assert(BR.minimapButton)
minimap:GetScript("OnClick")(minimap, "LeftButton")
local scanner = menu.Options["Mouseover scanner"]
assert(scanner.selected())
scanner.action()
assert(not scanner.selected())
scanner.action()
menu.Options["Set scan range…"].action()
local box = classic and popup.dialog.editBox or popup.dialog:GetEditBox()
assert(box:GetText() == "20")
box:SetText("25")
popup.accept()
assert(BloodRouteDB.scanYards == 25)
br("range 20")
WorldMapFrame = widget()
WorldMapFrame.canvas = widget()
WorldMapFrame.map = map
event("ADDON_LOADED", "Blizzard_WorldMap")
assert(BR._mapHooked)

x, y = epl.x - 1, epl.y
local angle, distance = BR:VectorToNode(epl)
close(angle, 1.5 * math.pi)
close(distance, 43)
local native = C_Map.GetWorldPosFromMapPos
C_Map.GetWorldPosFromMapPos = nil
angle, distance = BR:VectorToNode(epl)
close(angle, 1.5 * math.pi)
close(distance, 43)
C_Map.GetWorldPosFromMapPos = native

x, y = epl.x, epl.y
menu["Start route"]["Both Plaguelands"].action()
assert(BR.route[1].nr == 1 and BR.route[1].uiMapID == 1423)
assert(#BR._activePins == 0)
facing = nil -- Distance and auto-arrival still work without a heading.
BR:UpdateArrow(BR.arrow, 0.1)
now = now + 1
BR:UpdateArrow(BR.arrow, 1)
assert(BR.route[1].nr ~= 1)
assert(BR:IsSpawnAlreadyLogged(epl))

map, x, y = 1422, wpl.x, wpl.y
noPosition = true
event("ZONE_CHANGED_NEW_AREA")
assert(BR.route[1].uiMapID == 1422)
noPosition = false
BR:ScanTick()
assert(BR.route[1].nr == 1)

br("stop")
WorldMapFrame.map = map
WorldMapFrame:Hide()
if not classic then
  GameTooltip:Show()
  GameTooltip.data = { type = Enum.TooltipDataType.Item, lines = { { leftText = "Blood of Heroes" } } }
  BR:ScanTick()
  assert(not BR.scanHit)
  GameTooltip.data.type = Enum.TooltipDataType.Object
  BR:ScanTick()
  assert(BR.scanHit and BR.scanHit.source == "tooltip")
  GameTooltip:Hide()
end

br("mark")
assert(BR.scanHit and BR.scanHit.source == "manual")
WorldMapFrame:Show()
WorldMapFrame:OnMapChanged()
assert(#BR._activePins == 1)
assert(BR._activePins[1].tex.textureID == 134813 and BR._activePins[1].tex:IsShown())
close(BR._activePins[1].point[4], 359)
close(BR._activePins[1].point[5], -287)

local link = "|cff00ff00|Hitem:12938::::::::|h[Blood of Heroes]|h|r"
event("CHAT_MSG_LOOT", "Someone receives loot: " .. link .. ".")
assert(BR:GetBloodsLooted() == 0)
event("CHAT_MSG_LOOT", "You receive loot: " .. link .. "x2.")
assert(BR:GetBloodsLooted() == 2 and BR:GetSpawnLootCount(wpl) == 2)
local other = BR:CollectPoints("wpl")[2]
BR:RecordFound(other)
assert(#BR._activePins == 2)
for _, pin in ipairs(BR._activePins) do
  if pin.data.x == wpl.x and pin.data.y == wpl.y then
    local click = pin:GetScript("OnClick")
    click(pin, "LeftButton")
    assert(#BR._activePins == 2)
    click(pin, "RightButton")
    break
  end
end
assert(#BR._activePins == 1 and BR._activePins[1].data.x == other.x)
assert(not BR:IsSpawnAlreadyLogged(wpl) and BR:IsSpawnAlreadyLogged(other))
assert(BR:GetSpawnLootCount(wpl) == 2 and BR:GetBloodsLooted() == 2)
menu["Clear saved data"]["Clear FOUND pins"].action()
assert(#BR._activePins == 1)
popup.accept()
assert(#BR._activePins == 0)
br("quit")
event("CHAT_MSG_LOOT", "You receive loot: " .. link .. ".")
assert(BR.disabled and not BR._scanFrame and BR:GetBloodsLooted() == 2)
local previousMenu = menu
minimap:GetScript("OnClick")(minimap, "RightButton")
assert(BR.active and BR._scanFrame and BR.arrow:GetScript("OnUpdate"))
assert(BloodRouteDB.mode == "both" and menu == previousMenu)

print((classic and "Classic" or "Forever") .. " smoke test passed")
