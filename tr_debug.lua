collectgarbage'stop'
jit.off(true, true)

local readfile = require'glue'.readfile
local ffi = require'ffi'
local C = require'tr_h'

local font_data = assert(readfile('media/fonts/OpenSans-Regular.ttf'))

local function load_font(font_id, file_data, file_size)
	assert(font_data)
	file_data[0] = ffi.cast('void*', font_data)
	file_size = #font_data
end

local function unload_font(font_id, file_data, file_size)
	font_data = nil
end

local r = C.tr_renderer_new(load_font, unload_font)
local font_id = r:font()

local s = 'Hello'
local b = ffi.new('int[2]', {84, 0})

for i = 1, 1 do
	local layout = r:layout()
	layout:set_text(b, 1)
	--layout:text_from_utf8(s, #s)
	layout:set_font_id   (0, -1, font_id)
	layout:set_font_size (0, -1, 15)
	layout:set_color     (0, -1, 0xffffffff)
	layout:shape()
	layout:release()
end

r:release()
