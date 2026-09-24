--!strict
-- Minimal Lua signal (no Instances): Connect / Once / Fire / DisconnectAll.

export type Connection = { Connected: boolean, Disconnect: (Connection) -> () }

export type Signal<T...> = {
	Connect: (Signal<T...>, (T...) -> ()) -> Connection,
	Once: (Signal<T...>, (T...) -> ()) -> Connection,
	Fire: (Signal<T...>, T...) -> (),
	DisconnectAll: (Signal<T...>) -> (),
	_handlers: { [Connection]: (T...) -> () },
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local self = { _handlers = {} } :: any

	function self.Connect(signal: Signal<T...>, handler: (T...) -> ()): Connection
		local connection = { Connected = true } :: any
		function connection.Disconnect(c: Connection)
			c.Connected = false
			signal._handlers[c] = nil
		end
		signal._handlers[connection] = handler
		return connection
	end

	function self.Once(signal: Signal<T...>, handler: (T...) -> ()): Connection
		local connection: Connection
		connection = signal:Connect(function(...: T...)
			connection:Disconnect()
			handler(...)
		end)
		return connection
	end

	function self.Fire(signal: Signal<T...>, ...: T...)
		for connection, handler in table.clone(signal._handlers) do
			if connection.Connected then
				task.spawn(handler, ...)
			end
		end
	end

	function self.DisconnectAll(signal: Signal<T...>)
		for connection in signal._handlers do
			connection.Connected = false
		end
		table.clear(signal._handlers)
	end

	return self
end

return Signal
