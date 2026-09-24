--!nocheck
-- Deterministic virtual-time task scheduler used instead of the real
-- `task` library while running game code headlessly. Time only moves when a
-- test calls Scheduler.advance(), so waits of minutes run instantly.

local Scheduler = {}

Scheduler.now = 0
Scheduler.errors = {} :: { string }
Scheduler.frame = 1 / 30
Scheduler.onFrame = nil :: ((number) -> ())?

local queue = {} -- { { at = number, seq = number, thread = thread, args = {any} } }
local deferred = {}
local seq = 0

local function report(message: string)
	table.insert(Scheduler.errors, message)
	print("\27[31m[runtime error]\27[0m " .. message)
end
Scheduler.report = report

local function resume(thread: thread, ...)
	if coroutine.status(thread) ~= "suspended" then
		return
	end
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		report(debug.traceback(thread, tostring(err)))
	end
end

local function toThread(fnOrThread): thread
	if type(fnOrThread) == "thread" then
		return fnOrThread
	end
	return coroutine.create(fnOrThread)
end

function Scheduler.spawn(fnOrThread, ...): thread
	local thread = toThread(fnOrThread)
	resume(thread, ...)
	return thread
end

function Scheduler.defer(fnOrThread, ...): thread
	local thread = toThread(fnOrThread)
	table.insert(deferred, { thread = thread, args = table.pack(...) })
	return thread
end

local function schedule(at: number, thread: thread, args)
	seq += 1
	table.insert(queue, { at = at, seq = seq, thread = thread, args = args })
end

function Scheduler.delay(seconds: number?, fnOrThread, ...): thread
	local thread = toThread(fnOrThread)
	schedule(Scheduler.now + math.max(seconds or 0, 0), thread, table.pack(...))
	return thread
end

function Scheduler.wait(seconds: number?): number
	local thread = coroutine.running()
	local started = Scheduler.now
	schedule(Scheduler.now + math.max(seconds or 0, Scheduler.frame), thread, { n = 0, marker = started })
	coroutine.yield()
	return Scheduler.now - started
end

function Scheduler.cancel(thread: thread)
	for i = #queue, 1, -1 do
		if queue[i].thread == thread then
			table.remove(queue, i)
		end
	end
	for i = #deferred, 1, -1 do
		if deferred[i].thread == thread then
			table.remove(deferred, i)
		end
	end
	if coroutine.status(thread) == "suspended" then
		coroutine.close(thread)
	end
end

local function runDeferred()
	local guard = 0
	while #deferred > 0 do
		guard += 1
		if guard > 10000 then
			report("deferred queue did not drain (possible infinite defer loop)")
			deferred = {}
			return
		end
		local batch = deferred
		deferred = {}
		for _, item in batch do
			resume(item.thread, table.unpack(item.args, 1, item.args.n))
		end
	end
end

-- Runs everything due up to now + seconds, stepping frame by frame so
-- Heartbeat-style callbacks see realistic delta times.
function Scheduler.advance(seconds: number)
	local target = Scheduler.now + seconds
	runDeferred()
	while true do
		local nextFrame = math.min(Scheduler.now + Scheduler.frame, target)
		-- resume every thread due before the next frame boundary, in order
		while true do
			local bestIndex = nil
			for i, item in queue do
				if item.at <= nextFrame + 1e-9 then
					if
						bestIndex == nil
						or item.at < queue[bestIndex].at
						or (item.at == queue[bestIndex].at and item.seq < queue[bestIndex].seq)
					then
						bestIndex = i
					end
				end
			end
			if not bestIndex then
				break
			end
			local item = table.remove(queue, bestIndex)
			Scheduler.now = math.max(Scheduler.now, item.at)
			resume(item.thread, table.unpack(item.args, 1, item.args.n or #item.args))
			runDeferred()
		end
		local dt = nextFrame - Scheduler.now
		Scheduler.now = nextFrame
		if Scheduler.onFrame then
			Scheduler.onFrame(math.max(dt, Scheduler.frame))
		end
		runDeferred()
		if Scheduler.now >= target - 1e-9 then
			break
		end
	end
end

function Scheduler.pending(): number
	return #queue + #deferred
end

function Scheduler.reset()
	queue = {}
	deferred = {}
	Scheduler.errors = {}
	Scheduler.now = 0
	Scheduler.onFrame = nil
end

-- `task` library facade handed to game code.
Scheduler.task = {
	spawn = Scheduler.spawn,
	defer = Scheduler.defer,
	delay = Scheduler.delay,
	wait = Scheduler.wait,
	cancel = Scheduler.cancel,
	synchronize = function() end,
	desynchronize = function() end,
}

return Scheduler
