local ffi = require'ffi'
local C = ffi.load'tr'
ffi.cdef[[
typedef struct tr_renderer_t tr_renderer_t;
typedef struct tr_layout_t tr_layout_t;
typedef struct _cairo _cairo;
typedef void (*tr_font_load_func) (int32_t, void**, uint64_t*);
int32_t tr_renderer_sizeof();
tr_renderer_t* tr_renderer_new(tr_font_load_func, tr_font_load_func);
uint64_t memtotal();
void memreport();
void tr_renderer_release(tr_renderer_t*);
tr_layout_t* tr_renderer_layout(tr_renderer_t*);
void tr_renderer_init(tr_renderer_t*, tr_font_load_func, tr_font_load_func);
int32_t tr_renderer_get_glyph_run_cache_max_size(tr_renderer_t*);
void tr_renderer_set_glyph_run_cache_max_size(tr_renderer_t*, int32_t);
int32_t tr_renderer_get_glyph_run_cache_size(tr_renderer_t*);
int32_t tr_renderer_get_glyph_run_cache_count(tr_renderer_t*);
int32_t tr_renderer_get_glyph_cache_max_size(tr_renderer_t*);
void tr_renderer_set_glyph_cache_max_size(tr_renderer_t*, int32_t);
int32_t tr_renderer_get_glyph_cache_size(tr_renderer_t*);
int32_t tr_renderer_get_glyph_cache_count(tr_renderer_t*);
void tr_renderer_free(tr_renderer_t*);
int32_t tr_renderer_font(tr_renderer_t*);
void tr_renderer_free_font(tr_renderer_t*, int32_t);
int32_t tr_renderer_get_paint_glyph_num(tr_renderer_t*);
void tr_renderer_set_paint_glyph_num(tr_renderer_t*, int32_t);
int32_t tr_layout_sizeof();
void tr_layout_release(tr_layout_t*);
void tr_layout_free(tr_layout_t*);
void tr_layout_layout(tr_layout_t*);
int32_t tr_layout_get_text_len(tr_layout_t*);
uint32_t* tr_layout_get_text(tr_layout_t*);
void tr_layout_set_text(tr_layout_t*, uint32_t*, int32_t);
int32_t tr_layout_get_text_utf8(tr_layout_t*, const char *, int32_t);
void tr_layout_set_text_utf8(tr_layout_t*, const char *, int32_t);
void tr_layout_set_maxlen(tr_layout_t*, int32_t);
void tr_layout_set_dir(tr_layout_t*, uint32_t);
void tr_layout_set_wrap_w(tr_layout_t*, float);
void tr_layout_set_clip_x(tr_layout_t*, float);
void tr_layout_set_clip_y(tr_layout_t*, float);
void tr_layout_set_clip_w(tr_layout_t*, float);
void tr_layout_set_clip_h(tr_layout_t*, float);
void tr_layout_paint(tr_layout_t*, _cairo*);
bool tr_layout_get_features(tr_layout_t*, int32_t, int32_t, const char **);
bool tr_layout_get_script(tr_layout_t*, int32_t, int32_t, const char **);
bool tr_layout_get_font_size(tr_layout_t*, int32_t, int32_t, double*);
bool tr_layout_get_font_id(tr_layout_t*, int32_t, int32_t, int32_t*);
bool tr_layout_get_opacity(tr_layout_t*, int32_t, int32_t, double*);
bool tr_layout_get_color(tr_layout_t*, int32_t, int32_t, uint32_t*);
bool tr_layout_get_lang(tr_layout_t*, int32_t, int32_t, const char **);
bool tr_layout_get_operator(tr_layout_t*, int32_t, int32_t, const char *);
bool tr_layout_get_line_spacing(tr_layout_t*, int32_t, int32_t, double*);
bool tr_layout_get_hardline_spacing(tr_layout_t*, int32_t, int32_t, double*);
bool tr_layout_get_nowrap(tr_layout_t*, int32_t, int32_t, bool*);
bool tr_layout_get_dir(tr_layout_t*, int32_t, int32_t, int32_t*);
bool tr_layout_get_paragraph_spacing(tr_layout_t*, int32_t, int32_t, double*);
void tr_layout_set_script(tr_layout_t*, int32_t, int32_t, const char *);
void tr_layout_set_lang(tr_layout_t*, int32_t, int32_t, const char *);
void tr_layout_set_nowrap(tr_layout_t*, int32_t, int32_t, bool);
void tr_layout_set_opacity(tr_layout_t*, int32_t, int32_t, double);
void tr_layout_set_hardline_spacing(tr_layout_t*, int32_t, int32_t, double);
void tr_layout_set_font_id(tr_layout_t*, int32_t, int32_t, int32_t);
void tr_layout_set_font_size(tr_layout_t*, int32_t, int32_t, double);
void tr_layout_set_line_spacing(tr_layout_t*, int32_t, int32_t, double);
void tr_layout_set_color(tr_layout_t*, int32_t, int32_t, uint32_t);
void tr_layout_set_paragraph_spacing(tr_layout_t*, int32_t, int32_t, double);
void tr_layout_set_operator(tr_layout_t*, int32_t, int32_t, int8_t);
void tr_layout_set_features(tr_layout_t*, int32_t, int32_t, const char *);
int32_t tr_layout_get_maxlen(tr_layout_t*);
float tr_layout_get_wrap_w(tr_layout_t*);
float tr_layout_get_clip_x(tr_layout_t*);
float tr_layout_get_clip_y(tr_layout_t*);
float tr_layout_get_clip_w(tr_layout_t*);
float tr_layout_get_clip_h(tr_layout_t*);
void tr_layout_init(tr_layout_t*, tr_renderer_t*);
]]
local getters = {
	glyph_run_cache_max_size = C.tr_renderer_get_glyph_run_cache_max_size,
	glyph_run_cache_size = C.tr_renderer_get_glyph_run_cache_size,
	glyph_run_cache_count = C.tr_renderer_get_glyph_run_cache_count,
	glyph_cache_max_size = C.tr_renderer_get_glyph_cache_max_size,
	glyph_cache_size = C.tr_renderer_get_glyph_cache_size,
	glyph_cache_count = C.tr_renderer_get_glyph_cache_count,
	paint_glyph_num = C.tr_renderer_get_paint_glyph_num,
}
local setters = {
	glyph_run_cache_max_size = C.tr_renderer_set_glyph_run_cache_max_size,
	glyph_cache_max_size = C.tr_renderer_set_glyph_cache_max_size,
	paint_glyph_num = C.tr_renderer_set_paint_glyph_num,
}
local methods = {
	release = C.tr_renderer_release,
	layout = C.tr_renderer_layout,
	init = C.tr_renderer_init,
	free = C.tr_renderer_free,
	font = C.tr_renderer_font,
	free_font = C.tr_renderer_free_font,
}
ffi.metatype('tr_renderer_t', {
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
local getters = {
	text_len = C.tr_layout_get_text_len,
	text = C.tr_layout_get_text,
	maxlen = C.tr_layout_get_maxlen,
	wrap_w = C.tr_layout_get_wrap_w,
	clip_x = C.tr_layout_get_clip_x,
	clip_y = C.tr_layout_get_clip_y,
	clip_w = C.tr_layout_get_clip_w,
	clip_h = C.tr_layout_get_clip_h,
}
local setters = {
	maxlen = C.tr_layout_set_maxlen,
	dir = C.tr_layout_set_dir,
	wrap_w = C.tr_layout_set_wrap_w,
	clip_x = C.tr_layout_set_clip_x,
	clip_y = C.tr_layout_set_clip_y,
	clip_w = C.tr_layout_set_clip_w,
	clip_h = C.tr_layout_set_clip_h,
}
local methods = {
	release = C.tr_layout_release,
	free = C.tr_layout_free,
	layout = C.tr_layout_layout,
	set_text = C.tr_layout_set_text,
	get_text_utf8 = C.tr_layout_get_text_utf8,
	set_text_utf8 = C.tr_layout_set_text_utf8,
	paint = C.tr_layout_paint,
	get_features = C.tr_layout_get_features,
	get_script = C.tr_layout_get_script,
	get_font_size = C.tr_layout_get_font_size,
	get_font_id = C.tr_layout_get_font_id,
	get_opacity = C.tr_layout_get_opacity,
	get_color = C.tr_layout_get_color,
	get_lang = C.tr_layout_get_lang,
	get_operator = C.tr_layout_get_operator,
	get_line_spacing = C.tr_layout_get_line_spacing,
	get_hardline_spacing = C.tr_layout_get_hardline_spacing,
	get_nowrap = C.tr_layout_get_nowrap,
	get_dir = C.tr_layout_get_dir,
	get_paragraph_spacing = C.tr_layout_get_paragraph_spacing,
	set_script = C.tr_layout_set_script,
	set_lang = C.tr_layout_set_lang,
	set_nowrap = C.tr_layout_set_nowrap,
	set_opacity = C.tr_layout_set_opacity,
	set_hardline_spacing = C.tr_layout_set_hardline_spacing,
	set_font_id = C.tr_layout_set_font_id,
	set_font_size = C.tr_layout_set_font_size,
	set_line_spacing = C.tr_layout_set_line_spacing,
	set_color = C.tr_layout_set_color,
	set_paragraph_spacing = C.tr_layout_set_paragraph_spacing,
	set_operator = C.tr_layout_set_operator,
	set_features = C.tr_layout_set_features,
	init = C.tr_layout_init,
}
ffi.metatype('tr_layout_t', {
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
ffi.cdef[[
enum {
	TR_ALIGN_AUTO = 4,
	TR_ALIGN_BOTTOM = 2,
	TR_ALIGN_CENTER = 3,
	TR_ALIGN_LEFT = 1,
	TR_ALIGN_MAX = 4,
	TR_ALIGN_RIGHT = 2,
	TR_ALIGN_TOP = 1,
	TR_BREAK_LINE = 1,
	TR_BREAK_NONE = 0,
	TR_BREAK_PARA = 2,
	TR_DEFAULT_TEXT_OPERATOR = 2,
	TR_DIR_AUTO = 64,
	TR_DIR_LTR = 272,
	TR_DIR_RTL = 273,
	TR_DIR_WLTR = 32,
	TR_DIR_WRTL = 33,
	TR_STATE_ALIGNED = 3,
	TR_STATE_SHAPED = 1,
	TR_STATE_WRAPPED = 2,
}]]
return C
