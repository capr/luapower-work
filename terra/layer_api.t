--[[

	Layer C/ffi API.

	- creates a flattened API tailored for ffi use.
	- validates enums, clamps numbers to range.
	- invalidates state appropriately when input values are updated.
	- synchronizes state when computed values are accessed.
	- adds self-allocating constructors.

]]


setfenv(1, require'terra/layer')

local real_uint32 = uint32

--Using doubles in place of int types allows us to clamp out-of-range Lua
--numbers instead of the default x86 CPU behavior of converting them to -2^31.
--The downside is that this probably disables LuaJIT's number specialization.
api_types = api_types or {
	[num]    = double,
	[int]    = double,
	[uint32] = double,
	[enum]   = double,
}
local num    = api_types[num]    or num
local int    = api_types[int]    or int
local uint32 = api_types[uint32] or uint32
local enum   = api_types[enum]   or enum

local struct Layer (extends(_M.Layer, 'l')) {}

Layer.methods.change = macro(function(self, target, FIELD, v, WHAT)
	if WHAT then
		if type(WHAT) == 'terraquote' then WHAT = WHAT:asvalue() end
		return quote
			var changed = change(target, FIELD, v)
			if changed then
				self:[WHAT..'_changed']()
			end
		end
	else
		return quote change(target, FIELD, v) end
	end
end)

local MAX_U32 = 2^32-1
local MAX_X = 10^9
local MAX_W = 10^9
local MAX_OFFSET = 100
local MAX_COLOR_STOP_COUNT  = 100
local MAX_BORDER_DASH_COUNT = 10
local MIN_SCALE = 0.0001 --avoid a non-invertible matrix
local MAX_SCALE = 1000
local MAX_SHADOW_COUNT = 10
local MAX_SHADOW_BLUR = 255
local MAX_SHADOW_PASSES = 10
local MAX_SPAN_COUNT = 10^9
local MAX_GRID_ITEM_COUNT = 10^9
local MAX_CHILD_COUNT = 10^9

do end --lib new/release

local terra layerlib_new(load_font: tr.FontLoadFunc, unload_font: tr.FontLoadFunc)
	return new(Lib, load_font, unload_font)
end

terra Lib:release()
	release(self)
end

do end --text rendering engine configuration

terra Lib:get_font_size_resolution       (): num return self.text_renderer.font_size_resolution end
terra Lib:get_subpixel_x_resolution      (): num return self.text_renderer.subpixel_x_resolution end
terra Lib:get_word_subpixel_x_resolution (): num return self.text_renderer.word_subpixel_x_resolution end
terra Lib:get_glyph_cache_size           (): int return self.text_renderer.glyph_cache_size end
terra Lib:get_glyph_run_cache_size       (): int return self.text_renderer.glyph_run_cache_size end

terra Lib:set_font_size_resolution       (v: num) self.text_renderer.font_size_resolution = v end
terra Lib:set_subpixel_x_resolution      (v: num) self.text_renderer.subpixel_x_resolution = v end
terra Lib:set_word_subpixel_x_resolution (v: num) self.text_renderer.word_subpixel_x_resolution = v end
terra Lib:set_glyph_cache_size           (v: int) self.text_renderer.glyph_cache_max_size = v end
terra Lib:set_glyph_run_cache_size       (v: int) self.text_renderer.glyph_run_cache_max_size = v end

--font registration

terra Lib:font(): int
	return self.text_renderer:font()
end

do end --layer hierarchy

terra Layer:set_child_count(n: int)
	self:change(self.l, 'child_count', clamp(n, 0, MAX_CHILD_COUNT))
end

do end --geometry

for i,FIELD in ipairs{'x' , 'y', 'cx', 'cy'} do
	Layer.methods['get_'..FIELD] = terra(self: &Layer): num
		return self.l.[FIELD]
	end
	Layer.methods['set_'..FIELD] = terra(self: &Layer, v: num)
		self:change(self.l, FIELD, clamp(v, -MAX_X, MAX_X))
	end
end

for i,FIELD in ipairs{'w' , 'h', 'cw', 'ch'} do
	Layer.methods['get_'..FIELD] = terra(self: &Layer): num
		return self.l.[FIELD]
	end
	Layer.methods['set_'..FIELD] = terra(self: &Layer, v: num)
		self:change(self.l, FIELD, clamp(v, -MAX_W, MAX_W), 'layout')
	end
end

terra Layer:get_in_transition(): bool return self.l.in_transition end
terra Layer:set_in_transition(v: bool) self.l.in_transition = v end

terra Layer:get_final_x(): num return self.l.final_x end
terra Layer:get_final_y(): num return self.l.final_y end
terra Layer:get_final_w(): num return self.l.final_w end
terra Layer:get_final_h(): num return self.l.final_h end

for i,SIDE in ipairs{'left', 'right', 'top', 'bottom'} do

	Layer.methods['get_padding_'..SIDE] = terra(self: &Layer)
		return self.l.['padding_'..SIDE]
	end

	Layer.methods['set_padding_'..SIDE] = terra(self: &Layer, v: num)
		self:change(self.l, ['padding_'..SIDE], clamp(v, -MAX_W, MAX_W), 'minsize')
	end

end

terra Layer:get_padding(): num
	return (
		  self.padding_left
		+ self.padding_right
		+ self.padding_top
		+ self.padding_bottom) / 4
end

terra Layer:set_padding(v: num)
	self.padding_left   = v
	self.padding_right  = v
	self.padding_top    = v
	self.padding_bottom = v
end

do end --drawing

terra Layer:get_operator     (): enum return self.operator end
terra Layer:get_clip_content (): bool return self.clip_content end
terra Layer:get_snap_x       (): bool return self.snap_x end
terra Layer:get_snap_y       (): bool return self.snap_y end
terra Layer:get_opacity      (): num  return self.opacity end

terra Layer:set_operator     (v: enum)
	assert(v >= OPERATOR_MIN and v <= OPERATOR_MAX)
	self.l.operator = v
end
terra Layer:set_clip_content (v: bool) self.l.clip_content = v end
terra Layer:set_snap_x       (v: bool) self.l.snap_x = v end
terra Layer:set_snap_y       (v: bool) self.l.snap_y = v end
terra Layer:set_opacity      (v: num)  self.l.opacity = clamp(v, 0, 1) end

do end --transforms

terra Layer:get_rotation    (): num return self.transform.rotation    end
terra Layer:get_rotation_cx (): num return self.transform.rotation_cx end
terra Layer:get_rotation_cy (): num return self.transform.rotation_cy end
terra Layer:get_scale       (): num return self.transform.scale       end
terra Layer:get_scale_cx    (): num return self.transform.scale_cx    end
terra Layer:get_scale_cy    (): num return self.transform.scale_cy    end

terra Layer:set_rotation    (v: num) self.transform.rotation    = v end
terra Layer:set_rotation_cx (v: num) self.transform.rotation_cx = clamp(v, -MAX_X, MAX_X) end
terra Layer:set_rotation_cy (v: num) self.transform.rotation_cy = clamp(v, -MAX_X, MAX_X) end
terra Layer:set_scale       (v: num) self.transform.scale       = clamp(v, MIN_SCALE, MAX_SCALE) end
terra Layer:set_scale_cx    (v: num) self.transform.scale_cx    = clamp(v, -MAX_X, MAX_X) end
terra Layer:set_scale_cy    (v: num) self.transform.scale_cy    = clamp(v, -MAX_X, MAX_X) end

do end --borders

for i,SIDE in ipairs{'left', 'right', 'top', 'bottom'} do

	Layer.methods['get_border_width_'..SIDE] = terra(self: &Layer): num
		return self.border.['width_'..SIDE]
	end

	Layer.methods['set_border_width_'..SIDE] = terra(self: &Layer, v: num)
		self:change(self.border, ['width_'..SIDE], clamp(v, 0, MAX_W), 'border_shape')
	end

	Layer.methods['get_border_color_'..SIDE] = terra(self: &Layer): uint32
		return self.border.['color_'..SIDE].uint
	end

	Layer.methods['set_border_color_'..SIDE] = terra(self: &Layer, v: uint32)
		self.border.['color_'..SIDE].uint = clamp(v, 0, MAX_U32)
	end

end

terra Layer:get_border_width(): num
	return (
		  self.border_width_left
		+ self.border_width_right
		+ self.border_width_top
		+ self.border_width_bottom) / 4
end

terra Layer:set_border_width(v: num)
	self.border_width_left   = v
	self.border_width_right  = v
	self.border_width_top    = v
	self.border_width_bottom = v
end

terra Layer:get_border_color(): uint32
	return
		   self.border.color_left.uint
		or self.border.color_right.uint
		or self.border.color_top.uint
		or self.border.color_bottom.uint
end

terra Layer:set_border_color(v: num)
	self.border_color_left   = v
	self.border_color_right  = v
	self.border_color_top    = v
	self.border_color_bottom = v
end

for i,CORNER in ipairs{'top_left', 'top_right', 'bottom_left', 'bottom_right'} do

	local RADIUS = 'corner_radius_'..CORNER

	Layer.methods['get_'..RADIUS] = terra(self: &Layer): num
		return self.border.[RADIUS]
	end

	Layer.methods['set_'..RADIUS] = terra(self: &Layer, v: num)
		self:change(self.border, RADIUS, clamp(v, 0, MAX_W), 'border_shape')
	end

end

terra Layer:get_corner_radius(): num
	return (
		  self.corner_radius_top_left
		+ self.corner_radius_top_right
		+ self.corner_radius_bottom_left
		+ self.corner_radius_bottom_right) / 4
end

terra Layer:set_corner_radius(v: num)
	self.corner_radius_top_left     = v
	self.corner_radius_top_right    = v
	self.corner_radius_bottom_left  = v
	self.corner_radius_bottom_right = v
end

terra Layer:get_border_dash_count(): int return self.border.dash.len end
terra Layer:set_border_dash_count(v: int)
	v = clamp(v, 0, MAX_BORDER_DASH_COUNT)
	self.border.dash:setlen(v, 1)
end

terra Layer:get_border_dash(i: int): int
	return self.border.dash(i, 1)
end
terra Layer:set_border_dash(i: int, v: double)
	if i >= 0 and i < MAX_BORDER_DASH_COUNT then
		self.border.dash:set(i, clamp(v, 0.0001, MAX_W), 1)
	end
end

terra Layer:get_border_dash_offset(): num return self.border.dash_offset end
terra Layer:set_border_dash_offset(v: num)
	self.border.dash_offset = v
end

terra Layer:get_border_offset(): num return self.border.offset end
terra Layer:set_border_offset(v: num)
	self:change(self.border, 'offset', clamp(v, -MAX_OFFSET, MAX_OFFSET), 'border_shape')
end

terra Layer:set_border_line_to(line_to: BorderLineToFunc)
	self.border.line_to = line_to
	self:border_shape_changed()
end

do end --backgrounds

terra Layer:get_background_type(): enum return self.background.type end
terra Layer:set_background_type(v: enum)
	assert(v >= BACKGROUND_TYPE_MIN and v <= BACKGROUND_TYPE_MAX)
	self:change(self.background, 'type', v, 'background')
end

terra Layer:get_background_hittable(): bool return self.background.hittable end
terra Layer:set_background_hittable(v: bool) self.background.hittable = v end

terra Layer:get_background_operator(): enum return self.background.operator end
terra Layer:set_background_operator(v: enum)
	assert(v >= OPERATOR_MIN and v <= OPERATOR_MAX)
	self.background.operator = v
end

terra Layer:get_background_clip_border_offset(): num
	return self.background.clip_border_offset
end
terra Layer:set_background_clip_border_offset(v: num)
	self.background.clip_border_offset = clamp(v, -MAX_OFFSET, MAX_OFFSET)
end

terra Layer:get_background_color(): uint32 return self.background.color.uint end
terra Layer:set_background_color(v: uint32)
	v = clamp(v, 0, MAX_U32)
	self.background.color = color{uint = v}
	self.background.color_set = true
end

terra Layer:get_background_color_set(): bool
	return self.background.color_set
end
terra Layer:set_background_color_set(v: bool)
	self.background.color_set = v
	if not v then self.background.color.uint = 0 end
end

for i,FIELD in ipairs{'x1', 'y1', 'x2', 'y2', 'r1', 'r2'} do

	local MAX = FIELD:find'^r' and MAX_W or MAX_X

	Layer.methods['get_background_'..FIELD] = terra(self: &Layer): num
		return self.background.pattern.gradient.[FIELD]
	end

	Layer.methods['set_background_'..FIELD] = terra(self: &Layer, v: num)
		self:change(self.background.pattern.gradient, FIELD, clamp(v, -MAX, MAX), 'background')
	end

end

terra Layer:get_background_color_stop_count(): int
	return self.background.pattern.gradient.color_stops.len
end

terra Layer:set_background_color_stop_count(n: int)
	n = clamp(n, 0, MAX_COLOR_STOP_COUNT)
	if self.background.pattern.gradient.color_stops.len ~= n then
		self.background.pattern.gradient.color_stops:setlen(n, ColorStop{0, 0})
		self:background_changed()
	end
end

terra Layer:get_background_color_stop_color(i: int): uint32
	return self.background.pattern.gradient.color_stops(i, ColorStop{0, 0}).color.uint
end

terra Layer:get_background_color_stop_offset(i: int): num
	return self.background.pattern.gradient.color_stops(i, ColorStop{0, 0}).offset
end

terra Layer:set_background_color_stop_color(i: int, v: uint32)
	if i >= 0 and i < MAX_COLOR_STOP_COUNT then
		v = clamp(v, 0, MAX_U32)
		if self:get_background_color_stop_color(i) ~= v then
			self.background.pattern.gradient.color_stops:getat(i, ColorStop{0, 0}).color.uint = v
			self:background_changed()
		end
	end
end

terra Layer:set_background_color_stop_offset(i: int, v: num)
	if i >= 0 and i < MAX_COLOR_STOP_COUNT then
		v = clamp(v, 0, 1)
		if self:get_background_color_stop_offset(i) ~= v then
			self.background.pattern.gradient.color_stops:getat(i, ColorStop{0, 0}).offset = v
			self:background_changed()
		end
	end
end

terra Layer:set_background_image(w: int, h: int, format: enum, stride: int, pixels: &uint8)
	self.background.pattern:set_bitmap(w, h, format, stride, pixels)
	self:background_changed()
end

terra Layer:get_background_image_w      (): num  return self.background.pattern.bitmap.w end
terra Layer:get_background_image_h      (): num  return self.background.pattern.bitmap.h end
terra Layer:get_background_image_stride (): int  return self.background.pattern.bitmap.stride end
terra Layer:get_background_image_format (): enum return self.background.pattern.bitmap.format end
terra Layer:get_background_image_pixels()
	var s = self.background.pattern.bitmap_surface
	if s ~= nil then s:flush() end
	return self.background.pattern.bitmap.pixels
end
terra Layer:background_image_invalidate()
	var s = self.background.pattern.bitmap_surface
	if s ~= nil then s:mark_dirty() end
end
terra Layer:background_image_invalidate_rect(x: int, y: int, w: int, h: int)
	var s = self.background.pattern.bitmap_surface
	if s ~= nil then s:mark_dirty_rectangle(x, y, w, h) end
end

terra Layer:get_background_x      (): num  return self.background.pattern.x end
terra Layer:get_background_y      (): num  return self.background.pattern.y end
terra Layer:get_background_extend (): enum return self.background.pattern.extend end

terra Layer:set_background_x      (v: num) self.background.pattern.x = clamp(v, -MAX_X, MAX_X) end
terra Layer:set_background_y      (v: num) self.background.pattern.y = clamp(v, -MAX_X, MAX_X) end
terra Layer:set_background_extend (v: enum)
	assert(v >= BACKGROUND_EXTEND_MIN and v <= BACKGROUND_EXTEND_MAX)
	self.background.pattern.extend = v
end

terra Layer:get_background_rotation    (): num return self.background.pattern.transform.rotation    end
terra Layer:get_background_rotation_cx (): num return self.background.pattern.transform.rotation_cx end
terra Layer:get_background_rotation_cy (): num return self.background.pattern.transform.rotation_cy end
terra Layer:get_background_scale       (): num return self.background.pattern.transform.scale       end
terra Layer:get_background_scale_cx    (): num return self.background.pattern.transform.scale_cx    end
terra Layer:get_background_scale_cy    (): num return self.background.pattern.transform.scale_cy    end

terra Layer:set_background_rotation    (v: num) self.background.pattern.transform.rotation    = v end
terra Layer:set_background_rotation_cx (v: num) self.background.pattern.transform.rotation_cx = clamp(v, -MAX_X, MAX_X) end
terra Layer:set_background_rotation_cy (v: num) self.background.pattern.transform.rotation_cy = clamp(v, -MAX_X, MAX_X) end
terra Layer:set_background_scale       (v: num) self.background.pattern.transform.scale       = clamp(v, MIN_SCALE, MAX_SCALE) end
terra Layer:set_background_scale_cx    (v: num) self.background.pattern.transform.scale_cx    = clamp(v, -MAX_X, MAX_X) end
terra Layer:set_background_scale_cy    (v: num) self.background.pattern.transform.scale_cy    = clamp(v, -MAX_X, MAX_X) end

do end --shadows

terra Layer:get_shadow_count(): int return self.shadows.len end
terra Layer:set_shadow_count(n: int)
	n = clamp(n, 0, MAX_SHADOW_COUNT)
	var new_shadows = self.shadows:setlen(n)
	for _,s in new_shadows do
		s:init(&self.l)
	end
end

terra Layer:shadow(i: int)
	return self.shadows:at(i, &self.lib.default_shadow)
end

terra Layer:new_shadow(i: int)
	if i >= 0 and i < MAX_SHADOW_COUNT then
		var s, new_shadows = self.shadows:getat(i)
		for _,s in new_shadows do
			s:init(&self.l)
		end
		return s
	else
		return nil
	end
end

terra Layer:get_shadow_x       (i: int): num    return self:shadow(i).offset_x end
terra Layer:get_shadow_y       (i: int): num    return self:shadow(i).offset_y end
terra Layer:get_shadow_color   (i: int): uint32 return self:shadow(i).color.uint end
terra Layer:get_shadow_blur    (i: int): int    return self:shadow(i).blur_radius end
terra Layer:get_shadow_passes  (i: int): int    return self:shadow(i).blur_passes end
terra Layer:get_shadow_inset   (i: int): bool   return self:shadow(i).inset end
terra Layer:get_shadow_content (i: int): bool   return self:shadow(i).content end

terra Layer:set_shadow_x       (i: int, v: num)    var s = self:new_shadow(i); if s ~= nil then s.offset_x    = clamp(v, -MAX_X, MAX_X) end end
terra Layer:set_shadow_y       (i: int, v: num)    var s = self:new_shadow(i); if s ~= nil then s.offset_y    = clamp(v, -MAX_X, MAX_X) end end
terra Layer:set_shadow_color   (i: int, v: uint32) var s = self:new_shadow(i); if s ~= nil then s.color.uint  = clamp(v, 0, MAX_U32) end end
terra Layer:set_shadow_blur    (i: int, v: int)    var s = self:new_shadow(i); if s ~= nil then s.blur_radius = clamp(v, 0, 255) end end
terra Layer:set_shadow_passes  (i: int, v: int)    var s = self:new_shadow(i); if s ~= nil then s.blur_passes = clamp(v, 0, 10) end end
terra Layer:set_shadow_inset   (i: int, v: bool)   var s = self:new_shadow(i); if s ~= nil then s.inset       = v end end
terra Layer:set_shadow_content (i: int, v: bool)   var s = self:new_shadow(i); if s ~= nil then s.content     = v end end

do end --text

terra Layer:text_layout_changed()
	if not self.l.text.layout.min_size_valid then
		self:minsize_changed()
	elseif self.l.text.layout.state == tr.STATE_ALIGNED-1 then
		self.l.text.layout:align()
	end
end

terra Layer:get_text() return self.l.text.layout.text.elements end
terra Layer:get_text_len(): int return self.l.text.layout.text_len end

terra Layer:set_text(s: &codepoint, len: int)
	self.l.text.layout:set_text(s, len)
	self:text_layout_changed()
end

terra Layer:set_text_utf8(s: rawstring, len: int)
	self.l.text.layout:set_text_utf8(s, len)
	self:text_layout_changed()
end

terra Layer:get_text_utf8(out: rawstring, max_outlen: int): int
	return self.l.text.layout:get_text_utf8(out, max_outlen)
end

terra Layer:get_text_utf8_len(): int
	return self.l.text.layout.text_utf8_len
end

terra Layer:get_text_maxlen(): int return self.l.text.layout.maxlen end
terra Layer:set_text_maxlen(v: int)
	self.l.text.layout.maxlen = v
	self:text_layout_changed()
end

terra Layer:get_text_dir(): enum return self.l.text.layout.dir end
terra Layer:set_text_dir(v: enum)
	self.l.text.layout.dir = v
	self:text_layout_changed()
end

terra Layer:get_text_align_x(): enum return self.l.text.layout.align_x end
terra Layer:get_text_align_y(): enum return self.l.text.layout.align_y end
terra Layer:set_text_align_x(v: enum) self.l.text.layout.align_x = v; self:text_layout_changed() end
terra Layer:set_text_align_y(v: enum) self.l.text.layout.align_y = v; self:text_layout_changed() end

terra Layer:get_line_spacing      (): num return self.l.text.layout.line_spacing end
terra Layer:get_hardline_spacing  (): num return self.l.text.layout.hardline_spacing end
terra Layer:get_paragraph_spacing (): num return self.l.text.layout.paragraph_spacing end

terra Layer:set_line_spacing      (v: num) self.l.text.layout.line_spacing      = clamp(v, -MAX_OFFSET, MAX_OFFSET); self:text_layout_changed() end
terra Layer:set_hardline_spacing  (v: num) self.l.text.layout.hardline_spacing  = clamp(v, -MAX_OFFSET, MAX_OFFSET); self:text_layout_changed() end
terra Layer:set_paragraph_spacing (v: num) self.l.text.layout.paragraph_spacing = clamp(v, -MAX_OFFSET, MAX_OFFSET); self:text_layout_changed() end

--text spans

terra Layer:get_span_count(): int
	return self.l.text.layout.span_count
end

terra Layer:set_span_count(n: int)
	n = clamp(n, 0, MAX_SPAN_COUNT)
	if self.span_count ~= n then
		self.l.text.layout.span_count = n
		self:text_layout_changed()
	end
end

local prefixed = {
	offset  =1,
	color   =1,
	opacity =1,
	operator=1,
}

for FIELD, T in sortedpairs(tr.SPAN_FIELD_TYPES) do

	local API_T = api_types[T] or T
	local PFIELD = prefixed[FIELD] and 'text_'..FIELD or FIELD

	Layer.methods['get_'..PFIELD] = terra(self: &Layer, i: int, j: int, out_v: &API_T)
		var v: T
		var has_value = self.l.text.layout:['get_'..FIELD](i, j, &v)
		@out_v = v
		return has_value
	end

	Layer.methods['set_'..PFIELD] = terra(self: &Layer, i: int, j: int, v: API_T)
		self.l.text.layout:['set_'..FIELD](i, j, v)
		self:text_layout_changed()
	end

	Layer.methods['get_span_'..PFIELD] = terra(self: &Layer, span_i: int): API_T
		return self.l.text.layout:['get_span_'..FIELD](span_i)
	end

	Layer.methods['set_span_'..PFIELD] = terra(self: &Layer, span_i: int, v: API_T)
		if span_i < MAX_SPAN_COUNT then
			self.l.text.layout:['set_span_'..FIELD](span_i, v)
			self:text_layout_changed()
		end
	end

end

terra Layer:get_span_offset(span_i: int): int
	return self.l.text.layout:get_span_offset(span_i)
end

terra Layer:set_span_offset(span_i: int, v: int)
	return self.l.text.layout:set_span_offset(span_i, v)
end

--text measuring and hit-testing

terra Layer:text_cursor_xs(line_i: int, outlen: &int)
	self:sync()
	var xs = self.l.text.layout:cursor_xs(line_i)
	@outlen = xs.len
	return xs.elements
end

--text cursor & selection

terra Layer:get_cursor_offset(): int
	self:sync()
	return iif(self.caret_created, self.caret.p.offset, 0)
end

terra Layer:set_cursor_offset(offset: int)
	self:sync()
	if not self.caret_created then return end
	self.caret:move_to_offset(max(offset, 0), 0)
	self.text_selection.p2 = self.caret.p
end

terra Layer:get_selection_offset1()
	self:sync()
	--
end

terra Layer:set_selection_offset1()
	self:sync()
	--
end


do end --layouts

terra Layer:get_visible(): bool return self.visible end
terra Layer:set_visible(v: bool)
	self:change(self.l, 'visible', v, 'minsize')
end

terra Layer:get_align_items_x (): enum return self.align_items_x end
terra Layer:get_align_items_y (): enum return self.align_items_y end
terra Layer:get_item_align_x  (): enum return self.item_align_x  end
terra Layer:get_item_align_y  (): enum return self.item_align_y  end
terra Layer:get_align_x       (): enum return self.align_x end
terra Layer:get_align_y       (): enum return self.align_y end

local is_align = macro(function(v)
	return `
		   v == ALIGN_LEFT  --also ALIGN_TOP
		or v == ALIGN_RIGHT --also ALIGN_RIGHT
		or v == ALIGN_CENTER
		or v == ALIGN_STRETCH
		or v == ALIGN_START
		or v == ALIGN_END
end)

local is_align_items = macro(function(v)
	return `
		   is_align(v)
		or v == ALIGN_SPACE_EVENLY
		or v == ALIGN_SPACE_AROUND
		or v == ALIGN_SPACE_BETWEEN
end)

terra Layer:set_align_items_x(v: enum)
	assert(is_align_items(v))
	self:change(self.l, 'align_items_x', v, 'layout')
end
terra Layer:set_align_items_y(v: enum)
	assert(is_align_items(v))
	self:change(self.l, 'align_items_y', v, 'layout')
end
terra Layer:set_item_align_x(v: enum)
	assert(is_align(v))
	self:change(self.l, 'item_align_x', v, 'layout')
end
terra Layer:set_item_align_y(v: enum)
	assert(is_align(v) or v == ALIGN_BASELINE)
	self:change(self.l, 'item_align_y', v, 'layout')
end

terra Layer:set_align_x(v: enum)
	assert(v == ALIGN_DEFAULT or is_align(v))
	self:change(self.l, 'align_x', v, 'layout')
end
terra Layer:set_align_y(v: enum)
	assert(v == ALIGN_DEFAULT or is_align(v))
	self:change(self.l, 'align_y', v, 'layout')
end

terra Layer:get_flex_flow(): enum return self.flex.flow end
terra Layer:set_flex_flow(v: enum)
	assert(v == FLEX_FLOW_X or v == FLEX_FLOW_Y)
	self:change(self.flex, 'flow', v, 'layout')
end

terra Layer:get_flex_wrap(): bool return self.flex.wrap end
terra Layer:set_flex_wrap(v: bool) self:change(self.flex, 'wrap', v, 'layout') end

terra Layer:get_fr(): num return self.fr end
terra Layer:set_fr(v: num) self:change(self.l, 'fr', max(v, 0), 'layout') end

terra Layer:get_break_before (): bool return self.break_before end
terra Layer:get_break_after  (): bool return self.break_after  end

terra Layer:set_break_before (v: bool) self:change(self.l, 'break_before', v, 'layout') end
terra Layer:set_break_after  (v: bool) self:change(self.l, 'break_after' , v, 'layout') end

terra Layer:get_grid_col_fr_count(): num return self.grid.col_frs.len end
terra Layer:get_grid_row_fr_count(): num return self.grid.row_frs.len end

terra Layer:set_grid_col_fr_count(n: int)
	n = min(n, MAX_GRID_ITEM_COUNT)
	if self.grid.col_frs.len ~= n then
		self.grid.col_frs:setlen(n, 1)
		self:layout_changed()
	end
end
terra Layer:set_grid_row_fr_count(n: int)
	n = min(n, MAX_GRID_ITEM_COUNT)
	if self.grid.row_frs.len ~= n then
		self.grid.row_frs:setlen(n, 1)
		self:layout_changed()
	end
end

terra Layer:get_grid_col_fr(i: int): num return self.grid.col_frs(i, 1) end
terra Layer:get_grid_row_fr(i: int): num return self.grid.row_frs(i, 1) end

terra Layer:set_grid_col_fr(i: int, v: num)
	if i < MAX_GRID_ITEM_COUNT then
		if self:get_grid_col_fr(i) ~= v then
			self.grid.col_frs:set(i, v, 1)
			self:layout_changed()
		end
	end
end
terra Layer:set_grid_row_fr(i: int, v: num)
	if i < MAX_GRID_ITEM_COUNT then
		if self:get_grid_row_fr(i) ~= v then
			self.grid.row_frs:set(i, v, 1)
			self:layout_changed()
		end
	end
end

terra Layer:get_grid_col_gap(): num return self.grid.col_gap end
terra Layer:get_grid_row_gap(): num return self.grid.row_gap end

terra Layer:set_grid_col_gap(v: num) self.grid.col_gap = clamp(v, -MAX_W, MAX_W) end
terra Layer:set_grid_row_gap(v: num) self.grid.row_gap = clamp(v, -MAX_W, MAX_W) end

terra Layer:get_grid_flow(): enum return self.grid.flow end
terra Layer:set_grid_flow(v: enum)
	assert(v >= 0 and v <= GRID_FLOW_MAX)
	self:change(self.grid, 'flow', v, 'layout')
end

terra Layer:get_grid_wrap(): int return self.grid.wrap end
terra Layer:set_grid_wrap(v: int)
	self:change(self.grid, 'wrap', clamp(v, 1, MAX_GRID_ITEM_COUNT), 'layout')
end

terra Layer:get_grid_min_lines(): int return self.grid.min_lines end
terra Layer:set_grid_min_lines(v: int)
	self:change(self.grid, 'min_lines', clamp(v, 1, MAX_GRID_ITEM_COUNT), 'layout')
end

terra Layer:get_min_cw(): num return self.min_cw end
terra Layer:get_min_ch(): num return self.min_ch end

terra Layer:set_min_cw(v: num) self:change(self.l, 'min_cw', clamp(v, 0, MAX_W), 'minsize') end
terra Layer:set_min_ch(v: num) self:change(self.l, 'min_ch', clamp(v, 0, MAX_W), 'minsize') end

terra Layer:get_grid_col(): int return self.grid_col end
terra Layer:get_grid_row(): int return self.grid_row end

terra Layer:set_grid_col(v: int) self:change(self.l, 'grid_col', clamp(v, -MAX_GRID_ITEM_COUNT, MAX_GRID_ITEM_COUNT), 'layout') end
terra Layer:set_grid_row(v: int) self:change(self.l, 'grid_row', clamp(v, -MAX_GRID_ITEM_COUNT, MAX_GRID_ITEM_COUNT), 'layout') end

terra Layer:get_grid_col_span(): int return self.grid_col_span end
terra Layer:get_grid_row_span(): int return self.grid_row_span end

terra Layer:set_grid_col_span(v: int) self:change(self.l, 'grid_col_span', clamp(v, 1, MAX_GRID_ITEM_COUNT), 'layout') end
terra Layer:set_grid_row_span(v: int) self:change(self.l, 'grid_row_span', clamp(v, 1, MAX_GRID_ITEM_COUNT), 'layout') end

--drawing & hit testing

terra Layer:get_hit_test_mask(): enum return self.l.hit_test_mask end
terra Layer:set_hit_test_mask(v: enum) self.l.hit_test_mask = v end

terra Layer:hit_test_c(cr: &context, x: num, y: num, reason: int, out: &&Layer): enum
	var layer, area = self:hit_test(cr, x, y, reason)
	@out = [&Layer](layer)
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
		get_top_layer=1,

		get_index=1,
		set_index=1,

		get_child_count=1,
		set_child_count=1,
		child=1,
		layer=1,
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

		get_cx=1,
		get_cy=1,
		get_cw=1,
		get_ch=1,

		set_cx=1,
		set_cy=1,
		set_cw=1,
		set_ch=1,

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

		get_padding=1,
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

		get_border_width=1,
		set_border_width=1,

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

		get_corner_radius=1,
		set_corner_radius=1,

		get_border_color_left   =1,
		get_border_color_right  =1,
		get_border_color_top    =1,
		get_border_color_bottom =1,

		set_border_color_left   =1,
		set_border_color_right  =1,
		set_border_color_top    =1,
		set_border_color_bottom =1,

		get_border_color=1,
		set_border_color=1,

		get_border_dash_count=1,
		set_border_dash_count=1,

		get_border_dash=1,
		set_border_dash=1,

		get_border_dash_offset=1,
		set_border_dash_offset=1,

		get_border_offset=1,
		set_border_offset=1,

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

		set_background_image=1,
		get_background_image_w=1,
		get_background_image_h=1,
		get_background_image_stride=1,
		get_background_image_pixels=1,
		get_background_image_format=1,
		background_image_invalidate=1,
		background_image_invalidate_rect=1,

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

		get_shadow_count=1,
		set_shadow_count=1,

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

		get_line_spacing      =1,
		get_hardline_spacing  =1,
		get_paragraph_spacing =1,

		set_line_spacing      =1,
		set_hardline_spacing  =1,
		set_paragraph_spacing =1,

		get_font_id           =1,
		get_font_size         =1,
		get_features          =1,
		get_script            =1,
		get_lang              =1,
		get_paragraph_dir     =1,
		get_nowrap            =1,
		get_text_color        =1,
		get_text_opacity      =1,
		get_text_operator     =1,

		set_font_id           =1,
		set_font_size         =1,
		set_features          =1,
		set_script            =1,
		set_lang              =1,
		set_paragraph_dir     =1,
		set_nowrap            =1,
		set_text_color        =1,
		set_text_opacity      =1,
		set_text_operator     =1,

		get_span_count=1,
		set_span_count=1,

		get_span_font_id           =1,
		get_span_font_size         =1,
		get_span_features          =1,
		get_span_script            =1,
		get_span_lang              =1,
		get_span_paragraph_dir     =1,
		get_span_nowrap            =1,
		get_span_text_color        =1,
		get_span_text_opacity      =1,
		get_span_text_operator     =1,

		set_span_font_id           =1,
		set_span_font_size         =1,
		set_span_features          =1,
		set_span_script            =1,
		set_span_lang              =1,
		set_span_paragraph_dir     =1,
		set_span_nowrap            =1,
		set_span_text_color        =1,
		set_span_text_opacity      =1,
		set_span_text_operator     =1,

		get_span_offset=1,
		set_span_offset=1,

		get_text_selectable=1,
		set_text_selectable=1,

		get_cursor_offset=1,
		set_cursor_offset=1,

		text_cursor_xs=1,

		get_text_caret_width=1,
		get_text_caret_color=1,
		get_text_caret_insert_mode=1,

		set_text_caret_width=1,
		set_text_caret_color=1,
		set_text_caret_insert_mode=1,

		--

		--layouts

		get_in_transition=1,
		set_in_transition=1,

		get_final_x=1,
		get_final_y=1,
		get_final_w=1,
		get_final_h=1,

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

		top_layer_sync=1,
		top_layer_draw=1,
		sync_layout_separate_axes=1, --for scrollbox
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
	print('sizeof Layer', sizeof(Layer))
end

return _M
