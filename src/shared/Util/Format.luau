--!strict
-- Small text formatting helpers shared by the world signs and the UI.

local Format = {}

-- 12345 -> "12,345"
function Format.number(value: number): string
	local negative = value < 0
	local text = tostring(math.floor(math.abs(value)))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return if negative then "-" .. formatted else formatted
end

-- 75 -> "01:15", 3725 -> "1:02:05"
function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%02d:%02d", m, s)
end

function Format.days(days: number): string
	return if days == 1 then "1 DAY" else tostring(days) .. " DAYS"
end

-- Distance in studs -> "35 m" using the lobby's display scale.
function Format.meters(studs: number, scale: number): string
	return string.format("%d m", math.floor(studs * scale + 0.5))
end

function Format.percent(fraction: number): string
	return string.format("%d%%", math.floor(math.clamp(fraction, 0, 1) * 100 + 0.5))
end

-- "12:04Z" style military time from a unix timestamp.
function Format.zulu(timestamp: number): string
	local t = os.date("!*t", math.floor(timestamp))
	return string.format("%02d%02dZ", t.hour, t.min)
end

local MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }

-- "17 OCT 2026 · 0000Z" from a unix timestamp (UTC).
function Format.dateZulu(timestamp: number): string
	local t = os.date("!*t", math.floor(timestamp))
	return string.format("%02d %s %d · %02d%02dZ", t.day, MONTHS[t.month], t.year, t.hour, t.min)
end

-- Reads a dotted path ("victoriesByMap.RIVER_CROSSING") from a table.
function Format.readPath(root: { [string]: any }, path: string): any
	local node: any = root
	for key in path:gmatch("[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[key]
	end
	return node
end

return Format
