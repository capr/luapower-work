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
	--'media/fonts/Amiri-Regular.ttf',
	--'media/fonts/Amiri-Bold.ttf',
	--'media/fonts/FSEX300.ttf',
}

local font_data = {} --{font_i->data}

local function load_font(font_id, file_data, file_size)
	local font_i = assert(font_idx[font_id])
	local font_path = assert(font_paths[font_i])
	local s = assert(readfile(font_path))
	font_data[font_i] = s --pin it
	file_data[0] = ffi.cast('void*', s)
	file_size[0] = #s
end

local function unload_font(font_id, file_data, file_size)
	local font_i = assert(font_idx[font_id])
	assert(font_data[font_i])
	font_data[font_i] = nil --unpin it
end

local r = C.tr_renderer_new(load_font, unload_font)

for font_i = 1, #font_paths do --go through all fonts
	local font_id = r:font()
	font_idx[font_id] = font_i
	font_ids[font_i] = font_id
end

--r.glyph_cache_max_size = 1024*1024
--r.glyph_run_cache_max_size = 1024*1024

local texts = {
	--assert(glue.readfile'terra/tr_test/sample_arabic.txt'),
	--'Hello World\n',
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
			layout:set_text_utf8(text, #text)

			layout.align_y = C.TR_ALIGN_TOP

			layout:set_font_id   (0, -1, font_id)
			layout:set_font_size (0, -1, 11)
			layout:set_color     (0, -1, 0xffffffff)
		end
	end
	return layouts
end

local t0 = clock()
local layouts = make_layouts()
pfn('%.1fms for %d layouts', (clock() - t0) * 1000, #layouts)

local app = nw:app()

local win = app:window{
	w = 1000, h = 800,
}

function win:repaint()
	local bmp = win:bitmap()
	local cr = bmp:cairo()
	local w, h = win:client_size()
	for i,layout in ipairs(layouts) do
		layout.align_w = w - 20
		layout.align_h = h - 20
		layout.x = 10
		layout.y = 10
		layout.clip_x = 100
		layout.clip_y = 100
		layout.clip_w = w - 200
		layout.clip_h = h - 200
		layout:layout()
		layout:paint(cr)
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
