
--Layer C/ffi API

setfenv(1, require'terra/layer')

local terra layerlib_new(load_font: tr.FontLoadFunc, unload_font: tr.FontLoadFunc)
	return new(Lib, load_font, unload_font)
end

terra Lib:release()
	release(self)
end

terra Layer:get_x() return self.x end
terra Layer:get_y() return self.y end
terra Layer:get_w() return self.w end
terra Layer:get_h() return self.h end

terra Layer:set_x(v: num) self.x = v end
terra Layer:set_y(v: num) self.y = v end
terra Layer:set_w(v: num)
	v = max(v, 0)
	if self.w ~= v then
		self.w = v
		self:size_changed()
	end
end
terra Layer:set_h(v: num)
	v = max(v, 0)
	if self.h ~= v then
		self.h = v
		self:size_changed()
	end
end

terra Layer:get_padding_left  () return self.padding_left   end
terra Layer:get_padding_right () return self.padding_right  end
terra Layer:get_padding_top   () return self.padding_top    end
terra Layer:get_padding_bottom() return self.padding_bottom end

terra Layer:set_padding_left  (v: num) self.padding_left   = v end
terra Layer:set_padding_right (v: num) self.padding_right  = v end
terra Layer:set_padding_top   (v: num) self.padding_top    = v end
terra Layer:set_padding_bottom(v: num) self.padding_bottom = v end

terra Layer:set_padding(v: num)
	self.padding_left   = v
	self.padding_right  = v
	self.padding_top    = v
	self.padding_bottom = v
end

do end --drawing

terra Layer:get_visible      () return self.visible end
terra Layer:get_operator     () return self.operator end
terra Layer:get_clip_content () return self.clip_content end
terra Layer:get_snap_x       () return self.snap_x end
terra Layer:get_snap_y       () return self.snap_y end
terra Layer:get_opacity      () return self.opacity end

terra Layer:set_visible      (v: bool) self.visible = v end
terra Layer:set_operator     (v: enum) self.operator = v end
terra Layer:set_clip_content (v: enum) self.clip_content = v end
terra Layer:set_snap_x       (v: bool) self.snap_x = v end
terra Layer:set_snap_y       (v: bool) self.snap_y = v end
terra Layer:set_opacity      (v: num)  self.opacity = v end

do end --transforms

terra Layer:get_rotation    () return self.transform.rotation    end
terra Layer:get_rotation_cx () return self.transform.rotation_cx end
terra Layer:get_rotation_cy () return self.transform.rotation_cy end
terra Layer:get_scale       () return self.transform.scale       end
terra Layer:get_scale_cx    () return self.transform.scale_cx    end
terra Layer:get_scale_cy    () return self.transform.scale_cy    end

terra Layer:set_rotation    (v: num) self.transform.rotation    = v end
terra Layer:set_rotation_cx (v: num) self.transform.rotation_cx = v end
terra Layer:set_rotation_cy (v: num) self.transform.rotation_cy = v end
terra Layer:set_scale       (v: num) self.transform.scale       = v end
terra Layer:set_scale_cx    (v: num) self.transform.scale_cx    = v end
terra Layer:set_scale_cy    (v: num) self.transform.scale_cy    = v end

do end --borders

terra Layer:border_shape_changed() end --TODO

terra Layer:get_border_width_left   () return self.border.width_left   end
terra Layer:get_border_width_right  () return self.border.width_right  end
terra Layer:get_border_width_top    () return self.border.width_top    end
terra Layer:get_border_width_bottom () return self.border.width_bottom end

terra Layer:set_border_width_left   (v: num) self.border.width_left   = v; self:border_shape_changed() end
terra Layer:set_border_width_right  (v: num) self.border.width_right  = v; self:border_shape_changed() end
terra Layer:set_border_width_top    (v: num) self.border.width_top    = v; self:border_shape_changed() end
terra Layer:set_border_width_bottom (v: num) self.border.width_bottom = v; self:border_shape_changed() end

terra Layer:set_border_width(v: num)
	self.border_width_left   = v
	self.border_width_right  = v
	self.border_width_top    = v
	self.border_width_bottom = v
end

terra Layer:get_corner_radius_top_left     () return self.border.corner_radius_top_left     end
terra Layer:get_corner_radius_top_right    () return self.border.corner_radius_top_right    end
terra Layer:get_corner_radius_bottom_left  () return self.border.corner_radius_bottom_left  end
terra Layer:get_corner_radius_bottom_right () return self.border.corner_radius_bottom_right end
terra Layer:get_corner_radius_kappa        () return self.border.corner_radius_kappa        end

terra Layer:set_corner_radius_top_left     (v: num) self.border.corner_radius_top_left     = v; self:border_shape_changed() end
terra Layer:set_corner_radius_top_right    (v: num) self.border.corner_radius_top_right    = v; self:border_shape_changed() end
terra Layer:set_corner_radius_bottom_left  (v: num) self.border.corner_radius_bottom_left  = v; self:border_shape_changed() end
terra Layer:set_corner_radius_bottom_right (v: num) self.border.corner_radius_bottom_right = v; self:border_shape_changed() end
terra Layer:set_corner_radius_kappa        (v: num) self.border.corner_radius_kappa        = v; self:border_shape_changed() end

terra Layer:set_corner_radius(v: num)
	self.corner_radius_top_left     = v
	self.corner_radius_top_right    = v
	self.corner_radius_bottom_left  = v
	self.corner_radius_bottom_right = v
end

terra Layer:get_border_color_left   () return self.border.color_left   .uint end
terra Layer:get_border_color_right  () return self.border.color_right  .uint end
terra Layer:get_border_color_top    () return self.border.color_top    .uint end
terra Layer:get_border_color_bottom () return self.border.color_bottom .uint end

terra Layer:set_border_color_left   (v: uint32) self.border.color_left   .uint = v end
terra Layer:set_border_color_right  (v: uint32) self.border.color_right  .uint = v end
terra Layer:set_border_color_top    (v: uint32) self.border.color_top    .uint = v end
terra Layer:set_border_color_bottom (v: uint32) self.border.color_bottom .uint = v end

terra Layer:set_border_color(v: uint32)
	self.border_color_left   = v
	self.border_color_right  = v
	self.border_color_top    = v
	self.border_color_bottom = v
end

terra Layer:get_border_dash_count() return self.border.dash.len end
terra Layer:set_border_dash_count(v: int) self.border.dash:setlen(v, 0) end

terra Layer:get_border_dash(i: int) return self.border.dash(i) end
terra Layer:set_border_dash(i: int, v: num) return self.border.dash:set(i, v, 0) end

terra Layer:get_border_dash_offset() return self.border.dash_offset end
terra Layer:set_border_dash_offset(v: int) self.border.dash_offset = v end

terra Layer:get_border_offset() return self.border.offset end
terra Layer:set_border_offset(v: int) self.border.offset = v; self:border_shape_changed() end

terra Layer:set_border_line_to(line_to: BorderLineToFunc)
	self.border.line_to = line_to; self:border_shape_changed()
end

do end --backgrounds

terra Layer:get_background_type() return self.background.type end
terra Layer:set_background_type(v: enum) self.background.type = v end

terra Layer:get_background_hittable() return self.background.hittable end
terra Layer:set_background_hittable(v: bool) self.background.hittable = v end

terra Layer:get_background_operator() return self.background.operator end
terra Layer:set_background_operator(v: enum) self.background.operator = v end

terra Layer:get_background_clip_border_offset() return self.background.clip_border_offset end
terra Layer:set_background_clip_border_offset(v: num) self.background.clip_border_offset = v end

terra Layer:get_background_color() return self.background.color.uint end
terra Layer:set_background_color(v: uint)
	self.background.color = color{uint = v}
	self.background.color_set = true
end

terra Layer:get_background_color_set() return self.background.color_set end
terra Layer:set_background_color_set(v: bool) self.background.color_set = v end

terra Layer:get_background_x1() return self.background.pattern.gradient.x1 end
terra Layer:get_background_y1() return self.background.pattern.gradient.y1 end
terra Layer:get_background_x2() return self.background.pattern.gradient.x2 end
terra Layer:get_background_y2() return self.background.pattern.gradient.y2 end
terra Layer:get_background_r1() return self.background.pattern.gradient.r1 end
terra Layer:get_background_r2() return self.background.pattern.gradient.r2 end

terra Layer:set_background_x1(v: num) self.background.pattern.gradient.x1 = v; self:background_changed() end
terra Layer:set_background_y1(v: num) self.background.pattern.gradient.y1 = v; self:background_changed() end
terra Layer:set_background_x2(v: num) self.background.pattern.gradient.x2 = v; self:background_changed() end
terra Layer:set_background_y2(v: num) self.background.pattern.gradient.y2 = v; self:background_changed() end
terra Layer:set_background_r1(v: num) self.background.pattern.gradient.r1 = v; self:background_changed() end
terra Layer:set_background_r2(v: num) self.background.pattern.gradient.r2 = v; self:background_changed() end

terra Layer:get_background_color_stop_count()
	return self.background.pattern.gradient.color_stops.len
end

terra Layer:set_background_color_stop_count(n: int)
	self.background.pattern.gradient.color_stops:setlen(n, ColorStop{0, 0})
	self:background_changed()
end

terra Layer:get_background_color_stop_color(i: int)
	var cs = self.background.pattern.gradient.color_stops:at(i, nil)
	return iif(cs ~= nil, cs.color.uint, 0)
end

terra Layer:get_background_color_stop_offset(i: int)
	var cs = self.background.pattern.gradient.color_stops:at(i, nil)
	return iif(cs ~= nil, cs.offset, 0)
end

terra Layer:set_background_color_stop_color(i: int, color: uint32)
	self.background.pattern.gradient.color_stops:getat(i, ColorStop{0, 0}).color.uint = color
	self:background_changed()
end

terra Layer:set_background_color_stop_offset(i: int, offset: num)
	self.background.pattern.gradient.color_stops:getat(i, ColorStop{0, 0}).offset = offset
	self:background_changed()
end

terra Layer:get_background_image()
	return &self.background.pattern.bitmap
end

terra Layer:set_background_image(v: &Bitmap)
	self.background.pattern.bitmap = @v
	self:background_changed()
end

terra Layer:get_background_x      () return self.background.pattern.x end
terra Layer:get_background_y      () return self.background.pattern.y end
terra Layer:get_background_extend () return self.background.pattern.extend end

terra Layer:set_background_x      (v: num)  self.background.pattern.x = v end
terra Layer:set_background_y      (v: num)  self.background.pattern.y = v end
terra Layer:set_background_extend (v: enum) self.background.pattern.extend = v end

terra Layer:get_background_rotation    () return self.background.pattern.transform.rotation    end
terra Layer:get_background_rotation_cx () return self.background.pattern.transform.rotation_cx end
terra Layer:get_background_rotation_cy () return self.background.pattern.transform.rotation_cy end
terra Layer:get_background_scale       () return self.background.pattern.transform.scale       end
terra Layer:get_background_scale_cx    () return self.background.pattern.transform.scale_cx    end
terra Layer:get_background_scale_cy    () return self.background.pattern.transform.scale_cy    end

terra Layer:set_background_rotation    (v: num) self.background.pattern.transform.rotation = v end
terra Layer:set_background_rotation_cx (v: num) self.background.pattern.transform.rotation_cx = v end
terra Layer:set_background_rotation_cy (v: num) self.background.pattern.transform.rotation_cy = v end
terra Layer:set_background_scale       (v: num) self.background.pattern.transform.scale = v end
terra Layer:set_background_scale_cx    (v: num) self.background.pattern.transform.scale_cx = v end
terra Layer:set_background_scale_cy    (v: num) self.background.pattern.transform.scale_cy = v end

do end --shadows

terra Layer:shadow(i: int)
	return self.shadows:at(i, &self.lib.default_shadow)
end

terra Layer:new_shadow(i: int)
	var s, new_shadows = self.shadows:getat(i)
	for _,s in new_shadows do
		s:init(self)
	end
	return s
end

terra Layer:get_shadow_count() return self.shadows.len end
terra Layer:set_shadow_count(n: int)
	var new_shadows = self.shadows:setlen(n)
	for _,s in new_shadows do
		s:init(self)
	end
end

terra Layer:get_shadow_x       (i: int) return self:shadow(i).offset_x end
terra Layer:get_shadow_y       (i: int) return self:shadow(i).offset_y end
terra Layer:get_shadow_color   (i: int) return self:shadow(i).color end
terra Layer:get_shadow_blur    (i: int) return self:shadow(i).blur_radius end
terra Layer:get_shadow_passes  (i: int) return self:shadow(i).blur_passes end
terra Layer:get_shadow_inset   (i: int) return self:shadow(i).inset end
terra Layer:get_shadow_content (i: int) return self:shadow(i).content end

terra Layer:shadow_shape_changed() end --TODO

terra Layer:set_shadow_x       (i: int, v: num)    self:new_shadow(i).offset_x    = v end
terra Layer:set_shadow_y       (i: int, v: num)    self:new_shadow(i).offset_y    = v end
terra Layer:set_shadow_color   (i: int, v: uint32) self:new_shadow(i).color.uint  = v end
terra Layer:set_shadow_blur    (i: int, v: uint8)  self:new_shadow(i).blur_radius = v; self:shadow_shape_changed() end
terra Layer:set_shadow_passes  (i: int, v: uint8)  self:new_shadow(i).blur_passes = v; self:shadow_shape_changed() end
terra Layer:set_shadow_inset   (i: int, v: bool)   self:new_shadow(i).inset       = v; self:shadow_shape_changed() end
terra Layer:set_shadow_content (i: int, v: bool)   self:new_shadow(i).content     = v; self:shadow_shape_changed() end

do end --text

terra Layer:get_text()     return self.text.layout.text.elements end
terra Layer:get_text_len() return self.text.layout.text_len end

terra Layer:set_text(s: &codepoint, len: int)
	self.text.layout:set_text(s, len)
end

terra Layer:set_text_utf8(s: rawstring, len: int)
	self.text.layout:set_text_utf8(s, len)
end

terra Layer:get_text_utf8(out: rawstring, max_outlen: int)
	return self.text.layout:get_text_utf8(out, max_outlen)
end

terra Layer:get_text_maxlen() return self.text.layout.maxlen end
terra Layer:set_text_maxlen(v: int)  self.text.layout.maxlen = v end

terra Layer:get_text_dir()     return self.text.layout.dir end
terra Layer:set_text_dir(v: tr.dir_t) self.text.layout.dir = v end

terra Layer:get_text_align_x() return self.text.layout.align_x end
terra Layer:get_text_align_y() return self.text.layout.align_y end
terra Layer:set_text_align_x(v: enum) self.text.layout.align_x = v end
terra Layer:set_text_align_y(v: enum) self.text.layout.align_y = v end

--text spans

for FIELD, T in sortedpairs(tr.SPAN_FIELD_TYPES) do
	Layer.methods['get_text_'..FIELD] = terra(self: &Layer, i: int, j: int, v: &T)
		return self.text.layout:['get_'..FIELD](i, j, v)
	end
	Layer.methods['set_text_'..FIELD] = terra(self: &Layer, i: int, j: int, v: T)
		self.text.layout:['set_'..FIELD](i, j, v)
	end
end

--text measuring and hit-testing

terra Layer:text_cursor_xs(line_i: int, outlen: &int)
	return self.text.layout:cursor_xs_c(line_i, outlen)
end

do end --layouts

terra Layer:get_align_items_x () return self.align_items_x end
terra Layer:get_align_items_y () return self.align_items_y end
terra Layer:get_item_align_x  () return self.item_align_x  end
terra Layer:get_item_align_y  () return self.item_align_y  end

terra Layer:set_align_items_x (v: enum) self.align_items_x = v end
terra Layer:set_align_items_y (v: enum) self.align_items_y = v end
terra Layer:set_item_align_x  (v: enum) self.item_align_x  = v end
terra Layer:set_item_align_y  (v: enum) self.item_align_y  = v end

terra Layer:get_flex_flow() return self.flex.flow end
terra Layer:set_flex_flow(v: enum) self.flex.flow = v end

terra Layer:get_flex_wrap() return self.flex.wrap end
terra Layer:set_flex_wrap(v: bool) self.flex.wrap = v end

terra Layer:get_fr() return self.fr end
terra Layer:set_fr(v: num) self.fr = v end

terra Layer:get_break_before () return self.break_before end
terra Layer:get_break_after  () return self.break_after  end

terra Layer:set_break_before (v: bool) self.break_before = v end
terra Layer:set_break_after  (v: bool) self.break_after  = v end

terra Layer:get_grid_col_fr_count() return self.grid.col_frs.len end
terra Layer:get_grid_row_fr_count() return self.grid.row_frs.len end

terra Layer:set_grid_col_fr_count(n: int) self.grid.col_frs:setlen(n, 1) end
terra Layer:set_grid_row_fr_count(n: int) self.grid.row_frs:setlen(n, 1) end

terra Layer:get_grid_col_fr(i: int) return self.grid.col_frs(i, 1) end
terra Layer:get_grid_row_fr(i: int) return self.grid.row_frs(i, 1) end

terra Layer:set_grid_col_fr(i: int, v: num) self.grid.col_frs:set(i, v, 1) end
terra Layer:set_grid_row_fr(i: int, v: num) self.grid.row_frs:set(i, v, 1) end

terra Layer:get_grid_col_gap() return self.grid.col_gap end
terra Layer:get_grid_row_gap() return self.grid.row_gap end

terra Layer:set_grid_col_gap(v: num) self.grid.col_gap = v end
terra Layer:set_grid_row_gap(v: num) self.grid.row_gap = v end

terra Layer:get_grid_flow() return self.grid.flow end
terra Layer:set_grid_flow(v: enum) self.grid.flow = v end

terra Layer:get_grid_wrap() return self.grid.wrap end
terra Layer:set_grid_wrap(v: int) self.grid.wrap = v end

terra Layer:get_grid_min_lines() return self.grid.min_lines end
terra Layer:set_grid_min_lines(v: int) self.grid.min_lines = v end

terra Layer:get_min_cw() return self.min_cw end
terra Layer:get_min_ch() return self.min_cw end

terra Layer:set_min_cw(v: num) self.min_cw = v end
terra Layer:set_min_ch(v: num) self.min_ch = v end

terra Layer:get_align_x() return self.align_x end
terra Layer:get_align_y() return self.align_y end

terra Layer:set_align_x(v: enum) self.align_x = v end
terra Layer:set_align_y(v: enum) self.align_y = v end

terra Layer:get_grid_col() return self.grid_col end
terra Layer:get_grid_row() return self.grid_row end

terra Layer:set_grid_col(v: int) self.grid_col = v end
terra Layer:set_grid_row(v: int) self.grid_row = v end

terra Layer:get_grid_col_span() return self.grid_col_span end
terra Layer:get_grid_row_span() return self.grid_row_span end

terra Layer:set_grid_col_span(v: int) self.grid_col_span = v end
terra Layer:set_grid_row_span(v: int) self.grid_row_span = v end

--hit testing

terra Layer:get_hit_test_mask() return self.hit_test_mask end
terra Layer:set_hit_test_mask(v: enum) self.hit_test_mask = v end

terra Layer:hit_test_c(cr: &context, x: num, y: num, reason: enum, out: &&Layer)
	var layer, area = self:hit_test(cr, x, y, reason)
	@out = layer
	return area
end

--publish and build

function build()
	local layerlib = publish'layer'

	if memtotal then
		layerlib(memtotal)
		layerlib(memreport)
	end

	layerlib:getenums(_M)

	layerlib(layerlib_new, 'layerlib')

	layerlib(Lib, {

		release='free',

		font=1,
		layer=1,

		dump_stats=1,

		get_font_size_resolution       =1,
		get_subpixel_x_resolution      =1,
		get_word_subpixel_x_resolution =1,
		get_glyph_cache_size           =1,
		get_glyph_run_cache_size       =1,

		set_font_size_resolution       =1,
		set_subpixel_x_resolution      =1,
		set_word_subpixel_x_resolution =1,
		set_glyph_cache_size           =1,
		set_glyph_run_cache_size       =1,

	}, {
		cname = 'layerlib_t',
		cprefix = 'layerlib_',
		opaque = true,
	})

	layerlib(Layer, {

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

	}, {
		cname = 'layer_t',
		cprefix = 'layer_',
		opaque = true,
	})

	layerlib:build{
		linkto = {'cairo', 'freetype', 'harfbuzz', 'fribidi', 'unibreak', 'boxblur', 'xxhash'},
		optimize = false,
	}
end

if not ... then
	build()
	print(sizeof(Layer))
end

return _M
