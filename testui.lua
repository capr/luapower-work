
--IMGUI for creating manual tests for UI libraries.
--Written by Cosmin Apreutesei. Public Domain.

--This API is designed for maximum of stability and thus minimum flexibility.

local nw = require'nw'
local glue = require'glue'
local ffi = require'ffi'
local color = require'color'
local push, pop = table.insert, table.remove

local testui = {}

--drawing primitives ---------------------------------------------------------

local function half(x)
	return math.floor(x / 2 + 0.5)
end

function testui:setcolor(c)
	local r, g, b, a = color.parse(c, 'rgb')
	self.cr:rgba(r, g, b, a or 1)
end

function testui:text_w(s, bold)
	local cr = self.cr
	s = tostring(s)
	cr:font_face('Arial', 'normal', bold and 'bold' or 'normal')
	cr:font_size(12)
	return cr:text_extents(s).width
end

function testui:text(s, halign, valign, x, y, w, h, bold, color)
	local cr = self.cr
	s = tostring(s)
	halign = halign or 'center'
	valign = valign or 'center'
	local tw = self:text_w(s, bold)

	cr:save()
	cr:rectangle(x, y, w, h)
	cr:clip()

	local font_extents = cr:font_extents()
	if valign == 'top' then
		y = y + font_extents.ascent
	elseif valign == 'bottom' then
		y = y + h - font_extents.descent
	elseif valign == 'center' then
		y = y + half(h + font_extents.ascent - font_extents.descent)
	end

	if ffi.os == 'OSX' then --TODO: remove this hack
		y = y + 1
	end
	if halign == 'right' then
		cr:move_to(x + w - tw, y)
	elseif halign == 'center' then
		cr:move_to(x + half(w) - half(tw), y)
	else
		cr:move_to(x, y)
	end
	self:setcolor(color or '#ff')
	cr:show_text(s)

	cr:restore()
	return w
end

--layouting API --------------------------------------------------------------

function testui:reset()
	self.x = 10
	self.y = 10
	self.group_x = x
	self.group_y = y
	self.w = 0
	self.h = 0
	self.min_w = 18
	self.min_h = 16
	self.max_w = 1/0
	self.max_h = 1/0
	self.margin_h = 3
	self.margin_w = 3
	self.dir = 'down'
	self.groupstack = {}
end

function testui:rect(w, h)
	local x, y = self.x, self.y
	w = glue.clamp(w, self.min_w, self.max_w)
	h = glue.clamp(h, self.min_h, self.max_h)
	if self.dir == 'down' then
		self.y = y + h + self.margin_h
		self.w = math.max(self.w, w)
	elseif self.dir == 'right' then
		self.x = x + w + self.margin_w
		self.h = math.max(self.h, h)
	else
		assert(false)
	end
	return x, y, w, h
end

function testui:pushgroup(dir, minmax)
	assert(dir == 'down' or dir == 'right')
	push(self.groupstack, {self.dir, self.x, self.y, self.min_w, self.min_h,
		self.max_w, self.max_h, self.margin_w, self.margin_h})
	self.dir = dir
	self.group_x = self.x
	self.group_y = self.y
	if minmax then
		if self.dir == 'right' then
			self.min_w = self.min_w * minmax
			self.max_w = self.min_w
			self.margin_w = 0
		else
			self.min_h = self.min_h * minmax
			self.max_h = self.min_h
			self.margin_h = 0
		end
	end
end

function testui:popgroup(margin)
	local dir = self.dir
	if self.groupstack[#self.groupstack][1] == self.dir then
		local _
		_, _, _, self.min_w, self.min_h, self.max_w, self.max_h,
			self.margin_w, self.margin_h = unpack(pop(self.groupstack))
		return
	end
	self.dir, self.x, self.y, self.min_w, self.min_h, self.max_w, self.max_h,
		self.margin_w, self.margin_h = unpack(pop(self.groupstack))
	if self.dir == 'down'  then self.y = self.y + self.h + (margin or self.margin_h) end
	if self.dir == 'right' then self.x = self.x + self.w + (margin or self.margin_w) end
	local g = self.groupstack[#self.groupstack]
	self.group_x = g and g.x or self.x
	self.group_y = g and g.y or self.y
end

function testui:nextgroup(margin)
	local min_w, min_h, max_w, max_h, margin_w, margin_h =
		self.min_w, self.min_h, self.max_w, self.max_h, self.margin_w, self.margin_h
	local dir = self.dir
	self:popgroup(margin)
	self:pushgroup(dir)
	self.min_w, self.min_h, self.max_w, self.max_h, self.margin_w, self.margin_h =
		min_w, min_h, max_w, max_h, margin_w, margin_h
end

--input API ------------------------------------------------------------------

function testui:hit(x, y, w, h)
	return self.mx
		and self.mx >= x
		and self.my >= y
		and self.mx <= x + w
		and self.my <= y + h
end

function testui:activate(id, x, y, w, h)
	if self.active_id == id then
		return true, true
	elseif not self.active_id then
		local hit = self:hit(x, y, w, h)
		local active = hit and self.mouse.left
		if active then
			self.active_id = id
			return true, true, true
		end
		return active, hit
	end
end

--widgets --------------------------------------------------------------------

function testui:heading(s)
	local w = self:text_w(s, true)
	local x, y, w, h = self:rect(w + 10, 0)
	self:text(s, 'left', nil, x, y, w, h, true, '#ffff33ff')
end

function testui:label(s)
	local w = self:text_w(s)
	local x, y, w, h = self:rect(w + 10, 0)
	self:text(s, 'left', nil, x, y, w, h)
end

function testui:button(id, label, selected)
	label = label or id
	local cr = self.cr
	local w = self:text_w(label)
	local x, y, w, h = self:rect(w + 10, 0)
	local _, hit, activated = self:activate(id, x, y, w, h)
	cr:rectangle(x, y, w, h)
	self:setcolor'#99'
	cr:stroke_preserve()
	self:setcolor(selected and '#55' or hit and '#33' or '#00')
	cr:fill()
	self:text(label, nil, nil, x, y, w, h)
	if activated then
		self.window:invalidate()
		return true
	end
end

function testui:choose(id, options, v)
	local cr = self.cr
	local mw, mh = self.margin_w, self.margin_h
	self.margin_w, self.margin_h = 0, 0
	local option
	for i,s in ipairs(options) do
		local selected
		if type(v) == 'table' then --multiple choice
			selected = v[s]
		else
			selected = s == v
		end
		if self:button(id..'.'..s, s, selected) then
			option = s
		end
	end
	self.margin_w, self.margin_h = mw, mh
	return option
end

function testui:toggle(id, label, selected)
	local active, selected = self:button(id, label, selected)
	if active then return end
end

function testui:slide(id, label, v, min, max, step)
	v = glue.clamp(v or min, min, max)
	step = step or (max - min) / 100
	local cr = self.cr
	local s1 = label or id
	local s2 = string.format('%g', glue.snap(v, step))
	local w1 = self:text_w(s1)
	local w2 = self:text_w(s2)
	local x, y, w, h = self:rect(w1 + w2 + 10, 0)
	local active, hit = self:activate(id, x, y, w, h)
	cr:rectangle(x, y, w, h)
	self:setcolor'#99'
	cr:stroke_preserve()
	self:setcolor'#00'
	cr:fill()
	self:setcolor(hit and '#33' or '#22')
	local pw = glue.lerp(v, min, max, 0, w)
	cr:rectangle(x, y, pw, h)
	cr:fill()
	self:text(s1, 'left' , nil, x+5, y, w, h)
	self:text(s2, 'right', nil, x-5, y, w, h)
	if active then
		self.window:invalidate()
		local v = glue.lerp(self.mx, x, x + w, min, max)
		return glue.snap(glue.clamp(v, min, max), step)
	end
end

--test window ----------------------------------------------------------------

function testui:repaint() end --stub

function testui:run()

	assert(not self.app)
	self.app = nw:app()

	local d = self.app:active_display()

	self.window = self.app:window{
		x = 'center-active',
		y = 'center-active',
		w = d.w - 200,
		h = d.h - 200,
		--maximized = true,
	}

	self.window.testui = self

	function self.window:keyup(key)
		if key == 'esc' then
			if self:ismaximized() then self:restore() else self:close() end
		end
	end

	function self.window:mousedown(button)
		self.testui.mouse[button] = true
		self:invalidate()
	end

	self.mouse = {}

	function self.window:mouseup(button)
		self.testui.mouse[button] = false
		if button == 'left' then
			self.testui.active_id = false
		end
		self:invalidate()
	end

	function self.window:mousemove(x, y)
		self.testui.mx = x
		self.testui.my = y
		self:invalidate()
	end

	function self.window:repaint()
		local cr = self:bitmap():cairo()
		self.testui.cr = cr
		self.testui:setcolor'#00'
		cr:paint()
		self.testui.win_w, self.testui.win_h = self:client_size()
		self.testui:reset()
		cr:new_path()
		cr:operator'over'
		cr:save()
		self.testui:repaint()
		cr:restore()
	end

	self.app:run()
end

--self-test ------------------------------------------------------------------

if not ... then

	function testui:repaint()

		self:pushgroup'right'
		p1 = self:choose('poison1', {
			'Arsenic', 'Old Lace',
		}, p1) or p1
		self:popgroup()

		self:pushgroup'right'
		p2 = self:choose('poison2', {
			'Arsenic', 'Old Lace',
		}, p2) or p2
		self:popgroup()

		p3 = self:slide('slide1', 'Slide', p3, 0, 10, 0.1) or p3

	end

	testui:run()

end

return testui
