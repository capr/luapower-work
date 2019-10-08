
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

local outbuf = glue.growbuffer()
local get_text_utf8 = M.types.layer_t.methods.get_text_utf8
local text_utf8_len = M.types.layer_t.getters.text_utf8_len
function M.types.layer_t.getters.text(self)
	local n = text_utf8_len(self)
	local out = outbuf(n)
	local n = get_text_utf8(self, out, n)
	return n > 0 and ffi.string(out, n) or nil
end

local set_text_utf8 = M.types.layer_t.methods.set_text_utf8
function M.types.layer_t.setters.text(self, s)
	set_text_utf8(self, s, #s)
end

return M.done()
