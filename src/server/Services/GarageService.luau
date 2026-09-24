--!strict
-- Garage backend: unit collection (unlocks), paint shop (camo purchases
-- and per-unit schemes), and the preview models clients use for the
-- registry / paint shop viewports (ReplicatedStorage.LobbyUnitPreviews).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lobby = ReplicatedStorage.Lobby
local Net = require(Lobby.Net)
local Units = require(Lobby.Config.Units)
local GarageLogic = require(script.Parent.Parent.Core.GarageLogic)
local Vehicles = require(script.Parent.Parent.World.Vehicles)
local CommanderService = require(script.Parent.CommanderService)
local InteractionService = require(script.Parent.InteractionService)

local GarageService = {}

GarageService.PreviewFolderName = "LobbyUnitPreviews"
-- Purchases must be made at a garage station (registry, paint shop or a
-- showcase vehicle), matching the physical lobby.
GarageService.RequireProximity = true

local GARAGE_KINDS = { "UnitCollection", "UnitCosmetics", "UnitInspect" }
local PREVIEW_SIZE = Vector3.new(14, 11, 22)

function GarageService.buildPreviews(): Folder
	local existing = ReplicatedStorage:FindFirstChild(GarageService.PreviewFolderName)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = GarageService.PreviewFolderName
	for _, id in Units.Order do
		local unit = Units.List[id]
		local camo = Units.Camos.List[GarageLogic.defaultCamo(id)]
		local paint = if unit.Camo
			then { Base = camo.Colors[1], Accent = camo.Colors[2] }
			else Vehicles.DefaultPaint[unit.Faction] or Vehicles.DefaultPaint.NATO
		local model = Vehicles.spawn(folder, id, unit.Model, CFrame.new(), paint, PREVIEW_SIZE)
		model:SetAttribute("UnitId", id)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.CastShadow = false
			end
		end
	end
	folder.Parent = ReplicatedStorage
	return folder
end

local function atGarage(player: Player): boolean
	if not GarageService.RequireProximity then
		return true
	end
	for _, kind in GARAGE_KINDS do
		if InteractionService.isNear(player, kind) then
			return true
		end
	end
	return false
end

local function notify(player: Player, title: string, text: string, detail: string)
	Net.event("Notify"):FireClient(player, { kind = "Reward", title = title, text = text, detail = detail })
end

local function reply(player: Player, result: { [string]: any }): { [string]: any }
	local profile = CommanderService.get(player)
	result.profile = CommanderService.snapshot(player)
	result.units = if profile then GarageLogic.collection(profile) else {}
	return result
end

local ACTIONS: { [string]: (Player, { [string]: any }) -> { [string]: any } } = {}

ACTIONS.collection = function(player)
	return reply(player, { ok = true })
end

ACTIONS.unlock = function(player, request)
	local unitId = request.unit
	if type(unitId) ~= "string" or not Units.List[unitId] then
		return reply(player, { ok = false, error = "UNKNOWN_UNIT" })
	end
	if not atGarage(player) then
		return reply(player, { ok = false, error = "NOT_AT_GARAGE" })
	end
	local ok, err = false, "NO_PROFILE"
	CommanderService.update(player, function(profile)
		local success, reason = GarageLogic.unlock(profile, unitId)
		ok, err = success, reason or ""
		return success
	end)
	if ok then
		notify(player, "UNIT ACQUIRED", Units.List[unitId].Name, "NOW IN SERVICE WITH YOUR COMMAND")
		return reply(player, { ok = true })
	end
	return reply(player, { ok = false, error = err })
end

ACTIONS.buyCamo = function(player, request)
	local camoId = request.camo
	if type(camoId) ~= "string" or not Units.Camos.List[camoId] then
		return reply(player, { ok = false, error = "UNKNOWN_CAMO" })
	end
	if not atGarage(player) then
		return reply(player, { ok = false, error = "NOT_AT_GARAGE" })
	end
	local ok, err = false, "NO_PROFILE"
	CommanderService.update(player, function(profile)
		local success, reason = GarageLogic.buyCamo(profile, camoId)
		ok, err = success, reason or ""
		return success
	end)
	if ok then
		notify(player, "PAINT SCHEME PURCHASED", Units.Camos.List[camoId].Name, "APPLY IT AT THE PAINT SHOP")
		return reply(player, { ok = true })
	end
	return reply(player, { ok = false, error = err })
end

ACTIONS.setCamo = function(player, request)
	local unitId, camoId = request.unit, request.camo
	if type(unitId) ~= "string" or type(camoId) ~= "string" then
		return reply(player, { ok = false, error = "BAD_REQUEST" })
	end
	if not atGarage(player) then
		return reply(player, { ok = false, error = "NOT_AT_GARAGE" })
	end
	local ok, err = false, "NO_PROFILE"
	CommanderService.update(player, function(profile)
		local success, reason = GarageLogic.setCamo(profile, unitId, camoId)
		ok, err = success, reason or ""
		return success
	end)
	if ok or err == "UNCHANGED" then
		return reply(player, { ok = true })
	end
	return reply(player, { ok = false, error = err })
end

function GarageService.start()
	GarageService.buildPreviews()
	Net.fn("Garage").OnServerInvoke = function(player: Player, request: any)
		if type(request) ~= "table" or type(request.action) ~= "string" then
			return { ok = false, error = "BAD_REQUEST" }
		end
		local handler = ACTIONS[request.action]
		if not handler then
			return { ok = false, error = "UNKNOWN_ACTION" }
		end
		if not CommanderService.whenLoaded(player) then
			return { ok = false, error = "NO_PROFILE" }
		end
		return handler(player, request)
	end
end

return GarageService
