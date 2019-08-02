--go @ luajit -joff -jv *
jit.off(true, true)

local ffi = require'ffi'
local nw = require'nw'
local layer = require'layer'
local glue = require'glue'
local cairo = require'cairo'
local time = require'time'
local print = print
local assert = assert
local math = math

setfenv(1, setmetatable({}, {__index = layer}))

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

local lorem_ipsum = 'You only Oh dear… '..glue.readfile('lorem_ipsum.txt'):sub(1, 1000)

assert(memtotal() == 0)

local lib = layerlib(load_font, unload_font)

local opensans = lib:font()
local amiri    = lib:font()

--test harness ---------------------------------------------------------------

local test = {}
local e --top layer

local test_index = 1
local selections = {}
local zoom = 1
local density = 6
local tests
function do_test()
	tests = tests or glue.keys(test, true)

	test_index = glue.clamp(test_index, 1, #tests)
	density = glue.clamp(density, 1, 1000)

	local k = tests[test_index]
	if not k then return end
	print(test_index, k)
	if e then e:free(); e = nil end
	e = lib:layer()
	test[k]()
end

local function choose(sel_id, list)
	local x = selections[sel_id] or 1
	local x = glue.clamp(x, 1, #list)
	selections[sel_id] = x
	return list[x]
end

local function lerp(sel_id, i, j)
	local x = selections[sel_id] or 1
	local x = glue.clamp(x, 1, j-i+1)
	selections[sel_id] = x
	return glue.lerp(x, 1, j-i+1, i, j)
end

--window ---------------------------------------------------------------------

local app = nw:app()

local win = app:window{
	title = 'Hello!',
	w = 1800, h = 900,
}

--tests ----------------------------------------------------------------------

function test.layers_with_everything()
	e.child_count = density
	local e1 = e:child(0)
	local e2 = e:child(1)
	local e3 = e:child(2)
	local e4 = e:child(3)

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

	--e.background_type = background_LINEAR_GRADIENT
	e.background_y2 = 100
	e:set_background_color_stop_offset(0, 0)
	e:set_background_color_stop_offset(1, 1)
	e:set_background_color_stop_color(0, 0xff0000ff)
	e:set_background_color_stop_color(1, 0x0000ffff)
	e.background_x1 = 1

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

	e1.layout_type = LAYOUT_TEXTBOX
	e1.clip_content = CLIP_BACKGROUND
	e2.clip_content = CLIP_PADDING

	e2.layout_type = LAYOUT_TEXTBOX
	e2.background_type = BACKGROUND_COLOR
	e2.background_color = 0x33333366

	e1.border_width = 10; e1.padding = 20
	e2.border_width = 10; e2.padding = 20
	e1.border_color = 0xffff00ff
	e2.border_color = 0x00ff00ff
	e1.min_cw = 10; e1.min_ch = 10
	e2.min_cw = 10; e2.min_ch = 10

	--llib.subpixel_x_resolution = 1/2
	--llib.glyph_cache_size = 0
	--llib.glyph_run_cache_size = 0

	e1:set_text_utf8(lorem_ipsum, -1)
	e1:set_font_id    (0, -1, opensans)
	e1:set_font_size  (0, -1, 14)
	e1:set_text_color (0, -1, 0xffffffff)
	e1.text_align_y = ALIGN_TOP
	e1.text_align_x = ALIGN_CENTER

	e1:set_shadow_x       (2, 1)
	e1:set_shadow_y       (2, 1)
	e1:set_shadow_blur    (2, 1)
	e1:set_shadow_color   (2, 0x000000ff)
	e1:set_shadow_content (2, true)
	e1:set_shadow_inset   (2, false)

	--e1.visible = false
	--e2.visible = false

	do local e = e2
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

	--e3.border_width = 1
	--e4.border_width = 1
end

function test.flexbox_baseline_wrapped()
	e.layout_type = LAYOUT_FLEXBOX
	e.border_width = 1
	e.flex_wrap = true
	e.item_align_x = choose(1, {
		ALIGN_AUTO,
		--ALIGN_LEFT,
		--ALIGN_RIGHT,
		ALIGN_START,
		ALIGN_END,
		ALIGN_CENTER,
	})
	e.item_align_y = choose(2, {
		ALIGN_BASELINE,
		ALIGN_TOP,
		ALIGN_BOTTOM,
		--ALIGN_START,
		--ALIGN_END,
		ALIGN_CENTER,
	})
	e.align_items_y = choose(3, {
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
	e.align_items_x = choose(4, {
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

	e.child_count = density
	math.randomseed(lerp(5, 1, 10))
	for i = 0, e.child_count-1 do
		local e = e:child(i)
		e.border_width = 1
		e.padding = 10
		e.min_cw = math.random(lerp(6, 100, 500))
		print(e.min_cw)
		e.min_ch = math.random(lerp(7, 0, 200))
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

	e.child_count = density
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
	e.grid_wrap = math.sqrt(density) - 1
	e.grid_flow = flow or
		  choose(1, {0, GRID_FLOW_Y})
		+ choose(2, {0, GRID_FLOW_B})
		+ choose(3, {0, GRID_FLOW_R})
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
	e:sync_top(zoom * w - 100, zoom * h - 100)
	--print'synced'
	e:draw(cr)

	--e1:set_text_utf8('', -1)
	--e:clear_text_runs()
end

function win:keypress(key)
	if key == 'esc' then
		self:close()
	elseif key == 'pageup' or key == 'pagedown' then
		test_index = test_index + (key == 'pageup' and -1 or 1)
		selections = {}
	elseif key == 'up' or key == 'down' then
		if app:key'shift' then
			zoom = glue.clamp(zoom + 0.1 * (key == 'up' and -1 or 1), 0.1, 2)
		else
			local sel_id = 1
			for i = 1, 9 do
				if app:key(''..i) then
					sel_id = i
					break
				end
			end
			selections[sel_id] = (selections[sel_id] or 1) + (key == 'up' and -1 or 1)
		end
	elseif key == 'left' or key == 'right' then
		density = app:key'shift'
			and density * (key == 'left' and .5 or 2)
			 or density + (key == 'left' and -1 or 1)
	end
	do_test()
	self:invalidate()
end

app:run()

e:free()

lib:dump_stats()
lib:free()
memreport()
assert(memtotal() == 0)
