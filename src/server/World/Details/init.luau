--!strict
-- Phase 4 detailing: props, furniture, parked vehicles, utility, light
-- fittings and the recreation grounds that make the base look lived-in.
-- Built after the zones, stations and perimeter; skipped in Blockout mode.

local Kit = require(script.Parent.Kit)
local Grounds = require(script.Grounds)
local Interior = require(script.Interior)
local Outdoor = require(script.Outdoor)

local Details = {}

function Details.build(root: Instance): Folder
	local folder = Kit.folder(root, "Details")
	Outdoor.build(folder)
	Grounds.build(folder)
	Interior.build(folder)
	return folder
end

return Details
