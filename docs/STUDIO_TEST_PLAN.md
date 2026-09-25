# Manual Roblox Studio test plan

Everything in this project was built and tested **headlessly**: a Luau type
checker, a Lune harness that runs the real server and client scripts, a 2.5D
navigation analysis, and an approximate three.js preview renderer. There was
no Studio connection in the build environment, so the items below are
**NOT VERIFIED** until you check them in Studio.

Setup for all tests: open `dist/ColdWarLobby.rbxl`, or add the lobby to
Place1 with the insert kit or Rojo (see README).

Legend: **Steps** → **Expected**. Tick each box as you go.

## 0. Getting it into Place1

- [ ] **Insert kit.** In Place1, right-click each service and use *Insert from File…* with its file from `dist/InsertKit` (README, Option B). Press Play. → You spawn on one of the lobby's spawn pads, not on the old SpawnLocation. The Output shows `[Lobby] Moved template Baseplate, SpawnLocation to ServerStorage.LobbyDisplacedTemplate`. If Studio inserted the lobby at an offset, it also shows `[Lobby] Moved the lobby … studs back to the world origin`, and the base sits level with no gaps.
- [ ] **Camera limit after inserting.** Zoom out with the mouse wheel. → Zoom stops at about 55 studs, although Place1's StarterPlayer still allows 400.
- [ ] **Zone banner and locator after inserting.** Walk into the Garage and press **L**. → The banner names the Garage, and the locator arrows point at the buildings they name. If they are wrong, the lobby was not moved back to the origin.

## 1. Blockout: movement and scale

- [ ] **Spawn.** Press Play (Solo). → You spawn on one of the eight yellow-framed pads south of the dais, facing north toward the Operations Center tower and radome. You never spawn inside the dais or the map table.
- [ ] **Steps and floors.** Walk onto the dais (two 0.6-stud steps), into every building entrance, and onto the Hall of Commanders slab and the HQ floor (1.2 studs). → No stepping snags or jumping needed. In particular the Map Room, Command HQ and Operations Center doors: nothing runs across the doorway at knee height.
- [ ] **Walking times.** Walk from spawn to the Map Room entrance, the farthest building. → Takes about 9 s at the default WalkSpeed of 16.
- [ ] **Camera.** Walk through each interior. → The camera (max zoom 55) stays inside rooms without clipping far into walls or ceilings, and doesn't get stuck under the Mission Board shelter roof.
- [ ] **Boundary.** Try to leave the base through the fence or past the gate barrier. → You can't.

## 2. Architecture: rendering and readability

- [ ] **Palette.** Look around. → Colours read as muted olive, concrete, brown and faded red and blue. Neon appears only on small lamp bulbs and fluorescent tubes.
- [ ] **Lighting.** → A late-afternoon, slightly hazy look: ClockTime 15.6, shadows on, soft atmosphere. It is not too dark indoors. Tweak `World/LightingSetup.luau` if needed.
- [ ] **Signs from spawn.** → OPERATIONS CENTER, MAP ROOM, COMMAND HQ, GARAGE and HALL OF COMMANDERS are readable from the spawn pads. Signpost arrows point to the named buildings.
- [ ] **Plates and hanging signs.** → Every BLDG number plate sits on plain wall (not over a window, column or strut). Standing just inside the Operations Center door, the five terminal signs (PRIVATE, 1v1, QUICK MATCH, 2v2, 4v4) are all fully readable and none hides the command wall display.
- [ ] **No flicker.** Walk the base and look closely at road markings, the Ops floor pads, rooflines, the Mission Board papers and the winter yard. → Nothing flickers (z-fighting). The headless detector reports zero visible coplanar overlaps.
- [ ] **HQ materials.** → The Command HQ reads as a plastered German Kaserne with a clay-tile roof, dormers and a sandstone portal. Plaster, ClayRoofTiles and Sandstone are newer materials; if they look flat, check that the place uses the current material set.
- [ ] **Fonts.** → Headers use Oswald, text uses Roboto Condensed and Roboto Mono, and documents use Special Elite. All glyphs render; watch for "·", "—", "★" and "ä/ü/ß".
- [ ] **SurfaceGui culling.** Walk away from small signs and screens. → They fade out beyond their MaxDistance. Large landmark signs stay visible.
- [ ] **Flags.** → Flag emblems are the compass, chevron and diamond designs, not mirrored. The design reads correctly from both sides.

## 3. Interaction: prompts, panels and services

### Prompts and panels
- [ ] **Prompt plate (keyboard).** Stand at the QUICK MATCH terminal. → A dark plate shows `[E] JOIN MATCH · QUICK MATCH TERMINAL` above the console. Press **E**. → The Operations Center panel opens with a short fade and slide.
- [ ] **Every station.** Repeat at each station type:
  - five matchmaking terminals
  - a Map Room display and the planning table
  - the plaza theatre table
  - the HQ terminal, records, quartermaster and trophy case
  - a Garage vehicle, the registry and the paint shop
  - a leaderboard
  - the Mission Board
  - the event briefing desk

  → The right panel and tab open each time.
- [ ] **Closing.** → The ✕ button, the **X** key and walking about 8 studs away each close the panel. Esc opens the Roblox menu and must not be needed. Prompts are hidden while a panel is open.
- [ ] **Gamepad (optional).** → **X** triggers, **B** closes, **LB/RB** switch tabs, and the first button is selected.
- [ ] **Touch (Device emulator, e.g. iPhone).** → The prompt plate shows TAP, and tapping it opens the panel. Panels fit the screen below the top bar and text stays readable. The HUD commander card sits below the top bar and clear of the thumbstick.
- [ ] **Garage showroom.** Press E at the showroom console. → A full-screen viewer opens and the camera orbits the vehicle on the turntable. Pick another vehicle in the list. → It replaces the one on the turntable (for you only). Drag to turn the camera, use the wheel to zoom. → The camera never leaves the hall or ends up behind a pillar. Preview, buy and apply a camouflage. Close with ✕. → The camera returns to your character.
- [ ] **Event unit inspection.** Press E at the T-80BV "Zima" in the winter yard. → The sheet docks on the right and the camera slowly orbits the tank. Closing hands the camera back.
- [ ] **Registry and paint shop.** → The viewport previews show the selected vehicle turning slowly. Choosing a camo swatch repaints the preview.
- [ ] **Theatre and map drawings.** → Map previews and the theatre map draw correctly: roads, rivers, sectors A–F, spawns and the landmark diamond.

### Services (use Test → Clients and Servers, 2 players)
- [ ] **1v1 match.** Both players queue at the 1v1 terminal. → The HUD strip shows the queue. MATCH FOUND appears with both names and a 5-second countdown, then DEPLOYMENT SIMULATED (while TargetPlaceId is 0).
- [ ] **Private lobby.** Player 1 creates one; player 2 joins with the code (lower case also works). → Both see the member list, and the host can change the map and start.
- [ ] **Quick match.** One player waits in 2v2 while others use QUICK MATCH. → Quick-match players top up the 2v2.
- [ ] **Leaving.** → Leaving the queue from the HUD strip works, and so does leaving the game while queued.
- [ ] **Missions.** Use any terminal, then open the Mission Board. → The orientation order shows `!` and CLAIM works once. The printed order on the cork board is ticked for you only.
- [ ] **Event.** Read the briefing and inspect the T-80BV "Zima". → You have 100 points, and tier 1 (500 CR) can be claimed.
- [ ] **Leaderboards.** → The five boards fill. In Studio without API access the source reads STUDIO DEMO DATA; when published it reads GLOBAL.

### Data and teleport (published place)
- [ ] **Persistence.** Enable *Game Settings → Security → Enable Studio Access to API Services* and publish. Change faction or title, buy a camo, leave and rejoin. → The changes are kept and the profile isn't marked TEMPORARY FILE.
- [ ] **Match stats.** Write stats from a test script or match server with `UpdateAsync` on `commander_<userId>` while the player is in the lobby. → After the lobby saves, stats show the higher value and credits sum correctly.
- [ ] **Teleport.** Set `GameModes.Settings.TargetPlaceId` to the RTS place id, publish, and test with 2 real accounts. → They teleport to one reserved server. `TeleportService:GetLocalPlayerTeleportData()` in the RTS place returns mode, map and teams.

## 4. Detailing: props, lights and effects

- [ ] **Props.** Walk the base. → Benches, lamps, bins, picnic tables and vehicles sit on the ground (none float or sink) and nothing blocks doorways or terminals.
- [ ] **Lights.** Set ClockTime to 20 to check. → Street lamps, parking-lot lamps, fluorescent tubes in the Operations Center, Garage and canteen, and the floodlights give warm, soft light, and switch off again by day (ClockTime 15.6: no glowing lamp lenses). There are about 66 lights in total, none casting shadows.
- [ ] **Effects.** → Smoke rises from the canteen chimney and the field kitchen. In the winter yard the fire barrel burns with particle flames, drifting embers and thin smoke, both snow guns blow a plume of snow, and light snow falls over the yard. Textures: `rbxasset://textures/particles/smoke_main.dds`, `fire_main.dds` and `fire_sparks_main.dds`; swap in uploaded textures if any don't show.
- [ ] **Frost grade.** Walk into the winter yard. → Within about a second the picture turns slightly cooler and less saturated. Walk out. → It fades back.
- [ ] **Parked vehicles.** → The staff parking cars stand inside their stalls against the wheel stops, the helipad helicopter and the motor pool trucks look plausible at 60 % scale.
- [ ] **Map edge.** Look out through the gate and from the fence corners. → The public road bends away into the woods; hills and forest close the view on every side and the edge of the ground is never visible.
- [ ] **Performance (MicroProfiler, Ctrl+F6).** → Stable 60 FPS on a mid-range PC. On a phone, check with the Developer Console that frame time stays reasonable. There are about 11,100 parts (most of the added ones are decor: no collision, no query, no shadow) and 250 SurfaceGuis. Consider `Workspace.StreamingEnabled` for low-end devices; the client code handles streaming.

## 5. Polish: animation, sound and UI

- [ ] **Ambient animation.** → The radar on the Operations Center roof turns, flags wave, rack lamps and obstruction lights blink, CRTs flicker now and then, and the fire light flickers.
- [ ] **Ambient sound.** → Command-room tone and radio chatter play inside the Operations Center, teletype in the Map Room, canteen chatter and the fire in the courtyard, a truck idling at the motor pool, a transformer hum at the comms compound, and quiet wind everywhere. Adjust volumes in `Config/Sounds.luau`.
- [ ] **Sound IDs.** → Every sound ID loads. They are ProSoundEffects Creator Store assets; check the Output for "Failed to load sound".
- [ ] **Flyby.** Run `require(game.Players.LocalPlayer.PlayerScripts.LobbyClient.Ambient.Flyby).run()` in the client command bar, or wait 3–5 minutes. → A helicopter crosses the sky with its rotor turning and sound.
- [ ] **UI feedback.**
  - Claiming a reward slides a toast in from the right and floats +CR on the commander card.
  - Levelling up shows PROMOTED.
  - Buttons darken when pressed.
  - Toasts wait while a full panel is open.

## Known limitations
- Phone text is small (the UI scales to about 0.55 on a 360-pt-tall screen). This hasn't been checked on a device.
- Vehicle previews in the registry and paint shop use a ViewportFrame; asset overrides without Paint attributes don't repaint.
- Leaderboard names for offline users come from `GetNameFromUserIdAsync`, which can be slow the first time.
