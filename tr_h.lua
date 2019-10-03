-- This file was auto-generated. Modify at your own risk.

local ffi = require'ffi'
local C = ffi.load'tr'
ffi.cdef[[
uint64_t memtotal(void);
void memreport(void);
int32_t tr_renderer_sizeof(void);
int32_t tr_layout_sizeof(void);
typedef struct renderer_t renderer_t;
typedef void (*tr_font_load_func_t) (int32_t, void**, uint64_t*, bool*);
typedef void (*tr_font_unload_func_t) (int32_t, void*, uint64_t, bool);
renderer_t* tr_renderer(tr_font_load_func_t, tr_font_unload_func_t);
typedef struct renderer_t renderer_t;
typedef void (*error_func_t) (int8_t*);
error_func_t renderer_get_error_function(renderer_t*);
void renderer_free(renderer_t*);
void renderer_set_subpixel_x_resolution(renderer_t*, double);
double renderer_get_glyph_cache_size(renderer_t*);
void renderer_set_font_size_resolution(renderer_t*, double);
void renderer_init(renderer_t*, tr_font_load_func_t, tr_font_unload_func_t);
void renderer_set_error_function(renderer_t*, error_func_t);
void renderer_set_word_subpixel_x_resolution(renderer_t*, double);
void renderer_set_glyph_run_cache_max_size(renderer_t*, double);
double renderer_get_font_size_resolution(renderer_t*);
double renderer_get_mmapped_font_cache_max_count(renderer_t*);
void renderer_set_mmapped_font_cache_max_count(renderer_t*, double);
double renderer_get_mem_font_cache_count(renderer_t*);
double renderer_get_mem_font_cache_size(renderer_t*);
double renderer_get_word_subpixel_x_resolution(renderer_t*);
int32_t renderer_font_face_num(renderer_t*, int32_t);
void renderer_set_paint_glyph_num(renderer_t*, int32_t);
typedef struct layout_t layout_t;
layout_t* renderer_layout(renderer_t*);
typedef struct Layout Layout;
typedef struct Embed Embed;
typedef struct Span Span;
typedef void (*embed_set_size_func_t) (Layout*, int32_t, Embed*, Span*);
embed_set_size_func_t renderer_get_embed_set_size_function(renderer_t*);
double renderer_get_mmapped_font_cache_count(renderer_t*);
void renderer_set_mem_font_cache_max_size(renderer_t*, double);
void renderer_set_glyph_cache_max_size(renderer_t*, double);
typedef struct _cairo _cairo;
typedef void (*embed_draw_func_t) (_cairo*, layout_t*, int32_t, Embed*, Span*);
void renderer_set_embed_draw_function(renderer_t*, embed_draw_func_t);
void renderer_release(renderer_t*);
double renderer_get_mem_font_cache_max_size(renderer_t*);
double renderer_get_glyph_run_cache_count(renderer_t*);
double renderer_get_glyph_run_cache_max_size(renderer_t*);
embed_draw_func_t renderer_get_embed_draw_function(renderer_t*);
double renderer_get_subpixel_x_resolution(renderer_t*);
double renderer_get_glyph_cache_count(renderer_t*);
void renderer_set_embed_set_size_function(renderer_t*, embed_set_size_func_t);
double renderer_get_glyph_run_cache_size(renderer_t*);
int64_t renderer_get_paint_glyph_num(renderer_t*);
double renderer_get_glyph_cache_max_size(renderer_t*);
typedef struct layout_t layout_t;
int32_t layout_get_span_count(layout_t*);
void layout_set_selection_visible(layout_t*, int32_t, bool);
bool layout_has_paragraph_dir(layout_t*, int32_t, int32_t);
void layout_set_span_count(layout_t*, int32_t);
void layout_set_lang(layout_t*, int32_t, int32_t, int8_t*);
int32_t layout_get_cursor_xs_len(layout_t*);
void layout_set_hardline_spacing(layout_t*, double);
int32_t layout_get_selected_text_utf8_len(layout_t*, int32_t);
int8_t* layout_get_span_script(layout_t*, int32_t);
void layout_set_caret_thickness(layout_t*, int32_t, double);
void layout_set_embed_ascent(layout_t*, int32_t, double);
double layout_get_spaced_h(layout_t*);
double layout_get_line_spacing(layout_t*);
void layout_cursor_move_to_point(layout_t*, int32_t, double, double, bool);
double layout_get_clip_h(layout_t*);
void layout_set_paragraph_dir(layout_t*, int32_t, int32_t, int32_t);
int32_t layout_get_cursor_count(layout_t*);
void layout_set_span_script(layout_t*, int32_t, int8_t*);
double layout_get_hardline_spacing(layout_t*);
int32_t layout_insert_text(layout_t*, int32_t, uint32_t*, int32_t);
void layout_set_line_spacing(layout_t*, double);
double layout_get_x(layout_t*);
void layout_remove_selected_text(layout_t*, int32_t);
void layout_set_embed_descent(layout_t*, int32_t, double);
int32_t layout_get_text_len(layout_t*);
void layout_set_clip_h(layout_t*, double);
void layout_set_font_id(layout_t*, int32_t, int32_t, int32_t);
bool layout_has_nowrap(layout_t*, int32_t, int32_t);
void layout_set_cursor_sel_which(layout_t*, int32_t, int8_t);
bool layout_has_color(layout_t*, int32_t, int32_t);
void layout_set_span_color(layout_t*, int32_t, uint32_t);
int32_t layout_get_cursor_which(layout_t*, int32_t);
void layout_set_clip_w(layout_t*, double);
int8_t layout_get_align_y(layout_t*);
void layout_set_opacity(layout_t*, int32_t, int32_t, double);
bool layout_get_caret_visible(layout_t*, int32_t);
void layout_set_cursor_x(layout_t*, int32_t, double);
void layout_init(layout_t*, renderer_t*);
void layout_set_align_h(layout_t*, double);
void layout_set_span_operator(layout_t*, int32_t, int8_t);
void layout_set_span_opacity(layout_t*, int32_t, double);
void layout_set_paragraph_spacing(layout_t*, double);
void layout_set_clip_y(layout_t*, double);
int32_t layout_span_at_offset(layout_t*, int32_t);
void layout_set_color(layout_t*, int32_t, int32_t, uint32_t);
double layout_get_selection_opacity(layout_t*, int32_t);
double layout_remove_text(layout_t*, double, double);
double layout_get_align_h(layout_t*);
void layout_set_span_font_size(layout_t*, int32_t, double);
void layout_insert_text_at_cursor(layout_t*, int32_t, uint32_t*, int32_t);
void layout_set_selection_color(layout_t*, int32_t, uint32_t);
void layout_layout(layout_t*);
float layout_get_embed_ascent(layout_t*, int32_t);
bool layout_get_pixels_valid(layout_t*);
double layout_get_clip_x(layout_t*);
double layout_get_max_w(layout_t*);
bool layout_get_align_valid(layout_t*);
double layout_get_clip_y(layout_t*);
bool layout_has_features(layout_t*, int32_t, int32_t);
double layout_get_span_font_size(layout_t*, int32_t);
int8_t layout_get_cursor_sel_which(layout_t*, int32_t);
void layout_set_align_w(layout_t*, double);
void layout_set_clip_x(layout_t*, double);
void layout_set_features(layout_t*, int32_t, int32_t, int8_t*);
double layout_get_paragraph_spacing(layout_t*);
int32_t layout_get_span_font_face_index(layout_t*, int32_t);
void layout_set_x(layout_t*, double);
double layout_get_y(layout_t*);
int32_t layout_get_cursor_sel_offset(layout_t*, int32_t);
double* layout_get_cursor_xs(layout_t*);
bool layout_has_font_face_index(layout_t*, int32_t, int32_t);
double layout_get_baseline(layout_t*);
int8_t* layout_get_span_features(layout_t*, int32_t);
int32_t layout_get_selected_text_utf8(layout_t*, int32_t, int8_t*, int32_t);
double layout_get_align_w(layout_t*);
float layout_get_embed_descent(layout_t*, int32_t);
int32_t layout_get_selected_text_len(layout_t*, int32_t);
void layout_insert_text_utf8_at_cursor(layout_t*, int32_t, int8_t*, int32_t);
int32_t layout_get_selection_first_span(layout_t*, int32_t);
void layout_cursor_move_near_page(layout_t*, int32_t, double, double, bool);
void layout_set_align_y(layout_t*, int8_t);
void layout_cursor_move_near_line(layout_t*, int32_t, double, double, bool);
void layout_cursor_move_near(layout_t*, int32_t, int8_t, int8_t, int8_t, bool);
bool layout_has_opacity(layout_t*, int32_t, int32_t);
void layout_set_selection_opacity(layout_t*, int32_t, double);
void layout_set_caret_opacity(layout_t*, int32_t, double);
void layout_set_align_x(layout_t*, int8_t);
float layout_get_embed_advance_x(layout_t*, int32_t);
renderer_t* layout_get_r(layout_t*);
int32_t layout_get_text_utf8_len(layout_t*);
void layout_set_insert_mode(layout_t*, int32_t, bool);
void layout_set_caret_visible(layout_t*, int32_t, bool);
void layout_set_cursor_sel_offset(layout_t*, int32_t, double);
void layout_set_cursor_which(layout_t*, int32_t, int8_t);
void layout_set_dir(layout_t*, int8_t);
int32_t layout_get_span_offset(layout_t*, int32_t);
void layout_set_cursor_offset(layout_t*, int32_t, double);
uint32_t layout_get_selection_color(layout_t*, int32_t);
void layout_set_maxlen(layout_t*, int32_t);
void layout_release(layout_t*);
bool layout_has_script(layout_t*, int32_t, int32_t);
double layout_get_caret_opacity(layout_t*, int32_t);
bool layout_get_insert_mode(layout_t*, int32_t);
bool layout_get_selection_visible(layout_t*, int32_t);
void layout_shape(layout_t*);
double layout_get_span_opacity(layout_t*, int32_t);
void layout_set_embed_advance_x(layout_t*, int32_t, double);
double layout_get_cursor_x(layout_t*, int32_t);
int32_t layout_get_cursor_offset(layout_t*, int32_t);
void layout_remove_trailing_spans(layout_t*);
bool layout_has_operator(layout_t*, int32_t, int32_t);
int8_t layout_get_span_operator(layout_t*, int32_t);
void layout_set_span_font_face_index(layout_t*, int32_t, int32_t);
int8_t layout_get_align_x(layout_t*);
int32_t layout_set_cursor_count(layout_t*, int32_t);
double layout_get_min_w(layout_t*);
void layout_set_span_paragraph_dir(layout_t*, int32_t, int32_t);
void layout_set_script(layout_t*, int32_t, int32_t, int8_t*);
double layout_get_clip_w(layout_t*);
void layout_set_operator(layout_t*, int32_t, int32_t, int8_t);
void layout_load_cursor_xs(layout_t*, int32_t);
bool layout_get_min_size_valid(layout_t*);
void layout_set_clip_extents(layout_t*, double, double, double, double);
uint32_t layout_get_span_color(layout_t*, int32_t);
int8_t layout_get_dir(layout_t*);
void layout_align(layout_t*);
uint32_t* layout_get_selected_text(layout_t*, int32_t);
int8_t* layout_get_span_lang(layout_t*, int32_t);
void layout_wrap(layout_t*);
void layout_set_font_size(layout_t*, int32_t, int32_t, double);
int32_t layout_get_maxlen(layout_t*);
void layout_set_span_lang(layout_t*, int32_t, int8_t*);
bool layout_has_font_size(layout_t*, int32_t, int32_t);
bool layout_get_visible(layout_t*);
void layout_set_text(layout_t*, uint32_t*, int32_t);
int32_t layout_get_text_utf8(layout_t*, int8_t*, int32_t);
uint32_t* layout_get_text(layout_t*);
void layout_free(layout_t*);
void layout_paint(layout_t*, _cairo*);
bool layout_has_lang(layout_t*, int32_t, int32_t);
typedef struct {
	double _0;
	double _1;
	double _2;
	double _3;
} double4;
double4 layout_bbox(layout_t*);
void layout_set_span_features(layout_t*, int32_t, int8_t*);
void layout_set_y(layout_t*, double);
void layout_set_span_nowrap(layout_t*, int32_t, bool);
int32_t layout_get_span_font_id(layout_t*, int32_t);
void layout_set_text_utf8(layout_t*, int8_t*, int32_t);
void layout_set_font_face_index(layout_t*, int32_t, int32_t, int32_t);
bool layout_get_offsets_valid(layout_t*);
void layout_clip(layout_t*);
int32_t layout_get_span_paragraph_dir(layout_t*, int32_t);
void layout_set_nowrap(layout_t*, int32_t, int32_t, bool);
bool layout_get_span_nowrap(layout_t*, int32_t);
bool layout_has_font_id(layout_t*, int32_t, int32_t);
void layout_set_span_font_id(layout_t*, int32_t, int32_t);
void layout_set_span_offset(layout_t*, int32_t, int32_t);
double layout_get_caret_thickness(layout_t*, int32_t);
void layout_cursor_move_to(layout_t*, int32_t, double, int8_t, bool);
bool layout_get_valid(layout_t*);
]]
local getters = {
	embed_draw_function = C.renderer_get_embed_draw_function,
	embed_set_size_function = C.renderer_get_embed_set_size_function,
	error_function = C.renderer_get_error_function,
	font_size_resolution = C.renderer_get_font_size_resolution,
	glyph_cache_count = C.renderer_get_glyph_cache_count,
	glyph_cache_max_size = C.renderer_get_glyph_cache_max_size,
	glyph_cache_size = C.renderer_get_glyph_cache_size,
	glyph_run_cache_count = C.renderer_get_glyph_run_cache_count,
	glyph_run_cache_max_size = C.renderer_get_glyph_run_cache_max_size,
	glyph_run_cache_size = C.renderer_get_glyph_run_cache_size,
	mem_font_cache_count = C.renderer_get_mem_font_cache_count,
	mem_font_cache_max_size = C.renderer_get_mem_font_cache_max_size,
	mem_font_cache_size = C.renderer_get_mem_font_cache_size,
	mmapped_font_cache_count = C.renderer_get_mmapped_font_cache_count,
	mmapped_font_cache_max_count = C.renderer_get_mmapped_font_cache_max_count,
	paint_glyph_num = C.renderer_get_paint_glyph_num,
	subpixel_x_resolution = C.renderer_get_subpixel_x_resolution,
	word_subpixel_x_resolution = C.renderer_get_word_subpixel_x_resolution,
}
local setters = {
	embed_draw_function = C.renderer_set_embed_draw_function,
	embed_set_size_function = C.renderer_set_embed_set_size_function,
	error_function = C.renderer_set_error_function,
	font_size_resolution = C.renderer_set_font_size_resolution,
	glyph_cache_max_size = C.renderer_set_glyph_cache_max_size,
	glyph_run_cache_max_size = C.renderer_set_glyph_run_cache_max_size,
	mem_font_cache_max_size = C.renderer_set_mem_font_cache_max_size,
	mmapped_font_cache_max_count = C.renderer_set_mmapped_font_cache_max_count,
	paint_glyph_num = C.renderer_set_paint_glyph_num,
	subpixel_x_resolution = C.renderer_set_subpixel_x_resolution,
	word_subpixel_x_resolution = C.renderer_set_word_subpixel_x_resolution,
}
local methods = {
	font_face_num = C.renderer_font_face_num,
	free = C.renderer_free,
	init = C.renderer_init,
	layout = C.renderer_layout,
	release = C.renderer_release,
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
	align_h = C.layout_get_align_h,
	align_valid = C.layout_get_align_valid,
	align_w = C.layout_get_align_w,
	align_x = C.layout_get_align_x,
	align_y = C.layout_get_align_y,
	baseline = C.layout_get_baseline,
	clip_h = C.layout_get_clip_h,
	clip_w = C.layout_get_clip_w,
	clip_x = C.layout_get_clip_x,
	clip_y = C.layout_get_clip_y,
	cursor_count = C.layout_get_cursor_count,
	cursor_xs = C.layout_get_cursor_xs,
	cursor_xs_len = C.layout_get_cursor_xs_len,
	dir = C.layout_get_dir,
	hardline_spacing = C.layout_get_hardline_spacing,
	line_spacing = C.layout_get_line_spacing,
	max_w = C.layout_get_max_w,
	maxlen = C.layout_get_maxlen,
	min_size_valid = C.layout_get_min_size_valid,
	min_w = C.layout_get_min_w,
	offsets_valid = C.layout_get_offsets_valid,
	paragraph_spacing = C.layout_get_paragraph_spacing,
	pixels_valid = C.layout_get_pixels_valid,
	r = C.layout_get_r,
	spaced_h = C.layout_get_spaced_h,
	span_count = C.layout_get_span_count,
	text = C.layout_get_text,
	text_len = C.layout_get_text_len,
	text_utf8_len = C.layout_get_text_utf8_len,
	valid = C.layout_get_valid,
	visible = C.layout_get_visible,
	x = C.layout_get_x,
	y = C.layout_get_y,
}
local setters = {
	align_h = C.layout_set_align_h,
	align_w = C.layout_set_align_w,
	align_x = C.layout_set_align_x,
	align_y = C.layout_set_align_y,
	clip_h = C.layout_set_clip_h,
	clip_w = C.layout_set_clip_w,
	clip_x = C.layout_set_clip_x,
	clip_y = C.layout_set_clip_y,
	cursor_count = C.layout_set_cursor_count,
	dir = C.layout_set_dir,
	hardline_spacing = C.layout_set_hardline_spacing,
	line_spacing = C.layout_set_line_spacing,
	maxlen = C.layout_set_maxlen,
	paragraph_spacing = C.layout_set_paragraph_spacing,
	span_count = C.layout_set_span_count,
	x = C.layout_set_x,
	y = C.layout_set_y,
}
local methods = {
	align = C.layout_align,
	bbox = C.layout_bbox,
	clip = C.layout_clip,
	cursor_move_near = C.layout_cursor_move_near,
	cursor_move_near_line = C.layout_cursor_move_near_line,
	cursor_move_near_page = C.layout_cursor_move_near_page,
	cursor_move_to = C.layout_cursor_move_to,
	cursor_move_to_point = C.layout_cursor_move_to_point,
	free = C.layout_free,
	get_caret_opacity = C.layout_get_caret_opacity,
	get_caret_thickness = C.layout_get_caret_thickness,
	get_caret_visible = C.layout_get_caret_visible,
	get_cursor_offset = C.layout_get_cursor_offset,
	get_cursor_sel_offset = C.layout_get_cursor_sel_offset,
	get_cursor_sel_which = C.layout_get_cursor_sel_which,
	get_cursor_which = C.layout_get_cursor_which,
	get_cursor_x = C.layout_get_cursor_x,
	get_embed_advance_x = C.layout_get_embed_advance_x,
	get_embed_ascent = C.layout_get_embed_ascent,
	get_embed_descent = C.layout_get_embed_descent,
	get_insert_mode = C.layout_get_insert_mode,
	get_selected_text = C.layout_get_selected_text,
	get_selected_text_len = C.layout_get_selected_text_len,
	get_selected_text_utf8 = C.layout_get_selected_text_utf8,
	get_selected_text_utf8_len = C.layout_get_selected_text_utf8_len,
	get_selection_color = C.layout_get_selection_color,
	get_selection_first_span = C.layout_get_selection_first_span,
	get_selection_opacity = C.layout_get_selection_opacity,
	get_selection_visible = C.layout_get_selection_visible,
	get_span_color = C.layout_get_span_color,
	get_span_features = C.layout_get_span_features,
	get_span_font_face_index = C.layout_get_span_font_face_index,
	get_span_font_id = C.layout_get_span_font_id,
	get_span_font_size = C.layout_get_span_font_size,
	get_span_lang = C.layout_get_span_lang,
	get_span_nowrap = C.layout_get_span_nowrap,
	get_span_offset = C.layout_get_span_offset,
	get_span_opacity = C.layout_get_span_opacity,
	get_span_operator = C.layout_get_span_operator,
	get_span_paragraph_dir = C.layout_get_span_paragraph_dir,
	get_span_script = C.layout_get_span_script,
	get_text_utf8 = C.layout_get_text_utf8,
	has_color = C.layout_has_color,
	has_features = C.layout_has_features,
	has_font_face_index = C.layout_has_font_face_index,
	has_font_id = C.layout_has_font_id,
	has_font_size = C.layout_has_font_size,
	has_lang = C.layout_has_lang,
	has_nowrap = C.layout_has_nowrap,
	has_opacity = C.layout_has_opacity,
	has_operator = C.layout_has_operator,
	has_paragraph_dir = C.layout_has_paragraph_dir,
	has_script = C.layout_has_script,
	init = C.layout_init,
	insert_text = C.layout_insert_text,
	insert_text_at_cursor = C.layout_insert_text_at_cursor,
	insert_text_utf8_at_cursor = C.layout_insert_text_utf8_at_cursor,
	layout = C.layout_layout,
	load_cursor_xs = C.layout_load_cursor_xs,
	paint = C.layout_paint,
	release = C.layout_release,
	remove_selected_text = C.layout_remove_selected_text,
	remove_text = C.layout_remove_text,
	remove_trailing_spans = C.layout_remove_trailing_spans,
	set_caret_opacity = C.layout_set_caret_opacity,
	set_caret_thickness = C.layout_set_caret_thickness,
	set_caret_visible = C.layout_set_caret_visible,
	set_clip_extents = C.layout_set_clip_extents,
	set_color = C.layout_set_color,
	set_cursor_offset = C.layout_set_cursor_offset,
	set_cursor_sel_offset = C.layout_set_cursor_sel_offset,
	set_cursor_sel_which = C.layout_set_cursor_sel_which,
	set_cursor_which = C.layout_set_cursor_which,
	set_cursor_x = C.layout_set_cursor_x,
	set_embed_advance_x = C.layout_set_embed_advance_x,
	set_embed_ascent = C.layout_set_embed_ascent,
	set_embed_descent = C.layout_set_embed_descent,
	set_features = C.layout_set_features,
	set_font_face_index = C.layout_set_font_face_index,
	set_font_id = C.layout_set_font_id,
	set_font_size = C.layout_set_font_size,
	set_insert_mode = C.layout_set_insert_mode,
	set_lang = C.layout_set_lang,
	set_nowrap = C.layout_set_nowrap,
	set_opacity = C.layout_set_opacity,
	set_operator = C.layout_set_operator,
	set_paragraph_dir = C.layout_set_paragraph_dir,
	set_script = C.layout_set_script,
	set_selection_color = C.layout_set_selection_color,
	set_selection_opacity = C.layout_set_selection_opacity,
	set_selection_visible = C.layout_set_selection_visible,
	set_span_color = C.layout_set_span_color,
	set_span_features = C.layout_set_span_features,
	set_span_font_face_index = C.layout_set_span_font_face_index,
	set_span_font_id = C.layout_set_span_font_id,
	set_span_font_size = C.layout_set_span_font_size,
	set_span_lang = C.layout_set_span_lang,
	set_span_nowrap = C.layout_set_span_nowrap,
	set_span_offset = C.layout_set_span_offset,
	set_span_opacity = C.layout_set_span_opacity,
	set_span_operator = C.layout_set_span_operator,
	set_span_paragraph_dir = C.layout_set_span_paragraph_dir,
	set_span_script = C.layout_set_span_script,
	set_text = C.layout_set_text,
	set_text_utf8 = C.layout_set_text_utf8,
	shape = C.layout_shape,
	span_at_offset = C.layout_span_at_offset,
	wrap = C.layout_wrap,
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
return C
