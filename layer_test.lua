--go @ luajit -joff -jv *
jit.off(true, true)

local bit = require'bit'
local ffi = require'ffi'
local nw = require'nw'
local layer = require'layer'
local glue = require'glue'
local cairo = require'cairo'
local time = require'time'

setfenv(1, setmetatable(glue.update({}, _G), {__index = layer}))

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

assert(memtotal() == 0)

local lib = layerlib(load_font, unload_font)

local opensans = lib:font()
local amiri    = lib:font()

--lib.subpixel_x_resolution = 1/2

--window ---------------------------------------------------------------------

local app = nw:app()

local win = app:window{
	title = 'Hello!',
	w = 1800, h = 900,
}

--test harness ---------------------------------------------------------------

local test_names = {}
local test = setmetatable({}, {__newindex = function(self, k, v)
	table.insert(test_names, k)
	rawset(self, k, v)
end})
local e --top layer

local test_index = 1
local params = {}
function do_test()
	test_index = glue.clamp(test_index, 1, #test_names)

	local k = test_names[test_index]
	if not k then return end
	if not e then e = lib:layer() end
	test[k]()
end

local function choose(key, list, default)
	key = tostring(key)
	local x = params[key] or default or 1
	local x = glue.clamp(x, 1, #list)
	params[key] = x
	return list[x]
end

local function slide(key, i, j, default)
	key = tostring(key)
	local x = params[key] or default or i
	local x = glue.clamp(x, i, j)
	params[key] = x
	return x
end

--tests ----------------------------------------------------------------------

function test.box_model()
	e.border_width = slide(1, 0, 100)
	e.border_offset = slide('o', -10, 10) / 10
	e.background_clip_border_offset = slide('[', -10, 10) / 10
	e.corner_radius = slide('r', 0, 1000) * 10
	e.border_color = 0x33333388
	e.background_color = 0xcccccc88

	math.randomseed(0)
	e.border_color_left   = math.random(0xffffffff)
	e.border_color_top    = math.random(0xffffffff)
	e.border_color_right  = math.random(0xffffffff)
	e.border_color_bottom = math.random(0xffffffff)

	e.padding = slide('p', 0, 100, 0)
	e.clip_content = choose(6, {
		CLIP_BACKGROUND,
		CLIP_NONE,
		CLIP_PADDING,
	})
	e.child_count = 1
	e.layout_type = LAYOUT_FLEXBOX
	e:child(0).background_color = 0xffff00ff
end

function test.background_types()
	e.background_type = choose(1, {
		BACKGROUND_COLOR,
		BACKGROUND_LINEAR_GRADIENT,
		BACKGROUND_RADIAL_GRADIENT,
		BACKGROUND_IMAGE,
	})
	e.background_extend = choose(2, {
		BACKGROUND_EXTEND_NONE,
		BACKGROUND_EXTEND_PAD,
		BACKGROUND_EXTEND_REFLECT,
		BACKGROUND_EXTEND_REPEAT,
	})

	if e.background_type == BACKGROUND_COLOR then

		e.background_color =
			  slide(3, 0, 0xff, 0x88) * 0x1000000
			+ slide(4, 0, 0xff, 0x88) *   0x10000
			+ slide(5, 0, 0xff, 0x88) *     0x100
			+ slide(6, 0, 0xff, 0xff)

	elseif bit.band(e.background_type, BACKGROUND_GRADIENT) ~= 0 then

		e.background_x1 = 100
		e.background_y1 = 100
		e.background_x2 = 200
		e.background_y2 = 200
		e.background_r1 = 100
		e.background_r2 = 400
		e:set_background_color_stop_offset(0, 0)
		e:set_background_color_stop_offset(1, 1)
		e:set_background_color_stop_color(0, 0xff0000ff)
		e:set_background_color_stop_color(1, 0x0000ffff)

	elseif e.background_type == BACKGROUND_IMAGE then

		e:set_background_image(100, 100, BITMAP_FORMAT_ARGB32, 0, nil)
		local p = e.background_image_pixels
		ffi.fill(p, e.background_image_stride * (e.background_image_h - 1), 0x66)
		e:background_image_invalidate()

	end

	e.background_x = 10 * slide('x', 0, 100)
	e.background_y = 10 * slide('y', 0, 100)
	e.background_rotation = slide('r', 0, 360)
	e.background_scale = slide('s', 1, 100, 10) / 10
	e.background_rotation_cx = slide('shift x', 0, 1000)
	e.background_rotation_cy = slide('shift y', 0, 1000)
	e.background_scale_cx    = slide('ctrl x', 0, 1000)
	e.background_scale_cy    = slide('ctrl y', 0, 1000)
end

function test.layers_with_everything()
	e.child_count = slide(1, 0, 5, 3)

	e.clip_content = CLIP_PADDING
	--e.clip_content = CLIP_NONE

	e.padding_left   = 50
	e.padding_top    = 50
	e.padding_right  = 50
	e.padding_bottom = 50

	e.border_color_left   = 0xff00ffff
	e.border_color_top    = 0xffff00ff
	e.border_color_right  = 0x008800ff
	e.border_color_bottom = 0x888888ff
	e.corner_radius_bottom_left  = 20
	e.corner_radius_bottom_right = 10
	e.corner_radius_kappa = 1.2

	e.padding = 20
	e.border_width = 10
	e.border_color = 0xff0000ff

	e.background_type = BACKGROUND_COLOR
	e.background_color = 0x00336699 --0x336699ff

	e:set_shadow_x       (0, 6)
	e:set_shadow_y       (0, 6)
	e:set_shadow_blur    (0, 4)
	e:set_shadow_color   (0, 0x000000ff)
	e:set_shadow_content (0, false)
	e:set_shadow_inset   (0, false)

	e:set_shadow_x       (1, 4)
	e:set_shadow_y       (1, 4)
	e:set_shadow_blur    (1, 0)
	e:set_shadow_color   (1, 0xffffffff)
	e:set_shadow_content (1, false)
	e:set_shadow_inset   (1, false)

	e.layout_type = LAYOUT_FLEXBOX
	--e.flex_flow = FLEX_FLOW_Y

	local e1 = e:child(0)
	if e1 ~= nil then
		local e = e1
		e.layout_type = LAYOUT_TEXTBOX
		e.clip_content = CLIP_BACKGROUND
		e.border_width = 10; e1.padding = 20
		e.border_color = 0xffff00ff
		e.min_cw = 10; e1.min_ch = 10

		e:set_text_utf8(lorem_ipsum, -1)
		e:set_font_id    (0, -1, opensans)
		e:set_font_size  (0, -1, 14)
		e:set_text_color (0, -1, 0xffffffff)
		e.text_align_y = ALIGN_TOP
		e.text_align_x = ALIGN_CENTER

		e:set_shadow_x       (2, 1)
		e:set_shadow_y       (2, 1)
		e:set_shadow_blur    (2, 1)
		e:set_shadow_color   (2, 0x000000ff)
		e:set_shadow_content (2, true)
		e:set_shadow_inset   (2, false)
	end

	local e2 = e:child(1)
	if e2 ~= nil then
		local e = e2
		e.clip_content = CLIP_PADDING
		e.layout_type = LAYOUT_TEXTBOX
		e.background_type = BACKGROUND_COLOR
		e.background_color = 0x33333366

		e.border_width = 10; e2.padding = 20
		e.border_color = 0x00ff00ff
		e.min_cw = 10; e2.min_ch = 10

		e:set_text_utf8('It\'s just text but it\'s alive!', -1)
		e:set_font_id    (0, -1, amiri)
		e:set_font_size  (0, -1, 50)
		e:set_text_color (0, -1, 0x333333ff)
		e.text_align_y = ALIGN_CENTER
		e.text_align_x = ALIGN_CENTER

		e:set_shadow_x       (0, 0)
		e:set_shadow_y       (0, 1)
		e:set_shadow_blur    (0, 2)
		e:set_shadow_color   (0, 0x000000ff)
		e:set_shadow_content (0, true)
		e:set_shadow_inset   (0, true)

		e:set_shadow_x       (1, 0)
		e:set_shadow_y       (1, 1)
		e:set_shadow_blur    (1, 1)
		e:set_shadow_color   (1, 0x888888ff)
		e:set_shadow_content (1, true)
		e:set_shadow_inset   (1, false)
	end

	for i=3,e.child_count do
		local e = e:child(i-1)
		if e then
			e.border_width = 1
		end
	end
end

function test.flexbox_baseline_wrapped()
	e.layout_type = LAYOUT_FLEXBOX
	e.border_width = 1
	e.flex_wrap = choose('w', {true, false})
	e.item_align_x = choose(2, {
		ALIGN_AUTO,
		--ALIGN_LEFT,
		--ALIGN_RIGHT,
		ALIGN_START,
		ALIGN_END,
		ALIGN_CENTER,
		ALIGN_STRETCH,
	})
	e.item_align_y = choose(3, {
		ALIGN_BASELINE,
		ALIGN_TOP,
		ALIGN_BOTTOM,
		--ALIGN_START,
		--ALIGN_END,
		ALIGN_CENTER,
		ALIGN_STRETCH,
	})
	e.align_items_y = choose(4, {
		ALIGN_TOP,
		ALIGN_BOTTOM,
		--ALIGN_START,
		--ALIGN_END,
		ALIGN_CENTER,
		ALIGN_SPACE_AROUND,
		ALIGN_SPACE_BETWEEN,
		ALIGN_SPACE_EVENLY,
		ALIGN_STRETCH,
	})
	e.align_items_x = choose(5, {
		ALIGN_TOP,
		ALIGN_BOTTOM,
		--ALIGN_START,
		--ALIGN_END,
		ALIGN_CENTER,
		ALIGN_SPACE_AROUND,
		ALIGN_SPACE_BETWEEN,
		ALIGN_SPACE_EVENLY,
		ALIGN_STRETCH,
	})

	local texts = {
		"Lorem ipsum",
		"dolor sit amet",
		"You only killed the bride’s father, you know.",
		"I didn’t mean to.",
		"Didn’t mean to?",
		"You put your sword right through his head.",
		"Oh dear… is he all right?",
	}

	math.randomseed(slide(0, 1, 10))

	e.child_count = slide(1, 0, 1000, 20)
	for i = 0, e.child_count-1 do
		local e = e:child(i)
		e.border_width = 1
		e.padding = 10
		e.min_cw = 100 + math.random(slide(6, 0, 500))
		e.min_ch = math.random(slide(7, 0, 200))
		e.text_align_x = ALIGN_CENTER
		e.text_align_y = ALIGN_BOTTOM
		e.layout_type = LAYOUT_TEXTBOX
		e:set_text_utf8(texts[math.random(#texts)], -1)
		e:set_font_id   (0, -1, opensans)
		e:set_font_size (0, -1, 14)
		if i == 1 then
			--e.align_y = ALIGN_BOTTOM
		end
	end
end

function test.grid_autopos(flow)

	e.layout_type = LAYOUT_GRID
	e.border_color = 0x000000ff
	e.border_width = 1

	e.child_count = slide(1, 1, 1000, 21)
	for i = 0, e.child_count-1 do
		local e = e:child(i)
		e.min_cw = 0
		e.min_ch = 0
		e.border_width = 2
		e.border_offset = 0
		e.snap_x = false
		e.snap_y = true
		e.clip_content = CLIP_BACKGROUND
		e:set_text_utf8(''..i+1, -1)
		e:set_font_id   (0, -1, opensans)
		e:set_font_size (0, -1, 10)
	end
	e.grid_row_gap = 10
	e.grid_col_gap = 10
	e.grid_wrap = slide(2, 1, 100, math.sqrt(e.child_count) - 1)
	e.grid_flow = flow or
		  choose(3, {0, GRID_FLOW_Y})
		+ choose(4, {0, GRID_FLOW_B})
		+ choose(5, {0, GRID_FLOW_R})
end

do_test()

function win:repaint()

	local cr = self:bitmap():cairo()

	cr:identity_matrix()
	--cr:rgba(1, 1, 1, 1)
	cr:rgba(0, 0, 0, 1)
	cr:paint()

	local w, h = self:client_size()
	cr:translate(50, 50)

	local zoom = slide('z', 1, 10, 5)
	if zoom < 5 then zoom = 1/zoom else zoom = zoom - 4 end

	e:sync_top(zoom * w - 100, zoom * h - 100)
	e:draw(cr)
end

function win:keypress(key)
	if key == 'esc' then
		self:close()
	elseif key == 'pageup' or key == 'pagedown' then
		test_index = test_index + (key == 'pageup' and -1 or 1)
		params = {}
		e:free()
		e = nil
		do_test()
		self:invalidate()
	elseif key == 'up' or key == 'down' or key == 'left' or key == 'right' then
		local param_key
		for k in pairs(params) do
			if app:key(k) then
				param_key = k
			end
		end
		if param_key then
			params[param_key] = params[param_key]
				+ ((key == 'up' or key == 'left') and -1 or 1)
			do_test()
			self:invalidate()
		end
	end
end

app:run()

e:free()

lib:dump_stats()
lib:free()
memreport()
assert(memtotal() == 0)
