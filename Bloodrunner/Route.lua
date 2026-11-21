-- Covering route: visit fewer waypoints so walking within scanYards
-- "sees" every spawn (no node-to-node of every pin).

BloodRoute = BloodRoute or {}
local BR = BloodRoute

local function Dist2(ax, ay, bx, by)
  local dx, dy = ax - bx, ay - by
  return dx * dx + dy * dy
end

local function Dist(ax, ay, bx, by)
  return math.sqrt(Dist2(ax, ay, bx, by))
end

-- Approximate yards → map % for a uiMapID (sample 1% east of center).
function BR:YardsToMapPercent(uiMapID, yards)
  yards = yards or 18
  if self.WorldPos then
    local _, ax, ay = self:WorldPos(uiMapID, 50, 50)
    local _, bx, by = self:WorldPos(uiMapID, 51, 50)
    if ax and bx then
      local per = Dist(ax, ay, bx, by)
      if per > 0.5 then
        return yards / per
      end
    end
  end
  -- EPL/WPL rough fallback (~35–45 yd per 1%)
  return yards / 40
end

-- World-yard distance between two map-% points on the same map (bird path).
function BR:NodeDistanceYards(a, b)
  if not a or not b then return 999999 end
  if a.uiMapID ~= b.uiMapID then return math.huge end
  if self.WorldPos then
    local ca, ax, ay = self:WorldPos(a.uiMapID, a.x, a.y)
    local cb, bx, by = self:WorldPos(b.uiMapID, b.x, b.y)
    if ca and cb and ca == cb and ax and bx then
      return Dist(ax, ay, bx, by)
    end
  end
  local dx, dy = self:MapDeltaYards(a.uiMapID, b.x - a.x, b.y - a.y)
  return math.sqrt(dx * dx + dy * dy)
end

-- EPL map 1423: mountains block Plaguewood (north) ↔ western mountain nodes.
-- Walk around via the east loop (Corin's / SE) instead of bird path.
local EPL_MAP = 1423
-- Detour pin on the open east/south road around the massif
local gateX, gateY = BR:FromEraMapXY(EPL_MAP, 58, 62)
local EPL_EAST_GATE = { x = gateX, y = gateY, uiMapID = EPL_MAP }

function BR:EplRegion(x, y)
  if not x or not y then return "east" end
  x, y = self:ToEraMapXY(EPL_MAP, x, y)
  -- Plaguewood / northern basin (can't walk south into the mountains)
  if y < 48 and x >= 28 and x <= 56 then
    return "north"
  end
  -- Western mountain massif — approach from south/east only
  if x < 50 and y >= 48 then
    return "mountain"
  end
  if x < 28 then
    return "mountain"
  end
  return "east"
end

-- Walkable path distance (EPL north↔mountain goes via east gate).
function BR:PathDistanceYards(a, b)
  if not a or not b then return 999999 end
  local straight = self:NodeDistanceYards(a, b)
  if a.uiMapID ~= EPL_MAP or b.uiMapID ~= EPL_MAP then
    return straight
  end
  local ra = self:EplRegion(a.x, a.y)
  local rb = self:EplRegion(b.x, b.y)
  if (ra == "north" and rb == "mountain") or (ra == "mountain" and rb == "north") then
    return self:NodeDistanceYards(a, EPL_EAST_GATE) + self:NodeDistanceYards(EPL_EAST_GATE, b)
  end
  return straight
end

-- Greedy cover: pick waypoints so every spawn is within coverYards of one waypoint.
function BR:BuildCoveringSet(points, coverYards)
  coverYards = coverYards or 18
  if not points or #points == 0 then return {} end

  -- Split by map so we never cover across zones
  local byMap = {}
  for _, p in ipairs(points) do
    local id = p.uiMapID or 0
    byMap[id] = byMap[id] or {}
    byMap[id][#byMap[id] + 1] = p
  end

  local waypoints = {}
  for _, group in pairs(byMap) do
    local uncovered = {}
    for i, p in ipairs(group) do
      uncovered[i] = p
    end

    while #uncovered > 0 do
      local bestIdx, bestCount, bestList = 1, -1, nil
      for i, cand in ipairs(uncovered) do
        local covered = {}
        local count = 0
        for j, other in ipairs(uncovered) do
          if self:NodeDistanceYards(cand, other) <= coverYards then
            count = count + 1
            covered[#covered + 1] = j
          end
        end
        if count > bestCount then
          bestCount, bestIdx, bestList = count, i, covered
        end
      end

      local pick = uncovered[bestIdx]
      -- Attach which spawns this waypoint covers (indices into original group — store point refs)
      local covers = {}
      local removeSet = {}
      for _, j in ipairs(bestList or { bestIdx }) do
        covers[#covers + 1] = uncovered[j]
        removeSet[j] = true
      end
      pick.covers = covers
      pick.isCover = true
      waypoints[#waypoints + 1] = pick

      -- Remove covered from uncovered (high index first)
      local idxs = {}
      for j in pairs(removeSet) do idxs[#idxs + 1] = j end
      table.sort(idxs, function(a, b) return a > b end)
      for _, j in ipairs(idxs) do
        table.remove(uncovered, j)
      end
    end
  end

  return waypoints
end

-- Nearest-neighbor + 2-opt using walkable path distance (EPL mountain-aware).
function BR:OrderRoute(points, sx, sy)
  if not points or #points == 0 then return {} end

  local remaining = {}
  for i, p in ipairs(points) do
    remaining[i] = p
  end

  local route = {}
  local cx, cy = sx or points[1].x, sy or points[1].y
  local cMap = points[1].uiMapID
  local from = { x = cx, y = cy, uiMapID = cMap }

  while #remaining > 0 do
    local bestI, bestD = 1, nil
    for i = 1, #remaining do
      local p = remaining[i]
      local d = self:PathDistanceYards(from, p)
      if not bestD or d < bestD then
        bestI, bestD = i, d
      end
    end
    local pick = table.remove(remaining, bestI)
    route[#route + 1] = pick
    from = pick
  end

  local improved, guard = true, 0
  while improved and guard < 80 do
    improved = false
    guard = guard + 1
    for i = 1, #route - 2 do
      for k = i + 2, #route - 1 do
        local a, b, c, d = route[i], route[i + 1], route[k], route[k + 1]
        if not d then break end
        if a.uiMapID ~= b.uiMapID or c.uiMapID ~= d.uiMapID then
          -- skip 2-opt across zone edges
        else
          local before = self:PathDistanceYards(a, b) + self:PathDistanceYards(c, d)
          local after = self:PathDistanceYards(a, c) + self:PathDistanceYards(b, d)
          if after + 0.5 < before then
            local lo, hi = i + 1, k
            while lo < hi do
              route[lo], route[hi] = route[hi], route[lo]
              lo, hi = lo + 1, hi - 1
            end
            improved = true
          end
        end
      end
    end
  end

  return route
end

-- Full covering tour: one ordered path per zone, player's zone first, then the other.
-- Stops stay in this order for the whole run (no re-picking nearest each step).
function BR:BuildTour(points, coverYards, sx, sy, startMapID)
  coverYards = coverYards
    or (BloodRouteDB and BloodRouteDB.scanYards)
    or 18
  local covers = self:BuildCoveringSet(points, coverYards)
  if #covers == 0 then return {}, #points, 0 end

  local byMap = {}
  local mapIds = {}
  for _, wp in ipairs(covers) do
    local id = wp.uiMapID or 0
    if not byMap[id] then
      byMap[id] = {}
      mapIds[#mapIds + 1] = id
    end
    byMap[id][#byMap[id] + 1] = wp
  end

  table.sort(mapIds, function(a, b)
    if startMapID then
      if a == startMapID then return true end
      if b == startMapID then return false end
    end
    return a < b
  end)

  local tour = {}
  for _, mapID in ipairs(mapIds) do
    local group = byMap[mapID]
    local ox, oy = sx, sy
    if not startMapID or mapID ~= startMapID or not ox then
      ox, oy = group[1].x, group[1].y
    end
    local ordered = self:OrderRoute(group, ox, oy)
    for _, wp in ipairs(ordered) do
      tour[#tour + 1] = wp
    end
  end

  return tour, #points, #covers
end

function BR:BuildRoute(points, sx, sy, coverYards)
  local mapID = self.GetPlayerMapXY and select(1, self:GetPlayerMapXY())
  return self:BuildTour(points, coverYards, sx, sy, mapID)
end

function BR:WaypointFullyLogged(wp)
  if not wp then return true end
  if not self.IsSpawnAlreadyLogged then return false end
  if wp.covers and #wp.covers > 0 then
    for _, c in ipairs(wp.covers) do
      if not self:IsSpawnAlreadyLogged(c) then return false end
    end
    return true
  end
  return self:IsSpawnAlreadyLogged(wp)
end

function BR:DistanceToWaypoint(wp, mapID, mx, my)
  if not wp then return 999999 end
  if not mapID or not mx or not my or mapID ~= wp.uiMapID then return math.huge end
  -- EPL: use walkable path (north↔mountain via east), not bird path over peaks
  return self:PathDistanceYards({ x = mx, y = my, uiMapID = mapID }, wp)
end

-- Drop completed stops, then order by walkable path (this zone first).
-- opts.stickyKey: keep that stop as #1 unless another is stickySlack+ yards closer.
function BR:ResortFromPlayer(opts)
  opts = opts or {}
  local stickyKey = opts.stickyKey
  local stickySlack = opts.stickySlack or 60

  local keep = {}
  for _, wp in ipairs(self.remaining or {}) do
    if not self:WaypointFullyLogged(wp) then
      keep[#keep + 1] = wp
    end
  end
  local mapID, mx, my = self:GetPlayerMapXY()
  local distances, order = {}, {}
  for i, wp in ipairs(keep) do
    distances[wp] = self:DistanceToWaypoint(wp, mapID, mx, my)
    order[wp] = i
  end
  table.sort(keep, function(a, b)
    local aHere = mapID and a.uiMapID == mapID
    local bHere = mapID and b.uiMapID == mapID
    if aHere and not bHere then return true end
    if bHere and not aHere then return false end
    if distances[a] == distances[b] then return order[a] < order[b] end
    return distances[a] < distances[b]
  end)

  if stickyKey and #keep > 1 then
    local stickyIdx, stickyWp
    for i, wp in ipairs(keep) do
      if self:NodeKey(wp) == stickyKey then
        stickyIdx, stickyWp = i, wp
        break
      end
    end
    if stickyWp and stickyIdx > 1 then
      local bestDist = distances[keep[1]]
      local stickyDist = distances[stickyWp]
      if stickyDist <= bestDist + stickySlack then
        table.remove(keep, stickyIdx)
        table.insert(keep, 1, stickyWp)
      end
    end
  end

  self.remaining = keep
  self.route = keep
  self.index = 1
  return #keep
end

function BR:SyncTour()
  return self:ResortFromPlayer()
end

function BR:CollectPoints(mode)
  mode = mode or "both"
  local out = {}
  local function addZone(key)
    local z = BloodRouteSpawns and BloodRouteSpawns[key]
    if not z then return end
    for i, xy in ipairs(z.points or {}) do
      out[#out + 1] = {
        x = xy[1],
        y = xy[2],
        uiMapID = z.uiMapID,
        zone = key,
        zoneName = z.name,
        nr = i, -- 1-based index in Spawns.lua for that zone (epl/wpl)
      }
    end
  end
  if mode == "epl" or mode == "both" then addZone("epl") end
  if mode == "wpl" or mode == "both" then addZone("wpl") end
  return out
end
