--!strict
-- LobbyServer bootstrap: remotes first (clients wait for them), then the
-- world, then the services in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Lobby.Net)
local Services = script.Services
local Setup = require(Services.Setup)
local DataService = require(Services.DataService)
local CommanderService = require(Services.CommanderService)
local InteractionService = require(Services.InteractionService)
local MissionService = require(Services.MissionService)
local EventService = require(Services.EventService)
local GarageService = require(Services.GarageService)
local MatchmakingService = require(Services.MatchmakingService)
local LeaderboardService = require(Services.LeaderboardService)
local LobbyStatus = require(Services.LobbyStatus)

Net.setup()
Setup.prepareWorkspace()
local world, reused = Setup.ensureWorld()

DataService.init()
DataService.startAutosave()
CommanderService.start()
InteractionService.start()
MissionService.start()
EventService.start(world, reused)
GarageService.start()
MatchmakingService.start()
LeaderboardService.start(world)
LobbyStatus.start(world)
Setup.relocateCharacters(world)

world:SetAttribute("LobbyReady", true)
