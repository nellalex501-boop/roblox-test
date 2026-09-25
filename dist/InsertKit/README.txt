Cold War RTS lobby: insert kit
==============================

Adds the lobby to an existing Roblox place (for example Place1) without
replacing what is already there.

In Roblox Studio, open the place. In the Explorer, right-click each service
below, choose "Insert from File..." and pick the matching file:

  1_Workspace_ColdWarLobby.rbxm             -> Workspace
  2_ReplicatedStorage_Lobby.rbxm            -> ReplicatedStorage
  3_ServerScriptService_LobbyServer.rbxm    -> ServerScriptService
  4_StarterPlayerScripts_LobbyClient.rbxm   -> StarterPlayer > StarterPlayerScripts
  5_ServerStorage_LobbyAssets.rbxm          -> ServerStorage

Then press Play.

- If Studio drops the lobby at an offset, that is fine: the server moves it
  back to the world origin when the game starts.
- The template Baseplate and SpawnLocation are moved (not deleted) to
  ServerStorage.LobbyDisplacedTemplate when the game starts.
- Optional, for the intended look: select Lighting and set Technology to
  ShadowMap in the Properties window.

- Updating from an older kit: delete the old ColdWarLobby, Lobby,
  LobbyServer, LobbyClient and LobbyAssets first, or the lobby exists twice.
- On start the server also sets Lighting (time 15:36, atmosphere, sky,
  grading) and moves every SpawnLocation directly in Workspace aside, your
  own included. The lobby covers about 2048 x 2048 studs around the origin.
- Vehicle copies in ServerStorage.LobbyAssets.Units show up at once in the
  Garage and its previews; the parked and displayed vehicles of the baked
  lobby only change after a rebuild (see LIESMICH.md, section 7).

Built and tested headlessly; not yet opened in Studio. See
STUDIO_TEST_PLAN.md (docs/ in the repository) for the manual checks.
German guide with all details and caveats: LIESMICH.md.
