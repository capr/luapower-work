
local ffi = require'ffi'
local clock = require'time'.clock
local nw = require'nw'
local glue = require'glue'
local C = require'tr_h'
local readfile = glue.readfile
local add = table.insert
local pfn = function(...) print(string.format(...)) end

local font_idx = {} --{font_id->font_i}
local font_ids = {} --{font_i->font_id}

local font_paths = {
	'media/fonts/OpenSans-Regular.ttf',
	'media/fonts/Amiri-Regular.ttf',
	'media/fonts/Amiri-Bold.ttf',
	'media/fonts/FSEX300.ttf',
}

local font_data = {} --{font_i->data}

local function load_font(font_id, file_data, file_size)
	local font_i = assert(font_idx[font_id])
	local font_path = assert(font_paths[font_i])
	local s = assert(readfile(font_path))
	font_data[font_id] = s --pin it
	file_data[0] = ffi.cast('void*', s)
	file_size[0] = #s
end

local function unload_font(font_id, file_data, file_size)
	local font_i = assert(font_idx[font_id])
	font_data[font_i] = nil --unpin it
	file_data[0] = nil
	file_size[0] = 0
end

local r = C.tr_renderer_new(load_font, unload_font)

for font_i = 1, #font_paths do --go through all fonts
	local font_id = r:font()
	font_idx[font_id] = font_i
	font_ids[font_i] = font_id
end

r.glyph_cache_max_size = 1024*1024
r.glyph_run_cache_max_size = 1024*1024

local texts = {
	--assert(glue.readfile'terra/tr_test/sample_arabic.txt'),
	--'Hello World\nNew Line',
	--numbers,
	assert(readfile'terra/tr_test/lorem_ipsum.txt'),
	--assert(readfile'terra/tr_test/sample_wikipedia1.txt'),
	--assert(readfile'terra/tr_test/sample_names.txt'),
}

local function make_layouts()
	local layouts = {}
	for font_i = 1, #font_paths do --go through all fonts

		local font_id = font_ids[font_i]

		for text_i = 1, #texts do --go through all sample texts

			local layout = r:layout()
			add(layouts, layout)

			local text = texts[text_i]
			layout:text_from_utf8(text, #text)

			local N = 2^31-1
			layout:set_font_id(0, N, font_id)
			layout:set_font_size(0, N, 15)
			layout:set_color(0, N, 0xffffffff)

			--probe'start'

			layout:shape()
		end
	end
	return layouts
end

local t0 = clock()
local layouts = make_layouts()
pfn('%.1fms for %d layouts', (clock() - t0) * 1000, #layouts)
do return end

local app = nw:app()

local win = app:window{
	w = 1000, h = 800,
}

function win:repaint()
	local bmp = win:bitmap()
	local cr = bmp:cairo()
	local w, h = win:client_size()
	for i,layout in ipairs(layouts) do
		layout:wrap(w)
		layout:align(0, 0, w, h, C.TR_ALIGN_LEFT, C.TR_ALIGN_TOP)
		layout:clip(0, 0, w, h)
		layout:paint(cr)
		break
	end
end

app:run()

print('layouts: ', #layouts)
for i,layout in ipairs(layouts) do
	layout:release()
end
layouts = nil

pfn('Glyph cache size     : %7.2fmB', r.glyph_cache_size / 1024.0 / 1024.0)
pfn('Glyph cache count    : %7d', r.glyph_cache_count)
pfn('GlyphRun cache size  : %7.2fmB', r.glyph_run_cache_size / 1024.0 / 1024.0)
pfn('GlyphRun cache count : %7d', r.glyph_run_cache_count)

r:release()

C.memreport()