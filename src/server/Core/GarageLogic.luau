--!strict
-- Unit collection and paint shop rules (pure, unit-tested).
--
-- Units unlock by default, by credits once a level is reached, or only
-- through an event. Camos are bought with credits (Cost 0 = free,
-- Cost -1 = event reward only) and applied per owned unit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Lobby.Config
local Progression = require(Config.Progression)
local Units = require(Config.Units)
local ProfileSchema = require(script.Parent.ProfileSchema)

type Profile = ProfileSchema.Profile

export type UnitState = {
	id: string,
	owned: boolean,
	canUnlock: boolean,
	cost: number,
	level: number,
	event: string?,
	requirement: string,
	camo: string,
}

local GarageLogic = {}

GarageLogic.DefaultCamo = "FACTORY"

-- The scheme a unit wears when the commander has not repainted it.
function GarageLogic.defaultCamo(unitId: string): string
	local unit = Units.List[unitId]
	local camo = unit and unit.Camo
	return if camo and Units.Camos.List[camo] then camo else GarageLogic.DefaultCamo
end

function GarageLogic.camoOf(profile: Profile, unitId: string): string
	local camo = profile.unitCamos[unitId]
	if camo and Units.Camos.List[camo] and profile.camosOwned[camo] then
		return camo
	end
	return GarageLogic.defaultCamo(unitId)
end

function GarageLogic.unitState(profile: Profile, unitId: string): UnitState?
	local unit = Units.List[unitId]
	if not unit then
		return nil
	end
	local level = Progression.levelForXp(profile.xp)
	local owned = profile.unitsUnlocked[unitId] == true
	local unlock = unit.Unlock
	local cost = unlock.Credits or 0
	local needLevel = unlock.Level or 1
	local requirement
	local canUnlock = false
	if owned then
		requirement = "IN SERVICE"
	elseif unlock.Event then
		requirement = "EVENT REWARD"
	elseif unlock.Credits then
		if level < needLevel then
			requirement = ("REQUIRES LEVEL %d"):format(needLevel)
		else
			requirement = ("%d CR"):format(cost)
			canUnlock = profile.credits >= cost
		end
	else
		requirement = "UNAVAILABLE"
	end
	return {
		id = unitId,
		owned = owned,
		canUnlock = canUnlock,
		cost = cost,
		level = needLevel,
		event = unlock.Event,
		requirement = requirement,
		camo = GarageLogic.camoOf(profile, unitId),
	}
end

function GarageLogic.collection(profile: Profile): { UnitState }
	local out = {}
	for _, id in Units.Order do
		local state = GarageLogic.unitState(profile, id)
		if state then
			table.insert(out, state)
		end
	end
	return out
end

-- Errors: UNKNOWN_UNIT, ALREADY_OWNED, EVENT_ONLY, UNAVAILABLE,
-- LEVEL_TOO_LOW, NOT_ENOUGH_CREDITS.
function GarageLogic.unlock(profile: Profile, unitId: string): (boolean, string?)
	local unit = Units.List[unitId]
	if not unit then
		return false, "UNKNOWN_UNIT"
	end
	if profile.unitsUnlocked[unitId] then
		return false, "ALREADY_OWNED"
	end
	local unlock = unit.Unlock
	if unlock.Event then
		return false, "EVENT_ONLY"
	end
	local cost = unlock.Credits
	if not cost then
		return false, "UNAVAILABLE"
	end
	if Progression.levelForXp(profile.xp) < (unlock.Level or 1) then
		return false, "LEVEL_TOO_LOW"
	end
	if profile.credits < cost then
		return false, "NOT_ENOUGH_CREDITS"
	end
	profile.credits -= cost
	profile.unitsUnlocked[unitId] = true
	return true, nil
end

-- Errors: UNKNOWN_CAMO, ALREADY_OWNED, EVENT_ONLY, NOT_ENOUGH_CREDITS.
function GarageLogic.buyCamo(profile: Profile, camoId: string): (boolean, string?)
	local camo = Units.Camos.List[camoId]
	if not camo then
		return false, "UNKNOWN_CAMO"
	end
	if profile.camosOwned[camoId] then
		return false, "ALREADY_OWNED"
	end
	if camo.Cost < 0 then
		return false, "EVENT_ONLY"
	end
	if profile.credits < camo.Cost then
		return false, "NOT_ENOUGH_CREDITS"
	end
	profile.credits -= camo.Cost
	profile.camosOwned[camoId] = true
	return true, nil
end

-- Errors: UNKNOWN_UNIT, UNIT_LOCKED, UNKNOWN_CAMO, CAMO_LOCKED, UNCHANGED.
function GarageLogic.setCamo(profile: Profile, unitId: string, camoId: string): (boolean, string?)
	if not Units.List[unitId] then
		return false, "UNKNOWN_UNIT"
	end
	if not profile.unitsUnlocked[unitId] then
		return false, "UNIT_LOCKED"
	end
	if not Units.Camos.List[camoId] then
		return false, "UNKNOWN_CAMO"
	end
	local isDefault = camoId == GarageLogic.defaultCamo(unitId)
	if not isDefault and not profile.camosOwned[camoId] then
		return false, "CAMO_LOCKED"
	end
	if GarageLogic.camoOf(profile, unitId) == camoId then
		return false, "UNCHANGED"
	end
	if isDefault then
		profile.unitCamos[unitId] = nil
	else
		profile.unitCamos[unitId] = camoId
	end
	return true, nil
end

return GarageLogic
