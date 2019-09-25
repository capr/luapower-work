local ffi = require'ffi'
local C = ffi.load'tr'
ffi.cdef[[
typedef struct renderer_t renderer_t;
typedef struct layout_t layout_t;
typedef struct _cairo _cairo;
typedef struct double4 double4;
typedef void (*tr_font_load_func_t) (int32_t, void**, uint64_t*, bool*);
typedef void (*tr_font_unload_func_t) (int32_t, void*, uint64_t, bool);
uint64_t memtotal();
void memreport();
int32_t tr_renderer_sizeof();
int32_t tr_layout_sizeof();
renderer_t* tr_renderer(tr_font_load_func_t, tr_font_unload_func_t);
void tr_init(renderer_t*, tr_font_load_func_t, tr_font_unload_func_t);
void tr_free(renderer_t*);
void tr_release(renderer_t*);
layout_t* tr_layout(renderer_t*);
double tr_get_subpixel_x_resolution(renderer_t*);
void tr_set_subpixel_x_resolution(renderer_t*, double);
double tr_get_word_subpixel_x_resolution(renderer_t*);
void tr_set_word_subpixel_x_resolution(renderer_t*, double);
double tr_get_font_size_resolution(renderer_t*);
void tr_set_font_size_resolution(renderer_t*, double);
double tr_get_glyph_run_cache_max_size(renderer_t*);
void tr_set_glyph_run_cache_max_size(renderer_t*, double);
double tr_get_glyph_cache_max_size(renderer_t*);
void tr_set_glyph_cache_max_size(renderer_t*, double);
double tr_get_mem_font_cache_max_size(renderer_t*);
void tr_set_mem_font_cache_max_size(renderer_t*, double);
double tr_get_mmapped_font_cache_max_count(renderer_t*);
void tr_set_mmapped_font_cache_max_count(renderer_t*, double);
double tr_get_glyph_run_cache_size(renderer_t*);
double tr_get_glyph_run_cache_count(renderer_t*);
double tr_get_glyph_cache_size(renderer_t*);
double tr_get_glyph_cache_count(renderer_t*);
double tr_get_mem_font_cache_size(renderer_t*);
double tr_get_mem_font_cache_count(renderer_t*);
double tr_get_mmapped_font_cache_count(renderer_t*);
int64_t tr_get_paint_glyph_num(renderer_t*);
void tr_set_paint_glyph_num(renderer_t*, int32_t);
int32_t tr_font_face_num(renderer_t*, int32_t);
renderer_t* tr_get_r(layout_t*);
void tr_init(layout_t*, renderer_t*);
void tr_free(layout_t*);
void tr_release(layout_t*);
bool tr_get_offsets_valid(layout_t*);
bool tr_get_valid(layout_t*);
void tr_shape(layout_t*);
void tr_wrap(layout_t*);
void tr_align(layout_t*);
void tr_clip(layout_t*);
void tr_layout(layout_t*);
void tr_paint(layout_t*, _cairo*);
int32_t tr_get_maxlen(layout_t*);
void tr_set_maxlen(layout_t*, int32_t);
int32_t tr_get_text_len(layout_t*);
uint32_t* tr_get_text(layout_t*);
void tr_set_text(layout_t*, uint32_t*, int32_t);
int32_t tr_get_text_utf8(layout_t*, const char *, int32_t);
int32_t tr_get_text_utf8_len(layout_t*);
void tr_set_text_utf8(layout_t*, const char *, int32_t);
int8_t tr_get_dir(layout_t*);
void tr_set_dir(layout_t*, int8_t);
double tr_get_align_w(layout_t*);
double tr_get_align_h(layout_t*);
void tr_set_align_w(layout_t*, double);
void tr_set_align_h(layout_t*, double);
int8_t tr_get_align_x(layout_t*);
int8_t tr_get_align_y(layout_t*);
void tr_set_align_x(layout_t*, int8_t);
void tr_set_align_y(layout_t*, int8_t);
double tr_get_line_spacing(layout_t*);
double tr_get_hardline_spacing(layout_t*);
double tr_get_paragraph_spacing(layout_t*);
void tr_set_line_spacing(layout_t*, double);
void tr_set_hardline_spacing(layout_t*, double);
void tr_set_paragraph_spacing(layout_t*, double);
double tr_get_clip_x(layout_t*);
double tr_get_clip_y(layout_t*);
double tr_get_clip_w(layout_t*);
double tr_get_clip_h(layout_t*);
void tr_set_clip_x(layout_t*, double);
void tr_set_clip_y(layout_t*, double);
void tr_set_clip_w(layout_t*, double);
void tr_set_clip_h(layout_t*, double);
void tr_set_clip_extents(layout_t*, double, double, double, double);
double tr_get_x(layout_t*);
double tr_get_y(layout_t*);
void tr_set_x(layout_t*, double);
void tr_set_y(layout_t*, double);
void tr_remove_trailing_spans(layout_t*);
bool tr_has_color(layout_t*, int32_t, int32_t);
bool tr_has_features(layout_t*, int32_t, int32_t);
bool tr_has_font_face_index(layout_t*, int32_t, int32_t);
bool tr_has_font_id(layout_t*, int32_t, int32_t);
bool tr_has_font_size(layout_t*, int32_t, int32_t);
bool tr_has_lang(layout_t*, int32_t, int32_t);
bool tr_has_nowrap(layout_t*, int32_t, int32_t);
bool tr_has_opacity(layout_t*, int32_t, int32_t);
bool tr_has_operator(layout_t*, int32_t, int32_t);
bool tr_has_paragraph_dir(layout_t*, int32_t, int32_t);
bool tr_has_script(layout_t*, int32_t, int32_t);
void tr_set_color(layout_t*, int32_t, int32_t, uint32_t);
void tr_set_features(layout_t*, int32_t, int32_t, const char *);
void tr_set_font_face_index(layout_t*, int32_t, int32_t, int32_t);
void tr_set_font_id(layout_t*, int32_t, int32_t, int32_t);
void tr_set_font_size(layout_t*, int32_t, int32_t, double);
void tr_set_lang(layout_t*, int32_t, int32_t, const char *);
void tr_set_nowrap(layout_t*, int32_t, int32_t, bool);
void tr_set_opacity(layout_t*, int32_t, int32_t, double);
void tr_set_operator(layout_t*, int32_t, int32_t, int8_t);
void tr_set_paragraph_dir(layout_t*, int32_t, int32_t, int32_t);
void tr_set_script(layout_t*, int32_t, int32_t, const char *);
uint32_t tr_get_span_color(layout_t*, int32_t);
const char * tr_get_span_features(layout_t*, int32_t);
int32_t tr_get_span_font_face_index(layout_t*, int32_t);
int32_t tr_get_span_font_id(layout_t*, int32_t);
double tr_get_span_font_size(layout_t*, int32_t);
const char * tr_get_span_lang(layout_t*, int32_t);
bool tr_get_span_nowrap(layout_t*, int32_t);
double tr_get_span_opacity(layout_t*, int32_t);
int8_t tr_get_span_operator(layout_t*, int32_t);
int32_t tr_get_span_paragraph_dir(layout_t*, int32_t);
const char * tr_get_span_script(layout_t*, int32_t);
void tr_set_span_color(layout_t*, int32_t, uint32_t);
void tr_set_span_features(layout_t*, int32_t, const char *);
void tr_set_span_font_face_index(layout_t*, int32_t, int32_t);
void tr_set_span_font_id(layout_t*, int32_t, int32_t);
void tr_set_span_font_size(layout_t*, int32_t, double);
void tr_set_span_lang(layout_t*, int32_t, const char *);
void tr_set_span_nowrap(layout_t*, int32_t, bool);
void tr_set_span_opacity(layout_t*, int32_t, double);
void tr_set_span_operator(layout_t*, int32_t, int8_t);
void tr_set_span_paragraph_dir(layout_t*, int32_t, int32_t);
void tr_set_span_script(layout_t*, int32_t, const char *);
int32_t tr_get_span_offset(layout_t*, int32_t);
void tr_set_span_offset(layout_t*, int32_t, int32_t);
int32_t tr_get_span_count(layout_t*);
void tr_set_span_count(layout_t*, int32_t);
int32_t tr_span_at_offset(layout_t*, int32_t);
double tr_remove_text(layout_t*, double, double);
int32_t tr_insert_text(layout_t*, int32_t, uint32_t*, int32_t);
bool tr_get_min_size_valid(layout_t*);
bool tr_get_align_valid(layout_t*);
bool tr_get_pixels_valid(layout_t*);
bool tr_get_visible(layout_t*);
double tr_get_min_w(layout_t*);
double tr_get_max_w(layout_t*);
double tr_get_baseline(layout_t*);
double tr_get_spaced_h(layout_t*);
double4 tr_bbox(layout_t*);
int32_t tr_get_cursor_count(layout_t*);
int32_t tr_set_cursor_count(layout_t*, int32_t);
int32_t tr_get_cursor_offset(layout_t*, int32_t);
int32_t tr_get_cursor_which(layout_t*, int32_t);
int32_t tr_get_cursor_sel_offset(layout_t*, int32_t);
int32_t tr_get_cursor_sel_which(layout_t*, int32_t);
double tr_get_cursor_x(layout_t*, int32_t);
void tr_set_cursor_offset(layout_t*, int32_t, double);
void tr_set_cursor_which(layout_t*, int32_t, int32_t);
void tr_set_cursor_sel_offset(layout_t*, int32_t, double);
void tr_set_cursor_sel_which(layout_t*, int32_t, int32_t);
void tr_set_cursor_x(layout_t*, int32_t, double);
void tr_cursor_move_to(layout_t*, int32_t, double, int8_t, bool);
void tr_cursor_move_to_point(layout_t*, int32_t, double, double, bool);
void tr_cursor_move_near(layout_t*, int32_t, int8_t, int8_t, int8_t, bool);
void tr_cursor_move_near_line(layout_t*, int32_t, double, double, bool);
void tr_cursor_move_near_page(layout_t*, int32_t, double, double, bool);
bool tr_get_caret_visible(layout_t*, int32_t);
bool tr_get_selection_visible(layout_t*, int32_t);
void tr_set_caret_visible(layout_t*, int32_t, bool);
void tr_set_selection_visible(layout_t*, int32_t, bool);
int32_t tr_get_selection_first_span(layout_t*, int32_t);
void tr_remove_selected_text(layout_t*, int32_t);
void tr_insert_text_at_cursor(layout_t*, int32_t, uint32_t*, int32_t);
void tr_insert_text_utf8_at_cursor(layout_t*, int32_t, const char *, int32_t);
int32_t tr_get_selected_text_len(layout_t*, int32_t);
uint32_t* tr_get_selected_text(layout_t*, int32_t);
int32_t tr_get_selected_text_utf8(layout_t*, int32_t, const char *, int32_t);
int32_t tr_get_selected_text_utf8_len(layout_t*, int32_t);
void tr_load_cursor_xs(layout_t*, int32_t);
double* tr_get_cursor_xs(layout_t*);
int32_t tr_get_cursor_xs_len(layout_t*);
]]
pcall(ffi.cdef, 'struct double4 { double _0; double _1; double _2; double _3; };')
local getters = {
	subpixel_x_resolution = C.tr_get_subpixel_x_resolution,
	word_subpixel_x_resolution = C.tr_get_word_subpixel_x_resolution,
	font_size_resolution = C.tr_get_font_size_resolution,
	glyph_run_cache_max_size = C.tr_get_glyph_run_cache_max_size,
	glyph_cache_max_size = C.tr_get_glyph_cache_max_size,
	mem_font_cache_max_size = C.tr_get_mem_font_cache_max_size,
	mmapped_font_cache_max_count = C.tr_get_mmapped_font_cache_max_count,
	glyph_run_cache_size = C.tr_get_glyph_run_cache_size,
	glyph_run_cache_count = C.tr_get_glyph_run_cache_count,
	glyph_cache_size = C.tr_get_glyph_cache_size,
	glyph_cache_count = C.tr_get_glyph_cache_count,
	mem_font_cache_size = C.tr_get_mem_font_cache_size,
	mem_font_cache_count = C.tr_get_mem_font_cache_count,
	mmapped_font_cache_count = C.tr_get_mmapped_font_cache_count,
	paint_glyph_num = C.tr_get_paint_glyph_num,
}
local setters = {
	subpixel_x_resolution = C.tr_set_subpixel_x_resolution,
	word_subpixel_x_resolution = C.tr_set_word_subpixel_x_resolution,
	font_size_resolution = C.tr_set_font_size_resolution,
	glyph_run_cache_max_size = C.tr_set_glyph_run_cache_max_size,
	glyph_cache_max_size = C.tr_set_glyph_cache_max_size,
	mem_font_cache_max_size = C.tr_set_mem_font_cache_max_size,
	mmapped_font_cache_max_count = C.tr_set_mmapped_font_cache_max_count,
	paint_glyph_num = C.tr_set_paint_glyph_num,
}
local methods = {
	init = C.tr_init,
	free = C.tr_free,
	release = C.tr_release,
	layout = C.tr_layout,
	font_face_num = C.tr_font_face_num,
}
ffi.metatype('renderer_t', {
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
	r = C.tr_get_r,
	offsets_valid = C.tr_get_offsets_valid,
	valid = C.tr_get_valid,
	maxlen = C.tr_get_maxlen,
	text_len = C.tr_get_text_len,
	text = C.tr_get_text,
	text_utf8_len = C.tr_get_text_utf8_len,
	dir = C.tr_get_dir,
	align_w = C.tr_get_align_w,
	align_h = C.tr_get_align_h,
	align_x = C.tr_get_align_x,
	align_y = C.tr_get_align_y,
	line_spacing = C.tr_get_line_spacing,
	hardline_spacing = C.tr_get_hardline_spacing,
	paragraph_spacing = C.tr_get_paragraph_spacing,
	clip_x = C.tr_get_clip_x,
	clip_y = C.tr_get_clip_y,
	clip_w = C.tr_get_clip_w,
	clip_h = C.tr_get_clip_h,
	x = C.tr_get_x,
	y = C.tr_get_y,
	span_count = C.tr_get_span_count,
	min_size_valid = C.tr_get_min_size_valid,
	align_valid = C.tr_get_align_valid,
	pixels_valid = C.tr_get_pixels_valid,
	visible = C.tr_get_visible,
	min_w = C.tr_get_min_w,
	max_w = C.tr_get_max_w,
	baseline = C.tr_get_baseline,
	spaced_h = C.tr_get_spaced_h,
	cursor_count = C.tr_get_cursor_count,
	cursor_xs = C.tr_get_cursor_xs,
	cursor_xs_len = C.tr_get_cursor_xs_len,
}
local setters = {
	maxlen = C.tr_set_maxlen,
	dir = C.tr_set_dir,
	align_w = C.tr_set_align_w,
	align_h = C.tr_set_align_h,
	align_x = C.tr_set_align_x,
	align_y = C.tr_set_align_y,
	line_spacing = C.tr_set_line_spacing,
	hardline_spacing = C.tr_set_hardline_spacing,
	paragraph_spacing = C.tr_set_paragraph_spacing,
	clip_x = C.tr_set_clip_x,
	clip_y = C.tr_set_clip_y,
	clip_w = C.tr_set_clip_w,
	clip_h = C.tr_set_clip_h,
	x = C.tr_set_x,
	y = C.tr_set_y,
	span_count = C.tr_set_span_count,
	cursor_count = C.tr_set_cursor_count,
}
local methods = {
	init = C.tr_init,
	free = C.tr_free,
	release = C.tr_release,
	shape = C.tr_shape,
	wrap = C.tr_wrap,
	align = C.tr_align,
	clip = C.tr_clip,
	layout = C.tr_layout,
	paint = C.tr_paint,
	set_text = C.tr_set_text,
	get_text_utf8 = C.tr_get_text_utf8,
	set_text_utf8 = C.tr_set_text_utf8,
	set_clip_extents = C.tr_set_clip_extents,
	remove_trailing_spans = C.tr_remove_trailing_spans,
	has_color = C.tr_has_color,
	has_features = C.tr_has_features,
	has_font_face_index = C.tr_has_font_face_index,
	has_font_id = C.tr_has_font_id,
	has_font_size = C.tr_has_font_size,
	has_lang = C.tr_has_lang,
	has_nowrap = C.tr_has_nowrap,
	has_opacity = C.tr_has_opacity,
	has_operator = C.tr_has_operator,
	has_paragraph_dir = C.tr_has_paragraph_dir,
	has_script = C.tr_has_script,
	set_color = C.tr_set_color,
	set_features = C.tr_set_features,
	set_font_face_index = C.tr_set_font_face_index,
	set_font_id = C.tr_set_font_id,
	set_font_size = C.tr_set_font_size,
	set_lang = C.tr_set_lang,
	set_nowrap = C.tr_set_nowrap,
	set_opacity = C.tr_set_opacity,
	set_operator = C.tr_set_operator,
	set_paragraph_dir = C.tr_set_paragraph_dir,
	set_script = C.tr_set_script,
	get_span_color = C.tr_get_span_color,
	get_span_features = C.tr_get_span_features,
	get_span_font_face_index = C.tr_get_span_font_face_index,
	get_span_font_id = C.tr_get_span_font_id,
	get_span_font_size = C.tr_get_span_font_size,
	get_span_lang = C.tr_get_span_lang,
	get_span_nowrap = C.tr_get_span_nowrap,
	get_span_opacity = C.tr_get_span_opacity,
	get_span_operator = C.tr_get_span_operator,
	get_span_paragraph_dir = C.tr_get_span_paragraph_dir,
	get_span_script = C.tr_get_span_script,
	set_span_color = C.tr_set_span_color,
	set_span_features = C.tr_set_span_features,
	set_span_font_face_index = C.tr_set_span_font_face_index,
	set_span_font_id = C.tr_set_span_font_id,
	set_span_font_size = C.tr_set_span_font_size,
	set_span_lang = C.tr_set_span_lang,
	set_span_nowrap = C.tr_set_span_nowrap,
	set_span_opacity = C.tr_set_span_opacity,
	set_span_operator = C.tr_set_span_operator,
	set_span_paragraph_dir = C.tr_set_span_paragraph_dir,
	set_span_script = C.tr_set_span_script,
	get_span_offset = C.tr_get_span_offset,
	set_span_offset = C.tr_set_span_offset,
	span_at_offset = C.tr_span_at_offset,
	remove_text = C.tr_remove_text,
	insert_text = C.tr_insert_text,
	bbox = C.tr_bbox,
	get_cursor_offset = C.tr_get_cursor_offset,
	get_cursor_which = C.tr_get_cursor_which,
	get_cursor_sel_offset = C.tr_get_cursor_sel_offset,
	get_cursor_sel_which = C.tr_get_cursor_sel_which,
	get_cursor_x = C.tr_get_cursor_x,
	set_cursor_offset = C.tr_set_cursor_offset,
	set_cursor_which = C.tr_set_cursor_which,
	set_cursor_sel_offset = C.tr_set_cursor_sel_offset,
	set_cursor_sel_which = C.tr_set_cursor_sel_which,
	set_cursor_x = C.tr_set_cursor_x,
	cursor_move_to = C.tr_cursor_move_to,
	cursor_move_to_point = C.tr_cursor_move_to_point,
	cursor_move_near = C.tr_cursor_move_near,
	cursor_move_near_line = C.tr_cursor_move_near_line,
	cursor_move_near_page = C.tr_cursor_move_near_page,
	get_caret_visible = C.tr_get_caret_visible,
	get_selection_visible = C.tr_get_selection_visible,
	set_caret_visible = C.tr_set_caret_visible,
	set_selection_visible = C.tr_set_selection_visible,
	get_selection_first_span = C.tr_get_selection_first_span,
	remove_selected_text = C.tr_remove_selected_text,
	insert_text_at_cursor = C.tr_insert_text_at_cursor,
	insert_text_utf8_at_cursor = C.tr_insert_text_utf8_at_cursor,
	get_selected_text_len = C.tr_get_selected_text_len,
	get_selected_text = C.tr_get_selected_text,
	get_selected_text_utf8 = C.tr_get_selected_text_utf8,
	get_selected_text_utf8_len = C.tr_get_selected_text_utf8_len,
	load_cursor_xs = C.tr_load_cursor_xs,
}
ffi.metatype('layout_t', {
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
	ALIGN_BOTTOM = 2,
	ALIGN_CENTER = 3,
	ALIGN_END = 6,
	ALIGN_JUSTIFY = 4,
	ALIGN_LEFT = 1,
	ALIGN_MAX = 6,
	ALIGN_RIGHT = 2,
	ALIGN_START = 5,
	ALIGN_TOP = 1,
	CURSOR_DIR_CURR = 3,
	CURSOR_DIR_MAX = 3,
	CURSOR_DIR_MIN = 1,
	CURSOR_DIR_NEXT = 1,
	CURSOR_DIR_PREV = 2,
	CURSOR_MODE_CHAR = 2,
	CURSOR_MODE_DEFAULT = 0,
	CURSOR_MODE_LINE = 4,
	CURSOR_MODE_MAX = 4,
	CURSOR_MODE_MIN = 1,
	CURSOR_MODE_POS = 1,
	CURSOR_MODE_WORD = 3,
	CURSOR_WHICH_FIRST = 0,
	CURSOR_WHICH_LAST = 1,
	CURSOR_WHICH_MAX = 1,
	CURSOR_WHICH_MIN = 0,
	DIR_AUTO = 1,
	DIR_LTR = 2,
	DIR_MAX = 5,
	DIR_MIN = 1,
	DIR_RTL = 3,
	DIR_WLTR = 4,
	DIR_WRTL = 5,
}]]
return C
