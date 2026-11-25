# Design to Impress (Roblox) — First Milestone

A round-based room-decorating game: a theme is revealed, everyone decorates their own empty
room, every room is shown and rated 1–5 stars, and the top 3 stand on the podium for coins and XP.

This folder is the **First Milestone** from the game plan: a playable round with **3 themes,
30 free items, voting and a podium**, plus coins, XP, levels, saving and a lobby leaderboard.
Everything (lobby, podium, rooms, furniture, UI) is built from code, so nothing has to be
built by hand in Studio.

## Open it in Roblox Studio

**Option A — the place file (easiest)**
1. Download `DesignToImpress.rbxlx` from this folder.
2. Double-click it, or in Studio choose **File → Open from File…**.
3. Press **Play**. A solo round starts after about 10 seconds.

**Option B — Rojo (if you'd like to keep editing the code in VS Code)**
1. Install [Rojo](https://rojo.space) and its Studio plugin.
2. Run `rojo serve` in this folder, then click **Connect** in the Rojo plugin.
   (`rojo build -o DesignToImpress.rbxlx` also builds the place file.)

To rebuild the place file after editing `src/` without Rojo: `python3 tools/build_place.py`.

### Turn on saving
DataStores only work once the game is published:
1. **File → Publish to Roblox**.
2. **Home → Game Settings → Security → Enable Studio Access to API Services**.

Without this the game still runs; progress just won't save (you'll see a warning in Output).

### Test with friends in Studio
**Test → Clients and Servers**, choose 2–3 players, then **Start**. That's the only way to
try voting properly, because you can't rate your own room.

## How a round works
| Phase | Studio | Live game |
|---|---|---|
| Intermission in the lobby | 10 s | 20 s |
| Theme reveal | 4 s | 4 s |
| Design (in your own room) | 90 s | 5 min |
| Showcase, per room (rate 1–5 stars) | 10 s | 10 s |
| Results and podium | 10 s | 10 s |

Rounds start with 1 player in Studio and 2 in the live game. All of these numbers, the themes
and the rewards live in `src/shared/Config.luau`.

## Controls
- **Catalogue** opens the item panel with five tabs: Furniture, Walls, Floors, Lighting, Decor.
  Walls and Floors apply to the whole room as soon as you tap them.
- **PC:** the item follows the mouse. Click to place, **R** rotates, **Q** finishes.
- **Phone or tablet:** tap the floor to move the item, then press **Place**. Rotate and Done are buttons.
- **Move** picks a placed item back up. **Delete** removes it.
- Items snap to a 1-stud grid, rotate in 90° steps, and can't overlap (rugs can go under things).
  The preview turns red when a spot is blocked.

## What's in the code
```
src/shared/        (ReplicatedStorage.Shared)
  Config.luau        timings, themes, rewards, room size
  Catalog.luau       the 30 items, built from simple Parts
  ItemBuilder.luau   builds item models; grid snapping and overlap maths shared by client and server
src/server/        (ServerScriptService.Server)
  Main.server.luau   entry point: builds the world, creates remotes, starts services
  WorldBuilder.luau  lobby, podium, leaderboard board, 12 room plots
  RoundManager.luau  the round loop, voting, results and rewards
  PlotService.luau   room assignment and server-side checks on every build action
  DataService.luau   coins, XP, levels and wins with DataStores, plus leaderstats
  LeaderboardService.luau  lobby board ranked by wins, then level
src/client/        (StarterPlayerScripts.Client)
  Client.client.luau entry point
  HUD.luau           phase, theme, timer, coins, level and XP bar, theme splash
  BuildController.luau  catalogue, ghost preview, place, rotate, move, delete
  ShowcaseUI.luau    showcase camera, star voting, results panel
  UI.luau            UI helpers and toast messages
```

The server never trusts the client. It checks the phase, that the room is yours, the item id,
the position (snapped and kept inside the room), overlaps, a room item cap and a rate limit.
Votes only count for the room currently on screen, and never for your own.

## Next steps (from the plan)
1. Play a few rounds with friends and tune the timings and rewards in `Config.luau`.
2. Add more themes in `Config.Themes` and more items in `Catalog.luau`. An item is a list of parts,
   and it's easy to swap in real meshes later.
3. Paid items: give an item a `Price` and add a coin check in `PlotService.Place` (marked with a comment).
4. Game passes and developer products (VIP, extra time, coin packs) through `MarketplaceService`.
5. A global leaderboard with an `OrderedDataStore`.

> **Note:** this code was written without access to Roblox Studio, so it hasn't been run yet.
> If anything errors on the first Play, copy the red text from the **Output** window and paste it
> to Claude to get a fix.
