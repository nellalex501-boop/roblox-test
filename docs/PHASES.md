# Build log: DESIGN → BUILD → TEST → FIX → RETEST → APPROVE

Every phase was approved only after its spec passed. Results come from
`lune run tests/run.luau` (see `build/test-report.md` after a run).

**Final run:** 80 cases and 1,069 checks, all passing.

The checks are headless; the real-Roblox checks are in
[STUDIO_TEST_PLAN.md](STUDIO_TEST_PLAN.md).

## Phase 1: Blockout
- **Design.**
  - Parade square at the centre with the spawn pads to the south.
  - Buildings around a road loop: Operations Center (N), Map Room (NW), Command HQ (E), Garage (W).
  - Open zones to the south: Hall of Commanders (SE), Event Area (SW), Canteen (S).
  - The Mission Board sits beside the spawn.
  - Target: every system within 20–30 s of spawn.
- **Build.** Blockout volumes, the road network and spawn pads, all from one layout config (`Config/Layout.luau`).
- **Test.** `01_blockout`: 8 cases, 212 checks. Covers spawn placement and facing, zone overlaps, entrance/interior scale against a Roblox character, walkability from spawn to every entrance and interaction point (2.5D navigation grid), walking times, and landmark visibility.
- **Fix.**
  - Lune's `CFrame.lookAt` mirrored the Z axis and produced false overlaps; the harness now uses a Roblox-correct version, verified by `00_harness`.
  - The dais was a single 1.2-stud ledge; it became two 0.6-stud steps.
- **Retest → approve.** Worst entrance walk 8.7 s.

## Phase 2: Architecture
- **Design.**
  - Late-Cold-War German/US base: concrete command block with a radome, brick HQ, corrugated garage and a canteen.
  - Stencilled signage, flags and signposts.
  - Muted palette tokens in `Config/Theme.luau`.
- **Build.** Buildings, roofs, windows, doors, flags, signs, the perimeter fence, gate and towers, barracks, the comms compound, the helipad and the landscape.
- **Test.** `02_architecture`: 11 cases, 191 checks. Covers:
  - render budgets: parts, SurfaceGui pixels, unculled GUIs
  - no bright or saturated colours, neon only on bulbs
  - a readable sign per zone from spawn, and signpost arrows aimed at their targets
  - navigation, boundary and spawn regressions, and sightlines to the landmarks
- **Fix.**
  - Over the SurfaceGui budget → flag and sign pixel densities reduced, distance culling added.
  - Gate barrier sat 4 studs outside the fence → moved.
  - The spawn camera ended up under the Mission Board roof → the board moved to z 44.5.
  - Gable roof math, window rotation, flag emblem design and pivots, and signpost arrow barbs corrected.
  - Flagpoles hid the tower sign → arc angles changed.
- **Retest → approve.**

## Phase 3: Interaction
- **Design.**
  - One ProximityPrompt-based registry (`Interactions.luau`) maps each station kind to a panel and tab.
  - Server services are authoritative: profiles, matchmaking, missions, leaderboards, events, garage and status.
  - Terminal-style UI matching the RTS HUD.
- **Build.**
  - Stations in every zone and the services.
  - Client: state store, custom prompt plates, window manager, eight panels, HUD and toasts.
- **Test.**
  - `03_core`: 9 cases, 73 checks. Pure logic: profiles, trackers, missions, queues, private lobbies, events.
  - `04_server`: 16 cases, 172 checks. The real server booted headlessly: every prompt, matchmaking for 1v1, 2v2, 4v4, quick and private, teleport data, missions, global and fallback leaderboards, event claims and rotation, garage, persistence merging, status displays.
  - `05_client`: 13 cases, 157 checks. Bridged server + client drive every station, button and key. Also covers touch and phone scaling, and exports UI previews.
- **Fix.**
  - The harness kept callbacks in weak-keyed tables, which lost them on GC; the registries are now strong-keyed.
  - The HUD indexed `card.Name`, which is the instance's own Name property, and crashed the client; it now uses FindFirstChild.
  - A private-lobby code was read from a destroyed TextBox.
  - A lobby code label collided with the header's name.
  - Timestamps stored in attributes lost precision (float32 in Lune) and showed a countdown of 55 s instead of 5 s; they are now kept in Lua.
  - Toasts covered open panels (now deferred), a grid overlapped on the customise tab, the leaderboard header text touched, and a theatre map label collided with a town marker.
  - DataStore save race while in flight, and repeated access-error warnings.
- **Retest → approve.**

## Phase 4: Detailing
- **Design.** A reusable prop library, plus an outdoor and an interior pass that keep entrances, crossings and prompt approaches clear. Parked vehicles, utility lines, light fittings (no shadows), smoke and fire.
- **Build.** `World/Props.luau`, `World/Details/` and `World/Effects.luau`: 215 floor props and about 1,600 parts.
- **Test.** `06_detailing`: 10 cases, 194 checks.
  - Budgets: 5,428 parts, 51 lights with no shadows, 4 particle effects.
  - Palette.
  - Every floor prop rests on the floor (±0.35 studs) and no collidable prop part cuts into existing geometry.
  - Navigation, spawn and sightline regressions.
  - A source anchor for every ambient sound.
- **Fix.**
  - A stray empty folder shadowed `Props.luau` and broke `require`.
  - The clash test found trucks cutting into the shed wall, a forklift backing into a display vehicle, a barracks bin inside the leaderboard wall, a floodlight inside the gate booth, and a bookshelf overlapping a filing cabinet.
  - The renders showed desk CRTs facing away from the operators and plaza benches facing the road.
- **Retest → approve.**

## Phase 5: Polish
- **Design.** Subtle ambient animation (radar, flags, lamps, CRT flicker, fire), distance-culled positional sound, a wind bed, an occasional helicopter flyby, and UI feedback: sliding toasts, pressed buttons, credit floater, promotion toast. Plus cleanup and a performance budget.
- **Build.** `client/Ambient/` and UI tweaks.
- **Test.** `07_polish`: 6 cases, 40 checks. Covers ambient behaviour, sound culling, flyby lifecycle, UI feedback, code hygiene (strict mode, headers, no stray prints, placeholders or deprecated calls) and the ambient cost (about 0.14 ms per frame headless).
- **Fix.**
  - The flyby found the wrong "Helipad" folder.
  - The harness tweens were instant; they now interpolate over time.
  - The harness lacked `Sound.IsPlaying`.
  - One multi-line log line.
- **Retest → approve.**

## Release
- `tools/bake.luau` writes `dist/ColdWarLobby.rbxl` (0.4 MB) with the lobby baked in.
- `08_release` (3 cases, 17 checks) verifies that the baked place matches the current source, that the server reuses the baked lobby instead of rebuilding it, and that a client starts its UI on it.
