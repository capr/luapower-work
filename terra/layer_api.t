--[[

	CLayer C/ffi API.

	- creates a flattened API tailored to ffi use:
		- using doubles in place of int types for better range checking.
		- types are enlarged and simplified for forward compatibility.
		- enum values are consecutive for forward compatibility.
	- validates enums, clamps numbers to range.
	- invalidates state automatically when input values are updated.
	- synchronizes state automatically when computed values are accessed.
	- adds self-allocating constructors.

]]


local layer = require'terra/layer'
setfenv(1, require'terra/low'.module(layer))

--API types ------------------------------------------------------------------

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

--Lib & Layer wrappers -------------------------------------------------------

struct CLib (gettersandsetters) {
	l: layer.Lib;
}

struct CLayer (gettersandsetters) {
	l: layer.Layer;
}

--layout sync'ing: called by computed-value accessors.
terra CLayer.methods.sync :: {&CLayer} -> bool

--range limits ---------------------------------------------------------------

local MAX_U32 = 2^32-1
local MAX_X = 10^9
local MAX_W = 10^9
local MAX_RASTER_W = 20000
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

terra CLib:init(load_font: FontLoadFunc, unload_font: FontLoadFunc)
	self.l:init(load_font, unload_font)
end
terra CLib:free() self.l:free() end

local terra layerlib_new(load_font: FontLoadFunc, unload_font: FontLoadFunc)
	return new(CLib, load_font, unload_font)
end

terra CLib:release()
	release(self)
end

do end --text rendering engine configuration

ErrorFunction.cname = 'error_function_t'

terra CLib:get_font_size_resolution       (): num return self.l.text_renderer.font_size_resolution end
terra CLib:get_subpixel_x_resolution      (): num return self.l.text_renderer.subpixel_x_resolution end
terra CLib:get_word_subpixel_x_resolution (): num return self.l.text_renderer.word_subpixel_x_resolution end
terra CLib:get_glyph_cache_size           (): int return self.l.text_renderer.glyph_cache_size end
terra CLib:get_glyph_run_cache_size       (): int return self.l.text_renderer.glyph_run_cache_size end
terra CLib:get_error_function             (): ErrorFunction return self.l.error_function end

terra CLib:set_font_size_resolution       (v: num) self.l.text_renderer.font_size_resolution = v end
terra CLib:set_subpixel_x_resolution      (v: num) self.l.text_renderer.subpixel_x_resolution = v end
terra CLib:set_word_subpixel_x_resolution (v: num) self.l.text_renderer.word_subpixel_x_resolution = v end
terra CLib:set_glyph_cache_size           (v: int) self.l.text_renderer.glyph_cache_max_size = v end
terra CLib:set_glyph_run_cache_size       (v: int) self.l.text_renderer.glyph_run_cache_max_size = v end
terra CLib:set_error_function             (v: ErrorFunction) self.l.error_function = v end

do end --font registration

terra CLib:font(): int
	return self.l.text_renderer:font()
end

do end --layer new/release

terra CLayer:init(lib: &CLib, parent: &CLayer)
	self.l:init(&lib.l, &parent.l)
end
terra CLayer:free() self.l:free() end

terra CLayer:release()
	if self.l.parent ~= nil then
		self.l.parent.children:remove(self.l.index)
		self.l.parent:invalidate'layout'
	else
		self.l:free()
	end
end

terra CLib:layer()
	return new(CLayer, self, nil)
end

do end --layer hierarchy

terra CLayer:get_lib() return [&CLib](self.l.lib) end
terra CLayer:get_parent() return [&CLayer](self.l.parent) end
terra CLayer:get_index(): int return self.l.index end
terra CLayer:get_pos_parent() return [&CLayer](self.l.pos_parent) end
terra CLayer:get_top_layer() return [&CLayer](self.l.top_layer) end
terra CLayer:child(i: int) return [&CLayer](self.l:child(i)) end

terra CLayer:set_parent(parent: &CLayer)
	self.l:move(&parent.l, maxint) --does arg checking and invalidation
end

terra CLayer:set_index(i: int)
	self.l:move(self.l.parent, i) --does arg checking and invalidation
end

terra CLayer:set_pos_parent(parent: &CLayer)
	self.l.pos_parent = &parent.l --does arg checking and invalidation
end

terra CLayer:layer()
	var e = self.lib:layer()
	e.parent = self --does arg checking and invalidation
	return e
end

terra CLayer:get_child_count(): int
	return self.l.children.len
end

local new_child = macro(function(self, e)
	return quote @e = new(Layer, self.lib, self) end
end)
terra CLayer:set_child_count(n: int)
	self.l:changelen(self.l.children,
		clamp(n, 0, MAX_CHILD_COUNT), new_child,
		'layout pixels content_shadows parent_content_shadows')
end

do end --geometry

terra CLayer:get_x(): num return self.l.x end
terra CLayer:get_y(): num return self.l.y end
terra CLayer:get_w(): num return self.l.w end
terra CLayer:get_h(): num return self.l.h end

terra CLayer:set_x(v: num) self.l:change(self.l, 'x', clamp(v, -MAX_X, MAX_X)) end
terra CLayer:set_y(v: num) self.l:change(self.l, 'y', clamp(v, -MAX_X, MAX_X)) end
terra CLayer:set_w(v: num) self.l:change(self.l, 'w', clamp(v, -MAX_W, MAX_W)) end
terra CLayer:set_h(v: num) self.l:change(self.l, 'h', clamp(v, -MAX_W, MAX_W)) end

terra CLayer:get_cx(): num return self.l.cx end
terra CLayer:get_cy(): num return self.l.cy end
terra CLayer:get_cw(): num return self.l.cw end
terra CLayer:get_ch(): num return self.l.ch end

terra CLayer:set_cx(v: num) self.l:change(self.l, 'cx', clamp(v, -MAX_X, MAX_X)) end
terra CLayer:set_cy(v: num) self.l:change(self.l, 'cy', clamp(v, -MAX_X, MAX_X)) end
terra CLayer:set_cw(v: num) self.l:change(self.l, 'cw', clamp(v, -MAX_W, MAX_W)) end
terra CLayer:set_ch(v: num) self.l:change(self.l, 'ch', clamp(v, -MAX_W, MAX_W)) end

terra CLayer:get_in_transition(): bool return self.l.in_transition end
terra CLayer:set_in_transition(v: bool) self.l.in_transition = v end

terra CLayer:get_final_x(): num return self.l.final_x end
terra CLayer:get_final_y(): num return self.l.final_y end
terra CLayer:get_final_w(): num return self.l.final_w end
terra CLayer:get_final_h(): num return self.l.final_h end

for i,SIDE in ipairs{'left', 'right', 'top', 'bottom'} do

	CLayer.methods['get_padding_'..SIDE] = terra(self: &CLayer)
		return self.l.['padding_'..SIDE]
	end

	CLayer.methods['set_padding_'..SIDE] = terra(self: &CLayer, v: num)
		self.l:change(self.l, ['padding_'..SIDE], clamp(v, -MAX_W, MAX_W), 'pixels layout')
	end

end

terra CLayer:get_padding(): num
	return (
		  self.padding_left
		+ self.padding_right
		+ self.padding_top
		+ self.padding_bottom) / 4
end

terra CLayer:set_padding(v: num)
	self.padding_left   = v
	self.padding_right  = v
	self.padding_top    = v
	self.padding_bottom = v
end

do end --drawing

terra CLayer:get_operator     (): enum return self.l.operator end
terra CLayer:get_clip_content (): bool return self.l.clip_content end
terra CLayer:get_snap_x       (): bool return self.l.snap_x end
terra CLayer:get_snap_y       (): bool return self.l.snap_y end
terra CLayer:get_opacity      (): num  return self.l.opacity end

terra CLayer:set_operator     (v: enum)
	if self.l:checkrange('operator', v, OPERATOR_MIN, OPERATOR_MAX) then
		self.l:change(self.l, 'operator', v, 'pixels parent_content_shadows')
	end
end
terra CLayer:set_clip_content (v: bool) self.l:change(self.l, 'clip_content', v, 'pixels content_shadows parent_content_shadows') end
terra CLayer:set_snap_x       (v: bool) self.l:change(self.l, 'snap_x', v, 'pixels content_shadows parent_content_shadows') end
terra CLayer:set_snap_y       (v: bool) self.l:change(self.l, 'snap_y', v, 'pixels content_shadows parent_content_shadows') end
terra CLayer:set_opacity      (v: num)  self.l:change(self.l, 'opacity', clamp(v, 0, 1), 'pixels parent_content_shadows') end

do end --transforms

terra CLayer:get_rotation    (): num return self.l.transform.rotation    end
terra CLayer:get_rotation_cx (): num return self.l.transform.rotation_cx end
terra CLayer:get_rotation_cy (): num return self.l.transform.rotation_cy end
terra CLayer:get_scale       (): num return self.l.transform.scale       end
terra CLayer:get_scale_cx    (): num return self.l.transform.scale_cx    end
terra CLayer:get_scale_cy    (): num return self.l.transform.scale_cy    end

terra CLayer:set_rotation    (v: num) self.l:change(self.l.transform, 'rotation'   , v                             , 'pixels parent_content_shadows') end
terra CLayer:set_rotation_cx (v: num) self.l:change(self.l.transform, 'rotation_cx', clamp(v, -MAX_X, MAX_X)       , 'pixels parent_content_shadows') end
terra CLayer:set_rotation_cy (v: num) self.l:change(self.l.transform, 'rotation_cy', clamp(v, -MAX_X, MAX_X)       , 'pixels parent_content_shadows') end
terra CLayer:set_scale       (v: num) self.l:change(self.l.transform, 'scale'      , clamp(v, MIN_SCALE, MAX_SCALE), 'pixels parent_content_shadows') end
terra CLayer:set_scale_cx    (v: num) self.l:change(self.l.transform, 'scale_cx'   , clamp(v, -MAX_X, MAX_X)       , 'pixels parent_content_shadows') end
terra CLayer:set_scale_cy    (v: num) self.l:change(self.l.transform, 'scale_cy'   , clamp(v, -MAX_X, MAX_X)       , 'pixels parent_content_shadows') end

do end --borders

for i,SIDE in ipairs{'left', 'right', 'top', 'bottom'} do

	CLayer.methods['get_border_width_'..SIDE] = terra(self: &CLayer): num
		return self.l.border.['width_'..SIDE]
	end

	CLayer.methods['set_border_width_'..SIDE] = terra(self: &CLayer, v: num)
		self.l:change(self.l.border, ['width_'..SIDE], clamp(v, 0, MAX_W),
			'pixels box_shadows parent_content_shadows')
	end

	CLayer.methods['get_border_color_'..SIDE] = terra(self: &CLayer): uint32
		return self.l.border.['color_'..SIDE].uint
	end

	CLayer.methods['set_border_color_'..SIDE] = terra(self: &CLayer, v: uint32)
		self.l:change(self.l.border, ['color_'..SIDE],
			color{uint = clamp(v, 0, MAX_U32)},
			'pixels parent_content_shadows')
	end

end

terra CLayer:get_border_width(): num
	return (
		  self.border_width_left
		+ self.border_width_right
		+ self.border_width_top
		+ self.border_width_bottom) / 4
end

terra CLayer:set_border_width(v: num)
	self.border_width_left   = v
	self.border_width_right  = v
	self.border_width_top    = v
	self.border_width_bottom = v
end

terra CLayer:get_border_color(): uint32
	return
		   self.l.border.color_left.uint
		or self.l.border.color_right.uint
		or self.l.border.color_top.uint
		or self.l.border.color_bottom.uint
end

terra CLayer:set_border_color(v: num)
	self.border_color_left   = v
	self.border_color_right  = v
	self.border_color_top    = v
	self.border_color_bottom = v
end

for i,CORNER in ipairs{'top_left', 'top_right', 'bottom_left', 'bottom_right'} do

	local RADIUS = 'corner_radius_'..CORNER

	CLayer.methods['get_'..RADIUS] = terra(self: &CLayer): num
		return self.l.border.[RADIUS]
	end

	CLayer.methods['set_'..RADIUS] = terra(self: &CLayer, v: num)
		self.l:change(self.l.border, RADIUS, clamp(v, 0, MAX_W),
			'pixels box_shadows parent_content_shadows')
	end

end

terra CLayer:get_corner_radius(): num
	return (
		  self.corner_radius_top_left
		+ self.corner_radius_top_right
		+ self.corner_radius_bottom_left
		+ self.corner_radius_bottom_right) / 4
end

terra CLayer:set_corner_radius(v: num)
	self.corner_radius_top_left     = v
	self.corner_radius_top_right    = v
	self.corner_radius_bottom_left  = v
	self.corner_radius_bottom_right = v
end

terra CLayer:get_border_dash_count(): int return self.l.border.dash.len end
terra CLayer:set_border_dash_count(v: int)
	self.l:changelen(self.l.border.dash, clamp(v, 0, MAX_BORDER_DASH_COUNT), 1,
		'pixels parent_content_shadows')
end

terra CLayer:get_border_dash(i: int): int
	return self.l.border.dash(i, 1)
end
terra CLayer:set_border_dash(i: int, v: double)
	if i >= 0 and i < MAX_BORDER_DASH_COUNT then
		v = clamp(v, 0.0001, MAX_W)
		if self.l.border.dash(i, 0) ~= v then
			self.l.border.dash:set(i, v, 1)
			self.l:invalidate'pixels parent_content_shadows'
		end
	end
end

terra CLayer:get_border_dash_offset(): num return self.l.border.dash_offset end
terra CLayer:set_border_dash_offset(v: num)
	self.l:change(self.l.border, 'dash_offset', clamp(v, -MAX_W, MAX_W),
		'pixels parent_content_shadows')
end

terra CLayer:get_border_offset(): num return self.l.border.offset end
terra CLayer:set_border_offset(v: num)
	self.l:change(self.l.border, 'offset', clamp(v, -MAX_OFFSET, MAX_OFFSET),
		'pixels box_shadows parent_content_shadows')
end

CBorderLineToFunc = {&CLayer, &context, num, num, num} -> {}
CBorderLineToFunc.cname = 'll_border_lineto_func'

terra CLayer:set_border_line_to(line_to: CBorderLineToFunc)
	self.l.border.line_to = BorderLineToFunc(line_to)
	self.l:invalidate'pixels box_shadows parent_content_shadows'
end

do end --backgrounds

terra CLayer:get_background_type(): enum return self.l.background.type end
terra CLayer:set_background_type(v: enum)
	if self.l:checkrange('background_type', v, BACKGROUND_TYPE_MIN, BACKGROUND_TYPE_MAX) then
		self.l:change(self.l.background, 'type', v, 'background pixels parent_content_shadows')
	end
end

terra CLayer:get_background_hittable(): bool return self.l.background.hittable end
terra CLayer:set_background_hittable(v: bool) self.l.background.hittable = v end

terra CLayer:get_background_operator(): enum return self.l.background.operator end
terra CLayer:set_background_operator(v: enum)
	if self.l:checkrange('background_operator', v, OPERATOR_MIN, OPERATOR_MAX) then
		self.l:change(self.l.background, 'operator', v, 'pixels parent_content_shadows')
	end
end

terra CLayer:get_background_opacity(): num return self.l.background.opacity end
terra CLayer:set_background_opacity(v: num)
	self.l:change(self.l.background, 'opacity',
		clamp(v, 0, 1), 'pixels parent_content_shadows')
end

terra CLayer:get_background_clip_border_offset(): num
	return self.l.background.clip_border_offset
end
terra CLayer:set_background_clip_border_offset(v: num)
	self.l:change(self.l.background, 'clip_border_offset',
		clamp(v, -MAX_OFFSET, MAX_OFFSET), 'pixels content_shadows parent_content_shadows')
end

terra CLayer:get_background_color(): uint32 return self.l.background.color.uint end
terra CLayer:set_background_color(v: uint32)
	if self.l.background.type == BACKGROUND_TYPE_NONE then
		--switch type automatically, but only from `none` to `color` type to
		--avoid side-effects in a sequence of property assignments.
		self.l.background.type = BACKGROUND_TYPE_COLOR
	end
	v = clamp(v, 0, MAX_U32)
	if self.l:change(self.l.background, 'color', color{uint = v}) then
		if self.l.background.type == BACKGROUND_TYPE_COLOR then
			self.l:invalidate'pixels parent_content_shadows'
		end
	end
end

for i,FIELD in ipairs{'x1', 'y1', 'x2', 'y2', 'r1', 'r2'} do

	local MAX = FIELD:find'^r' and MAX_W or MAX_X

	CLayer.methods['get_background_'..FIELD] = terra(self: &CLayer): num
		return self.l.background.pattern.gradient.[FIELD]
	end

	CLayer.methods['set_background_'..FIELD] = terra(self: &CLayer, v: num)
		if self.l:change(self.l.background.pattern.gradient, FIELD,
			clamp(v, -MAX, MAX), 'background')
		then
			if self.l.background.is_gradient then
				self.l:invalidate'pixels parent_content_shadows'
			end
		end
	end

end

terra CLayer:get_background_color_stop_count(): int
	return self.l.background.pattern.gradient.color_stops.len
end

terra CLayer:set_background_color_stop_count(n: int)
	if self.l:changelen(self.l.background.pattern.gradient.color_stops,
		clamp(n, 0, MAX_COLOR_STOP_COUNT), ColorStop{0, 0}, 'background')
	then
		if self.l.background.is_gradient then
			self.l:invalidate'pixels parent_content_shadows'
		end
	end
end

terra CLayer:get_background_color_stop_color(i: int): uint32
	return self.l.background.pattern.gradient.color_stops(i, ColorStop{0, 0}).color.uint
end

terra CLayer:get_background_color_stop_offset(i: int): num
	return self.l.background.pattern.gradient.color_stops(i, ColorStop{0, 0}).offset
end

terra CLayer:set_background_color_stop_color(i: int, v: uint32)
	if i >= 0 and i < MAX_COLOR_STOP_COUNT then
		v = clamp(v, 0, MAX_U32)
		if self:get_background_color_stop_color(i) ~= v then
			self.l.background.pattern.gradient.color_stops:getat(i, ColorStop{0, 0}).color.uint = v
			self.l:invalidate'background'
			if self.l.background.is_gradient then
				self.l:invalidate'pixels parent_content_shadows'
			end
		end
	end
end

terra CLayer:set_background_color_stop_offset(i: int, v: num)
	if i >= 0 and i < MAX_COLOR_STOP_COUNT then
		v = clamp(v, 0, 1)
		if self:get_background_color_stop_offset(i) ~= v then
			self.l.background.pattern.gradient.color_stops:getat(i, ColorStop{0, 0}).offset = v
			self.l:invalidate'background'
			if self.l.background.is_gradient then
				self.l:invalidate'pixels parent_content_shadows'
			end
		end
	end
end

terra CLayer:set_background_image(w: int, h: int, format: enum, stride: int, pixels: &uint8)
	w = clamp(w, 0, MAX_RASTER_W)
	h = clamp(h, 0, MAX_RASTER_W)
	stride = max(stride, -1)
	var b = &self.l.background.pattern.bitmap
	if    b.w ~= w
		or b.h ~= h
		or b.format ~= format
		or b.stride ~= stride
		or b.pixels ~= pixels
	then
		self.l.background.pattern:set_bitmap(w, h, format, stride, pixels)
		self.l:invalidate'background'
		if self.l.background.type == BACKGROUND_TYPE_IMAGE then
			self.l:invalidate'pixels parent_content_shadows'
		end
	end
end

terra CLayer:get_background_image_w      (): num  return self.l.background.pattern.bitmap.w end
terra CLayer:get_background_image_h      (): num  return self.l.background.pattern.bitmap.h end
terra CLayer:get_background_image_stride (): int  return self.l.background.pattern.bitmap.stride end
terra CLayer:get_background_image_format (): enum return self.l.background.pattern.bitmap.format end
terra CLayer:get_background_image_pixels()
	var s = self.l.background.pattern.bitmap_surface
	if s ~= nil then s:flush() end
	return self.l.background.pattern.bitmap.pixels
end
terra CLayer:background_image_invalidate()
	var s = self.l.background.pattern.bitmap_surface
	if s ~= nil then
		s:mark_dirty()
		self.l:invalidate'pixels parent_content_shadows'
	end
end
terra CLayer:background_image_invalidate_rect(x: int, y: int, w: int, h: int)
	var s = self.l.background.pattern.bitmap_surface
	if s ~= nil then
		s:mark_dirty_rectangle(x, y, w, h)
		self.l:invalidate'pixels parent_content_shadows'
	end
end

terra CLayer:get_background_x      (): num  return self.l.background.pattern.x end
terra CLayer:get_background_y      (): num  return self.l.background.pattern.y end
terra CLayer:get_background_extend (): enum return self.l.background.pattern.extend end

terra CLayer:set_background_x      (v: num) self.l.background.pattern.x = clamp(v, -MAX_X, MAX_X) end
terra CLayer:set_background_y      (v: num) self.l.background.pattern.y = clamp(v, -MAX_X, MAX_X) end
terra CLayer:set_background_extend (v: enum)
	if self.l:checkrange('background_extend', v, BACKGROUND_EXTEND_MIN, BACKGROUND_EXTEND_MAX) then
		self.l:change(self.l.background.pattern, 'extend', v, 'pixels parent_content_shadows')
	end
end

terra CLayer:get_background_rotation    (): num return self.l.background.pattern.transform.rotation    end
terra CLayer:get_background_rotation_cx (): num return self.l.background.pattern.transform.rotation_cx end
terra CLayer:get_background_rotation_cy (): num return self.l.background.pattern.transform.rotation_cy end
terra CLayer:get_background_scale       (): num return self.l.background.pattern.transform.scale       end
terra CLayer:get_background_scale_cx    (): num return self.l.background.pattern.transform.scale_cx    end
terra CLayer:get_background_scale_cy    (): num return self.l.background.pattern.transform.scale_cy    end

terra CLayer:set_background_rotation    (v: num) self.l:change(self.l.background.pattern.transform, 'rotation'   , v, 'pixels parent_content_shadows') end
terra CLayer:set_background_rotation_cx (v: num) self.l:change(self.l.background.pattern.transform, 'rotation_cx', clamp(v, -MAX_X, MAX_X), 'pixels parent_content_shadows') end
terra CLayer:set_background_rotation_cy (v: num) self.l:change(self.l.background.pattern.transform, 'rotation_cy', clamp(v, -MAX_X, MAX_X), 'pixels parent_content_shadows') end
terra CLayer:set_background_scale       (v: num) self.l:change(self.l.background.pattern.transform, 'scale'      , clamp(v, MIN_SCALE, MAX_SCALE), 'pixels parent_content_shadows') end
terra CLayer:set_background_scale_cx    (v: num) self.l:change(self.l.background.pattern.transform, 'scale_cx'   , clamp(v, -MAX_X, MAX_X), 'pixels parent_content_shadows') end
terra CLayer:set_background_scale_cy    (v: num) self.l:change(self.l.background.pattern.transform, 'scale_cy'   , clamp(v, -MAX_X, MAX_X), 'pixels parent_content_shadows') end

do end --shadows

terra CLayer:get_shadow_count(): int
	return self.l.shadows.len
end

local new_shadow = macro(function(self, s)
	return quote s:init(self) end
end)
terra CLayer:set_shadow_count(n: int)
	self.l:changelen(self.l.shadows,
		clamp(n, 0, MAX_SHADOW_COUNT), new_shadow,
		'pixels parent_content_shadows')
end

local terra shadow(self: &CLayer, i: int)
	return self.l.shadows:at(i, &self.l.lib.default_shadow)
end

terra CLayer:get_shadow_x       (i: int): num    return shadow(self, i).offset_x end
terra CLayer:get_shadow_y       (i: int): num    return shadow(self, i).offset_y end
terra CLayer:get_shadow_color   (i: int): uint32 return shadow(self, i).color.uint end
terra CLayer:get_shadow_blur    (i: int): int    return shadow(self, i).blur_radius end
terra CLayer:get_shadow_passes  (i: int): int    return shadow(self, i).blur_passes end
terra CLayer:get_shadow_inset   (i: int): bool   return shadow(self, i).inset end
terra CLayer:get_shadow_content (i: int): bool   return shadow(self, i).content end

local change_shadow = macro(function(self, i, FIELD, v, changed)
	FIELD = FIELD:asvalue()
	return quote
		if i >= 0 and i < MAX_SHADOW_COUNT then
			var s, new_shadows = self.l.shadows:getat(i)
			for _,s in new_shadows do
				s:init(&self.l)
			end
			if s.[FIELD] ~= v then
				s.[FIELD] = v
				self.l:invalidate'pixels parent_content_shadows'
			end
		end
	end
end)

terra CLayer:set_shadow_x       (i: int, v: num)    change_shadow(self, i, 'offset_x'   , clamp(v, -MAX_X, MAX_X)) end
terra CLayer:set_shadow_y       (i: int, v: num)    change_shadow(self, i, 'offset_y'   , clamp(v, -MAX_X, MAX_X)) end
terra CLayer:set_shadow_color   (i: int, v: uint32) change_shadow(self, i, 'color'      , color{uint = clamp(v, 0, MAX_U32)}) end
terra CLayer:set_shadow_blur    (i: int, v: int)    change_shadow(self, i, 'blur_radius', clamp(v, 0, 255)) end
terra CLayer:set_shadow_passes  (i: int, v: int)    change_shadow(self, i, 'blur_passes', clamp(v, 0, 10)) end
terra CLayer:set_shadow_inset   (i: int, v: bool)   change_shadow(self, i, 'inset'      , v) end
terra CLayer:set_shadow_content (i: int, v: bool)   change_shadow(self, i, 'content'    , v) end

do end --text

terra CLayer:get_text() return self.l.text.layout.text.elements end
terra CLayer:get_text_len(): int return self.l.text.layout.text_len end

terra CLayer:set_text(s: &codepoint, len: int)
	self.l.text.layout:set_text(s, len)
	self.l:invalidate_text()
end

terra CLayer:set_text_utf8(s: rawstring, len: int)
	self.l.text.layout:set_text_utf8(s, len)
	self.l:invalidate_text()
end

terra CLayer:get_text_utf8(out: rawstring, max_outlen: int): int
	return self.l.text.layout:get_text_utf8(out, max_outlen)
end

terra CLayer:get_text_utf8_len(): int
	return self.l.text.layout.text_utf8_len
end

terra CLayer:get_text_maxlen(): int return self.l.text.layout.maxlen end
terra CLayer:set_text_maxlen(v: int)
	self.l.text.layout.maxlen = v
	self.l:invalidate_text()
end

terra CLayer:get_text_dir(): enum return self.l.text.layout.dir end
terra CLayer:set_text_dir(v: enum)
	self.l.text.layout.dir = v
	self.l:invalidate_text()
end

terra CLayer:get_text_align_x(): enum return self.l.text.layout.align_x end
terra CLayer:get_text_align_y(): enum return self.l.text.layout.align_y end
terra CLayer:set_text_align_x(v: enum) self.l.text.layout.align_x = v; self.l:invalidate_text() end
terra CLayer:set_text_align_y(v: enum) self.l.text.layout.align_y = v; self.l:invalidate_text() end

terra CLayer:get_line_spacing      (): num return self.l.text.layout.line_spacing end
terra CLayer:get_hardline_spacing  (): num return self.l.text.layout.hardline_spacing end
terra CLayer:get_paragraph_spacing (): num return self.l.text.layout.paragraph_spacing end

terra CLayer:set_line_spacing      (v: num) self.l.text.layout.line_spacing      = clamp(v, -MAX_OFFSET, MAX_OFFSET); self.l:invalidate_text() end
terra CLayer:set_hardline_spacing  (v: num) self.l.text.layout.hardline_spacing  = clamp(v, -MAX_OFFSET, MAX_OFFSET); self.l:invalidate_text() end
terra CLayer:set_paragraph_spacing (v: num) self.l.text.layout.paragraph_spacing = clamp(v, -MAX_OFFSET, MAX_OFFSET); self.l:invalidate_text() end

--text spans

terra CLayer:get_span_count(): int
	return self.l.text.layout.span_count
end

terra CLayer:set_span_count(n: int)
	n = clamp(n, 0, MAX_SPAN_COUNT)
	if self.span_count ~= n then
		self.l.text.layout.span_count = n
		self.l:invalidate_text()
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

	CLayer.methods['get_'..PFIELD] = terra(self: &CLayer, i: int, j: int, out_v: &API_T)
		var v: T
		var has_value = self.l.text.layout:['get_'..FIELD](i, j, &v)
		@out_v = v
		return has_value
	end

	CLayer.methods['set_'..PFIELD] = terra(self: &CLayer, i: int, j: int, v: API_T)
		self.l.text.layout:['set_'..FIELD](i, j, v)
		self.l:invalidate_text()
	end

	CLayer.methods['get_span_'..PFIELD] = terra(self: &CLayer, span_i: int): API_T
		return self.l.text.layout:['get_span_'..FIELD](span_i)
	end

	CLayer.methods['set_span_'..PFIELD] = terra(self: &CLayer, span_i: int, v: API_T)
		if span_i < MAX_SPAN_COUNT then
			self.l.text.layout:['set_span_'..FIELD](span_i, v)
			self.l:invalidate_text()
		end
	end

end

terra CLayer:get_span_offset(span_i: int): int
	return self.l.text.layout:get_span_offset(span_i)
end

terra CLayer:set_span_offset(span_i: int, v: int)
	return self.l.text.layout:set_span_offset(span_i, v)
end

--text measuring and hit-testing

terra CLayer:text_cursor_xs(line_i: int, outlen: &int)
	self:sync()
	var xs = self.l.text.layout:cursor_xs(line_i)
	@outlen = xs.len
	return xs.elements
end

--text cursor & selection

terra CLayer:get_text_selectable(): bool return self.l.text_selectable end
terra CLayer:set_text_selectable(v: bool)
	self.l:change(self.l, 'text_selectable', v, 'pixels')
end

terra CLayer:get_cursor_offset(): int
	self:sync()
	return iif(self.l.caret_created, self.l.caret.p.offset, 0)
end

terra CLayer:set_cursor_offset(offset: int)
	self:sync()
	if self.l.caret_created then
		self.l.caret:move_to_offset(max(offset, 0), 0)
		self.l.text_selection.p2 = self.l.caret.p
		self.l:invalidate_pixels()
	end
end

terra CLayer:get_selection_offset1()
	self:sync()
	--
end

terra CLayer:set_selection_offset1()
	self:sync()
	--
end


do end --layouts

terra CLayer:get_visible(): bool return self.l.visible end
terra CLayer:set_visible(v: bool)
	if self.l:change(self.l, 'visible', v) then
		self.l.top_layer.pixels_valid = false
		if self.l.pos_parent == nil then
			self.l.top_layer.layout_valid = false
		end
	end
end

terra CLayer:get_layout_type(): enum return self.l.layout_type end
terra CLayer:set_layout_type(v: enum)
	self.l:change(self.l, 'layout_type', v, 'layout')
end

terra CLayer:get_align_items_x (): enum return self.l.align_items_x end
terra CLayer:get_align_items_y (): enum return self.l.align_items_y end
terra CLayer:get_item_align_x  (): enum return self.l.item_align_x  end
terra CLayer:get_item_align_y  (): enum return self.l.item_align_y  end
terra CLayer:get_align_x       (): enum return self.l.align_x end
terra CLayer:get_align_y       (): enum return self.l.align_y end

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

terra CLayer:set_align_items_x(v: enum)
	if self.l:check('align_items_x', v, is_align_items(v)) then
		self.l:change(self.l, 'align_items_x', v, 'layout')
	end
end
terra CLayer:set_align_items_y(v: enum)
	if self.l:check('align_items_y', v, is_align_items(v)) then
		self.l:change(self.l, 'align_items_y', v, 'layout')
	end
end
terra CLayer:set_item_align_x(v: enum)
	if self.l:check('item_align_x', v, is_align(v)) then
		self.l:change(self.l, 'item_align_x', v, 'layout')
	end
end
terra CLayer:set_item_align_y(v: enum)
	if self.l:check('item_align_y', v, is_align(v) or v == ALIGN_BASELINE) then
		self.l:change(self.l, 'item_align_y', v, 'layout')
	end
end

terra CLayer:set_align_x(v: enum)
	if self.l:check('align_x', v, v == ALIGN_DEFAULT or is_align(v)) then
		self.l:change(self.l, 'align_x', v, 'layout')
	end
end
terra CLayer:set_align_y(v: enum)
	if self.l:check('align_y', v, v == ALIGN_DEFAULT or is_align(v)) then
		self.l:change(self.l, 'align_y', v, 'layout')
	end
end

terra CLayer:get_flex_flow(): enum return self.l.flex.flow end
terra CLayer:set_flex_flow(v: enum)
	if self.l:checkrange('flex_flow', v, FLEX_FLOW_MIN, FLEX_FLOW_MAX) then
		self.l:change(self.l.flex, 'flow', v, 'layout')
	end
end

terra CLayer:get_flex_wrap(): bool return self.l.flex.wrap end
terra CLayer:set_flex_wrap(v: bool) self.l:change(self.l.flex, 'wrap', v, 'layout') end

terra CLayer:get_fr(): num return self.l.fr end
terra CLayer:set_fr(v: num) self.l:change(self.l, 'fr', max(v, 0), 'layout') end

terra CLayer:get_break_before (): bool return self.l.break_before end
terra CLayer:get_break_after  (): bool return self.l.break_after  end

terra CLayer:set_break_before (v: bool) self.l:change(self.l, 'break_before', v, 'layout') end
terra CLayer:set_break_after  (v: bool) self.l:change(self.l, 'break_after' , v, 'layout') end

terra CLayer:get_grid_col_fr_count(): num return self.l.grid.col_frs.len end
terra CLayer:get_grid_row_fr_count(): num return self.l.grid.row_frs.len end

terra CLayer:set_grid_col_fr_count(n: int)
	self.l:changelen(self.l.grid.col_frs, min(n, MAX_GRID_ITEM_COUNT), 1, 'layout')
end
terra CLayer:set_grid_row_fr_count(n: int)
	self.l:changelen(self.l.grid.row_frs, min(n, MAX_GRID_ITEM_COUNT), 1, 'layout')
end

terra CLayer:get_grid_col_fr(i: int): num return self.l.grid.col_frs(i, 1) end
terra CLayer:get_grid_row_fr(i: int): num return self.l.grid.row_frs(i, 1) end

terra CLayer:set_grid_col_fr(i: int, v: num)
	if i < MAX_GRID_ITEM_COUNT then
		if self:get_grid_col_fr(i) ~= v then
			self.l.grid.col_frs:set(i, v, 1)
			self.l:invalidate_layout()
		end
	end
end
terra CLayer:set_grid_row_fr(i: int, v: num)
	if i < MAX_GRID_ITEM_COUNT then
		if self:get_grid_row_fr(i) ~= v then
			self.l.grid.row_frs:set(i, v, 1)
			self.l:invalidate_layout()
		end
	end
end

terra CLayer:get_grid_col_gap(): num return self.l.grid.col_gap end
terra CLayer:get_grid_row_gap(): num return self.l.grid.row_gap end

terra CLayer:set_grid_col_gap(v: num) self.l:change(self.l.grid, 'col_gap', clamp(v, 0, MAX_W), 'layout') end
terra CLayer:set_grid_row_gap(v: num) self.l:change(self.l.grid, 'row_gap', clamp(v, 0, MAX_W), 'layout') end

terra CLayer:get_grid_flow(): enum return self.l.grid.flow end
terra CLayer:set_grid_flow(v: enum)
	if v >= 0 and v <= GRID_FLOW_MAX then
		self.l:change(self.l.grid, 'flow', v, 'layout')
	else
		self.l.lib:error('invalid grid_flow: %d', v)
	end
end

terra CLayer:get_grid_wrap(): int return self.l.grid.wrap end
terra CLayer:set_grid_wrap(v: int)
	self.l:change(self.l.grid, 'wrap', clamp(v, 1, MAX_GRID_ITEM_COUNT), 'layout')
end

terra CLayer:get_grid_min_lines(): int return self.l.grid.min_lines end
terra CLayer:set_grid_min_lines(v: int)
	self.l:change(self.l.grid, 'min_lines', clamp(v, 1, MAX_GRID_ITEM_COUNT), 'layout')
end

terra CLayer:get_min_cw(): num return self.l.min_cw end
terra CLayer:get_min_ch(): num return self.l.min_ch end

terra CLayer:set_min_cw(v: num) self.l:change(self.l, 'min_cw', clamp(v, 0, MAX_W), 'layout') end
terra CLayer:set_min_ch(v: num) self.l:change(self.l, 'min_ch', clamp(v, 0, MAX_W), 'layout') end

terra CLayer:get_grid_col(): int return self.l.grid_col end
terra CLayer:get_grid_row(): int return self.l.grid_row end

terra CLayer:set_grid_col(v: int) self.l:change(self.l, 'grid_col', clamp(v, -MAX_GRID_ITEM_COUNT, MAX_GRID_ITEM_COUNT), 'layout') end
terra CLayer:set_grid_row(v: int) self.l:change(self.l, 'grid_row', clamp(v, -MAX_GRID_ITEM_COUNT, MAX_GRID_ITEM_COUNT), 'layout') end

terra CLayer:get_grid_col_span(): int return self.l.grid_col_span end
terra CLayer:get_grid_row_span(): int return self.l.grid_row_span end

terra CLayer:set_grid_col_span(v: int) self.l:change(self.l, 'grid_col_span', clamp(v, 1, MAX_GRID_ITEM_COUNT), 'layout') end
terra CLayer:set_grid_row_span(v: int) self.l:change(self.l, 'grid_row_span', clamp(v, 1, MAX_GRID_ITEM_COUNT), 'layout') end

--sync'ing, drawing & hit testing

terra CLayer:sync()
	var layer = self.l.top_layer
	if not layer.layout_valid then
		layer:sync_layout()
		layer.layout_valid = true
	end
	return not layer.pixels_valid
end

terra CLayer:draw(cr: &context)
	self:sync()
	var layer = self.l.top_layer
	layer:draw(cr, false)
	layer.pixels_valid = true
end

terra CLayer:get_hit_test_mask(): enum return self.l.hit_test_mask end
terra CLayer:set_hit_test_mask(v: enum) self.l.hit_test_mask = v end

terra CLayer:hit_test(cr: &context, x: num, y: num, reason: int, out: &&CLayer): enum
	self:sync()
	var layer, area = self.l:hit_test(cr, x, y, reason)
	@out = [&CLayer](layer)
	return area
end

--publish and build

function build()
	local layerlib = publish'layer'

	if memtotal then
		layerlib(memtotal)
		layerlib(memreport)
	end

	layerlib:getenums(layer)

	layerlib(layerlib_new, 'layerlib')

	layerlib(CLib, nil, {
		cname = 'layerlib_t',
		cprefix = 'layerlib_',
		opaque = true,
	})

	layerlib(CLayer, nil, {
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
	print('sizeof CLayer', sizeof(CLayer))
end

return _M
