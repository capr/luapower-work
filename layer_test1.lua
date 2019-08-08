
local ffi = require'ffi'
local testui = require'testui'
local layer = require'layer'
local color = require'color'
local pp = require'pp'

--lib object & fonts ---------------------------------------------------------

local fonts = {
	assert(glue.readfile'media/fonts/OpenSans-Regular.ttf');
	assert(glue.readfile'media/fonts/Amiri-Regular.ttf');
}

local function load_font(font_id, file_data_buf, file_size_buf)
	local s = assert(fonts[font_id+1])
	file_data_buf[0] = ffi.cast('void*', s)
	file_size_buf[0] = #s
end

local function unload_font(font_id, file_data_buf, file_size_buf)
	--nothing
end

local lorem_ipsum = glue.readfile('lorem_ipsum.txt'):sub(1, 1000)

assert(layer.memtotal() == 0)

local lib = layer.layerlib(load_font, unload_font)

local opensans = lib:font()
local amiri    = lib:font()

--top layer object -----------------------------------------------------------

local top_e = lib:layer()
local e = top_e
local hit_e, hit_area
e.x = 1100
e.y = 100
e.w = 500
e.h = 300
e.border_width = 1

--testui wrappers ------------------------------------------------------------

local function get_prop(e, prop) return e[prop] end
local function set_prop(e, prop, v) e[prop] = v end
local function get_prop_i(e, prop, i) return e['get_'..prop](e, i) end
local function set_prop_i(e, prop, v, i) e['set_'..prop](e, i, v) end
local function getset(prop, i)
	local id = i and prop..'['..i..']' or prop
	get = i and get_prop_i or get_prop
	set = i and set_prop_i or set_prop
	return id, get, set
end
local function slide(prop, min, max, step, i, ...)
	local id, get, set = getset(prop, i, ...)
	local v = get(e, prop, i)
	local v = testui:slide(id, nil, v, min, max, step)
	if v then set(e, prop, v, i) end
end
local function slidex(prop, ...) return slide(prop, -testui.win_w, testui.win_w, .5, ...) end
local function slidey(prop, ...) return slide(prop, -testui.win_h, testui.win_h, .5, ...) end
local function slidew(prop, ...) return slide(prop, -100, 100, .5, ...) end
local function slidea(prop, ...) return slide(prop, -360, 360, .5, ...) end
local function sliden(prop, ...) return slide(prop, -10, 10, .1, ...) end
local function slideo(prop, ...) return slide(prop, -2, 2, .001, ...) end
local function pickcolor(prop, i, ...)
	local id, get, set = getset(prop, i, ...)
	local r, g, b, a = color.parse_rgba32(get(e, prop, i))
	local h, s, l = color.convert('hsl', 'rgb', r, g, b)

	testui:pushgroup'down'
	testui.margin_h = 0
	testui.min_h = 11
	testui:label(prop)
	testui:popgroup()
	testui:pushgroup'right'
	testui.min_w = 50
	testui.margin_w = 0
	local h1 = testui:slide(id..'_H', 'H', h, 0, 360, 1)
	local s1 = testui:slide(id..'_S', 'S', s, 0, 1, .01)
	local l1 = testui:slide(id..'_L', 'L', l, 0, 1, .01)
	local a1 = testui:slide(id..'_A', 'a', a, 0, 1, .01)
	testui:popgroup()

	if h1 or s1 or l1 or a1 then
		local r, g, b = color.convert('rgb', 'hsl', h1 or h, s1 or s, l1 or l)
		local c = color.format('rgba32', 'rgb', r, g, b, a1 or a)
		set(e, prop, c, i)
	end
end

local map_t = glue.memoize(function(prop) return {} end)
local function enum_map(prop, prefix, options)
	local t = map_t(prop)
	if not next(t) then
		for i,s in ipairs(options) do
			local enum = layer[prefix:upper()..s:upper()]
			t[s] = enum
			t[enum] = s
		end
	end
	return t
end
local function choose(prop, prefix, options, i, ...)
	local id, get, set = getset(prop, i, ...)
	local t = enum_map(prop, prefix, options)
	local v = t[get(e, prop, i)]
	testui:pushgroup'down'
	testui.margin_h = -2
	testui:label(prop)
	testui:popgroup()
	testui:pushgroup'right'
	testui.min_w = 0
	local s = testui:choose(id, options, v)
	if s then set(e, prop, t[s], i) end
	testui:popgroup()
end

local function bits_to_options(bits, maps)
	local vt = {}
	for k,v in pairs(maps) do
		if type(k) == 'number' and glue.getbit(bits, k) then
			vt[v] = true
		end
	end
	return vt
end
local function mchoose(prop, prefix, options, i, ...)
	local id, get, set = getset(prop, i, ...)
	local t = enum_map(prop, prefix, options)
	local v = get(e, prop, i)
	testui:pushgroup'down'
	testui.margin_h = -2
	testui:label(prop)
	testui:popgroup()
	testui:pushgroup'right'
	testui.min_w = 0
	local vt = bits_to_options(v, t)
	local s = testui:choose(id, options, vt)
	if s then
		local v = glue.setbit(v, t[s], not vt[s])
		set(e, prop, v, i)
	end
	testui:popgroup()
end

local function toggle(prop, i, ...)
	local id, get, set = getset(prop, i, ...)
	local v = get(e, prop, i, ...)
	if testui:button(id, nil, v) then
		set(e, prop, not v, i)
	end
end

--layer tree (de)serialization -----------------------------------------------

local function serialize(e)
	local function list(e, n, fields)
		local dt = {}
		for i = 0, n-1 do
			local t = {}
			dt[i+1] = t
			for k, convert in glue.sortedpairs(fields) do
				local v = e['get_'..k](e, i)
				if type(convert) == 'function' then
					v = convert(v)
				end
				t[k] = v
			end
		end
		return dt
	end
	local t = {}
	t.x = e.x
	t.y = e.y
	t.w = e.w
	t.h = e.h
	t.min_cw = e.min_cw
	t.min_ch = e.min_ch
	t.align_x = e.align_x
	t.align_y = e.align_y
	t.padding_left   = e.padding_left
	t.padding_top    = e.padding_top
	t.padding_right  = e.padding_right
	t.padding_bottom = e.padding_bottom
	t.rotation    = e.rotation
	t.rotation_cx = e.rotation_cx
	t.rotation_cy = e.rotation_cy
	t.scale       = e.scale
	t.scale_cx    = e.scale_cx
	t.scale_cy    = e.scale_cy
	t.visible     = e.visible
	t.operator    = e.operator
	t.clip_content = e.clip_content
	t.snap_x  = e.snap_x
	t.snap_y  = e.snap_y
	t.opacity = e.opacity
	t.hit_test_mask = e.hit_test_mask
	t.border_width_left   = e.border_width_left
	t.border_width_right  = e.border_width_right
	t.border_width_top    = e.border_width_top
	t.border_width_bottom = e.border_width_bottom
	t.corner_radius_top_left     = e.corner_radius_top_left
	t.corner_radius_top_right    = e.corner_radius_top_right
	t.corner_radius_bottom_left  = e.corner_radius_bottom_left
	t.corner_radius_bottom_right = e.corner_radius_bottom_right
	t.corner_radius_kappa        = e.corner_radius_kappa
	t.border_color_left   = e.border_color_left
	t.border_color_right  = e.border_color_right
	t.border_color_top    = e.border_color_top
	t.border_color_bottom = e.border_color_bottom
	t.border_dash_count   = e.border_dash_count
	t.border_dash         = list(e, e.border_dash_count, {border_dash=1})
	t.border_dash_offset  = e.border_dash_offset
	t.border_offset = e.border_offset
	t.background_type = e.background_type
	t.background_color = e.background_color
	t.background_color_set = e.background_color_set
	t.background_x1 = e.background_x1
	t.background_y1 = e.background_y1
	t.background_x2 = e.background_x2
	t.background_y2 = e.background_y2
	t.background_r1 = e.background_r1
	t.background_r2 = e.background_r2
	t.background_color_stop_count = e.background_color_stop_count
	t.background_color_stops = list(e, e.background_color_stop_count, {
		background_color_stop_color=1,
		background_color_stop_offset=1,
	})
	--TODO: background_image = e.background_image
	t.background_hittable            = e.background_hittable
	t.background_operator            = e.background_operator
	t.background_clip_border_offset  = e.background_clip_border_offset
	t.background_x                   = e.background_x
	t.background_y                   = e.background_y
	t.background_rotation            = e.background_rotation
	t.background_rotation_cx         = e.background_rotation_cx
	t.background_rotation_cy         = e.background_rotation_cy
	t.background_scale               = e.background_scale
	t.background_scale_cx            = e.background_scale_cx
	t.background_scale_cy            = e.background_scale_cy
	t.background_extend              = e.background_extend
	t.shadow_count = e.shadow_count
	t.shadows = list(e, e.shadow_count, {
		shadow_x       =1,
		shadow_y       =1,
		shadow_color   =1,
		shadow_blur    =1,
		shadow_passes  =1,
		shadow_inset   =1,
		shadow_content =1,
	})
	t.text_utf8 = e.text_utf8
	t.text_maxlen = e.text_maxlen
	t.text_dir = e.text_dir
	t.text_align_x = e.text_align_x
	t.text_align_y = e.text_align_y
	t.span_count = e.span_count
	t.text_spans = list(e, e.span_count, {
		span_font_id           =1,
		span_font_size         =1,
		span_features          =1,
		span_script            =ffi.string,
		span_lang              =1,
		span_paragraph_dir     =1,
		span_line_spacing      =1,
		span_hardline_spacing  =1,
		span_paragraph_spacing =1,
		span_nowrap            =1,
		span_text_color        =1,
		span_text_opacity      =1,
		span_text_operator     =1,
	})
	--TODO: text_cursor_xs
	-- text_caret_width
	-- text_caret_color
	-- text_caret_insert_mode
	-- text_selectable
	t.in_transition     = e.in_transition
	t.layout_type       = e.layout_type
	t.align_items_x     = e.align_items_x
	t.align_items_y     = e.align_items_y
	t.item_align_x      = e.item_align_x
	t.item_align_y      = e.item_align_y
	t.flex_flow         = e.flex_flow
	t.flex_wrap         = e.flex_wrap
	t.fr                = e.fr
	t.break_before      = e.break_before
	t.break_after       = e.break_after
	t.grid_col_fr_count = e.grid_col_fr_count
	t.grid_row_fr_count = e.grid_row_fr_count
	t.grid_col_fr       = e.grid_col_fr
	t.grid_row_fr       = e.grid_row_fr
	t.grid_col_gap      = e.grid_col_gap
	t.grid_row_gap      = e.grid_row_gap
	t.grid_flow         = e.grid_flow
	t.grid_wrap         = e.grid_wrap
	t.grid_min_lines    = e.grid_min_lines
	t.grid_col          = e.grid_col
	t.grid_row          = e.grid_row
	t.grid_col_span     = e.grid_col_span
	t.grid_row_span     = e.grid_row_span
	if e.child_count > 0 then
		t.children = {}
		for i = 0, e.child_count-1 do
			t.children[i+1] = serialize(e:child(i))
		end
	end
	return t
end

local function save_state()
	assert(glue.writefile('var/layer_test.lua',
		'return '..pp.format(serialize(top_e), {indent = '\t', sort_keys = true})))
end

local function deserialize(e, t)
	for k,v in glue.sortedpairs(t) do
		if k == 'children' then
			e.child_count = #v
			for i,t in ipairs(v) do
				deserialize(e:child(i-1), t)
			end
		elseif type(v) == 'table' then
			for i,t in ipairs(v) do
				for k,v in glue.sortedpairs(t) do
					local set = e['set_'..k]
					set(e, i-1, v)
				end
			end
		else
			e[k] = v
		end
	end
end

local function load_state()
	local chunk = loadfile('var/layer_test.lua')
	if not chunk then return end
	local t = chunk()
	deserialize(top_e, t)
end

--test UI --------------------------------------------------------------------

local child_i = 'top layer'

function testui:repaint()

	self:pushgroup'down'
	self.min_w = 240
	self.max_w = 240

	self:pushgroup'right'
	local cur_e = e
	e = top_e
	sliden('child_count')
	e = cur_e
	local t = {'top layer'}
	for i = 0, top_e.child_count-1 do
		table.insert(t, 'child '..i)
	end
	self.min_w = 0
	local i = self:choose('children', t, child_i)
	if i then
		if i == 'top layer' then
			e = top_e
		else
			local i = tonumber(i:match'%d+')
			e = top_e:child(i)
		end
		child_i = i
	end

	self:popgroup()

	self:pushgroup'right'

	self:pushgroup'down'

	self:heading'Position'

	self:pushgroup('right', 1/2)
	slidex('x')
	slidey('y')
	self:nextgroup()
	slidex('w')
	slidey('h')
	self:popgroup()

	self:heading'Drawing'

	choose('operator', 'operator_', {'clear', 'source', 'over', 'in', 'out', 'xor'})

	self:pushgroup('right', 1/4)
	toggle'clip_content'
	toggle'snap_x'
	toggle'snap_y'
	self:popgroup()

	slideo'opacity'

	self:heading'Border'

	slidew('border_width'       )
	slidew('border_width_left'  )
	slidew('border_width_right' )
	slidew('border_width_top'   )
	slidew('border_width_bottom')

	slidew('corner_radius')
	slidew('corner_radius_top_left')
	slidew('corner_radius_top_right')
	slidew('corner_radius_bottom_left')
	slidew('corner_radius_bottom_right')

	pickcolor('border_color')
	pickcolor('border_color_left')
	pickcolor('border_color_right')
	pickcolor('border_color_top')
	pickcolor('border_color_bottom')

	sliden('border_dash_count')
	for i = 0, e.border_dash_count-1 do
		slide('border_dash', -100, 100, .1, i)
	end
	slide('border_dash_offset', -100, 100, .1)

	self:heading'Padding'

	slidew('padding'       )
	self:pushgroup('right', 1/2)
	slidew('padding_left'  )
	slidew('padding_right' )
	self:nextgroup()
	slidew('padding_top'   )
	slidew('padding_bottom')
	self:popgroup()

	self:heading'Transforms'

	slidea('rotation')
	self:pushgroup('right', 1/2)
	slidex('rotation_cx')
	slidey('rotation_cy')
	self:popgroup()

	slideo('scale')
	self:pushgroup('right', 1/2)
	slidex('scale_cx')
	slidey('scale_cy')
	self:popgroup()

	self:nextgroup(10)

	self:heading'Background'

	choose('background_type', 'background_', {'color', 'linear_gradient', 'radial_gradient', 'image'})
	pickcolor('background_color')
	toggle('background_color_set')

	self:pushgroup'right'
	self.min_w = self.min_w / 2
	self.max_w = self.min_w
	slidex('background_x1')
	slidey('background_y1')
	self:nextgroup()
	slidex('background_x2')
	slidey('background_y2')
	self:nextgroup()
	slidex('background_r1')
	slidey('background_r2')
	self:popgroup()

	sliden('background_color_stop_count')

	for i = 0, e.background_color_stop_count-1 do
		pickcolor('background_color_stop_color', i)
		slideo('background_color_stop_offset', i)
	end

	--[[
		set_background_image=1,
		get_background_image_w=1,
		get_background_image_h=1,
		get_background_image_stride=1,
		get_background_image_pixels=1,
		get_background_image_format=1,
		background_image_invalidate=1,
		background_image_invalidate_rect=1,
	]]

	toggle('background_hittable')
	choose('background_operator', 'operator_', {'clear', 'source', 'over', 'in', 'out', 'xor'})
	slideo('background_clip_border_offset')

	self:pushgroup('right', 1/2)
	slidex('background_x')
	slidex('background_y')
	self:popgroup()
	slidea('background_rotation')
	slidex('background_rotation_cx')
	slidey('background_rotation_cy')
	slideo('background_scale')
	slidex('background_scale_cx')
	slidey('background_scale_cy')

	choose('background_extend', 'background_extend_', {'none', 'pad', 'reflect', 'repeat'})

	self:heading'Shadows'

	slide('shadow_count', -10, 10, 1)
	for i = 0, e.shadow_count-1 do
		pickcolor('shadow_color', i)
		self:pushgroup('right', 1/2)
		slidew('shadow_x', i)
		slidew('shadow_y', i)
		self:popgroup()
		self:pushgroup('right', 1/2)
		slide ('shadow_blur',   -500, 500, 1, i)
		slide ('shadow_passes',  -20,  20, 1, i)
		self:nextgroup()
		toggle('shadow_inset', i)
		toggle('shadow_content', i)
		self:popgroup()
	end

	self:nextgroup(10)

	self:heading'Layouting'

	choose('layout_type', 'layout_', {'null', 'textbox', 'flexbox', 'grid'})

	self:pushgroup('right', 1/2)
	slidex('min_cw')
	slidey('min_ch')
	self:popgroup()

	toggle('in_transition')

	choose('align_items_x', 'align_', {
		'left', 'right', 'center', 'stretch', 'start', 'end',
		'space_evenly', 'space_around', 'space_between',
	})
	choose('align_items_y', 'align_', {
		'top', 'bottom', 'center', 'stretch', 'start', 'end',
		'space_evenly', 'space_around', 'space_between',
	})
	choose('item_align_x', 'align_', {
		'left', 'right', 'center', 'stretch', 'start', 'end',

	})
	choose('item_align_y', 'align_', {
		'top', 'bottom', 'center', 'stretch', 'start', 'end',
	})
	choose('align_x', 'align_', {
		'default',
		'left', 'right', 'center', 'stretch', 'start', 'end',
	})
	choose('align_y', 'align_', {
		'default',
		'top', 'bottom', 'center', 'stretch', 'start', 'end',
		'baseline',
	})

	choose('flex_flow', 'flex_flow_', {'x', 'y'})
	toggle('flex_wrap')

	slideo('fr')

	self:pushgroup('right', 1/2)
	toggle('break_before')
	toggle('break_after')
	self:popgroup()

	sliden('grid_col_fr_count')
	for i = 0, e.grid_col_fr_count-1 do
		slideo('grid_col_fr', i)
	end
	sliden('grid_row_fr_count')
	for i = 0, e.grid_row_fr_count-1 do
		slideo('grid_row_fr', i)
	end

	self:pushgroup('right', 1/2)
	slidew('grid_col_gap')
	slidew('grid_row_gap')
	self:popgroup()

	mchoose('grid_flow', 'grid_flow_', {'y', 'r', 'b'})

	sliden('grid_wrap')

	slideo('grid_min_lines')

	self:pushgroup('right', 1/2)
	sliden('grid_col')
	sliden('grid_col_span')
	self:nextgroup()
	sliden('grid_row')
	sliden('grid_row_span')
	self:popgroup()

	self:popgroup()
	self:popgroup()
	self:popgroup()

	top_e:sync_layout()
	top_e:draw(self.cr)

	if self.mx then
		local lbuf = ffi.new'layer_t*[1]'
		hit_area = top_e:hit_test(self.cr, self.mx, self.my, 0, lbuf)
		hit_e = lbuf[0]
		if hit_e == nil then hit_e = nil end
		if hit_area == 0 then hit_area = nil end
		if hit_e then
			--child_i = hit_e ~= top_e and hit_e.index or nil
		end
	end

end

load_state()

testui:run()

save_state()
