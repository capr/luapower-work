--go @ luajit -joff -jv *
jit.off(true, true)

local ffi = require'ffi'
local nw = require'nw'
local layer = require'layer'
local glue = require'glue'
local cairo = require'cairo'
local random = math.random
local print = print
local assert = assert

setfenv(1, setmetatable({}, {__index = layer}))

local app = nw:app()

local win = app:window{
	title = 'Hello!',
	w = 1800, h = 700,
}

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

--assert(memtotal() == 0)

local lib = layerlib(load_font, unload_font)

local opensans = lib:font()
local amiri    = lib:font()

local function layers_with_everything()
	local e = lib:layer()
	e.child_count = 4
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
	e1:set_text_font_id  (0, -1, opensans)
	e1:set_text_font_size(0, -1, 14)
	e1:set_text_color    (0, -1, 0xffffffff)
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
	e:set_text_font_id  (0, -1, amiri)
	e:set_text_font_size(0, -1, 50)
	e:set_text_color    (0, -1, 0x333333ff)
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
	return e
end

local function flexbox_baseline_wrapped()
	local e = lib:layer()

	e.layout_type = LAYOUT_FLEXBOX
	e.border_width = 1
	e.flex_wrap = true
	e.item_align_y = ALIGN_BASELINE
	--e.item_align_y = ALIGN_CENTER
	e.align_items_y = ALIGN_CENTER
	e.align_items_x = ALIGN_CENTER

	local texts = {
		"Lorem ipsum",
		"dolor sit amet",
		"You only killed the bride’s father, you know.",
		"I didn’t mean to.",
		"Didn’t mean to?",
		"You put your sword right through his head.",
		"Oh dear… is he all right?",
	}

	e.child_count = 10
	for i = 0, e.child_count-1 do
		local e = e:child(i)
		e.border_width = 1
		e.padding = 10
		e.min_cw = random(40, 100)
		e.min_ch = random(0, 100)
		e.text_align_x = ALIGN_CENTER
		e.layout_type = LAYOUT_TEXTBOX
		e:set_text_utf8(texts[random(#texts)], -1)
		e:set_text_font_id  (0, -1, opensans)
		e:set_text_font_size(0, -1, 14)
		if i == 1 then
			--e.align_y = ALIGN_BOTTOM
		end
	end

	return e
end

local function grid_layout()
	local e = lib:layer()

	e.layout_type = LAYOUT_GRID
	e.border_color = 0x000000ff
	e.border_width = 1

	e.child_count = 1000
	for i = 0, e.child_count-1 do
		local e = e:child(i)
		e.min_cw = 0
		e.min_ch = 0
		e.border_color = 0x000000ff
		e.border_width = 2
		e.border_offset = 0
		--e.snap_x = true
		--e.snap_y = true
	end
	e.grid_row_gap = 10
	e.grid_col_gap = 10
	e.grid_wrap = 51

	return e
end

--local e = layers_with_everything()
local e = flexbox_baseline_wrapped()
--local e = grid_layout()

function win:repaint()

	local cr = self:bitmap():cairo()

	cr:identity_matrix()
	--cr:rgba(1, 1, 1, 1)
	cr:rgba(0, 0, 0, 1)
	cr:paint()

	local w, h = self:client_size()
	cr:translate(50, 50)
	e:sync_top(w - 100, h - 100)
	--print'synced'
	e:draw(cr)

	--e1:set_text_utf8('', -1)
	--e:clear_text_runs()
end

function win:keyup(key)
	if key == 'esc' then
		self:close()
	end
end

app:run()

e:free()

lib:dump_stats()
lib:free()
memreport()
assert(memtotal() == 0)
