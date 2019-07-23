local ffi = require'ffi'
local clock = require'time'.clock
local nw = require'nw'
local glue = require'glue'
local C = require'tr_h'
local readfile = glue.readfile
local add = table.insert
local pfn = function(...) print(string.format(...)) end

s = assert(readfile'media/fonts/OpenSans-Regular.ttf')

local function load_font(font_id, file_data, file_size)
	file_data[0] = ffi.cast('void*', s)
	file_size[0] = #s
end

local function unload_font(font_id, file_data, file_size)
	--
end

local r = C.tr_renderer_new(load_font, unload_font)

local layout = r:layout()
--layout:set_text_utf8()
layout:set_font_id   (0, -1, 0)
layout:set_font_size (0, -1, 11)

--[[
set_maxlen=1,
set_dir=1,
set_align_w=1,
set_align_h=1,
set_align_x=1,
set_align_y=1,
set_clip_x=1,
set_clip_y=1,
set_clip_w=1,
set_clip_h=1,
set_clip_extents=1,
set_x=1,
set_y=1,
set_font_id           =1,
set_font_size         =1,
set_features          =1,
set_script            =1,
set_lang              =1,
set_paragraph_dir     =1,
set_line_spacing      =1,
set_hardline_spacing  =1,
set_paragraph_spacing =1,
set_nowrap            =1,
set_color             =1,
set_opacity           =1,
set_operator          =1,
]]

--[[
get_visible=1,
get_clipped=1,

shape=1,
wrap=1,
align=1,
clip=1,
layout=1,
paint=1,

--get_bidi=1,
--get_base_dir=1,
--get_line_count=1,
--get_line=1,
--get_max_ax=1,
--get_h=1,
--get_spaced_h=1,
--get_baseline=1,
--get_min_x=1,
--get_first_visible_line=1,
--get_last_visible_line=1,

]]

local c = layout:cursor()

local app = nw:app()

local win = app:window{
	w = 1000, h = 800,
}

function win:repaint()
	local bmp = win:bitmap()
	local cr = bmp:cairo()
	local w, h = win:client_size()
	layout.align_w = w - 20
	layout.align_h = h - 20
	layout.x = 10
	layout.y = 10
	layout.clip_x = 100
	layout.clip_y = 100
	layout.clip_w = w - 200
	layout.clip_h = h - 200
	layout:layout()
	layout:clip()
	layout:paint(cr)
	c:paint(cr)
end

app:run()

--layout:paint(cr)
layout:release()

pfn('Glyph cache size     : %7.2fmB', r.glyph_cache_size / 1024.0 / 1024.0)
pfn('Glyph cache count    : %7d', r.glyph_cache_count)
pfn('GlyphRun cache size  : %7.2fmB', r.glyph_run_cache_size / 1024.0 / 1024.0)
pfn('GlyphRun cache count : %7d', r.glyph_run_cache_count)

r:release()

C.memreport()
