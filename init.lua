local titter = require(... .. ".titter")

local bread = {}

bread.opts = {
	side = "r",
	xPad = 20,
	yPad = 1,
	width = "40%",
	dispNumberKeys = false,
	scrollMult = 1,
	scrollInvert = false
}
bread.theme = {
	colors = {
		back = {150, 150, 150, 255},
		text = {255, 255, 255, 255},
		highlight = {200, 200, 200, 255}
	},
	font = love.graphics.getFont()
}

bread.saves = {}
bread.watching = {}
bread.minimized = {}
bread.names = {}
bread.filters = {}

bread.scrollOffset = 0

bread.isBinary = function(v)
	return type(v) == "thread" or type(v) == "userdata" or type(v) == "function"
end

bread.validID = function(k)
	if type(k) ~= "string" then
		return false
	else
		return k:match("[%a_]+[%a%d_]*")
	end
end

bread.iter = function()
	return titter(bread.watching, "Bread")
end

bread.getRowHeight = function()
	return bread.theme.font:getHeight() + bread.opts.yPad
end

bread.getTextHeight = function()
	local minimizeLevel = 0
	local yDepth = 0
	for f, k, v, l in bread.iter() do
		if minimizeLevel == 0 then
			yDepth = yDepth + 1

			if bread.minimized[v] then
				minimizeLevel = 1
			end
		else
			if f then
				minimizeLevel = minimizeLevel - 1
			elseif type(v) == "table" then
				minimizeLevel = minimizeLevel + 1
			end
		end
	end

	return yDepth * bread.getRowHeight()
end

bread.pointInPanel = function(x, y)
	local width = bread.getBarWidth()
	return (bread.opts.side == "l" and x < width) or (bread.opts.side == "r" and x > love.graphics.getWidth() - width)
end

bread.screenToDepth = function(y)
	local index = math.floor((y - bread.scrollOffset) /  bread.getRowHeight())
	return index
end

bread.getBarWidth = function()
	local width
	if type(bread.opts.width) == "string" and bread.opts.width:find("%%") then
		width = love.graphics.getWidth() * tonumber(bread.opts.width:gsub("%%", "") .. "") / 100
	else
		width = tonumber(bread.opts.width)
	end
	return width
end

bread.getCoord = function(x, y)
	return x * bread.opts.xPad, y * bread.getRowHeight()
end

bread.drawText = function(text, x, y)
	love.graphics.push("all")
	love.graphics.setFont(bread.theme.font)
	love.graphics.setColor(bread.theme.colors.text)
	love.graphics.print(text, bread.getCoord(x, y))
	love.graphics.pop()
end

bread.watch = function(thing, name)
	assert(type(thing) == "table")

	bread.watching[name] = thing

	return thing
end

bread.doMinimize = function(x, y)
	local minimizeLevel = 0
	local tDepth = bread.screenToDepth(y)
	local yDepth = 0

	for finish, key, value, last, empty in bread.iter() do
		local filtered = bread.isFiltered(value)
		if minimizeLevel == 0 then
			if yDepth == tDepth and not finish then
				if type(value) == "table" and not empty then
					bread.minimized[value] = not bread.minimized[value]
				end

				break
			end

			if not finish then
				yDepth = yDepth + 1
			elseif not value then
				yDepth = yDepth + 1
			end

			if bread.minimized[value] or filtered then
				minimizeLevel = 1
			end
		else
			if finish then
				minimizeLevel = minimizeLevel - 1
			elseif type(value) == "table" then
				minimizeLevel = minimizeLevel + 1
			end
		end
	end
end

bread.isFiltered = function(thing)
	if type(thing) == "table" then
		for filter in pairs(bread.filters) do
			if filter(thing) then
				return true
			end
		end
	end
	return false
end

-- General user functions

bread.save = function(name)
	bread.saves[name] = {
		watching = bread.watching,
		minimized = bread.minimized,
		filters = bread.filters
	}
end

bread.unsave = function(name)
	bread.saves[name] = nil
end

bread.load = function(name)
	local save = bread.saves[name]

	bread.watching = save.watching
	bread.minimized = save.minimized
	bread.filters = save.filters
end

bread.reset = function(name)
	if name then
		bread.save(name)
	end

	bread.watching = {}
	bread.minimized = {}
	bread.filters = {}
end

bread.filter = function(filter)
	bread.filters[filter] = true
	return filter
end

bread.unfilter = function(filter)
	bread.filters[filter] = nil
end

bread.mousepressed = function(x, y, b)
	local pointValid = bread.pointInPanel(x, y)
	if pointValid then
		if b == 1 then
			bread.doMinimize(x, y)
		end
	end
	return pointValid
end

bread.wheelmoved = function(x, y)
	local pointValid = bread.pointInPanel(love.mouse.getX(), love.mouse.getY())
	if pointValid and y ~= 0 then
		local textHeight = bread.getTextHeight()
		local loveHeight = love.graphics.getHeight()
		local rowHeight = bread.getRowHeight()

		local desiredScroll = bread.scrollOffset
			- (math.abs(y) / y) * bread.opts.scrollMult * rowHeight
		if desiredScroll > loveHeight - textHeight and desiredScroll <= 0 then
			bread.scrollOffset = desiredScroll
		end
	end
	return pointValid
end

bread.draw = function()
	local size = bread.getBarWidth()
	local drawRect = function()
		if not bread.minimized[bread.watching] then
			love.graphics.rectangle("fill", 0, 0, size, love.graphics.getHeight())
		else
			love.graphics.rectangle("fill", 0, 0, size, bread.getRowHeight())
		end
	end

	love.graphics.push("all")

	if bread.opts.side == "r" then
		love.graphics.translate(love.graphics.getWidth() - size, 0)
	end

	love.graphics.push("all")

	love.graphics.setColor(bread.theme.colors.back)
	drawRect()
	love.graphics.pop()

	love.graphics.stencil(drawRect)
	love.graphics.setStencilTest("greater", 0)

	love.graphics.translate(0, bread.scrollOffset)

	local yDepth = 0
	local xDepth = 0
	local minimizeLevel = 0
	local alreadyEnded = false
	for finish, key, value, last, empty in bread.iter() do
		local minimized = bread.minimized[value]
		local filtered = bread.isFiltered(value)

		if minimizeLevel == 0 then
			if finish then
				last = key
				xDepth = xDepth - 1
				if not alreadyEnded then
					bread.drawText("}" .. (last and "" or ","), xDepth, yDepth)
				else
					alreadyEnded = false
				end
			else
				if bread.pointInPanel(love.mouse.getX())
				and bread.screenToDepth(love.mouse.getY()) == yDepth then
					local rowHeight = bread.getRowHeight()

					love.graphics.push("all")
					love.graphics.setColor(bread.theme.colors.highlight)
					love.graphics.rectangle("fill", 0, yDepth * rowHeight, size, rowHeight)
					love.graphics.pop()
				end

				local dispKey = true
				local name
				if bread.names[value] then
					name = "*" .. bread.names[value] .. "*"
				else
					dispKey = type(key) ~= "number" or bread.opts.dispNumberKeys
					name = tostring(key)

					if type(key) ~= "string" or not bread.validID(name) then
						if type(key) == "string" then
							name = "\"" .. name .. "\""
						end
						if type(key) == "table" or bread.isBinary(v) then
							name = "<" .. name .. ">"
						end
						name = "[" .. name .. "]"
					end
				end

				local strung
				if type(value) == "table" then
					if filtered then
						strung = "(filtered: <" .. tostring(value) .. ">)"
					else
						strung = "{"
						if minimized then
							strung = strung .. "...}"
						elseif empty then
							strung = strung .. "}"
							alreadyEnded = true
						end
					end
					if (minimized or empty or filtered) and not last then
						strung = strung .. ","
					end
				else
					strung = tostring(value)

					if type(value) == "string" then
						strung = "\"" .. strung .. "\""
					elseif bread.isBinary(value) then
						strung = "<" .. strung .. ">"
					end

					if not last then
						strung = strung .. ","
					end
				end

				bread.drawText((dispKey and name .. " = " or "") .. strung, xDepth, yDepth)

				if minimized or filtered then
					minimizeLevel = 1
				elseif type(value) == "table" then
					xDepth = xDepth + 1
				end
			end

			if not alreadyEnded then
				yDepth = yDepth + 1
			end
		else
			if finish then
				minimizeLevel = minimizeLevel - 1
			elseif type(value) == "table" then
				minimizeLevel = minimizeLevel + 1
			end
		end
	end

	love.graphics.pop()
end

return bread
