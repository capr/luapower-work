
--Layer ffi binding.

local ffi = require'ffi'
local glue = require'glue'
local M = require'layer_h'

local function cstring(inherited)
	return function(...)
		local s = inherited(...)
		return s ~= nil and ffi.string(s) or nil
	end
end

local function nojit(inherited)
	local f = function(...)
		return inherited(...)
	end
	jit.off(f)
	return f
end

local function unpack_tuple2(inherited)
	return function(...)
		local r = inherited(...)
		return r._0, r._1
	end
end

M.wrap('layer_t', 'methods', 'get_span_features', cstring)
M.wrap('layer_t', 'methods', 'get_span_lang', cstring)
M.wrap('layer_t', 'methods', 'get_span_script', cstring)
M.wrap('layer_t', 'methods', 'get_text_selection_features', cstring)
M.wrap('layer_t', 'methods', 'get_text_selection_lang', cstring)
M.wrap('layer_t', 'methods', 'get_text_selection_script', cstring)

--these trigger unload_font callback so they must not be allowed to be jit'ed.
M.wrap('layer_t', 'methods', 'set_span_font_id', nojit)
M.wrap('layer_t', 'methods', 'set_text_selection_font_id', nojit)
M.wrap('layerlib_t', 'methods', 'free', nojit)
M.wrap('layerlib_t', 'setters', 'mem_font_cache_max_size', nojit)
M.wrap('layerlib_t', 'setters', 'mmapped_font_cache_max_count', nojit)

M.wrap('layer_t', 'methods', 'from_window', unpack_tuple2)

--conversion to/from utf8 Lua strings ----------------------------------------

--Make utf8 the default encoding in Lua-land: remove `_utf8` from method
--names and add `_utf32` to methods that work in codepoints.

local outbuf = glue.growbuffer()
local function text_utf8_getset(
	get_text_utf8_len,
	get_text_utf8,
	set_text_utf8
)
	return
		get_text_utf8_len,
		function(self, out, outlen)
			local outlen = outlen or get_text_utf8_len(self)
			local out = out or outbuf(outlen)
			local n = get_text_utf8(self, out, outlen)
			return n > 0 and ffi.string(out, n) or nil
		end,
		function(self, s, len)
			set_text_utf8(self, s, len or #s)
		end
end

local t = M.types.layer_t

t.getters.text_utf32_len = t.getters.text_len
t.methods.get_text_utf32 = t.methods.get_text
t.methods.set_text_utf32 = t.methods.set_text

t.getters.text_len,
t.getters.text,
t.setters.text
	= text_utf8_getset(
		t.getters.text_utf8_len,
		t.methods.get_text_utf8,
		t.methods.set_text_utf8
	)

t.getters.text_utf8_len = nil
t.methods.get_text_utf8 = nil
t.methods.set_text_utf8 = nil

t.methods.get_selected_text_utf32_len = t.methods.get_selected_text_len
t.methods.get_selected_text_utf32     = t.methods.get_selected_text
t.methods.set_selected_text_utf32     = t.methods.set_selected_text

t.methods.get_selected_text_len,
t.methods.get_selected_text,
t.methods.set_selected_text
	= text_utf8_getset(
		t.methods.get_selected_text_utf8_len,
		t.methods.get_selected_text_utf8,
		t.methods.set_selected_text_utf8
	)

t.methods.get_selected_text_utf8_len = nil
t.methods.get_selected_text_utf8 = nil
t.methods.set_selected_text_utf8 = nil

t.methods.insert_text_utf32_at_cursor = t.methods.insert_text_at_cursor
t.methods.insert_text_at_cursor = t.methods.insert_text_utf8_at_cursor
t.methods.insert_text_utf8_at_cursor = nil

return M.done()
