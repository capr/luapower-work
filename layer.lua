
--Layer ffi binding.

local ffi = require'ffi'
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

return M.done()
