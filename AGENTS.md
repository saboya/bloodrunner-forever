# Bloodrunner agent handoff

Bloodrunner (BloodRoute in chat) is a Blood of Heroes farming-route addon for Eastern and Western Plaguelands. The original files targeted Classic Era/SoD (`11509`), not Retail. The port adds Blizzard's WoW: Forever 1.60.1 (`16001`) alongside the Classic target.

## Start here

1. Read the relevant Lua module below and its coverage in `tests/forever_smoke.lua` before editing.
2. Treat `Bloodrunner/` as the source of truth. Build install artifacts with `tools/package.py`; don't commit ZIPs or edit their contents by hand. Keep the install directory and addon ID `Bloodrunner` so existing `Bloodrunner.lua` SavedVariables still load.
3. The Lua modules are shared across clients. Keep the Lua 5.1-compatible syntax and run both smoke-test modes after changes. Gate Forever-only APIs rather than assuming Classic has them. If adding a Lua file, add it to both `.toc` files in dependency order.

## Code map

| File | Responsibility |
| --- | --- |
| `Bloodrunner/Spawns.lua` | Client detection, source waypoints, and Era ↔ Forever coordinate conversion. |
| `Bloodrunner/Route.lua` | Waypoint selection, EPL terrain heuristics, and remaining-stop ordering. |
| `Bloodrunner/Scanner.lua` | Player coordinates, bearing and distance, world tooltip detection, and manual marks. |
| `Bloodrunner/MapPins.lua` | FOUND/checked storage and world-map pin rendering. |
| `Bloodrunner/Arrow.lua` | Directional arrow, distance labels, skip button, and auto-arrival. |
| `Bloodrunner/Minimap.lua` | Draggable minimap button and native menu that delegates actions to `/br`. |
| `Bloodrunner/Core.lua` | Slash commands, saved data defaults, route lifecycle, and loot events. |
| `tests/forever_smoke.lua` | Mock WoW client that loads files in manifest order and exercises the main flows. |
| `tools/package.py` | Validate the tag and Forever manifest and build the install ZIP. |
| `.github/workflows/release.yml` | Test/package on PRs and `master` pushes; publish a release on version tag pushes. |

## Behavior to preserve

- Arrival or skip checks off a stop; only a matching world-object mouseover, your own loot, or `/br mark` creates a FOUND pin.
- Prefer unfinished stops in the current farm zone and retarget when crossing between EPL and WPL. Don't compare raw percentages across zones as if they shared a coordinate system.
- Starting a new route clears checked progress, not FOUND pins or lifetime loot counters. `/br stop` leaves detection on; `/br quit` shuts it off and suspends loot tracking until `/br start`.
- Right-clicking a FOUND pin removes only that saved record, not loot counts or current route progress. The minimap button stays available after `/br quit` so the user can restart from the menu.
- Forever navigation is standalone. Keep HereBeDragons optional on Classic and handle missing or restricted client data without inventing a bearing.

## What changed for Forever

- **Packaging:** Reorganized the original files, whose names contained literal backslashes, into a real `Bloodrunner/` addon directory with `Media/arrow.blp` and `Media/logo.png`. Added `Bloodrunner/Bloodrunner_Camelot.toc` for Forever, retaining the Classic `Bloodrunner/Bloodrunner.toc`. Both load the same Lua files in the same order and use `BloodRouteDB`. The Forever manifest has no dependencies.
- **Map coordinates (`Spawns.lua`, `Route.lua`):** Detect Forever via project ID `WOW_PROJECT_CAMELOT` (`18`) or interface `16001`. Forever keeps EPL/WPL map IDs `1423`/`1422`, but EPL has different map bounds. Reproject the original EPL coordinates and the terrain detour gate using the [QuestieDB map-bounds comparison](https://github.com/Questie/QuestieDB/blob/master/data/Forever/conversion.json). Convert back to Era coordinates when evaluating the original EPL terrain regions. WPL and Classic coordinates are unchanged. The original SoD waypoint list is not an exhaustive Forever spawn database.
- **Navigation (`Scanner.lua`, `Route.lua`, `Arrow.lua`, `Core.lua`):** Use Blizzard map APIs on Forever; Classic can still use HereBeDragons if installed. Normalize native north/west world coordinates before computing bearings and use map width and height for fallback distance calculations. Do not treat nearby percentages from different maps as nearby stops. Sort using one player-position snapshot; pick the next in-zone stop on start, arrival, skip, map change, or when position data returns. The arrow shows travel or waiting text when it can't guide, and distance-based auto-arrival can still work without a heading.
- **Find detection (`Scanner.lua`, `Core.lua`):** On Forever, read the world-cursor tooltip through `C_TooltipInfo.GetWorldCursor()` and match a Blood of Heroes object name, not a bag item or map tooltip. Ignore secret tooltip text and suppress repeat alerts for the same active hit. Classic retains its legacy tooltip path. Use the raid-warning sound kit when available. Wire up `/br mark` to manually confirm the nearest known stop within 25 yards. Proximity alone never creates a FOUND pin.
- **Loot and lifecycle (`Core.lua`):** Match item ID `12938` in localized self-loot messages and use the reported stack size. Ignore other players' loot and don't advance an unrelated stop when a nearby puddle is looted. `/br stop` stops the route but leaves detection running; `/br quit` also stops detection and loot tracking and hides pins. `/br start` re-enables them. Fresh runs reset checked stops but retain FOUND pins until cleared.
- **World map (`MapPins.lua`):** Fixed the invalid `:GetMapID` method-existence check. Attach FOUND pins to the map canvas and refresh on map show, map change, and canvas resize instead of polling. Set up hooks even if Blizzard's world-map addon loads after login. FOUND pins use the built-in Blood of Heroes item icon (`134813`) instead of the old green square; checked stops are route progress, not FOUND pins.

### Adaptation notes for future ports

1. **Separate the client API from the content data.** Forever uses the modern UI API despite using mostly Classic world content. Start from its interface number and client UI source (see [Gethe's Forever branch](https://github.com/Gethe/wow-ui-source/tree/forever)), not a numeric comparison against Retail versions. Use the client-specific manifest for metadata and guard client-specific code in shared modules.
2. **Verify map bounds before copying coordinates.** The EPL conversion is affine: `x' = x * 0.8997577709204458 - 1.6464926382438023`, `y' = y * 0.9004358590984077 - 3.7790494664060477`, using percentages, not normalized `0–1` values. The coefficients come from Era `1.15.9.69722` → Forever `1.60.1.69893` client map assignments. This is a change in map bounds, not evidence that terrain or spawns moved. Keep raw candidate data in Era space and avoid applying the conversion twice. For example, `(38.8, 26.7)` should display near `(33.3, 20.3)` on Forever. WPL needs no transform. A FOUND pin records the matching known waypoint, so don't change the whole transform based on one pin being slightly off the actual puddle. Capture several live player coordinates before revising the data.
3. **Use the correct coordinate space for each operation.** Route and pin records store map percentages; `C_Map` takes normalized coordinates, and its world-position vectors are north/west. Bearing calculations use the normalized west/north convention internally. A map-change event can arrive before position data is ready; keep the per-tick check that re-sorts when position returns.
4. **Validate confirmation paths independently.** On Forever, the tooltip data must be a world cursor object, not an item or map tooltip named Blood of Heroes. Keep `/br mark` as a fallback. Loot confirmation uses an item link plus localized self-loot templates; don't key it on English chat text or infer confirmation from proximity. To investigate a live report, distinguish the item icon or map placement, the route waypoint, and the actual player location at the puddle.

## Local verification and packaging

From the workspace root:

```sh
luajit tests/forever_smoke.lua
luajit tests/forever_smoke.lua classic
find Bloodrunner tests -name '*.lua' -exec luac -p '{}' \;
python3 tools/package.py
unzip -t dist/Bloodrunner-v1.4.10-forever.zip
```

Both smoke-test modes, Lua syntax checks, and ZIP integrity passed at the port handoff. The tests cover coordinate conversion, arrow bearings, auto-arrival, cross-zone retargeting, manual marking, Forever object-tooltip filtering, map pins, loot tracking, and quit/restart. They do not prove the live client behaves like the mocks.

## GitHub releases and WoWUp

- Repo and WoWUp **Install from URL**: `https://github.com/saboya/bloodrunner-forever`. Default branch: `master`. First published version: `v1.4.9`, following upstream SoD `1.4.8` and the local Forever builds.
- Release ZIP: `Bloodrunner-vMAJOR.MINOR.PATCH-forever.zip`. It has one addon folder. The packager writes the **Forever** manifest as `Bloodrunner/Bloodrunner.toc` inside the ZIP so the packaged addon and manager see the correct interface. The Classic manifest stays in source only. The ZIP includes `AGENTS.md` inside `Bloodrunner/` so the handoff ships without adding an extra top-level install entry.
- To release when requested: update `## Version` in `Bloodrunner/Bloodrunner_Camelot.toc`, run both smoke tests and `python3 tools/package.py vX.Y.Z`, and commit and push `master`. Then run `git tag -a vX.Y.Z -m "Release vX.Y.Z"` and `git push origin vX.Y.Z`. Use a new version rather than moving a published tag.
- The tag workflow validates the manifest version, runs both tests, and publishes with the workflow's `GITHUB_TOKEN`; no personal token secret is needed. Verify the Actions run and confirm the named ZIP is attached to the GitHub release, not just present as an Actions artifact. Test WoWUp discovery separately if a client is available.

## Next: live Forever verification

1. Install as described in `README.md`. Start `/br start` in EPL and check that the arrow points toward the intended stop, then advances on arrival. Cross into WPL and check that the next WPL stop is selected.
2. Mouse over and loot a real puddle. Confirm that the mouseover produces a FOUND alert, the pin is on the correct map, and `/br status` counts your pickup once.
3. Run `/reload` and confirm the pin and pickup count persist. If anything fails, record the client build, zone, command or action, and exact Lua error or observed behavior. Add a regression test where the failure can be reproduced in the mock.
