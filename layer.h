/* This file was auto-generated. Modify at your own risk. */

uint64_t memtotal(void);
void memreport(void);
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
};
typedef struct layerlib_t layerlib_t;
typedef void (*tr_font_load_func_t) (int32_t, void**, uint64_t*, bool*);
typedef void (*tr_font_unload_func_t) (int32_t, void*, uint64_t, bool);
layerlib_t* layerlib(tr_font_load_func_t, tr_font_unload_func_t);
typedef struct layerlib_t layerlib_t;
double layerlib_get_font_size_resolution(layerlib_t*);
double layerlib_get_mmapped_font_cache_max_count(layerlib_t*);
void layerlib_free(layerlib_t*);
void layerlib_set_mmapped_font_cache_max_count(layerlib_t*, double);
void layerlib_set_subpixel_x_resolution(layerlib_t*, double);
double layerlib_get_mem_font_cache_count(layerlib_t*);
double layerlib_get_glyph_cache_size(layerlib_t*);
double layerlib_get_word_subpixel_x_resolution(layerlib_t*);
void layerlib_set_font_size_resolution(layerlib_t*, double);
void layerlib_init(layerlib_t*, tr_font_load_func_t, tr_font_unload_func_t);
typedef struct layer_t layer_t;
layer_t* layerlib_layer(layerlib_t*);
int32_t layerlib_font_face_num(layerlib_t*, int32_t);
double layerlib_get_mmapped_font_cache_count(layerlib_t*);
double layerlib_get_mem_font_cache_size(layerlib_t*);
void layerlib_set_mem_font_cache_max_size(layerlib_t*, double);
void layerlib_set_glyph_cache_max_size(layerlib_t*, double);
double layerlib_get_glyph_cache_count(layerlib_t*);
typedef void (*string_to_void) (const char *);
void layerlib_set_error_function(layerlib_t*, string_to_void);
double layerlib_get_mem_font_cache_max_size(layerlib_t*);
void layerlib_set_word_subpixel_x_resolution(layerlib_t*, double);
double layerlib_get_glyph_run_cache_count(layerlib_t*);
double layerlib_get_glyph_run_cache_size(layerlib_t*);
double layerlib_get_subpixel_x_resolution(layerlib_t*);
double layerlib_get_glyph_run_cache_max_size(layerlib_t*);
void layerlib_set_glyph_run_cache_max_size(layerlib_t*, double);
void layerlib_release(layerlib_t*);
string_to_void layerlib_get_error_function(layerlib_t*);
double layerlib_get_glyph_cache_max_size(layerlib_t*);
typedef struct layer_t layer_t;
int32_t layer_get_span_count(layer_t*);
double layer_get_padding_left(layer_t*);
int8_t layer_get_background_image_format(layer_t*);
uint32_t layer_get_border_color_left(layer_t*);
int32_t layer_get_selected_text_utf8_len(layer_t*, int32_t);
int32_t layer_get_text_selection_font_id(layer_t*, int32_t);
layer_t* layer_get_parent(layer_t*);
void layer_set_break_after(layer_t*, bool);
void layer_set_padding_left(layer_t*, double);
double layer_get_line_spacing(layer_t*);
double layer_get_background_rotation(layer_t*);
void layer_set_background_scale_cy(layer_t*, double);
uint32_t layer_get_border_color_right(layer_t*);
void layer_set_background_rotation(layer_t*, double);
void layer_text_cursor_move_near(layer_t*, int32_t, int8_t, int8_t, int8_t, bool);
void layer_set_parent(layer_t*, layer_t*);
bool layer_text_selection_has_color(layer_t*, int32_t);
void layer_set_grid_row_gap(layer_t*, double);
void layer_set_background_extend(layer_t*, int8_t);
void layer_set_corner_radius_bottom_right(layer_t*, double);
void layer_set_scale(layer_t*, double);
void layer_remove_selected_text(layer_t*, int32_t);
int32_t layer_get_span_font_id(layer_t*, int32_t);
double layer_get_scale(layer_t*);
void layer_set_border_offset(layer_t*, double);
void layer_set_text_selection_operator(layer_t*, int32_t, int8_t);
void layer_set_border_width_right(layer_t*, double);
double layer_get_background_x1(layer_t*);
void layer_set_min_cw(layer_t*, double);
double layer_get_background_y(layer_t*);
double layer_get_rotation(layer_t*);
bool layer_get_in_transition(layer_t*);
int8_t layer_get_align_y(layer_t*);
void layer_set_shadow_x(layer_t*, int32_t, double);
void layer_set_background_x1(layer_t*, double);
int8_t layer_get_text_selection_operator(layer_t*, int32_t);
uint32_t layer_get_background_color(layer_t*);
double layer_get_background_y1(layer_t*);
void layer_text_cursor_move_near_line(layer_t*, int32_t, double, double, bool);
double layer_get_cx(layer_t*);
double layer_get_background_image_w(layer_t*);
void layer_set_background_r2(layer_t*, double);
void layer_set_background_y1(layer_t*, double);
bool layer_get_snap_y(layer_t*);
void layer_set_shadow_inset(layer_t*, int32_t, bool);
void layer_set_corner_radius_bottom_left(layer_t*, double);
double layer_get_padding_bottom(layer_t*);
double layer_get_background_opacity(layer_t*);
double layer_get_scale_cx(layer_t*);
void layer_set_background_rotation_cx(layer_t*, double);
int32_t layer_get_text_cursor_sel_offset(layer_t*, int32_t);
void layer_set_padding_bottom(layer_t*, double);
void layer_set_grid_row_fr(layer_t*, int32_t, double);
void layer_set_snap_y(layer_t*, bool);
double layer_get_rotation_cx(layer_t*);
layerlib_t* layer_get_lib(layer_t*);
void layer_set_text(layer_t*, uint32_t*, int32_t);
bool layer_get_background_hittable(layer_t*);
double layer_get_background_clip_border_offset(layer_t*);
bool layer_get_span_nowrap(layer_t*, int32_t);
uint32_t layer_get_span_text_color(layer_t*, int32_t);
uint32_t layer_get_text_selection_color(layer_t*, int32_t);
void layer_set_rotation_cx(layer_t*, double);
void layer_set_span_text_color(layer_t*, int32_t, uint32_t);
double layer_get_shadow_x(layer_t*, int32_t);
double layer_get_w(layer_t*);
double layer_get_corner_radius_bottom_left(layer_t*);
void layer_set_background_clip_border_offset(layer_t*, double);
double layer_get_corner_radius_top_left(layer_t*);
void layer_set_border_width(layer_t*, double);
uint32_t layer_get_border_color_top(layer_t*);
double layer_get_span_font_size(layer_t*, int32_t);
double layer_get_grid_row_fr(layer_t*, int32_t);
void layer_set_break_before(layer_t*, bool);
void layer_set_border_color_top(layer_t*, uint32_t);
int32_t layer_get_span_font_face_index(layer_t*, int32_t);
void layer_set_x(layer_t*, double);
double layer_get_y(layer_t*);
int8_t layer_get_flex_flow(layer_t*);
int8_t layer_get_span_text_operator(layer_t*, int32_t);
void layer_set_child_count(layer_t*, int32_t);
const char * layer_get_span_features(layer_t*, int32_t);
layer_t* layer_child(layer_t*, int32_t);
double layer_get_grid_col_fr(layer_t*, int32_t);
void layer_set_background_opacity(layer_t*, double);
int8_t layer_get_item_align_x(layer_t*);
typedef struct _cairo _cairo;
void layer_draw(layer_t*, _cairo*);
void layer_set_text_align_x(layer_t*, int8_t);
void layer_set_shadow_blur(layer_t*, int32_t, int32_t);
double layer_get_background_image_h(layer_t*);
double layer_get_text_selection_opacity(layer_t*, int32_t);
void layer_set_text_cursor_which(layer_t*, int32_t, int32_t);
void layer_set_padding_top(layer_t*, double);
void layer_set_text_selection_opacity(layer_t*, int32_t, double);
void layer_release(layer_t*);
void layer_set_span_text_operator(layer_t*, int32_t, int8_t);
bool layer_text_selection_has_font_id(layer_t*, int32_t);
double layer_get_hit_test_y(layer_t*);
bool layer_get_text_valid(layer_t*);
int32_t layer_get_span_paragraph_dir(layer_t*, int32_t);
int32_t layer_get_border_dash_count(layer_t*);
void layer_set_border_width_bottom(layer_t*, double);
int32_t layer_get_text_selection_paragraph_dir(layer_t*, int32_t);
void layer_set_span_font_face_index(layer_t*, int32_t, int32_t);
int8_t layer_get_align_x(layer_t*);
void layer_set_span_paragraph_dir(layer_t*, int32_t, int32_t);
bool layer_get_shadow_content(layer_t*, int32_t);
void layer_insert_text_utf8_at_cursor(layer_t*, int32_t, const char *, int32_t);
bool layer_get_text_selectable(layer_t*);
void layer_set_grid_row_fr_count(layer_t*, int32_t);
bool layer_text_selection_has_font_size(layer_t*, int32_t);
uint32_t* layer_get_selected_text(layer_t*, int32_t);
const char * layer_get_span_lang(layer_t*, int32_t);
void layer_set_span_lang(layer_t*, int32_t, const char *);
void layer_set_grid_wrap(layer_t*, double);
double layer_get_background_scale_cx(layer_t*);
void layer_set_background_image(layer_t*, int32_t, int32_t, int8_t, int32_t, uint8_t*);
int8_t layer_get_background_operator(layer_t*);
void layer_set_background_scale_cx(layer_t*, double);
void layer_set_cy(layer_t*, double);
void layer_set_text_selection_features(layer_t*, int32_t, const char *);
double layer_get_opacity(layer_t*);
void layer_set_text_maxlen(layer_t*, int32_t);
void layer_set_h(layer_t*, double);
void layer_set_grid_col_fr(layer_t*, int32_t, double);
void layer_set_grid_flow(layer_t*, int8_t);
void layer_set_text_selectable(layer_t*, bool);
double layer_get_span_text_opacity(layer_t*, int32_t);
double layer_get_cw(layer_t*);
double layer_get_border_offset(layer_t*);
double layer_get_corner_radius(layer_t*);
void layer_set_shadow_passes(layer_t*, int32_t, int32_t);
void layer_set_span_text_opacity(layer_t*, int32_t, double);
double layer_get_padding(layer_t*);
void layer_set_rotation(layer_t*, double);
void layer_set_corner_radius_top_right(layer_t*, double);
double layer_get_text_cursor_x(layer_t*, int32_t);
void layer_set_shadow_content(layer_t*, int32_t, bool);
void layer_set_layout_type(layer_t*, int8_t);
void layer_set_text_utf8(layer_t*, const char *, int32_t);
int32_t layer_get_index(layer_t*);
int32_t layer_get_grid_col_span(layer_t*);
void layer_set_border_width_left(layer_t*, double);
int32_t layer_get_grid_row(layer_t*);
int8_t layer_get_hit_test_text_cursor_which(layer_t*);
double layer_get_hardline_spacing(layer_t*);
int32_t layer_get_hit_test_text_offset(layer_t*);
double layer_get_background_x2(layer_t*);
double layer_get_hit_test_x(layer_t*);
int8_t layer_get_hit_test_area(layer_t*);
void layer_set_text_cursor_sel_offset(layer_t*, int32_t, double);
double layer_get_x(layer_t*);
layer_t* layer_get_hit_test_layer(layer_t*);
bool layer_hit_test(layer_t*, _cairo*, double, double, int32_t);
void layer_set_align_x(layer_t*, int8_t);
int8_t layer_get_background_extend(layer_t*);
bool layer_text_selection_has_lang(layer_t*, int32_t);
bool layer_get_pixels_valid(layer_t*);
void layer_set_grid_row_span(layer_t*, double);
void layer_set_background_x2(layer_t*, double);
void layer_set_grid_col_span(layer_t*, double);
void layer_sync(layer_t*);
void layer_text_cursor_move_near_page(layer_t*, int32_t, double, double, bool);
int32_t layer_get_grid_row_span(layer_t*);
void layer_set_background_operator(layer_t*, int8_t);
void layer_set_border_dash(layer_t*, int32_t, double);
void layer_set_grid_row(layer_t*, double);
int32_t layer_get_selected_text_utf8(layer_t*, int32_t, const char *, int32_t);
int8_t layer_get_background_type(layer_t*);
void layer_set_background_rotation_cy(layer_t*, double);
void layer_set_text_selection_paragraph_dir(layer_t*, int32_t, int32_t);
void layer_set_min_ch(layer_t*, double);
void layer_set_background_hittable(layer_t*, bool);
int32_t layer_get_background_color_stop_count(layer_t*);
double layer_get_min_cw(layer_t*);
void layer_set_cw(layer_t*, double);
void layer_set_background_y2(layer_t*, double);
void layer_set_opacity(layer_t*, double);
int32_t layer_get_grid_min_lines(layer_t*);
void layer_load_text_cursor_xs(layer_t*, int32_t);
void layer_set_background_type(layer_t*, int8_t);
int32_t layer_get_grid_wrap(layer_t*);
void layer_set_shadow_y(layer_t*, int32_t, double);
void layer_init(layer_t*, layerlib_t*, layer_t*);
int8_t layer_get_grid_flow(layer_t*);
int8_t layer_get_align_items_y(layer_t*);
layer_t* layer_layer(layer_t*);
double layer_get_grid_row_gap(layer_t*);
double layer_get_grid_col_gap(layer_t*);
double layer_get_border_width_bottom(layer_t*);
void layer_set_border_color_right(layer_t*, uint32_t);
void layer_set_flex_flow(layer_t*, int8_t);
typedef struct {
	double _0;
	double _1;
} double2;
double2 layer_from_window(layer_t*, double, double);
void layer_set_paragraph_spacing(layer_t*, double);
double layer_get_scale_cy(layer_t*);
double layer_get_grid_col_fr_count(layer_t*);
bool layer_get_break_after(layer_t*);
void layer_set_text_cursor_sel_which(layer_t*, int32_t, int32_t);
bool layer_get_break_before(layer_t*);
void layer_set_fr(layer_t*, double);
double layer_get_fr(layer_t*);
void layer_set_flex_wrap(layer_t*, bool);
layer_t* layer_get_top_layer(layer_t*);
bool layer_get_flex_wrap(layer_t*);
double layer_get_grid_row_fr_count(layer_t*);
void layer_set_background_r1(layer_t*, double);
void layer_set_padding(layer_t*, double);
void layer_set_align_y(layer_t*, int8_t);
void layer_set_hit_test_mask(layer_t*, int8_t);
bool layer_get_clip_content(layer_t*);
void layer_set_item_align_y(layer_t*, int8_t);
void layer_set_item_align_x(layer_t*, int8_t);
void layer_set_align_items_y(layer_t*, int8_t);
int32_t layer_get_shadow_count(layer_t*);
void layer_set_scale_cy(layer_t*, double);
layer_t* layer_get_pos_parent(layer_t*);
void layer_set_text_cursor_x(layer_t*, int32_t, double);
double layer_get_background_r1(layer_t*);
double layer_get_border_width_right(layer_t*);
void layer_set_grid_col_gap(layer_t*, double);
int8_t layer_get_align_items_x(layer_t*);
void layer_set_clip_content(layer_t*, bool);
void layer_set_snap_x(layer_t*, bool);
int32_t layer_get_text_cursor_which(layer_t*, int32_t);
int8_t layer_get_layout_type(layer_t*);
void layer_set_shadow_count(layer_t*, int32_t);
void layer_set_text_selection_nowrap(layer_t*, int32_t, bool);
void layer_set_visible(layer_t*, bool);
int8_t layer_get_hit_test_mask(layer_t*);
double layer_get_corner_radius_top_right(layer_t*);
void layer_set_grid_col(layer_t*, double);
int32_t layer_get_selected_text_len(layer_t*, int32_t);
void layer_insert_text_at_cursor(layer_t*, int32_t, uint32_t*, int32_t);
void layer_set_y(layer_t*, double);
void layer_text_cursor_move_to_point(layer_t*, int32_t, double, double, bool);
void layer_text_cursor_move_to(layer_t*, int32_t, double, int8_t, bool);
bool layer_text_selection_has_operator(layer_t*, int32_t);
double layer_get_background_y2(layer_t*);
void layer_set_text_selection_color(layer_t*, int32_t, uint32_t);
int32_t layer_get_shadow_blur(layer_t*, int32_t);
double layer_get_shadow_y(layer_t*, int32_t);
double layer_get_rotation_cy(layer_t*);
double layer_get_final_y(layer_t*);
const char * layer_get_text_selection_lang(layer_t*, int32_t);
int32_t layer_get_border_dash(layer_t*, int32_t);
double layer_get_background_rotation_cy(layer_t*);
double layer_get_background_scale(layer_t*);
double layer_get_h(layer_t*);
int32_t layer_get_shadow_passes(layer_t*, int32_t);
int32_t layer_get_grid_col(layer_t*);
bool layer_text_selection_has_paragraph_dir(layer_t*, int32_t);
void layer_set_text_selection_lang(layer_t*, int32_t, const char *);
double layer_get_paragraph_spacing(layer_t*);
double layer_get_final_w(layer_t*);
void layer_set_text_selection_script(layer_t*, int32_t, const char *);
bool layer_get_text_offsets_valid(layer_t*);
double layer_get_text_selection_font_size(layer_t*, int32_t);
void layer_set_text_align_y(layer_t*, int8_t);
void layer_set_span_nowrap(layer_t*, int32_t, bool);
const char * layer_get_text_selection_features(layer_t*, int32_t);
typedef void (*player_t_p_cairo_double3_to_void) (layer_t*, _cairo*, double, double, double);
void layer_set_border_line_to(layer_t*, player_t_p_cairo_double3_to_void);
void layer_set_index(layer_t*, double);
void layer_set_text_selection_font_size(layer_t*, int32_t, double);
int32_t layer_get_text_selection_font_face_index(layer_t*, int32_t);
void layer_set_text_selection_font_face_index(layer_t*, int32_t, int32_t);
int8_t layer_get_item_align_y(layer_t*);
void layer_set_border_dash_offset(layer_t*, double);
void layer_set_background_color(layer_t*, uint32_t);
double layer_get_cy(layer_t*);
uint32_t layer_get_background_color_stop_color(layer_t*, int32_t);
int32_t layer_get_text_cursor_offset(layer_t*, int32_t);
double layer_get_padding_top(layer_t*);
const char * layer_get_span_script(layer_t*, int32_t);
void layer_set_background_scale(layer_t*, double);
void layer_set_border_color(layer_t*, double);
void layer_set_corner_radius(layer_t*, double);
void layer_set_padding_right(layer_t*, double);
int32_t layer_get_child_count(layer_t*);
void layer_set_border_color_left(layer_t*, uint32_t);
bool layer_text_selection_has_features(layer_t*, int32_t);
void layer_set_border_color_bottom(layer_t*, uint32_t);
int32_t layer_get_text_cursor_sel_which(layer_t*, int32_t);
int32_t layer_get_text_utf8_len(layer_t*);
double layer_get_border_width_top(layer_t*);
double layer_get_min_ch(layer_t*);
void layer_set_background_color_stop_offset(layer_t*, int32_t, double);
void layer_set_border_width_top(layer_t*, double);
int32_t layer_get_span_offset(layer_t*, int32_t);
void layer_set_background_color_stop_color(layer_t*, int32_t, uint32_t);
int8_t layer_get_text_align_y(layer_t*);
double layer_get_border_width_left(layer_t*);
double layer_get_padding_right(layer_t*);
void layer_set_text_dir(layer_t*, int8_t);
void layer_set_shadow_color(layer_t*, int32_t, uint32_t);
double layer_get_final_x(layer_t*);
void layer_set_scale_cx(layer_t*, double);
int32_t layer_get_text_len(layer_t*);
void layer_set_ch(layer_t*, double);
void layer_free(layer_t*);
bool layer_get_shadow_inset(layer_t*, int32_t);
int32_t layer_set_text_cursor_count(layer_t*, int32_t);
void layer_set_pos_parent(layer_t*, layer_t*);
uint32_t layer_get_border_color_bottom(layer_t*);
void layer_set_background_x(layer_t*, double);
double layer_get_background_x(layer_t*);
void layer_set_text_selection_font_id(layer_t*, int32_t, int32_t);
uint32_t layer_get_border_color(layer_t*);
int8_t layer_get_operator(layer_t*);
const char * layer_get_text_selection_script(layer_t*, int32_t);
double layer_get_background_color_stop_offset(layer_t*, int32_t);
bool layer_text_selection_has_opacity(layer_t*, int32_t);
int32_t layer_get_text_cursor_xs_len(layer_t*);
void layer_set_align_items_x(layer_t*, int8_t);
uint8_t* layer_get_background_image_pixels(layer_t*);
void layer_set_operator(layer_t*, int8_t);
void layer_set_border_dash_count(layer_t*, int32_t);
int32_t layer_get_background_image_stride(layer_t*);
double layer_get_border_width(layer_t*);
void layer_set_background_color_stop_count(layer_t*, int32_t);
bool layer_get_snap_x(layer_t*);
int32_t layer_get_text_cursor_count(layer_t*);
double* layer_get_text_cursor_xs(layer_t*);
void layer_set_background_y(layer_t*, double);
double layer_get_background_rotation_cx(layer_t*);
void layer_set_grid_min_lines(layer_t*, double);
void layer_background_image_invalidate(layer_t*);
uint32_t layer_get_shadow_color(layer_t*, int32_t);
void layer_background_image_invalidate_rect(layer_t*, int32_t, int32_t, int32_t, int32_t);
double layer_get_background_r2(layer_t*);
bool layer_get_visible(layer_t*);
double layer_get_border_dash_offset(layer_t*);
int32_t layer_get_text_utf8(layer_t*, const char *, int32_t);
int32_t layer_get_text_maxlen(layer_t*);
void layer_set_rotation_cy(layer_t*, double);
int8_t layer_get_text_dir(layer_t*);
bool layer_text_selection_has_font_face_index(layer_t*, int32_t);
void layer_set_text_cursor_offset(layer_t*, int32_t, double);
int8_t layer_get_text_align_x(layer_t*);
void layer_set_w(layer_t*, double);
void layer_set_span_features(layer_t*, int32_t, const char *);
bool layer_get_text_selection_nowrap(layer_t*, int32_t);
double layer_get_ch(layer_t*);
void layer_set_cx(layer_t*, double);
uint32_t* layer_get_text(layer_t*);
void layer_set_line_spacing(layer_t*, double);
void layer_set_hardline_spacing(layer_t*, double);
void layer_set_span_count(layer_t*, int32_t);
double layer_get_corner_radius_bottom_right(layer_t*);
void layer_set_in_transition(layer_t*, bool);
void layer_set_span_font_size(layer_t*, int32_t, double);
void layer_set_grid_col_fr_count(layer_t*, int32_t);
double layer_get_background_scale_cy(layer_t*);
void layer_set_span_script(layer_t*, int32_t, const char *);
void layer_set_corner_radius_top_left(layer_t*, double);
void layer_set_span_font_id(layer_t*, int32_t, int32_t);
void layer_set_span_offset(layer_t*, int32_t, int32_t);
bool layer_text_selection_has_script(layer_t*, int32_t);
bool layer_text_selection_has_nowrap(layer_t*, int32_t);
double layer_get_final_h(layer_t*);
