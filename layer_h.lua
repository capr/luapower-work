local ffi = require'ffi'
local C = ffi.load'layer'
ffi.cdef[[
typedef struct layerlib_t layerlib_t;
typedef struct layer_t layer_t;
typedef struct double2 double2;
typedef struct _cairo _cairo;
typedef void (*tr_font_load_func) (int32_t, void**, uint64_t*);
typedef void (*error_function_t) (const char *);
typedef void (*ll_border_lineto_func) (layer_t*, _cairo*, double, double, double);
uint64_t memtotal();
void memreport();
layerlib_t* layerlib(tr_font_load_func, tr_font_load_func);
void layerlib_init(layerlib_t*, tr_font_load_func, tr_font_load_func);
void layerlib_free(layerlib_t*);
void layerlib_release(layerlib_t*);
double layerlib_get_font_size_resolution(layerlib_t*);
double layerlib_get_subpixel_x_resolution(layerlib_t*);
double layerlib_get_word_subpixel_x_resolution(layerlib_t*);
int32_t layerlib_get_glyph_cache_max_size(layerlib_t*);
int32_t layerlib_get_glyph_run_cache_max_size(layerlib_t*);
int32_t layerlib_get_mem_font_cache_max_size(layerlib_t*);
int32_t layerlib_get_mmapped_font_cache_max_count(layerlib_t*);
error_function_t layerlib_get_error_function(layerlib_t*);
void layerlib_set_font_size_resolution(layerlib_t*, double);
void layerlib_set_subpixel_x_resolution(layerlib_t*, double);
void layerlib_set_word_subpixel_x_resolution(layerlib_t*, double);
void layerlib_set_glyph_cache_max_size(layerlib_t*, double);
void layerlib_set_glyph_run_cache_max_size(layerlib_t*, double);
void layerlib_set_mem_font_cache_max_size(layerlib_t*, double);
void layerlib_set_mmapped_font_cache_max_count(layerlib_t*, double);
void layerlib_set_error_function(layerlib_t*, error_function_t);
int32_t layerlib_get_glyph_run_cache_size(layerlib_t*);
int32_t layerlib_get_glyph_run_cache_count(layerlib_t*);
int32_t layerlib_get_glyph_cache_size(layerlib_t*);
int32_t layerlib_get_glyph_cache_count(layerlib_t*);
int32_t layerlib_get_mem_font_cache_size(layerlib_t*);
int32_t layerlib_get_mem_font_cache_count(layerlib_t*);
int32_t layerlib_get_mmapped_font_cache_count(layerlib_t*);
layer_t* layerlib_layer(layerlib_t*);
void layer_init(layer_t*, layerlib_t*, layer_t*);
void layer_free(layer_t*);
void layer_release(layer_t*);
layerlib_t* layer_get_lib(layer_t*);
layer_t* layer_get_parent(layer_t*);
int32_t layer_get_index(layer_t*);
layer_t* layer_get_pos_parent(layer_t*);
layer_t* layer_get_top_layer(layer_t*);
layer_t* layer_child(layer_t*, int32_t);
void layer_set_parent(layer_t*, layer_t*);
void layer_set_index(layer_t*, double);
void layer_set_pos_parent(layer_t*, layer_t*);
layer_t* layer_layer(layer_t*);
int32_t layer_get_child_count(layer_t*);
void layer_set_child_count(layer_t*, int32_t);
double layer_get_x(layer_t*);
double layer_get_y(layer_t*);
double layer_get_w(layer_t*);
double layer_get_h(layer_t*);
void layer_set_x(layer_t*, double);
void layer_set_y(layer_t*, double);
void layer_set_w(layer_t*, double);
void layer_set_h(layer_t*, double);
double layer_get_cx(layer_t*);
double layer_get_cy(layer_t*);
double layer_get_cw(layer_t*);
double layer_get_ch(layer_t*);
void layer_set_cx(layer_t*, double);
void layer_set_cy(layer_t*, double);
void layer_set_cw(layer_t*, double);
void layer_set_ch(layer_t*, double);
bool layer_get_in_transition(layer_t*);
void layer_set_in_transition(layer_t*, bool);
double layer_get_final_x(layer_t*);
double layer_get_final_y(layer_t*);
double layer_get_final_w(layer_t*);
double layer_get_final_h(layer_t*);
double layer_get_padding_bottom(layer_t*);
double layer_get_padding_left(layer_t*);
double layer_get_padding_right(layer_t*);
double layer_get_padding_top(layer_t*);
void layer_set_padding_bottom(layer_t*, double);
void layer_set_padding_left(layer_t*, double);
void layer_set_padding_right(layer_t*, double);
void layer_set_padding_top(layer_t*, double);
double layer_get_padding(layer_t*);
void layer_set_padding(layer_t*, double);
double2 layer_from_window(layer_t*, double, double);
int8_t layer_get_operator(layer_t*);
bool layer_get_clip_content(layer_t*);
bool layer_get_snap_x(layer_t*);
bool layer_get_snap_y(layer_t*);
double layer_get_opacity(layer_t*);
void layer_set_operator(layer_t*, int8_t);
void layer_set_clip_content(layer_t*, bool);
void layer_set_snap_x(layer_t*, bool);
void layer_set_snap_y(layer_t*, bool);
void layer_set_opacity(layer_t*, double);
double layer_get_rotation(layer_t*);
double layer_get_rotation_cx(layer_t*);
double layer_get_rotation_cy(layer_t*);
double layer_get_scale(layer_t*);
double layer_get_scale_cx(layer_t*);
double layer_get_scale_cy(layer_t*);
void layer_set_rotation(layer_t*, double);
void layer_set_rotation_cx(layer_t*, double);
void layer_set_rotation_cy(layer_t*, double);
void layer_set_scale(layer_t*, double);
void layer_set_scale_cx(layer_t*, double);
void layer_set_scale_cy(layer_t*, double);
double layer_get_border_width_bottom(layer_t*);
double layer_get_border_width_left(layer_t*);
double layer_get_border_width_right(layer_t*);
double layer_get_border_width_top(layer_t*);
void layer_set_border_width_bottom(layer_t*, double);
void layer_set_border_width_left(layer_t*, double);
void layer_set_border_width_right(layer_t*, double);
void layer_set_border_width_top(layer_t*, double);
uint32_t layer_get_border_color_bottom(layer_t*);
uint32_t layer_get_border_color_left(layer_t*);
uint32_t layer_get_border_color_right(layer_t*);
uint32_t layer_get_border_color_top(layer_t*);
void layer_set_border_color_bottom(layer_t*, uint32_t);
void layer_set_border_color_left(layer_t*, uint32_t);
void layer_set_border_color_right(layer_t*, uint32_t);
void layer_set_border_color_top(layer_t*, uint32_t);
double layer_get_border_width(layer_t*);
void layer_set_border_width(layer_t*, double);
uint32_t layer_get_border_color(layer_t*);
void layer_set_border_color(layer_t*, double);
double layer_get_corner_radius_bottom_left(layer_t*);
double layer_get_corner_radius_bottom_right(layer_t*);
double layer_get_corner_radius_top_left(layer_t*);
double layer_get_corner_radius_top_right(layer_t*);
void layer_set_corner_radius_bottom_left(layer_t*, double);
void layer_set_corner_radius_bottom_right(layer_t*, double);
void layer_set_corner_radius_top_left(layer_t*, double);
void layer_set_corner_radius_top_right(layer_t*, double);
double layer_get_corner_radius(layer_t*);
void layer_set_corner_radius(layer_t*, double);
int32_t layer_get_border_dash_count(layer_t*);
void layer_set_border_dash_count(layer_t*, int32_t);
int32_t layer_get_border_dash(layer_t*, int32_t);
void layer_set_border_dash(layer_t*, int32_t, double);
double layer_get_border_dash_offset(layer_t*);
void layer_set_border_dash_offset(layer_t*, double);
double layer_get_border_offset(layer_t*);
void layer_set_border_offset(layer_t*, double);
void layer_set_border_line_to(layer_t*, ll_border_lineto_func);
int8_t layer_get_background_type(layer_t*);
void layer_set_background_type(layer_t*, int8_t);
bool layer_get_background_hittable(layer_t*);
void layer_set_background_hittable(layer_t*, bool);
int8_t layer_get_background_operator(layer_t*);
void layer_set_background_operator(layer_t*, int8_t);
double layer_get_background_opacity(layer_t*);
void layer_set_background_opacity(layer_t*, double);
double layer_get_background_clip_border_offset(layer_t*);
void layer_set_background_clip_border_offset(layer_t*, double);
uint32_t layer_get_background_color(layer_t*);
void layer_set_background_color(layer_t*, uint32_t);
double layer_get_background_r1(layer_t*);
double layer_get_background_r2(layer_t*);
double layer_get_background_x1(layer_t*);
double layer_get_background_x2(layer_t*);
double layer_get_background_y1(layer_t*);
double layer_get_background_y2(layer_t*);
void layer_set_background_r1(layer_t*, double);
void layer_set_background_r2(layer_t*, double);
void layer_set_background_x1(layer_t*, double);
void layer_set_background_x2(layer_t*, double);
void layer_set_background_y1(layer_t*, double);
void layer_set_background_y2(layer_t*, double);
int32_t layer_get_background_color_stop_count(layer_t*);
void layer_set_background_color_stop_count(layer_t*, int32_t);
uint32_t layer_get_background_color_stop_color(layer_t*, int32_t);
double layer_get_background_color_stop_offset(layer_t*, int32_t);
void layer_set_background_color_stop_color(layer_t*, int32_t, uint32_t);
void layer_set_background_color_stop_offset(layer_t*, int32_t, double);
void layer_set_background_image(layer_t*, int32_t, int32_t, int8_t, int32_t, uint8_t*);
double layer_get_background_image_w(layer_t*);
double layer_get_background_image_h(layer_t*);
int32_t layer_get_background_image_stride(layer_t*);
int8_t layer_get_background_image_format(layer_t*);
uint8_t* layer_get_background_image_pixels(layer_t*);
void layer_background_image_invalidate(layer_t*);
void layer_background_image_invalidate_rect(layer_t*, int32_t, int32_t, int32_t, int32_t);
double layer_get_background_x(layer_t*);
double layer_get_background_y(layer_t*);
int8_t layer_get_background_extend(layer_t*);
void layer_set_background_x(layer_t*, double);
void layer_set_background_y(layer_t*, double);
void layer_set_background_extend(layer_t*, int8_t);
double layer_get_background_rotation(layer_t*);
double layer_get_background_rotation_cx(layer_t*);
double layer_get_background_rotation_cy(layer_t*);
double layer_get_background_scale(layer_t*);
double layer_get_background_scale_cx(layer_t*);
double layer_get_background_scale_cy(layer_t*);
void layer_set_background_rotation(layer_t*, double);
void layer_set_background_rotation_cx(layer_t*, double);
void layer_set_background_rotation_cy(layer_t*, double);
void layer_set_background_scale(layer_t*, double);
void layer_set_background_scale_cx(layer_t*, double);
void layer_set_background_scale_cy(layer_t*, double);
int32_t layer_get_shadow_count(layer_t*);
void layer_set_shadow_count(layer_t*, int32_t);
double layer_get_shadow_x(layer_t*, int32_t);
double layer_get_shadow_y(layer_t*, int32_t);
uint32_t layer_get_shadow_color(layer_t*, int32_t);
int32_t layer_get_shadow_blur(layer_t*, int32_t);
int32_t layer_get_shadow_passes(layer_t*, int32_t);
bool layer_get_shadow_inset(layer_t*, int32_t);
bool layer_get_shadow_content(layer_t*, int32_t);
void layer_set_shadow_x(layer_t*, int32_t, double);
void layer_set_shadow_y(layer_t*, int32_t, double);
void layer_set_shadow_color(layer_t*, int32_t, uint32_t);
void layer_set_shadow_blur(layer_t*, int32_t, int32_t);
void layer_set_shadow_passes(layer_t*, int32_t, int32_t);
void layer_set_shadow_inset(layer_t*, int32_t, bool);
void layer_set_shadow_content(layer_t*, int32_t, bool);
uint32_t* layer_get_text(layer_t*);
int32_t layer_get_text_len(layer_t*);
void layer_set_text(layer_t*, uint32_t*, int32_t);
void layer_set_text_utf8(layer_t*, const char *, int32_t);
int32_t layer_get_text_utf8(layer_t*, const char *, int32_t);
int32_t layer_get_text_utf8_len(layer_t*);
int32_t layer_get_text_maxlen(layer_t*);
void layer_set_text_maxlen(layer_t*, int32_t);
int8_t layer_get_text_dir(layer_t*);
void layer_set_text_dir(layer_t*, int8_t);
int8_t layer_get_text_align_x(layer_t*);
int8_t layer_get_text_align_y(layer_t*);
void layer_set_text_align_x(layer_t*, int8_t);
void layer_set_text_align_y(layer_t*, int8_t);
double layer_get_line_spacing(layer_t*);
double layer_get_hardline_spacing(layer_t*);
double layer_get_paragraph_spacing(layer_t*);
void layer_set_line_spacing(layer_t*, double);
void layer_set_hardline_spacing(layer_t*, double);
void layer_set_paragraph_spacing(layer_t*, double);
int32_t layer_get_span_count(layer_t*);
void layer_set_span_count(layer_t*, int32_t);
const char * layer_get_span_features(layer_t*, int32_t);
int32_t layer_get_span_font_id(layer_t*, int32_t);
double layer_get_span_font_size(layer_t*, int32_t);
const char * layer_get_span_lang(layer_t*, int32_t);
bool layer_get_span_nowrap(layer_t*, int32_t);
int32_t layer_get_span_paragraph_dir(layer_t*, int32_t);
const char * layer_get_span_script(layer_t*, int32_t);
uint32_t layer_get_span_text_color(layer_t*, int32_t);
double layer_get_span_text_opacity(layer_t*, int32_t);
int8_t layer_get_span_text_operator(layer_t*, int32_t);
void layer_set_span_features(layer_t*, int32_t, const char *);
void layer_set_span_font_id(layer_t*, int32_t, int32_t);
void layer_set_span_font_size(layer_t*, int32_t, double);
void layer_set_span_lang(layer_t*, int32_t, const char *);
void layer_set_span_nowrap(layer_t*, int32_t, bool);
void layer_set_span_paragraph_dir(layer_t*, int32_t, int32_t);
void layer_set_span_script(layer_t*, int32_t, const char *);
void layer_set_span_text_color(layer_t*, int32_t, uint32_t);
void layer_set_span_text_opacity(layer_t*, int32_t, double);
void layer_set_span_text_operator(layer_t*, int32_t, int8_t);
int32_t layer_get_span_offset(layer_t*, int32_t);
void layer_set_span_offset(layer_t*, int32_t, int32_t);
void layer_load_text_cursor_xs(layer_t*, int32_t);
double* layer_get_text_cursor_xs(layer_t*);
int32_t layer_get_text_cursor_xs_len(layer_t*);
bool layer_get_text_selectable(layer_t*);
void layer_set_text_selectable(layer_t*, bool);
int32_t layer_get_text_cursor_count(layer_t*);
int32_t layer_set_text_cursor_count(layer_t*, int32_t);
int32_t layer_get_text_cursor_offset(layer_t*, int32_t);
int32_t layer_get_text_cursor_which(layer_t*, int32_t);
int32_t layer_get_text_cursor_sel_offset(layer_t*, int32_t);
int32_t layer_get_text_cursor_sel_which(layer_t*, int32_t);
double layer_get_text_cursor_x(layer_t*, int32_t);
void layer_set_text_cursor_offset(layer_t*, int32_t, double);
void layer_set_text_cursor_which(layer_t*, int32_t, int32_t);
void layer_set_text_cursor_sel_offset(layer_t*, int32_t, double);
void layer_set_text_cursor_sel_which(layer_t*, int32_t, int32_t);
void layer_set_text_cursor_x(layer_t*, int32_t, double);
bool layer_get_text_valid(layer_t*);
bool layer_get_text_offsets_valid(layer_t*);
bool layer_text_selection_has_color(layer_t*, int32_t);
bool layer_text_selection_has_features(layer_t*, int32_t);
bool layer_text_selection_has_font_id(layer_t*, int32_t);
bool layer_text_selection_has_font_size(layer_t*, int32_t);
bool layer_text_selection_has_lang(layer_t*, int32_t);
bool layer_text_selection_has_nowrap(layer_t*, int32_t);
bool layer_text_selection_has_opacity(layer_t*, int32_t);
bool layer_text_selection_has_operator(layer_t*, int32_t);
bool layer_text_selection_has_paragraph_dir(layer_t*, int32_t);
bool layer_text_selection_has_script(layer_t*, int32_t);
uint32_t layer_get_text_selection_color(layer_t*, int32_t);
const char * layer_get_text_selection_features(layer_t*, int32_t);
int32_t layer_get_text_selection_font_id(layer_t*, int32_t);
double layer_get_text_selection_font_size(layer_t*, int32_t);
const char * layer_get_text_selection_lang(layer_t*, int32_t);
bool layer_get_text_selection_nowrap(layer_t*, int32_t);
double layer_get_text_selection_opacity(layer_t*, int32_t);
int8_t layer_get_text_selection_operator(layer_t*, int32_t);
int32_t layer_get_text_selection_paragraph_dir(layer_t*, int32_t);
const char * layer_get_text_selection_script(layer_t*, int32_t);
void layer_set_text_selection_color(layer_t*, int32_t, uint32_t);
void layer_set_text_selection_features(layer_t*, int32_t, const char *);
void layer_set_text_selection_font_id(layer_t*, int32_t, int32_t);
void layer_set_text_selection_font_size(layer_t*, int32_t, double);
void layer_set_text_selection_lang(layer_t*, int32_t, const char *);
void layer_set_text_selection_nowrap(layer_t*, int32_t, bool);
void layer_set_text_selection_opacity(layer_t*, int32_t, double);
void layer_set_text_selection_operator(layer_t*, int32_t, int8_t);
void layer_set_text_selection_paragraph_dir(layer_t*, int32_t, int32_t);
void layer_set_text_selection_script(layer_t*, int32_t, const char *);
void layer_text_cursor_move_to(layer_t*, int32_t, double, int8_t, bool);
void layer_text_cursor_move_to_point(layer_t*, int32_t, double, double, bool);
void layer_text_cursor_move_near(layer_t*, int32_t, int8_t, int8_t, int8_t, bool);
void layer_text_cursor_move_near_line(layer_t*, int32_t, int32_t, double, bool);
void layer_text_cursor_move_near_page(layer_t*, int32_t, int32_t, double, bool);
bool layer_get_visible(layer_t*);
void layer_set_visible(layer_t*, bool);
int8_t layer_get_layout_type(layer_t*);
void layer_set_layout_type(layer_t*, int8_t);
int8_t layer_get_align_items_x(layer_t*);
int8_t layer_get_align_items_y(layer_t*);
int8_t layer_get_item_align_x(layer_t*);
int8_t layer_get_item_align_y(layer_t*);
int8_t layer_get_align_x(layer_t*);
int8_t layer_get_align_y(layer_t*);
void layer_set_align_items_x(layer_t*, int8_t);
void layer_set_align_items_y(layer_t*, int8_t);
void layer_set_item_align_x(layer_t*, int8_t);
void layer_set_item_align_y(layer_t*, int8_t);
void layer_set_align_x(layer_t*, int8_t);
void layer_set_align_y(layer_t*, int8_t);
int8_t layer_get_flex_flow(layer_t*);
void layer_set_flex_flow(layer_t*, int8_t);
bool layer_get_flex_wrap(layer_t*);
void layer_set_flex_wrap(layer_t*, bool);
double layer_get_fr(layer_t*);
void layer_set_fr(layer_t*, double);
bool layer_get_break_before(layer_t*);
bool layer_get_break_after(layer_t*);
void layer_set_break_before(layer_t*, bool);
void layer_set_break_after(layer_t*, bool);
double layer_get_grid_col_fr_count(layer_t*);
double layer_get_grid_row_fr_count(layer_t*);
void layer_set_grid_col_fr_count(layer_t*, int32_t);
void layer_set_grid_row_fr_count(layer_t*, int32_t);
double layer_get_grid_col_fr(layer_t*, int32_t);
double layer_get_grid_row_fr(layer_t*, int32_t);
void layer_set_grid_col_fr(layer_t*, int32_t, double);
void layer_set_grid_row_fr(layer_t*, int32_t, double);
double layer_get_grid_col_gap(layer_t*);
double layer_get_grid_row_gap(layer_t*);
void layer_set_grid_col_gap(layer_t*, double);
void layer_set_grid_row_gap(layer_t*, double);
int8_t layer_get_grid_flow(layer_t*);
void layer_set_grid_flow(layer_t*, int8_t);
int32_t layer_get_grid_wrap(layer_t*);
void layer_set_grid_wrap(layer_t*, double);
int32_t layer_get_grid_min_lines(layer_t*);
void layer_set_grid_min_lines(layer_t*, double);
double layer_get_min_cw(layer_t*);
double layer_get_min_ch(layer_t*);
void layer_set_min_cw(layer_t*, double);
void layer_set_min_ch(layer_t*, double);
int32_t layer_get_grid_col(layer_t*);
int32_t layer_get_grid_row(layer_t*);
void layer_set_grid_col(layer_t*, double);
void layer_set_grid_row(layer_t*, double);
int32_t layer_get_grid_col_span(layer_t*);
int32_t layer_get_grid_row_span(layer_t*);
void layer_set_grid_col_span(layer_t*, double);
void layer_set_grid_row_span(layer_t*, double);
void layer_sync(layer_t*);
bool layer_get_pixels_valid(layer_t*);
void layer_draw(layer_t*, _cairo*);
int8_t layer_get_hit_test_mask(layer_t*);
void layer_set_hit_test_mask(layer_t*, int8_t);
bool layer_hit_test(layer_t*, _cairo*, double, double, int32_t);
layer_t* layer_get_hit_test_layer(layer_t*);
int8_t layer_get_hit_test_area(layer_t*);
double layer_get_hit_test_x(layer_t*);
double layer_get_hit_test_y(layer_t*);
int32_t layer_get_hit_test_text_offset(layer_t*);
int8_t layer_get_hit_test_text_cursor_which(layer_t*);
]]
pcall(ffi.cdef, 'struct double2 { double _0; double _1; };')
local getters = {
	font_size_resolution = C.layerlib_get_font_size_resolution,
	subpixel_x_resolution = C.layerlib_get_subpixel_x_resolution,
	word_subpixel_x_resolution = C.layerlib_get_word_subpixel_x_resolution,
	glyph_cache_max_size = C.layerlib_get_glyph_cache_max_size,
	glyph_run_cache_max_size = C.layerlib_get_glyph_run_cache_max_size,
	mem_font_cache_max_size = C.layerlib_get_mem_font_cache_max_size,
	mmapped_font_cache_max_count = C.layerlib_get_mmapped_font_cache_max_count,
	error_function = C.layerlib_get_error_function,
	glyph_run_cache_size = C.layerlib_get_glyph_run_cache_size,
	glyph_run_cache_count = C.layerlib_get_glyph_run_cache_count,
	glyph_cache_size = C.layerlib_get_glyph_cache_size,
	glyph_cache_count = C.layerlib_get_glyph_cache_count,
	mem_font_cache_size = C.layerlib_get_mem_font_cache_size,
	mem_font_cache_count = C.layerlib_get_mem_font_cache_count,
	mmapped_font_cache_count = C.layerlib_get_mmapped_font_cache_count,
}
local setters = {
	font_size_resolution = C.layerlib_set_font_size_resolution,
	subpixel_x_resolution = C.layerlib_set_subpixel_x_resolution,
	word_subpixel_x_resolution = C.layerlib_set_word_subpixel_x_resolution,
	glyph_cache_max_size = C.layerlib_set_glyph_cache_max_size,
	glyph_run_cache_max_size = C.layerlib_set_glyph_run_cache_max_size,
	mem_font_cache_max_size = C.layerlib_set_mem_font_cache_max_size,
	mmapped_font_cache_max_count = C.layerlib_set_mmapped_font_cache_max_count,
	error_function = C.layerlib_set_error_function,
}
local methods = {
	init = C.layerlib_init,
	free = C.layerlib_free,
	release = C.layerlib_release,
	layer = C.layerlib_layer,
}
ffi.metatype('layerlib_t', {
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
	lib = C.layer_get_lib,
	parent = C.layer_get_parent,
	index = C.layer_get_index,
	pos_parent = C.layer_get_pos_parent,
	top_layer = C.layer_get_top_layer,
	child_count = C.layer_get_child_count,
	x = C.layer_get_x,
	y = C.layer_get_y,
	w = C.layer_get_w,
	h = C.layer_get_h,
	cx = C.layer_get_cx,
	cy = C.layer_get_cy,
	cw = C.layer_get_cw,
	ch = C.layer_get_ch,
	in_transition = C.layer_get_in_transition,
	final_x = C.layer_get_final_x,
	final_y = C.layer_get_final_y,
	final_w = C.layer_get_final_w,
	final_h = C.layer_get_final_h,
	padding_bottom = C.layer_get_padding_bottom,
	padding_left = C.layer_get_padding_left,
	padding_right = C.layer_get_padding_right,
	padding_top = C.layer_get_padding_top,
	padding = C.layer_get_padding,
	operator = C.layer_get_operator,
	clip_content = C.layer_get_clip_content,
	snap_x = C.layer_get_snap_x,
	snap_y = C.layer_get_snap_y,
	opacity = C.layer_get_opacity,
	rotation = C.layer_get_rotation,
	rotation_cx = C.layer_get_rotation_cx,
	rotation_cy = C.layer_get_rotation_cy,
	scale = C.layer_get_scale,
	scale_cx = C.layer_get_scale_cx,
	scale_cy = C.layer_get_scale_cy,
	border_width_bottom = C.layer_get_border_width_bottom,
	border_width_left = C.layer_get_border_width_left,
	border_width_right = C.layer_get_border_width_right,
	border_width_top = C.layer_get_border_width_top,
	border_color_bottom = C.layer_get_border_color_bottom,
	border_color_left = C.layer_get_border_color_left,
	border_color_right = C.layer_get_border_color_right,
	border_color_top = C.layer_get_border_color_top,
	border_width = C.layer_get_border_width,
	border_color = C.layer_get_border_color,
	corner_radius_bottom_left = C.layer_get_corner_radius_bottom_left,
	corner_radius_bottom_right = C.layer_get_corner_radius_bottom_right,
	corner_radius_top_left = C.layer_get_corner_radius_top_left,
	corner_radius_top_right = C.layer_get_corner_radius_top_right,
	corner_radius = C.layer_get_corner_radius,
	border_dash_count = C.layer_get_border_dash_count,
	border_dash_offset = C.layer_get_border_dash_offset,
	border_offset = C.layer_get_border_offset,
	background_type = C.layer_get_background_type,
	background_hittable = C.layer_get_background_hittable,
	background_operator = C.layer_get_background_operator,
	background_opacity = C.layer_get_background_opacity,
	background_clip_border_offset = C.layer_get_background_clip_border_offset,
	background_color = C.layer_get_background_color,
	background_r1 = C.layer_get_background_r1,
	background_r2 = C.layer_get_background_r2,
	background_x1 = C.layer_get_background_x1,
	background_x2 = C.layer_get_background_x2,
	background_y1 = C.layer_get_background_y1,
	background_y2 = C.layer_get_background_y2,
	background_color_stop_count = C.layer_get_background_color_stop_count,
	background_image_w = C.layer_get_background_image_w,
	background_image_h = C.layer_get_background_image_h,
	background_image_stride = C.layer_get_background_image_stride,
	background_image_format = C.layer_get_background_image_format,
	background_image_pixels = C.layer_get_background_image_pixels,
	background_x = C.layer_get_background_x,
	background_y = C.layer_get_background_y,
	background_extend = C.layer_get_background_extend,
	background_rotation = C.layer_get_background_rotation,
	background_rotation_cx = C.layer_get_background_rotation_cx,
	background_rotation_cy = C.layer_get_background_rotation_cy,
	background_scale = C.layer_get_background_scale,
	background_scale_cx = C.layer_get_background_scale_cx,
	background_scale_cy = C.layer_get_background_scale_cy,
	shadow_count = C.layer_get_shadow_count,
	text = C.layer_get_text,
	text_len = C.layer_get_text_len,
	text_utf8_len = C.layer_get_text_utf8_len,
	text_maxlen = C.layer_get_text_maxlen,
	text_dir = C.layer_get_text_dir,
	text_align_x = C.layer_get_text_align_x,
	text_align_y = C.layer_get_text_align_y,
	line_spacing = C.layer_get_line_spacing,
	hardline_spacing = C.layer_get_hardline_spacing,
	paragraph_spacing = C.layer_get_paragraph_spacing,
	span_count = C.layer_get_span_count,
	text_cursor_xs = C.layer_get_text_cursor_xs,
	text_cursor_xs_len = C.layer_get_text_cursor_xs_len,
	text_selectable = C.layer_get_text_selectable,
	text_cursor_count = C.layer_get_text_cursor_count,
	text_valid = C.layer_get_text_valid,
	text_offsets_valid = C.layer_get_text_offsets_valid,
	visible = C.layer_get_visible,
	layout_type = C.layer_get_layout_type,
	align_items_x = C.layer_get_align_items_x,
	align_items_y = C.layer_get_align_items_y,
	item_align_x = C.layer_get_item_align_x,
	item_align_y = C.layer_get_item_align_y,
	align_x = C.layer_get_align_x,
	align_y = C.layer_get_align_y,
	flex_flow = C.layer_get_flex_flow,
	flex_wrap = C.layer_get_flex_wrap,
	fr = C.layer_get_fr,
	break_before = C.layer_get_break_before,
	break_after = C.layer_get_break_after,
	grid_col_fr_count = C.layer_get_grid_col_fr_count,
	grid_row_fr_count = C.layer_get_grid_row_fr_count,
	grid_col_gap = C.layer_get_grid_col_gap,
	grid_row_gap = C.layer_get_grid_row_gap,
	grid_flow = C.layer_get_grid_flow,
	grid_wrap = C.layer_get_grid_wrap,
	grid_min_lines = C.layer_get_grid_min_lines,
	min_cw = C.layer_get_min_cw,
	min_ch = C.layer_get_min_ch,
	grid_col = C.layer_get_grid_col,
	grid_row = C.layer_get_grid_row,
	grid_col_span = C.layer_get_grid_col_span,
	grid_row_span = C.layer_get_grid_row_span,
	pixels_valid = C.layer_get_pixels_valid,
	hit_test_mask = C.layer_get_hit_test_mask,
	hit_test_layer = C.layer_get_hit_test_layer,
	hit_test_area = C.layer_get_hit_test_area,
	hit_test_x = C.layer_get_hit_test_x,
	hit_test_y = C.layer_get_hit_test_y,
	hit_test_text_offset = C.layer_get_hit_test_text_offset,
	hit_test_text_cursor_which = C.layer_get_hit_test_text_cursor_which,
}
local setters = {
	parent = C.layer_set_parent,
	index = C.layer_set_index,
	pos_parent = C.layer_set_pos_parent,
	child_count = C.layer_set_child_count,
	x = C.layer_set_x,
	y = C.layer_set_y,
	w = C.layer_set_w,
	h = C.layer_set_h,
	cx = C.layer_set_cx,
	cy = C.layer_set_cy,
	cw = C.layer_set_cw,
	ch = C.layer_set_ch,
	in_transition = C.layer_set_in_transition,
	padding_bottom = C.layer_set_padding_bottom,
	padding_left = C.layer_set_padding_left,
	padding_right = C.layer_set_padding_right,
	padding_top = C.layer_set_padding_top,
	padding = C.layer_set_padding,
	operator = C.layer_set_operator,
	clip_content = C.layer_set_clip_content,
	snap_x = C.layer_set_snap_x,
	snap_y = C.layer_set_snap_y,
	opacity = C.layer_set_opacity,
	rotation = C.layer_set_rotation,
	rotation_cx = C.layer_set_rotation_cx,
	rotation_cy = C.layer_set_rotation_cy,
	scale = C.layer_set_scale,
	scale_cx = C.layer_set_scale_cx,
	scale_cy = C.layer_set_scale_cy,
	border_width_bottom = C.layer_set_border_width_bottom,
	border_width_left = C.layer_set_border_width_left,
	border_width_right = C.layer_set_border_width_right,
	border_width_top = C.layer_set_border_width_top,
	border_color_bottom = C.layer_set_border_color_bottom,
	border_color_left = C.layer_set_border_color_left,
	border_color_right = C.layer_set_border_color_right,
	border_color_top = C.layer_set_border_color_top,
	border_width = C.layer_set_border_width,
	border_color = C.layer_set_border_color,
	corner_radius_bottom_left = C.layer_set_corner_radius_bottom_left,
	corner_radius_bottom_right = C.layer_set_corner_radius_bottom_right,
	corner_radius_top_left = C.layer_set_corner_radius_top_left,
	corner_radius_top_right = C.layer_set_corner_radius_top_right,
	corner_radius = C.layer_set_corner_radius,
	border_dash_count = C.layer_set_border_dash_count,
	border_dash_offset = C.layer_set_border_dash_offset,
	border_offset = C.layer_set_border_offset,
	border_line_to = C.layer_set_border_line_to,
	background_type = C.layer_set_background_type,
	background_hittable = C.layer_set_background_hittable,
	background_operator = C.layer_set_background_operator,
	background_opacity = C.layer_set_background_opacity,
	background_clip_border_offset = C.layer_set_background_clip_border_offset,
	background_color = C.layer_set_background_color,
	background_r1 = C.layer_set_background_r1,
	background_r2 = C.layer_set_background_r2,
	background_x1 = C.layer_set_background_x1,
	background_x2 = C.layer_set_background_x2,
	background_y1 = C.layer_set_background_y1,
	background_y2 = C.layer_set_background_y2,
	background_color_stop_count = C.layer_set_background_color_stop_count,
	background_x = C.layer_set_background_x,
	background_y = C.layer_set_background_y,
	background_extend = C.layer_set_background_extend,
	background_rotation = C.layer_set_background_rotation,
	background_rotation_cx = C.layer_set_background_rotation_cx,
	background_rotation_cy = C.layer_set_background_rotation_cy,
	background_scale = C.layer_set_background_scale,
	background_scale_cx = C.layer_set_background_scale_cx,
	background_scale_cy = C.layer_set_background_scale_cy,
	shadow_count = C.layer_set_shadow_count,
	text_maxlen = C.layer_set_text_maxlen,
	text_dir = C.layer_set_text_dir,
	text_align_x = C.layer_set_text_align_x,
	text_align_y = C.layer_set_text_align_y,
	line_spacing = C.layer_set_line_spacing,
	hardline_spacing = C.layer_set_hardline_spacing,
	paragraph_spacing = C.layer_set_paragraph_spacing,
	span_count = C.layer_set_span_count,
	text_selectable = C.layer_set_text_selectable,
	text_cursor_count = C.layer_set_text_cursor_count,
	visible = C.layer_set_visible,
	layout_type = C.layer_set_layout_type,
	align_items_x = C.layer_set_align_items_x,
	align_items_y = C.layer_set_align_items_y,
	item_align_x = C.layer_set_item_align_x,
	item_align_y = C.layer_set_item_align_y,
	align_x = C.layer_set_align_x,
	align_y = C.layer_set_align_y,
	flex_flow = C.layer_set_flex_flow,
	flex_wrap = C.layer_set_flex_wrap,
	fr = C.layer_set_fr,
	break_before = C.layer_set_break_before,
	break_after = C.layer_set_break_after,
	grid_col_fr_count = C.layer_set_grid_col_fr_count,
	grid_row_fr_count = C.layer_set_grid_row_fr_count,
	grid_col_gap = C.layer_set_grid_col_gap,
	grid_row_gap = C.layer_set_grid_row_gap,
	grid_flow = C.layer_set_grid_flow,
	grid_wrap = C.layer_set_grid_wrap,
	grid_min_lines = C.layer_set_grid_min_lines,
	min_cw = C.layer_set_min_cw,
	min_ch = C.layer_set_min_ch,
	grid_col = C.layer_set_grid_col,
	grid_row = C.layer_set_grid_row,
	grid_col_span = C.layer_set_grid_col_span,
	grid_row_span = C.layer_set_grid_row_span,
	hit_test_mask = C.layer_set_hit_test_mask,
}
local methods = {
	init = C.layer_init,
	free = C.layer_free,
	release = C.layer_release,
	child = C.layer_child,
	layer = C.layer_layer,
	from_window = C.layer_from_window,
	get_border_dash = C.layer_get_border_dash,
	set_border_dash = C.layer_set_border_dash,
	get_background_color_stop_color = C.layer_get_background_color_stop_color,
	get_background_color_stop_offset = C.layer_get_background_color_stop_offset,
	set_background_color_stop_color = C.layer_set_background_color_stop_color,
	set_background_color_stop_offset = C.layer_set_background_color_stop_offset,
	set_background_image = C.layer_set_background_image,
	background_image_invalidate = C.layer_background_image_invalidate,
	background_image_invalidate_rect = C.layer_background_image_invalidate_rect,
	get_shadow_x = C.layer_get_shadow_x,
	get_shadow_y = C.layer_get_shadow_y,
	get_shadow_color = C.layer_get_shadow_color,
	get_shadow_blur = C.layer_get_shadow_blur,
	get_shadow_passes = C.layer_get_shadow_passes,
	get_shadow_inset = C.layer_get_shadow_inset,
	get_shadow_content = C.layer_get_shadow_content,
	set_shadow_x = C.layer_set_shadow_x,
	set_shadow_y = C.layer_set_shadow_y,
	set_shadow_color = C.layer_set_shadow_color,
	set_shadow_blur = C.layer_set_shadow_blur,
	set_shadow_passes = C.layer_set_shadow_passes,
	set_shadow_inset = C.layer_set_shadow_inset,
	set_shadow_content = C.layer_set_shadow_content,
	set_text = C.layer_set_text,
	set_text_utf8 = C.layer_set_text_utf8,
	get_text_utf8 = C.layer_get_text_utf8,
	get_span_features = C.layer_get_span_features,
	get_span_font_id = C.layer_get_span_font_id,
	get_span_font_size = C.layer_get_span_font_size,
	get_span_lang = C.layer_get_span_lang,
	get_span_nowrap = C.layer_get_span_nowrap,
	get_span_paragraph_dir = C.layer_get_span_paragraph_dir,
	get_span_script = C.layer_get_span_script,
	get_span_text_color = C.layer_get_span_text_color,
	get_span_text_opacity = C.layer_get_span_text_opacity,
	get_span_text_operator = C.layer_get_span_text_operator,
	set_span_features = C.layer_set_span_features,
	set_span_font_id = C.layer_set_span_font_id,
	set_span_font_size = C.layer_set_span_font_size,
	set_span_lang = C.layer_set_span_lang,
	set_span_nowrap = C.layer_set_span_nowrap,
	set_span_paragraph_dir = C.layer_set_span_paragraph_dir,
	set_span_script = C.layer_set_span_script,
	set_span_text_color = C.layer_set_span_text_color,
	set_span_text_opacity = C.layer_set_span_text_opacity,
	set_span_text_operator = C.layer_set_span_text_operator,
	get_span_offset = C.layer_get_span_offset,
	set_span_offset = C.layer_set_span_offset,
	load_text_cursor_xs = C.layer_load_text_cursor_xs,
	get_text_cursor_offset = C.layer_get_text_cursor_offset,
	get_text_cursor_which = C.layer_get_text_cursor_which,
	get_text_cursor_sel_offset = C.layer_get_text_cursor_sel_offset,
	get_text_cursor_sel_which = C.layer_get_text_cursor_sel_which,
	get_text_cursor_x = C.layer_get_text_cursor_x,
	set_text_cursor_offset = C.layer_set_text_cursor_offset,
	set_text_cursor_which = C.layer_set_text_cursor_which,
	set_text_cursor_sel_offset = C.layer_set_text_cursor_sel_offset,
	set_text_cursor_sel_which = C.layer_set_text_cursor_sel_which,
	set_text_cursor_x = C.layer_set_text_cursor_x,
	text_selection_has_color = C.layer_text_selection_has_color,
	text_selection_has_features = C.layer_text_selection_has_features,
	text_selection_has_font_id = C.layer_text_selection_has_font_id,
	text_selection_has_font_size = C.layer_text_selection_has_font_size,
	text_selection_has_lang = C.layer_text_selection_has_lang,
	text_selection_has_nowrap = C.layer_text_selection_has_nowrap,
	text_selection_has_opacity = C.layer_text_selection_has_opacity,
	text_selection_has_operator = C.layer_text_selection_has_operator,
	text_selection_has_paragraph_dir = C.layer_text_selection_has_paragraph_dir,
	text_selection_has_script = C.layer_text_selection_has_script,
	get_text_selection_color = C.layer_get_text_selection_color,
	get_text_selection_features = C.layer_get_text_selection_features,
	get_text_selection_font_id = C.layer_get_text_selection_font_id,
	get_text_selection_font_size = C.layer_get_text_selection_font_size,
	get_text_selection_lang = C.layer_get_text_selection_lang,
	get_text_selection_nowrap = C.layer_get_text_selection_nowrap,
	get_text_selection_opacity = C.layer_get_text_selection_opacity,
	get_text_selection_operator = C.layer_get_text_selection_operator,
	get_text_selection_paragraph_dir = C.layer_get_text_selection_paragraph_dir,
	get_text_selection_script = C.layer_get_text_selection_script,
	set_text_selection_color = C.layer_set_text_selection_color,
	set_text_selection_features = C.layer_set_text_selection_features,
	set_text_selection_font_id = C.layer_set_text_selection_font_id,
	set_text_selection_font_size = C.layer_set_text_selection_font_size,
	set_text_selection_lang = C.layer_set_text_selection_lang,
	set_text_selection_nowrap = C.layer_set_text_selection_nowrap,
	set_text_selection_opacity = C.layer_set_text_selection_opacity,
	set_text_selection_operator = C.layer_set_text_selection_operator,
	set_text_selection_paragraph_dir = C.layer_set_text_selection_paragraph_dir,
	set_text_selection_script = C.layer_set_text_selection_script,
	text_cursor_move_to = C.layer_text_cursor_move_to,
	text_cursor_move_to_point = C.layer_text_cursor_move_to_point,
	text_cursor_move_near = C.layer_text_cursor_move_near,
	text_cursor_move_near_line = C.layer_text_cursor_move_near_line,
	text_cursor_move_near_page = C.layer_text_cursor_move_near_page,
	get_grid_col_fr = C.layer_get_grid_col_fr,
	get_grid_row_fr = C.layer_get_grid_row_fr,
	set_grid_col_fr = C.layer_set_grid_col_fr,
	set_grid_row_fr = C.layer_set_grid_row_fr,
	sync = C.layer_sync,
	draw = C.layer_draw,
	hit_test = C.layer_hit_test,
}
ffi.metatype('layer_t', {
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
	ALIGN_BASELINE = 11,
	ALIGN_BOTTOM = 2,
	ALIGN_CENTER = 3,
	ALIGN_DEFAULT = 0,
	ALIGN_END = 6,
	ALIGN_JUSTIFY = 4,
	ALIGN_LEFT = 1,
	ALIGN_RIGHT = 2,
	ALIGN_SPACE_AROUND = 9,
	ALIGN_SPACE_BETWEEN = 10,
	ALIGN_SPACE_EVENLY = 8,
	ALIGN_START = 5,
	ALIGN_STRETCH = 7,
	ALIGN_TOP = 1,
	AXIS_ORDER_XY = 1,
	AXIS_ORDER_YX = 2,
	BACKGROUND_EXTEND_MAX = 3,
	BACKGROUND_EXTEND_MIN = 0,
	BACKGROUND_EXTEND_NONE = 0,
	BACKGROUND_EXTEND_PAD = 3,
	BACKGROUND_EXTEND_REFLECT = 2,
	BACKGROUND_EXTEND_REPEAT = 1,
	BACKGROUND_TYPE_COLOR = 1,
	BACKGROUND_TYPE_IMAGE = 4,
	BACKGROUND_TYPE_LINEAR_GRADIENT = 2,
	BACKGROUND_TYPE_MAX = 4,
	BACKGROUND_TYPE_MIN = 0,
	BACKGROUND_TYPE_NONE = 0,
	BACKGROUND_TYPE_RADIAL_GRADIENT = 3,
	BITMAP_FORMAT_ARGB32 = 2,
	BITMAP_FORMAT_G8 = 1,
	BITMAP_FORMAT_INVALID = 0,
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
	FLEX_FLOW_MAX = 1,
	FLEX_FLOW_MIN = 0,
	FLEX_FLOW_X = 0,
	FLEX_FLOW_Y = 1,
	GRID_FLOW_B = 4,
	GRID_FLOW_L = 0,
	GRID_FLOW_MAX = 7,
	GRID_FLOW_R = 2,
	GRID_FLOW_T = 0,
	GRID_FLOW_X = 0,
	GRID_FLOW_Y = 1,
	HIT_BACKGROUND = 2,
	HIT_BORDER = 1,
	HIT_NONE = 0,
	HIT_TEXT = 3,
	HIT_TEXT_SELECTION = 4,
	LAYOUT_FLEXBOX = 2,
	LAYOUT_GRID = 3,
	LAYOUT_NULL = 0,
	LAYOUT_TEXTBOX = 1,
	OPERATOR_ADD = 12,
	OPERATOR_ATOP = 5,
	OPERATOR_CLEAR = 0,
	OPERATOR_COLOR_BURN = 20,
	OPERATOR_COLOR_DODGE = 19,
	OPERATOR_DARKEN = 17,
	OPERATOR_DEST = 6,
	OPERATOR_DEST_ATOP = 10,
	OPERATOR_DEST_IN = 8,
	OPERATOR_DEST_OUT = 9,
	OPERATOR_DEST_OVER = 7,
	OPERATOR_DIFFERENCE = 23,
	OPERATOR_EXCLUSION = 24,
	OPERATOR_HARD_LIGHT = 21,
	OPERATOR_HSL_COLOR = 27,
	OPERATOR_HSL_HUE = 25,
	OPERATOR_HSL_LUMINOSITY = 28,
	OPERATOR_HSL_SATURATION = 26,
	OPERATOR_IN = 3,
	OPERATOR_LIGHTEN = 18,
	OPERATOR_MAX = 28,
	OPERATOR_MIN = 0,
	OPERATOR_MULTIPLY = 14,
	OPERATOR_OUT = 4,
	OPERATOR_OVER = 2,
	OPERATOR_OVERLAY = 16,
	OPERATOR_SATURATE = 13,
	OPERATOR_SCREEN = 15,
	OPERATOR_SOFT_LIGHT = 22,
	OPERATOR_SOURCE = 1,
	OPERATOR_XOR = 11,
}]]
return C
