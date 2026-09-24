--!nocheck
-- Self-test of the headless runtime: the emulation must match Roblox
-- semantics wherever game code depends on it.

local Runtime = require("../harness/Runtime")
local Scheduler = require("../harness/Scheduler")

return function(test)
	test("CFrame.lookAt matches Roblox (Lune's is mirrored on Z)", function(t)
		local rt = Runtime.new()
		local CF = rt.globals.CFrame
		local V3 = rt.globals.Vector3
		local north = CF.lookAt(V3.new(0, 0, 0), V3.new(0, 0, -1))
		t.ok((north.LookVector - V3.new(0, 0, -1)).Magnitude < 1e-5, "look north = identity look")
		t.ok((north.RightVector - V3.new(1, 0, 0)).Magnitude < 1e-5, "right = +X when looking north")
		local east = CF.lookAt(V3.new(0, 0, 0), V3.new(1, 0, 0))
		t.ok((east.RightVector - V3.new(0, 0, 1)).Magnitude < 1e-5, "right = +Z when looking east")
		local diag = CF.lookAt(V3.new(0, 0, 0), V3.new(1, 0, -1))
		t.ok((diag.LookVector - V3.new(1, 0, -1).Unit).Magnitude < 1e-5, "diagonal look preserved")
	end)

	test("scheduler: virtual time, ordering, errors are captured", function(t)
		local rt = Runtime.new()
		local order = {}
		rt.globals.task.delay(2, function()
			table.insert(order, "b")
		end)
		rt.globals.task.delay(1, function()
			table.insert(order, "a")
		end)
		rt.globals.task.spawn(function()
			local waited = rt.globals.task.wait(3)
			table.insert(order, "c" .. math.floor(waited + 0.5))
		end)
		Scheduler.advance(5)
		t.eq(table.concat(order, ","), "a,b,c3", "delays resume in time order")
		rt.globals.task.spawn(function()
			error("boom")
		end)
		t.eq(#Scheduler.errors, 1, "error in a thread is recorded, not fatal")
		Scheduler.errors = {}
	end)

	test("remote payloads follow Roblox serialisation rules", function(t)
		local ok1 = pcall(Runtime.remoteCopy, { 1, 2, 3 }, "p")
		local ok2 = pcall(Runtime.remoteCopy, { a = 1, b = { c = true } }, "p")
		local ok3 = pcall(Runtime.remoteCopy, { 1, 2, x = 3 }, "p")
		local ok4 = pcall(Runtime.remoteCopy, { [1] = "a", [3] = "b" }, "p")
		local ok5 = pcall(Runtime.remoteCopy, { f = function() end }, "p")
		t.ok(ok1 and ok2, "arrays and string dictionaries pass")
		t.ok(not ok3, "mixed tables rejected")
		t.ok(not ok4, "sparse arrays rejected")
		t.ok(not ok5, "functions rejected")
	end)

	test("DataStore mock rejects non-JSON values and can emulate Studio", function(t)
		local rt = Runtime.new()
		local store = rt.datastores.dataStore("Test")
		local okSet, okBad, okOff
		rt.globals.task.spawn(function()
			okSet = pcall(store.SetAsync, store, "k", { a = 1, list = { 1, 2 } })
			okBad = pcall(store.SetAsync, store, "k2", { color = rt.globals.Color3.new(1, 0, 0) })
			rt.datastores.unavailable = true
			okOff = pcall(store.GetAsync, store, "k")
		end)
		Scheduler.advance(1)
		t.ok(okSet, "plain table stored")
		t.ok(not okBad, "Color3 rejected (not storable in DataStores)")
		t.ok(not okOff, "unavailable mode errors like Studio without API access")
	end)
end
