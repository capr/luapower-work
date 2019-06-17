
setfenv(1, require'terra/low'.module())
require'terra/memcheck'
require'terra/tr_paint_cairo'
require'terra/utf8'
setfenv(1, require'terra/tr')
local strlen = includecstring'unsigned long long strlen (const char *str);'.strlen
local sprintf = includecstring'int sprintf(char* str, const char* format, ...);'.sprintf

do return end

local font_paths_list = {
	'../media/fonts/OpenSans-Regular.ttf',
	'../media/fonts/Amiri-Regular.ttf',
	'../media/fonts/Amiri-Bold.ttf',
	'../media/fonts/FSEX300.ttf',
}
local font_paths = constant(`array([font_paths_list]))

terra load_font(font_id: int, file_data: &&opaque, file_size: &size_t)
	var font_path = font_paths[font_id]
	@file_data, @file_size = readfile(font_path)
end

terra unload_font(font_id: int, file_data: &&opaque, file_size: &size_t)
	dealloc(@file_data)
end

local numbers = {}
for i=1, 100000 do
	add(numbers, tostring(i..' '))
end
local numbers = concat(numbers)

local texts_list = {
	--assert(glue.readfile'tr_test/sample_arabic.txt'),
	'Hello World\nNew Line',
	--numbers,
	assert(readfile'tr_test/lorem_ipsum.txt'),
	assert(readfile'tr_test/sample_wikipedia1.txt'),
	assert(readfile'tr_test/sample_names.txt'),
}
local texts = constant(`array([texts_list]))


local font_paths_count = #font_paths_list
local texts_count = #texts_list
local paint_times = 1

terra test()
	var sr = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 1920, 1080)
	var cr = sr:context()
	var r: Renderer; r:init(load_font, unload_font)

	r.glyph_cache_size = 1024*1024
	r.glyph_run_cache_size = 1024*1024

	var layouts = arr(Layout)

	for font_i = 0, font_paths_count do --go through all fonts

		var font_id = r:font()

		for text_i = 0, texts_count do --go through all sample texts

			var layout = layouts:add()
			layout:init(&r)
			var text = texts[text_i]
			var text_len = strlen(text)
			utf8.decode.toarr(text, text_len, &layout.text, maxint, utf8.REPLACE, utf8.INVALID)

			var sp: Span; sp:init()
			sp.offset = 0
			sp.font_id = font_id
			sp.font_size = 16
			sp.color = 0xffffffff
			layout.spans:push(sp)

			--probe'start'

			layout:shape()

			var t0: double
			var wanted_fps = 60
			var glyphs_per_frame = -1

			var offset_count = [int](1/r.subpixel_x_resolution)

			for offset_i = 0, offset_count do --go through all subpixel offsets

				var w = sr:width()
				var h = sr:height()
				var offset_x = offset_i * (1.0 / offset_count)

				layout:wrap(w)
				layout:align(offset_x, 0, w, h, ALIGN_LEFT, ALIGN_TOP)
				layout:clip(0, 0, w, h)
				assert(layout.clip_valid)
				--probe'shape/wrap/align/clip'

				r.paint_glyph_num = 0
				t0 = clock()
				for frame_i = 0, paint_times do
					--cr:rgb(0, 0, 0)
					--cr:paint()
					layout:paint(cr)
					if glyphs_per_frame == -1 then
						glyphs_per_frame = r.paint_glyph_num
					end
				end

			end

			var dt = clock() - t0
			pfn('%.2fs\tpaint %d times %7d glyphs %7.2f%% of a frame @60fps',
				dt, paint_times, r.paint_glyph_num,
				100 * glyphs_per_frame * wanted_fps * dt / r.paint_glyph_num)

			var s: char[200]
			sprintf(s, 'out%d.png', layouts.len)
			sr:save_png(s)

			cr:rgb(0, 0, 0)
			cr:paint()

		end

		layouts.len = 0

	end

	print('layouts: ', layouts.len)
	layouts:free()

	pfn('Glyph cache size     : %7.2fmB', r.glyphs.size / 1024.0 / 1024.0)
	pfn('Glyph cache count    : %7d', r.glyphs.count)
	pfn('GlyphRun cache size  : %7.2fmB', r.glyph_runs.size / 1024.0 / 1024.0)
	pfn('GlyphRun cache count : %7d', r.glyph_runs.count)

	r:free()
	cr:free()
	sr:free()

	memreport()
end
test()
