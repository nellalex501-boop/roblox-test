--!nocheck
-- RBXScriptSignal stand-in. Handlers run on the virtual scheduler; errors
-- inside handlers are recorded (like Roblox printing to Output) instead of
-- crashing the test process.

local Scheduler = require("./Scheduler")

local Signal = {}
Signal.__index = Signal
Signal.__type = "RBXScriptSignal"

function Signal.new(name: string?)
	return setmetatable({ Name = name or "Signal", _handlers = {}, _waiting = {} }, Signal)
end

function Signal:Connect(fn)
	assert(type(fn) == "function", "Attempt to connect failed: Passed value is not a function")
	local handlers = self._handlers
	local connection = { Connected = true }
	function connection.Disconnect(c)
		c.Connected = false
		local index = table.find(handlers, c)
		if index then
			table.remove(handlers, index)
		end
	end
	connection.disconnect = connection.Disconnect
	connection._fn = fn
	table.insert(handlers, connection)
	return connection
end
Signal.connect = Signal.Connect
Signal.ConnectParallel = Signal.Connect

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		if connection.Connected then
			connection:Disconnect()
			fn(...)
		end
	end)
	return connection
end

function Signal:Wait()
	table.insert(self._waiting, coroutine.running())
	return coroutine.yield()
end

function Signal:Fire(...)
	for _, connection in table.clone(self._handlers) do
		if connection.Connected then
			Scheduler.spawn(connection._fn, ...)
		end
	end
	local waiting = self._waiting
	self._waiting = {}
	for _, thread in waiting do
		Scheduler.spawn(thread, ...)
	end
end

function Signal:ConnectionCount(): number
	return #self._handlers
end

return Signal
