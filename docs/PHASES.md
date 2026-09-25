# Build log: DESIGN → BUILD → TEST → FIX → RETEST → APPROVE

Every phase was approved only after its spec passed. Results come from
`lune run tests/run.luau` (see `build/test-report.md` after a run).

**Final run:** 83 cases and 1,112 checks, all passing.

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
  - Budgets: 5,429 parts, 51 lights with no shadows, 4 particle effects.
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
- It also writes the insert kit, `dist/InsertKit`: one model file per service for adding the lobby to an existing place such as Place1.
- **Design.** Copying into another place loses two things:
  - The StarterPlayer camera zoom limit. The client now applies it itself.
  - The lobby's position. Studio can shift a pasted or inserted model, while the layout, zones and HUD use world coordinates. An invisible `LobbyOrigin` marker lets the server move the lobby back at start-up.
- **Test.** `08_release` (6 cases, 60 checks) verifies:
  - The baked place and every kit file match the current source.
  - The server reuses the baked lobby instead of rebuilding it, and a client starts its UI on it.
  - The kit, inserted into a fresh Baseplate place with the lobby shifted by 40 studs, boots: the template is moved aside, the lobby returns to the origin with its spawn pads at their baked positions, a commander joins, and the camera limit applies.
- **Fix.** A mutation check (snap-back and zoom limit removed, then rebaked) made the kit tests fail as expected. Restored and rebaked.

## Review pass (41 findings)
A review listed 41 problems in four groups, plus requests for more detail, a
realistic parking lot and a single-vehicle Garage. Each fix follows the same
loop, and the new `09_visual` spec keeps the visual ones fixed.

- **Flicker (#1–#8).**
  - An exact coplanar-face detector (`tests/lib/Geometry.luau`) checks every pair of same-facing faces within 0.045 studs that overlap and are not buried in a third part.
  - Visible overlaps went from 1,563 to 0. Fixes include: Ops pads and edges raised and inset; parapets proud of the roof slabs; decorations 0.05+ off their base; road markings at +0.06; butt-jointed roads, kerbs, plinths and accent bands; Mission Board layers 0.06 apart; theatre-map layers stacked; floor slabs inset under walls with a front lip; sandbag runs stacked at different course heights; pine plates outside their face planes.
  - The detector itself measured gaps with a rounded shared normal; it now measures the true plane gap at each overlap.
  - #9: CRTs restore their own brightness. #10: signs render to 250+ studs, flags animate every frame, fire light uses smooth noise.
- **Placement (#11–#22).**
  - Status-board posts moved outside the boards; leaderboards centred between the canopy columns.
  - The vehicle camera clamps its distance with a ray so it never ends up behind a wall.
  - Mission Board items moved to empty cork.
  - Building plates moved to measured solid wall (between windows, columns, struts and porch pillars); the Garage sign dropped below the roof overhang; the HQ name moved onto a portal entablature.
  - Operations hall signs hang at two heights and the hall lights hang above them, so from the doorway no sign hides another or the wall display.
  - Street lamps moved off the guard booth's glass and away from flagpoles.
  - The public road bends away into the woods at both ends; two rings of irregular hills and a 2048-stud ground hide the map edge.
  - Theatre-map labels are placed greedily so none covers another label or a marker.
  - Clipping: parked cars (parking redesign), the typewriter inside the monitor, the guy anchor, doubled fence posts, bikes on door steps.
  - **Found on the way:** the stone plinths of the Map Room, Command HQ and Operations Center ran across their doorways at knee height (1.6–2.2 studs), so players had to jump in. The navigation test missed it because it sampled a 1-stud grid and the plinths were 0.4 deep. The plinths now stop at the door frames, the navigation grid samples thin parts on a 4×4 sub-grid (6 destinations became unreachable with the old plinths), and a doorway ray test was added.
- **Theme (#23–#31).**
  - The regiment flag is an 11th ACR cavalry pennant, the Pact flag is gone, the NATO flag has the real compass rose, and flags read correctly from both sides.
  - The Event Area is a bounded winter warfare training yard kept white by two snow guns: one snow cover cut around the walkway and tent, soft drifts, snow on the tent roof, falling snow, snowy pines, and a cool frost grade that fades in while the camera is inside (client, tested).
  - Lamps switch with the time of day; string lights removed; the fire barrel is in the winter yard and burns with particle flames, embers and smoke.
  - Chain-link fences with one post per corner.
  - The Command HQ is a German-built Kaserne block: plaster, steep clay-tile roof with dormers, sandstone portal.
  - Wording: American spelling, Zulu time, one name per place (HALL OF COMMANDERS), matching terminal numbers.
- **Looks and UI (#32–#41).** Brighter interiors and ShadowMap lighting; pyramid-tier pines in clusters; ridges of several hills with rock outcrops; flags of 6+ segments; windows set into the walls with frames; painted signs lit by the scene; panels close with ✕ or X instead of Esc.
  - #39: a new test measures the rendered height of every text on a surface (box height per line, box width per character, size caps). 51 labels were under a quarter stud. They now all pass: shorter wording on the Mission Board, the Ops terminal screens, the Garage placards and swatches and the event briefing desk; bigger boards where the text needs the room (DIESEL tank, HALT sign, road signs sized to their subtitle); larger theatre-map markers.
  - #40: the Matchmaking panel's empty right half now holds a mode briefing: three rules of engagement, the match length and the likely battlefield drawn as a small map. That is your preferred map when it suits the mode, otherwise the first map of the mode's pool (for example RIVER CROSSING for 4v4). The briefing stays while you are in the queue.
- **Detail.** A realistic staff parking lot (access lane, 14 stalls sized for the cars, wheel stops, lamps on the planting strips, reserved spaces, oil stains, footpath); detailed bicycles; a snow-gun carriage with hose and hydrant; a pulk and skis; the briefing desk rebuilt. Recreation grounds on the open lawns: a softball diamond south of the winter yard (infield, mound, bases, backstop, dugouts, bleachers, outfield fence, scoreboard), a seven-obstacle assault course behind the Map Room (dirt track, chalk start and finish lines, a numbered marker at each obstacle) and groups of old broadleaf trees.
- **Budgets.** Parts 9,000 → 12,000 and particles 20 → 60 per second: the added parts are nearly all decor, and the particles are the fire, two snow guns and the snowfall.
- **Final run.** 92 cases, all passing, on the rebaked place: 11,283 parts, 70 lights (43 on by day, none casting shadows), 261 SurfaceGuis. Previews of the result: `docs/previews/review-*.png` and `docs/previews/ui/review-*.png` (approximate renders, not Roblox).

## Second review pass (critical map review)
A second, deliberately picky walk over the whole map: every area rendered
from the corners and backs nobody walks past on purpose, plus automated
probes for floating parts, text with something in front of it, trees in
structures and dead-end roads (`tests/lib/Audit.luau`). About 30 findings,
many with several instances. All are fixed (two were preview-renderer bugs, not game bugs), and `09_visual` gained nine
cases so they stay fixed.

- **Bugs.**
  - Floating parts: bench backrests leaned forward and hung over the seat (now tilted back on posts); the assault-course trestles, engine hoist and rope frame splayed the wrong way (rebuilt as members meeting at the apex, the rope frame's legs lapped side by side); climbing-wall struts, bleacher rails, the heli tail rotor, tropo feed horns, every building number plate (each stood 0.2 off its wall), wall-clock labels, room signs, the HQ office map and beret, trophy-case mullions, the showroom backdrop and the Map Room display lamps all touch what carries them now.
  - Trophies stood inside a solid block: the awards case is an open cabinet with a velvet back and three shelves.
  - Clashes: a tree in the water tower, pines through the fences, oil drums and tyres inside each other and inside the M35, bikes in walls, a cabinet in the dado.
  - Covered text: the event billboard's posts ran across its face (now behind it), a post stood in front of the RESERVED signs, and the RESTRICTED stamp was cut at the card edge. In the previews the paint-scheme names ran over each other and the vending machine's label looked covered. Close-ups show both clear now; the paint names were a renderer bug (single-word scaled text overflowing its box), fixed in `tools/render/gui.js`.
- **Layout.**
  - Three roads ended in the grass. The north road now runs to a west lane, and two service lanes join the north and south roads behind the Garage and the Command HQ into one loop.
  - Barracks doors opened onto grass, and Barracks 203 faced the Hall's side wall 4 studs away. Each barracks front has a footpath to the road network, and 203 is set back on an open lawn. Barracks 202 no longer faces a bare grass strip: the west lane runs there.
  - From the spawn pads, a lobby-status board hid the Map Room. The two boards now flank the Operations Center.
  - The Hall of Commanders' front columns cut the board titles. The canopy now hangs from wall columns with knee braces.
- **Look.**
  - Interiors had black voids for ceilings and black windows. There are now light ceilings in the Operations Center, Map Room, Command HQ and canteen, and plain windows on the backs. The Map Room's clerestories moved above the displays.
  - Blank walls got windows (the HQ back on both storeys, the Ops back, the Map Room back, the canteen's kitchen side with a service door, a step and a canopy), and the HQ entry hall got the regiment plaque.
  - Doors have frames, glazing and handles, and the watch-desk CRTs show text. The Garage has lighter cladding and lights under its tie beams.
  - The event tent's sign stands on two posts by the entrance (it lay on the roof slope).
  - Vehicles: bicycles have spoked rims; cars have real proportions (a 15-stud saloon, a 13-stud hatchback, a 15.6-stud bus); the T-80 has a faceted turret, a mantlet and tracks; the helicopter stands on its skids.
  - The windsock is one tapered sleeve, the comms mast is banded red and white, and the field kitchen is olive.
  - The canteen got tables, a counter, a menu board, a dartboard, a TV and a coat rack.
- **Found by the new tests.** Rebuilding so much brought new problems, and the tests caught them:
  - 16 flickering face pairs: car tyres flush with the body sides, the trophy case's top, sides and plinth, locker vents, the TV glass, the bullseye, floodlight brackets, rope-frame legs, billboard posts, and the heli tail hub.
  - The courtyard's planter trees hid the canteen sign, so the planters hold clipped shrubs now. The Mission Board also hides that sign from the middle of the parade square, so name boards stand above the courtyard wall beside both side openings. From 7 of 8 pads one is in view, and from the eighth the signpost plate naming the canteen is.
  - Barracks 203's number faced the Hall's back wall 10 studs away. It is on the gable facing the path now.
  - Signs stood off their walls: the HQ door plates by 0.04, the Map Room name plates by 0.23, the Hall boards, the tower, Map Room and HQ signs and the clock labels by 0.05, the yard sign 0.07 in front of its posts. All sit flush now (0.02 into the surface).
  - The canteen clock hung half in the door opening, with its label in the opening. It hangs over the till now.
  - From a first-person eye at the Ops door, the QUICK desk's CRTs covered the deployment board's last two lines. The display is 0.6 higher, and all its text sits above the lowest fifth.
- **Tests.** Nine new `09_visual` cases:
  - Every visible part rests on the ground or on another part.
  - No part stands within 3 studs in front of any label.
  - No tree cuts into anything.
  - Both ends of every road join another road.
  - Every barracks door opens onto a footpath that reaches a road.
  - Each zone's sign is in view from at least 6 of the 8 spawn pads (camera turned toward it, popping in front of anything between it and the head), and the zone is named in view from every pad.
  - Nothing stands between a reader and any Hall board.
  - The Ops wall display is in full view of the doorway camera, and every board line is in view of a first-person eye.
  - 62 wall-mounted signs sit within 0.03 of their surface.
  - A mutation check broke six things at once: removed the canteen name boards, moved a footpath, shortened the north road, pulled the name plates off the wall, lowered the Operation line and lifted the door plates. Each broke exactly its test. Everything was restored afterwards.
- **Renderer.** A pixel-rounding bug in the preview renderer drew some scaled text at 1 px (for example the deployment board's header). It only affected the preview images, and it is fixed.
- **Final run.** 101 cases, all passing, on the rebaked place: 11,824 parts, 70 lights (43 on by day, none casting shadows), 271 SurfaceGuis, 0 visible coplanar overlaps. New previews: `docs/previews/review-canteen-*.png`, `review-barracks-203.png`, `review-maproom-displays.png` and `review-ops-wall-door.png` (approximate renders, not Roblox).
