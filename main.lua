local bread = loadfile("init.lua")("") -- This is because the Bread library is in this folder.
-- Change this in your projects!

bread.opts.width = "50%"

local toBeFiltered = {filterMe = true, {{{{{}}}}}}

local circ = {}
circ[1] = circ

local static = {
	t1 = {["1 *"] = "asdf", "asdfg", a = 1},
	{t = {"a", "b", {}}},
	{{{"hi"}}},
	[coroutine.create(function()end)] = 5,
	circ = circ,
	toBeFiltered = toBeFiltered,
}

local keys = {}
local presses = {}

bread.watch(static, "Static")
bread.watch(keys, "Keys")
bread.watch(presses, "Presses")

bread.filter(function(t)
		return t.filterMe
end)

function love.draw()
	bread.draw()
end

function love.mousepressed(x, y, b)
	if not bread.mousepressed(x, y, b) then
		table.insert(presses, 1, {x = x, y = y, b = b})
		presses[11] = nil
	end
end

function love.wheelmoved(x, y)
	bread.wheelmoved(x, y)
end

function love.keypressed(k)
	keys[k] = keys[k] and keys[k] + 1 or 1
end
