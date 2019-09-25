
--Layer ffi binding continuation (C wrappers).

local ffi = require'ffi'
local M = require'layer_h'

local function cstring(inherited)
	return function(...)
		local s = inherited(...)
		return s ~= nil and ffi.string(s) or nil
	end
end

M.wrap('layer_t', 'methods', 'get_span_features', cstring)
M.wrap('layer_t', 'methods', 'get_span_lang', cstring)

local layer = M.done()

local lib = layer.layerlib(nil, nil)

local l = lib:layer()

l:set_span_lang(0, 'en-us')
assert(l:get_span_lang(0) == 'en-us')
