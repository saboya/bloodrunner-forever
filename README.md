# Bloodrunner for WoW: Forever

Bloodrunner (called BloodRoute in chat) is a Blood of Heroes route helper for Eastern and Western Plaguelands. This port targets WoW: Forever 1.60.1, interface `16001`, with no addon dependencies. The original Classic manifest is still included.

## Install

In WoWUp, select **WoW Forever → Get Addons → Install from URL** and paste `https://github.com/saboya/bloodrunner-forever`.

For manual installation, download `Bloodrunner-v<version>-forever.zip` from [GitHub Releases](https://github.com/saboya/bloodrunner-forever/releases), not GitHub's automatic source archive. Extract it into `World of Warcraft/_forever_/Interface/AddOns/` so the manifest is at `Interface/AddOns/Bloodrunner/Bloodrunner.toc`. Restart WoW if this is a new installation. If updating an earlier manual port, replace the old addon directory rather than merging it, so its old `Bloodrunner_Camelot.toc` doesn't take precedence. SavedVariables live separately under `WTF`.

## Use

Left-click the Blood of Heroes icon on the minimap to open the command menu, or right-click it to start a fresh EPL + WPL route (`/br start`). Drag it to move it around the minimap. On the **world map**, right-click a Bloodrunner FOUND pin to remove only that pin. This doesn't reset loot counts or add the stop back to a route already in progress.

| Command | What it does |
| --- | --- |
| `/br start` | Start an EPL + WPL route. |
| `/br epl` or `/br wpl` | Route through one zone. |
| `/br skip` | Check off the current stop and pick the next one. |
| `/br mark` | Manually mark a puddle at the nearest known stop (within 25 yards). |
| `/br stop` | Stop the route, but keep mouseover detection running. |
| `/br quit` | Turn off the route, scanner, loot tracking, and map pins. `/br start` re-enables them. |
| `/br clearfound` | Remove FOUND map pins so those stops can be included in the next run. |
| `/br status` | Show pickup counts and current route progress. |

The route uses the original SoD waypoint list, reprojected onto Forever's changed EPL map using [QuestieDB's map bounds comparison](https://github.com/Questie/QuestieDB/blob/master/data/Forever/conversion.json). WPL uses the original coordinates. These are candidate stops, not an exhaustive Forever spawn list or a way to detect unobserved world objects. Only mouseover, your own loot, or `/br mark` can confirm a find; arrival alone checks off a stop. Starting a new run resets checked stops but keeps FOUND pins.

## Verification

Run `luajit tests/forever_smoke.lua` and `luajit tests/forever_smoke.lua classic` from the workspace root. The tests mock the WoW APIs; they do not replace a live-client check. In Forever, try `/br start` in EPL, check that moving to a stop advances the arrow, then cross into WPL. Mouse over and loot a real puddle, check its FOUND pin and `/br status`, and confirm that saved counts survive `/reload`.

## Release

Pull requests and pushes to `master` run both smoke tests and upload a ZIP as an Actions artifact. To publish a release, set `## Version` in `Bloodrunner/Bloodrunner_Camelot.toc`, commit and push the change, then push the matching annotated `vMAJOR.MINOR.PATCH` tag. Actions verifies the version and publishes the `-forever.zip` asset. Run `python3 tools/package.py` to package locally without publishing. See [AGENTS.md](AGENTS.md) for the release handoff and port details.
