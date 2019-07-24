
local layer = require'layer'
local cairo = require'cairo'
memtotal = layer.memtotal

local fonts = {
	assert(glue.readfile'media/fonts/OpenSans-Regular.ttf');
	assert(glue.readfile'media/fonts/Amiri-Regular.ttf');
	assert(glue.readfile'media/fonts/ionicons.ttf');
}

local function load_font(font_id, file_data_buf, file_size_buf)
	local s = assert(fonts[font_id+1])
	file_data_buf[0] = ffi.cast('void*', s)
	file_size_buf[0] = #s
end

local function unload_font(font_id, file_data_buf, file_size_buf)
	--nothing
end

local function newlib()
	lib = layer.layerlib(load_font, unload_font)
	opensans = lib:font()
	amiri    = lib:font()
	ionicons = lib:font()
end
newlib()


function test_free_children()
	local e1 = lib:layer()
	e1:layer():layer():layer()
	e1:layer():layer():layer()
	e1:free()
	lib:free()
	assert(memtotal() == 0)
	newlib()
end

test_free_children()

function test_()

end

--layer.memreport()



--[==[

release:free()

release='free',

--position in hierarchy

get_parent=1,
set_parent=1,

get_index=1,
set_index=1,

get_child_count=1,
set_child_count=1,
child=1,
move=1,

--size and position

get_x=1,
get_y=1,
get_w=1,
get_h=1,

set_x=1,
set_y=1,
set_w=1,
set_h=1,

get_cw=1,
get_ch=1,

set_cw=1,
set_ch=1,

get_cx=1,
get_cy=1,

set_cx=1,
set_cy=1,

get_min_cw=1,
get_min_ch=1,
set_min_cw=1,
set_min_ch=1,

get_align_x=1,
get_align_y=1,

set_align_x=1,
set_align_y=1,

get_padding_left=1,
get_padding_top=1,
get_padding_right=1,
get_padding_bottom=1,

set_padding_left=1,
set_padding_top=1,
set_padding_right=1,
set_padding_bottom=1,
set_padding=1,

--transforms

get_rotation=1,
get_rotation_cx=1,
get_rotation_cy=1,
get_scale=1,
get_scale_cx=1,
get_scale_cy=1,

set_rotation=1,
set_rotation_cx=1,
set_rotation_cy=1,
set_scale=1,
set_scale_cx=1,
set_scale_cy=1,

--point conversions

from_box_to_parent=1,
from_parent_to_box=1,
to_parent=1,  from_parent=1,
to_window=1,  from_window=1,
to_content=1, from_content=1,

--drawing

get_visible=1,
set_visible=1,

get_operator=1,
set_operator=1,

get_clip_content=1,
set_clip_content=1,

get_snap_x=1,
get_snap_y=1,

set_snap_x=1,
set_snap_y=1,

get_opacity=1,
set_opacity=1,

get_hit_test_mask=1,
set_hit_test_mask=1,

--borders

get_border_width_left   =1,
get_border_width_right  =1,
get_border_width_top    =1,
get_border_width_bottom =1,

set_border_width_left   =1,
set_border_width_right  =1,
set_border_width_top    =1,
set_border_width_bottom =1,
set_border_width        =1,

get_corner_radius_top_left     =1,
get_corner_radius_top_right    =1,
get_corner_radius_bottom_left  =1,
get_corner_radius_bottom_right =1,
get_corner_radius_kappa        =1,

set_corner_radius_top_left     =1,
set_corner_radius_top_right    =1,
set_corner_radius_bottom_left  =1,
set_corner_radius_bottom_right =1,
set_corner_radius_kappa        =1,
set_corner_radius              =1,

get_border_color_left   =1,
get_border_color_right  =1,
get_border_color_top    =1,
get_border_color_bottom =1,

set_border_color_left   =1,
set_border_color_right  =1,
set_border_color_top    =1,
set_border_color_bottom =1,
set_border_color        =1,

get_border_dash_count=1,
set_border_dash_count=1,

get_border_dash=1,
set_border_dash=1,

get_border_dash_offset=1,
set_border_dash_offset=1,

set_border_line_to=1,

--backgrounds

get_background_type=1,
set_background_type=1,

get_background_color=1,
set_background_color=1,

get_background_color_set=1,
set_background_color_set=1,

get_background_x1=1,
get_background_y1=1,
get_background_x2=1,
get_background_y2=1,
get_background_r1 =1,
get_background_r2 =1,

set_background_x1=1,
set_background_y1=1,
set_background_x2=1,
set_background_y2=1,
set_background_r1 =1,
set_background_r2 =1,

get_background_color_stop_count=1,
set_background_color_stop_count=1,
get_background_color_stop_color=1,
set_background_color_stop_color=1,
get_background_color_stop_offset=1,
set_background_color_stop_offset=1,

get_background_image=1,
set_background_image=1,

get_background_hittable    =1,
get_background_operator    =1,
get_background_clip_border_offset=1,
get_background_x           =1,
get_background_y           =1,
get_background_rotation    =1,
get_background_rotation_cx =1,
get_background_rotation_cy =1,
get_background_scale       =1,
get_background_scale_cx    =1,
get_background_scale_cy    =1,
get_background_extend      =1,

set_background_hittable    =1,
set_background_operator    =1,
set_background_clip_border_offset=1,
set_background_x           =1,
set_background_y           =1,
set_background_rotation    =1,
set_background_rotation_cx =1,
set_background_rotation_cy =1,
set_background_scale       =1,
set_background_scale_cx    =1,
set_background_scale_cy    =1,
set_background_extend      =1,

--shadows

get_shadow_x       =1,
get_shadow_y       =1,
get_shadow_color   =1,
get_shadow_blur    =1,
get_shadow_passes  =1,
get_shadow_inset   =1,
get_shadow_content =1,

set_shadow_x       =1,
set_shadow_y       =1,
set_shadow_color   =1,
set_shadow_blur    =1,
set_shadow_passes  =1,
set_shadow_inset   =1,
set_shadow_content =1,

--text

get_text=1,
get_text_len=1,
set_text=1,

set_text_utf8=1,
get_text_utf8=1,
get_text_utf8_len=1,

get_text_maxlen=1,
set_text_maxlen=1,

get_text_dir=1,
set_text_dir=1,

get_text_align_x=1,
get_text_align_y=1,

set_text_align_x=1,
set_text_align_y=1,

get_text_font_id           =1,
get_text_font_size         =1,
get_text_features          =1,
get_text_script            =1,
get_text_lang              =1,
get_text_paragraph_dir     =1,
get_text_line_spacing      =1,
get_text_hardline_spacing  =1,
get_text_paragraph_spacing =1,
get_text_nowrap            =1,
get_text_color             =1,
get_text_opacity           =1,
get_text_operator          =1,

set_text_font_id           =1,
set_text_font_size         =1,
set_text_features          =1,
set_text_script            =1,
set_text_lang              =1,
set_text_paragraph_dir     =1,
set_text_line_spacing      =1,
set_text_hardline_spacing  =1,
set_text_paragraph_spacing =1,
set_text_nowrap            =1,
set_text_color             =1,
set_text_opacity           =1,
set_text_operator          =1,

--[[
get_text_span_font_id           =1,
get_text_span_font_size         =1,
get_text_span_features          =1,
get_text_span_script            =1,
get_text_span_lang              =1,
get_text_span_paragraph_dir     =1,
get_text_span_line_spacing      =1,
get_text_span_hardline_spacing  =1,
get_text_span_paragraph_spacing =1,
get_text_span_nowrap            =1,
get_text_span_color             =1,
get_text_span_opacity           =1,
get_text_span_operator          =1,

set_text_span_font_id           =1,
set_text_span_font_size         =1,
set_text_span_features          =1,
set_text_span_script            =1,
set_text_span_lang              =1,
set_text_span_paragraph_dir     =1,
set_text_span_line_spacing      =1,
set_text_span_hardline_spacing  =1,
set_text_span_paragraph_spacing =1,
set_text_span_nowrap            =1,
set_text_span_color             =1,
set_text_span_opacity           =1,
set_text_span_operator          =1,
]]

text_cursor_xs=1,

get_text_caret_width=1,
get_text_caret_color=1,
get_text_caret_insert_mode=1,
get_text_selectable=1,

set_text_caret_width=1,
set_text_caret_color=1,
set_text_caret_insert_mode=1,
set_text_selectable=1,

--

--layouts

set_layout_type=1,
get_layout_type=1,

get_align_items_x =1,
get_align_items_y =1,
get_item_align_x  =1,
get_item_align_y  =1,

set_align_items_x =1,
set_align_items_y =1,
set_item_align_x  =1,
set_item_align_y  =1,

get_flex_flow=1,
set_flex_flow=1,

get_flex_wrap=1,
set_flex_wrap=1,

get_fr=1,
set_fr=1,

get_break_before=1,
get_break_after=1,

set_break_before=1,
set_break_after=1,

get_grid_col_fr_count=1,
get_grid_row_fr_count=1,

set_grid_col_fr_count=1,
set_grid_row_fr_count=1,

get_grid_col_fr=1,
get_grid_row_fr=1,

set_grid_col_fr=1,
set_grid_row_fr=1,

get_grid_col_gap=1,
get_grid_row_gap=1,

set_grid_col_gap=1,
set_grid_row_gap=1,

get_grid_flow=1,
set_grid_flow=1,

get_grid_wrap=1,
set_grid_wrap=1,

get_grid_min_lines=1,
set_grid_min_lines=1,

get_grid_col=1,
get_grid_row=1,

set_grid_col=1,
set_grid_row=1,

get_grid_col_span=1,
get_grid_row_span=1,

set_grid_col_span=1,
set_grid_row_span=1,

--drawing & sync

sync_top=1,
sync_layout_separate_axes=1, --for scrollbox
draw=1,
hit_test_c='hit_test',

]==]
