--!strict
-- LobbyClient bootstrap: waits for the lobby remotes, then starts the
-- client store, the UI (window manager, panels, HUD), the controllers and
-- the ambient layer (animation, positional sound, flyby).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage:WaitForChild("Lobby")
Lobby:WaitForChild("Remotes")

local State = require(script.State)
local WindowManager = require(script.UI.WindowManager)
local Hud = require(script.UI.Hud.Hud)
local Notifications = require(script.UI.Hud.Notifications)
local InteractionController = require(script.Controllers.InteractionController)
local CameraController = require(script.Controllers.CameraController)
local MissionBoardView = require(script.Controllers.MissionBoardView)
local AmbientAnimator = require(script.Ambient.AmbientAnimator)
local AmbientSound = require(script.Ambient.AmbientSound)
local Flyby = require(script.Ambient.Flyby)

local Panels = script.UI.Panels
local PANELS: { [string]: WindowManager.Panel } = {
	Matchmaking = require(Panels.Matchmaking),
	Maps = require(Panels.Maps),
	Profile = require(Panels.Profile),
	Inspect = require(Panels.Inspect),
	Garage = require(Panels.Garage),
	Leaderboards = require(Panels.Leaderboards),
	Missions = require(Panels.Missions),
	Event = require(Panels.Event),
}

State.start()
WindowManager.start()
for name, panel in PANELS do
	WindowManager.register(name, panel)
end
Hud.start()
Notifications.start()
InteractionController.start()
CameraController.start()
MissionBoardView.start()
AmbientAnimator.start()
AmbientSound.start()
Flyby.start()
