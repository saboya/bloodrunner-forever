-- Blood of Heroes spawn points from Questie SoD corrections (object 176213).
-- Original Era/SoD coordinates are map % (0-100); the map IDs are shared with Forever.
BloodRoute = BloodRoute or {}
local BR = BloodRoute

-- Forever uses different EPL map bounds. WPL's bounds are unchanged.
-- QuestieDB UiMapAssignment comparison (Era 1.15.9.69722 → Forever 1.60.1.69893):
-- https://github.com/Questie/QuestieDB/blob/master/data/Forever/conversion.json
local scaleX, offsetX = 0.8997577709204458, -1.6464926382438023
local scaleY, offsetY = 0.9004358590984077, -3.7790494664060477
BR.isForever = WOW_PROJECT_ID == (WOW_PROJECT_CAMELOT or 18)
  or (GetBuildInfo and select(4, GetBuildInfo()) == 16001)

function BR:FromEraMapXY(mapID, x, y)
  if self.isForever and mapID == 1423 then
    return x * scaleX + offsetX, y * scaleY + offsetY
  end
  return x, y
end

function BR:ToEraMapXY(mapID, x, y)
  if self.isForever and mapID == 1423 then
    return (x - offsetX) / scaleX, (y - offsetY) / scaleY
  end
  return x, y
end

BloodRouteSpawns = {
  epl = {
    uiMapID = 1423,
    name = "Eastern Plaguelands",
    points = {
      {7.1, 50.7},
      {8, 54.5},
      {14.2, 64.7},
      {20, 61},
      {20.5, 66.9},
      {21.5, 73.9},
      {22.1, 85.1},
      {24.3, 88.2},
      {26, 74.7},
      {26.3, 70.5},
      {26.7, 69.5},
      {27.1, 75.6},
      {27.3, 64},
      {28.8, 86},
      {29.2, 78.8},
      {30.9, 65.5},
      {32, 71},
      {33.6, 32.6},
      {34, 80.2},
      {34.3, 67.8},
      {34.4, 76.9},
      {34.5, 25.8},
      {35.6, 73.3},
      {35.9, 75.8},
      {36.7, 38},
      {36.9, 70.6},
      {37.1, 65.7},
      {37.6, 68.5},
      {38.4, 31.1},
      {38.5, 54},
      {38.8, 26.7},
      {38.9, 36.1},
      -- removed inaccurate Plaguewood ridge pin {40, 49.9} (other-side entrance / mountain cross)
      {41.4, 79.7},
      {41.5, 65.7},
      {42.4, 75.8},
      {44.9, 32.9},
      {46.2, 70.8},
      {46.3, 64},
      {46.5, 74.8},
      {47.5, 40.8},
      {47.9, 80},
      {48.9, 67.2},
      {49.1, 35.5},
      {50.3, 45.5},
      {50.4, 77.4},
      {51.8, 70.3},
      {53.5, 50.7},
      {55.5, 58.7},
      {56.2, 63.9},
      {56.5, 76.1},
      {57.1, 81.9},
      {57.4, 71.9},
      {57.8, 76.1},
      {58.1, 79.7},
      {58.4, 64.8},
      {58.6, 79.6},
      {59.2, 62.2},
      {59.3, 80.9},
      {59.5, 76},
      {59.9, 67.5},
      {61.8, 70.2},
      {63.6, 67.7},
      {64.7, 65.4},
      {64.7, 81},
      {66.2, 53},
      {67.6, 66.8},
      {68.2, 70.6},
      {68.3, 74.6},
      {68.6, 78.4},
      {68.8, 80.8},
      {68.9, 83.3},
      {69, 71.5},
      {70.6, 80.8},
      {70.7, 69.5},
      {71.1, 75.3},
      {72.2, 78.4},
      {73.3, 77.2},
      {73.4, 69.8},
      {73.4, 82.1},
      {73.6, 76.8},
      {73.8, 51.1},
      {74.1, 83.8},
      {74.7, 58.7},
      {75.6, 55.3},
      {75.9, 83.5},
      {76.1, 78.2},
      {76.2, 50.4},
      {76.7, 72.4},
      {78.4, 57.5},
      {78.7, 67.3},
      {78.8, 63.5},
      {80.4, 59.8},
      {89.4, 85.314},
      {90.899, 86.875},
      {95.64, 78.639},
      {92.677, 95.731},
    },
  },
  wpl = {
    uiMapID = 1422,
    name = "Western Plaguelands",
    points = {
      {35.9, 57.4},
      {36.4, 53.7},
      {38.2, 56.3},
      {39.7, 69.4},
      {40.6, 73.1},
      {40.7, 57.4},
      {41.4, 62.1},
      {41.9, 70.5},
      {42.2, 54.9},
      {42.8, 64.2},
      {43.3, 68.3},
      {43.6, 70.4},
      {44.2, 65},
      {44.4, 71.6},
      {44.5, 53.3},
      {45.8, 71.5},
      {45.9, 51.1},
      {46.7, 34.4},
      {47, 59.9},
      {47, 67.1},
      {47.6, 70},
      {47.9, 53.1},
      {49.4, 68.1},
      {49.8, 33.3},
      {52.2, 66.5},
      {52.3, 55},
      {53, 64.2},
      {53.2, 66.5},
      {53.3, 65.1},
      {53.4, 63.4},
      {54.9, 27.1},
      {55.2, 69.4},
      {56.7, 34.7},
      {57.8, 66.4},
      {62, 58.3},
      {62.9, 57.2},
      {62.9, 57.9},
      {63.2, 59.2},
      {63.6, 75.4},
      {64, 48.7},
      {64.1, 57.9},
      {64.9, 74.4},
      {65.8, 76.8},
      {66.4, 42.1},
      {67, 53.9},
      {67.8, 84.6},
      {68, 44.7},
      {68.3, 81.4},
      {68.4, 77.1},
      {68.7, 49.2},
      {68.7, 79.2},
      {68.9, 73.8},
      {69.5, 78.6},
    },
  },
}

for _, zone in pairs(BloodRouteSpawns) do
  for _, xy in ipairs(zone.points) do
    xy[1], xy[2] = BR:FromEraMapXY(zone.uiMapID, xy[1], xy[2])
  end
end
