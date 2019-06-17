local ffi = require'ffi'
local C = ffi.load'tr'
ffi.cdef[[
typedef struct trlib_t trlib_t;
typedef struct tr_layout_t tr_layout_t;
typedef void (*tr_font_load_func) (int32_t, void**, uint64_t*);
int32_t tr_renderer_sizeof();
trlib_t* tr_renderer_new(tr_font_load_func, tr_font_load_func);
void trlib_release(trlib_t*);
tr_layout_t* trlib_layout(trlib_t*);
void trlib_init(trlib_t*, tr_font_load_func, tr_font_load_func);
int32_t trlib_get_glyph_run_cache_size(trlib_t*);
void trlib_set_glyph_run_cache_size(trlib_t*, int32_t);
int32_t trlib_get_glyph_cache_size(trlib_t*);
void trlib_set_glyph_cache_size(trlib_t*, int32_t);
void trlib_free(trlib_t*);
int32_t trlib_font(trlib_t*);
void trlib_free_font(trlib_t*, int32_t);
int32_t tr_layout_sizeof();
void tr_layout_release(tr_layout_t*);
void tr_layout_set_text_utf32(tr_layout_t*, uint32_t*, int32_t);
void tr_layout_set_text_utf8(tr_layout_t*, const char *, int32_t);
void tr_layout_free(tr_layout_t*);
tr_layout_t* tr_layout_align(tr_layout_t*, float, float, float, float, int32_t, int32_t);
tr_layout_t* tr_layout_wrap(tr_layout_t*, float);
void tr_layout_shape(tr_layout_t*);
void tr_layout_init(tr_layout_t*, trlib_t*);
]]
local getters = {
	glyph_run_cache_size = C.trlib_get_glyph_run_cache_size,
	glyph_cache_size = C.trlib_get_glyph_cache_size,
}
local setters = {
	glyph_run_cache_size = C.trlib_set_glyph_run_cache_size,
	glyph_cache_size = C.trlib_set_glyph_cache_size,
}
local methods = {
	release = C.trlib_release,
	layout = C.trlib_layout,
	init = C.trlib_init,
	free = C.trlib_free,
	font = C.trlib_font,
	free_font = C.trlib_free_font,
}
ffi.metatype('trlib_t', {
	__index = function(self, k)
		local getter = getters[k]
		if getter then return getter(self) end
		return methods[k]
	end,
	__newindex = function(self, k, v)
		local setter = setters[k]
		if not setter then
			error(('field not found: %s'):format(tostring(k)), 2)
		end
		setter(self, v)
	end,
})
ffi.metatype('tr_layout_t', {__index = {
	release = C.tr_layout_release,
	set_text_utf32 = C.tr_layout_set_text_utf32,
	set_text_utf8 = C.tr_layout_set_text_utf8,
	free = C.tr_layout_free,
	align = C.tr_layout_align,
	wrap = C.tr_layout_wrap,
	shape = C.tr_layout_shape,
	init = C.tr_layout_init,
}})
return C
