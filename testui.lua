
local nw = require'nw'
local glue = require'glue'
local ffi = require'ffi'
local color = require'color'

local testui = {}

local function half(x)
	return math.floor(x / 2 + 0.5)
end

function testui:setcolor(c)
	local r, g, b, a = color.parse(c, 'rgb')
	self.cr:rgba(r, g, b, a or 1)
end

function testui:text(s, halign, valign, x, y, w, h)
	local cr = self.cr

	s = tostring(s)
	halign = halign or 'center'
	valign = valign or 'center'
	x = x or self.x
	y = y or self.y
	w = w or self.w
	h = h or self.h

	cr:save()
	cr:rectangle(x, y, w, h)
	cr:clip()

	cr:font_face('Arial', 'normal', 'normal')
	cr:font_size(14)
	self:setcolor'#ff'

	local font_extents = cr:font_extents()
	local line_h = font_extents.height * 1.2

	if halign == 'right' then
		x = x + w
	elseif halign == 'center' then
		x = x + half(w)
	end

	if valign == 'top' then
		y = y + font_extents.ascent
	else
		local lines_h = 0
		for _ in glue.lines(s) do
			lines_h = lines_h + line_h
		end
		lines_h = lines_h - line_h

		if valign == 'bottom' then
			y = y + h - font_extents.descent
		elseif valign == 'center' then
			y = y + half(h + font_extents.ascent - font_extents.descent + lines_h)
		end
		y = y - lines_h
	end

	if ffi.os == 'OSX' then --TOOD: remove this hack
		y = y + 1
	end
	for s in glue.lines(s) do
		if align == 'right' then
			local extents = cr:text_extents(s)
			cr:move_to(x - extents.width, y)
		elseif align == 'center' then
			local extents = cr:text_extents(s)
			cr:move_to(x - half(extents.width), y)
		else
			cr:move_to(x, y)
		end
		cr:show_text(s)
		y = y + line_h
	end

	cr:restore()
end

function testui:push()
	table.insert(self.dirstack, self._down)
end

function testui:pop()
	self._down = table.remove(self.dirstack)
end

function testui:next()
	if self._down then
		self.y = self.y + self.h
	else
		self.x = self.x + self.w
	end
end

function testui:down()
	self._down = true
	self:next()
end

function testui:right()
	self._down = false
	self:next()
end

function testui:rect()
	return self.x, self.y, self.w, self.h
end

function testui:button(label)
	local cr = self.cr
	cr:setcolor'#ff'
	self:text(label)
	self:down()
end

function testui:choose(label, options, default)
	local cr = self.cr
	self:text(label, 'left')
	self:next()
	self.down = false
	self:
end

function testui:slide(label, min, max, step, default)
	local cr = self.cr
	self:text(label, 'left')
	self:next()
end

function testui:repaint() end --stub


function testui:create_window()

	local d = self.app:active_display()

	self.window = self.app:window{
		x = 'center-active',
		y = 'center-active',
		w = d.w - 200,
		h = d.h - 200,
	}

	self.window.testui = self

	function self.window:keyup(key)
		if key == 'esc' then self:close() end
	end

	function self.window:mousedown(button)
		self.mouse[button] = true
	end

	function self.window:mouseup(button)
		self.mouse[button] = false
	end

	function self.window:mousemove(x, y)
		self.mx = x
		self.my = y
	end

	function self.window:repaint()
		self.testui.cr = self:bitmap():cairo()
		self.testui:repaint()
	end

end

function testui:run()

	assert(not self.app)
	self.app = nw:app()

	self:create_window()

	self.x = 10
	self.y = 10
	self.w = 200
	self.h = 20
	self._down = true

	self.app:run()
end

if not ... then

	function testui:repaint()

		self:choose('Your poison', {})

	end

	testui:run()

end

return testui
