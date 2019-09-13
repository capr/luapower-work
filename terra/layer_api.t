--[[

	Layer Terra/C/ffi API.
	Implements a flattened API tailored for LuaJIT ffi use.

	This module adds input validation and state management to the raw
	implementation in order to achieve the following goals:

	* Invalid input should never cause fatal errors or crashes or affect other
	non-child layers in the tree (except min_cw and min_ch which can affect
	the whole geometry).

	* The order in which layer properties are set is not important, in order to
	avoid call-order dependencies, eg. you don't have to set `background_type`
	to a gradient type before setting `background_color_stop_color`, and you
	don't have to set `background_color_stop_count` either (the color stops
	array is expanded automatically). There are exceeptions to this, eg.
	setting `background_color_stop_count = 0` after adding some color stops
	_will_ remove those colors stops.

	Additional functionality:

	- self-allocating constructors.
	- non-fatal error checking and reporting.
	- enum validation, number clamping to range.
	- state invalidation when input values are changed.
	- state resync'ing when computed values are read.
	- uses doubles in place of ints for better range checking with LuaJIT ffi.

	- simplified and enlarged number types for forward ABI compatibility.
	- consecutive enum values for forward ABI compatibility.
	- functions and types are renamed and prefixed to C conventions.
	- methods and virtual properties are bound back to types via ffi.metatype.

	Usage:

	- make a layer lib object. make top layers from that or child layers from
	  other top layers, constructing a tree. set properties on the layers.
	- call draw(<cairo-context>) on the top layer. change any properties,
	  check if `pixels_valid` is false, and issue a repaint if it is.
	- hit test layers.
	- navigate, hit-test, select and edit text with cursors.

]]


local layer = require'terra/layer'
setfenv(1, require'terra/low'.module(layer))

struct Layer;
struct Lib;

--arg checking & error reporting macros --------------------------------------

Lib.methods.error = macro(function(self, ...)
	local args = args(...)
	return quote
		self.l.text_renderer:error([args])
	end
end)

Layer.methods.check = macro(function(self, NAME, v, valid)
	NAME = NAME:asvalue()
	FORMAT = 'invalid '..NAME..': %d'
	return quote
		if not valid then
			self.lib:error(FORMAT, v)
		end
		in valid
	end
end)

Layer.methods.checkrange = macro(function(self, NAME, v, MIN, MAX)
	NAME = NAME:asvalue()
	MIN = MIN:asvalue()
	MAX = MAX:asvalue()
	FORMAT = 'invalid '..NAME..': %d (range: '..MIN..'..'..MAX..')'
	return quote
		var ok = v >= MIN and v <= MAX
		if not ok then
			self.lib:error(FORMAT, v)
		end
		in ok
	end
end)

Layer.methods.change = macro(function(self, target, FIELD, v, WHAT)
	return `self.l:change(target, FIELD, v, [WHAT or ''])
end)

Layer.methods.changelen = macro(function(self, target, len, init, WHAT)
	return `self.l:changelen(target, len, init, [WHAT or ''])
end)

--API types ------------------------------------------------------------------

local real_int    = int
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

struct Lib (gettersandsetters) {
	l: layer.Lib;
}

struct Layer (gettersandsetters) {
	l: layer.Layer;
}

--layout sync'ing: called by computed-value accessors.
terra Layer.methods.sync :: {&Layer} -> {}

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
local MAX_CURSOR_COUNT = 10000

do end --lib new/release

terra Lib:init(load_font: FontLoadFunc, unload_font: FontLoadFunc)
	self.l:init(load_font, unload_font)
end
terra Lib:free() self.l:free() end

local terra layerlib_new(load_font: FontLoadFunc, unload_font: FontLoadFunc)
	return new(Lib, load_font, unload_font)
end

terra Lib:release()
	release(self)
end

do end --text rendering engine configuration

terra Lib:get_font_size_resolution       (): num return self.l.text_renderer.font_size_resolution end
terra Lib:get_subpixel_x_resolution      (): num return self.l.text_renderer.subpixel_x_resolution end
terra Lib:get_word_subpixel_x_resolution (): num return self.l.text_renderer.word_subpixel_x_resolution end
terra Lib:get_glyph_cache_size           (): int return self.l.text_renderer.glyph_cache_size end
terra Lib:get_glyph_run_cache_size       (): int return self.l.text_renderer.glyph_run_cache_size end
terra Lib:get_error_function             (): ErrorFunction return self.l.text_renderer.error_function end

terra Lib:set_font_size_resolution       (v: num) self.l.text_renderer.font_size_resolution = v end
terra Lib:set_subpixel_x_resolution      (v: num) self.l.text_renderer.subpixel_x_resolution = v end
terra Lib:set_word_subpixel_x_resolution (v: num) self.l.text_renderer.word_subpixel_x_resolution = v end
terra Lib:set_glyph_cache_size           (v: int) self.l.text_renderer.glyph_cache_max_size = v end
terra Lib:set_glyph_run_cache_size       (v: int) self.l.text_renderer.glyph_run_cache_max_size = v end
terra Lib:set_error_function             (v: ErrorFunction) self.l.text_renderer.error_function = v end

do end --layer new/release

terra Layer:init(lib: &Lib, parent: &Layer)
	self.l:init(&lib.l, &parent.l)
end
terra Layer:free() self.l:free() end

terra Layer:release()
	if self.l.parent ~= nil then
		self.l.parent.children:remove(self.l.index)
		self.l.parent:invalidate'layout'
	else
		self.l:free()
	end
end

terra Lib:layer()
	return new(Layer, self, nil)
end

do end --layer hierarchy

terra Layer:get_lib() return [&Lib](self.l.lib) end
terra Layer:get_parent() return [&Layer](self.l.parent) end
terra Layer:get_index(): int return self.l.index end
terra Layer:get_pos_parent() return [&Layer](self.l.pos_parent) end
terra Layer:get_top_layer() return [&Layer](self.l.top_layer) end
terra Layer:child(i: int) return [&Layer](self.l:child(i)) end

terra Layer:set_parent(parent: &Layer)
	self.l:move(&parent.l, maxint) --does arg checking and invalidation
end

terra Layer:set_index(i: int)
	self.l:move(self.l.parent, i) --does arg checking and invalidation
end

terra Layer:set_pos_parent(parent: &Layer)
	self.l.pos_parent = &parent.l --does arg checking and invalidation
end

terra Layer:layer()
	var e = self.lib:layer()
	e.parent = self --does arg checking and invalidation
	return e
end

terra Layer:get_child_count(): int
	return self.l.children.len
end

local new_child = macro(function(self, e)
	return quote @e = new(layer.Layer, self.lib, self) end
end)
terra Layer:set_child_count(n: int)
	self:changelen(self.l.children,
		clamp(n, 0, MAX_CHILD_COUNT), new_child,
		'layout pixels content_shadows parent_content_shadows')
end

do end --geometry

terra Layer:get_x(): num return self.l.x end
terra Layer:get_y(): num return self.l.y end
terra Layer:get_w(): num return self.l.w end
terra Layer:get_h(): num return self.l.h end

terra Layer:set_x(v: num) self:change(self.l, 'x', clamp(v, -MAX_X, MAX_X), 'pixels') end
terra Layer:set_y(v: num) self:change(self.l, 'y', clamp(v, -MAX_X, MAX_X), 'pixels') end
terra Layer:set_w(v: num) self:change(self.l, 'w', clamp(v, -MAX_W, MAX_W), 'pixels layout') end
terra Layer:set_h(v: num) self:change(self.l, 'h', clamp(v, -MAX_W, MAX_W), 'pixels layout') end

terra Layer:get_cx(): num return self.l.cx end
terra Layer:get_cy(): num return self.l.cy end
terra Layer:get_cw(): num return self.l.cw end
terra Layer:get_ch(): num return self.l.ch end

terra Layer:set_cx(v: num) self:change(self.l, 'cx', clamp(v, -MAX_X, MAX_X)) end
terra Layer:set_cy(v: num) self:change(self.l, 'cy', clamp(v, -MAX_X, MAX_X)) end
terra Layer:set_cw(v: num) self:change(self.l, 'cw', clamp(v, -MAX_W, MAX_W)) end
terra Layer:set_ch(v: num) self:change(self.l, 'ch', clamp(v, -MAX_W, MAX_W)) end

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
		self:change(self.l, ['padding_'..SIDE], clamp(v, -MAX_W, MAX_W), 'pixels layout')
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

do end --space helpers

terra Layer:from_window(x: num, y: num)
	return self.l:from_window(x, y)
end

do end --drawing

terra Layer:get_operator     (): enum return self.l.operator end
terra Layer:get_clip_content (): bool return self.l.clip_content end
terra Layer:get_snap_x       (): bool return self.l.snap_x end
terra Layer:get_snap_y       (): bool return self.l.snap_y end
terra Layer:get_opacity      (): num  return self.l.opacity end

terra Layer:set_operator     (v: enum)
	if self:checkrange('operator', v, OPERATOR_MIN, OPERATOR_MAX) then
		self:change(self.l, 'operator', v, 'pixels parent_content_shadows')
	end
end
terra Layer:set_clip_content (v: bool) self:change(self.l, 'clip_content', v, 'pixels content_shadows parent_content_shadows') end
terra Layer:set_snap_x       (v: bool) self:change(self.l, 'snap_x', v, 'pixels content_shadows parent_content_shadows') end
terra Layer:set_snap_y       (v: bool) self:change(self.l, 'snap_y', v, 'pixels content_shadows parent_content_shadows') end
terra Layer:set_opacity      (v: num)  self:change(self.l, 'opacity', clamp(v, 0, 1), 'pixels parent_content_shadows') end

do end --transforms

terra Layer:get_rotation    (): num return self.l.transform.rotation    end
terra Layer:get_rotation_cx (): num return self.l.transform.rotation_cx end
terra Layer:get_rotation_cy (): num return self.l.transform.rotation_cy end
terra Layer:get_scale       (): num return self.l.transform.scale       end
terra Layer:get_scale_cx    (): num return self.l.transform.scale_cx    end
terra Layer:get_scale_cy    (): num return self.l.transform.scale_cy    end

terra Layer:set_rotation    (v: num) self:change(self.l.transform, 'rotation'   , v                             , 'pixels parent_content_shadows') end
terra Layer:set_rotation_cx (v: num) self:change(self.l.transform, 'rotation_cx', clamp(v, -MAX_X, MAX_X)       , 'pixels parent_content_shadows') end
terra Layer:set_rotation_cy (v: num) self:change(self.l.transform, 'rotation_cy', clamp(v, -MAX_X, MAX_X)       , 'pixels parent_content_shadows') end
terra Layer:set_scale       (v: num) self:change(self.l.transform, 'scale'      , clamp(v, MIN_SCALE, MAX_SCALE), 'pixels parent_content_shadows') end
terra Layer:set_scale_cx    (v: num) self:change(self.l.transform, 'scale_cx'   , clamp(v, -MAX_X, MAX_X)       , 'pixels parent_content_shadows') end
terra Layer:set_scale_cy    (v: num) self:change(self.l.transform, 'scale_cy'   , clamp(v, -MAX_X, MAX_X)       , 'pixels parent_content_shadows') end

do end --borders

for i,SIDE in ipairs{'left', 'right', 'top', 'bottom'} do

	Layer.methods['get_border_width_'..SIDE] = terra(self: &Layer): num
		return self.l.border.['width_'..SIDE]
	end

	Layer.methods['set_border_width_'..SIDE] = terra(self: &Layer, v: num)
		self:change(self.l.border, ['width_'..SIDE], clamp(v, 0, MAX_W),
			'pixels box_shadows parent_content_shadows')
	end

	Layer.methods['get_border_color_'..SIDE] = terra(self: &Layer): uint32
		return self.l.border.['color_'..SIDE].uint
	end

	Layer.methods['set_border_color_'..SIDE] = terra(self: &Layer, v: uint32)
		self:change(self.l.border, ['color_'..SIDE],
			color{uint = clamp(v, 0, MAX_U32)},
			'pixels parent_content_shadows')
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
		   self.l.border.color_left.uint
		or self.l.border.color_right.uint
		or self.l.border.color_top.uint
		or self.l.border.color_bottom.uint
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
		return self.l.border.[RADIUS]
	end

	Layer.methods['set_'..RADIUS] = terra(self: &Layer, v: num)
		self:change(self.l.border, RADIUS, clamp(v, 0, MAX_W),
			'pixels box_shadows parent_content_shadows')
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

terra Layer:get_border_dash_count(): int return self.l.border.dash.len end
terra Layer:set_border_dash_count(v: int)
	self:changelen(self.l.border.dash, clamp(v, 0, MAX_BORDER_DASH_COUNT), 1,
		'pixels parent_content_shadows')
end

terra Layer:get_border_dash(i: int): int
	return self.l.border.dash(i, 1)
end
terra Layer:set_border_dash(i: int, v: double)
	if i >= 0 and i < MAX_BORDER_DASH_COUNT then
		v = clamp(v, 0.0001, MAX_W)
		if self.l.border.dash(i, 0) ~= v then
			self.l.border.dash:set(i, v, 1)
			self.l:invalidate'pixels parent_content_shadows'
		end
	end
end

terra Layer:get_border_dash_offset(): num return self.l.border.dash_offset end
terra Layer:set_border_dash_offset(v: num)
	self:change(self.l.border, 'dash_offset', clamp(v, -MAX_W, MAX_W),
		'pixels parent_content_shadows')
end

terra Layer:get_border_offset(): num return self.l.border.offset end
terra Layer:set_border_offset(v: num)
	self:change(self.l.border, 'offset', clamp(v, -MAX_OFFSET, MAX_OFFSET),
		'pixels box_shadows parent_content_shadows')
end

CBorderLineToFunc = {&Layer, &context, num, num, num} -> {}
CBorderLineToFunc.cname = 'll_border_lineto_func'

terra Layer:set_border_line_to(line_to: CBorderLineToFunc)
	self.l.border.line_to = BorderLineToFunc(line_to)
	self.l:invalidate'pixels box_shadows parent_content_shadows'
end

do end --backgrounds

terra Layer:get_background_type(): enum return self.l.background.type end
terra Layer:set_background_type(v: enum)
	if self:checkrange('background_type', v, BACKGROUND_TYPE_MIN, BACKGROUND_TYPE_MAX) then
		self:change(self.l.background, 'type', v, 'background pixels parent_content_shadows')
	end
end

terra Layer:get_background_hittable(): bool return self.l.background.hittable end
terra Layer:set_background_hittable(v: bool) self.l.background.hittable = v end

terra Layer:get_background_operator(): enum return self.l.background.operator end
terra Layer:set_background_operator(v: enum)
	if self:checkrange('background_operator', v, OPERATOR_MIN, OPERATOR_MAX) then
		self:change(self.l.background, 'operator', v, 'pixels parent_content_shadows')
	end
end

terra Layer:get_background_opacity(): num return self.l.background.opacity end
terra Layer:set_background_opacity(v: num)
	self:change(self.l.background, 'opacity',
		clamp(v, 0, 1), 'pixels parent_content_shadows')
end

terra Layer:get_background_clip_border_offset(): num
	return self.l.background.clip_border_offset
end
terra Layer:set_background_clip_border_offset(v: num)
	self:change(self.l.background, 'clip_border_offset',
		clamp(v, -MAX_OFFSET, MAX_OFFSET), 'pixels content_shadows parent_content_shadows')
end

terra Layer:get_background_color(): uint32 return self.l.background.color.uint end
terra Layer:set_background_color(v: uint32)
	if self.l.background.type == BACKGROUND_TYPE_NONE then
		--switch type automatically, but only from `none` to `color` type to
		--avoid side-effects in a sequence of property assignments.
		self.l.background.type = BACKGROUND_TYPE_COLOR
	end
	v = clamp(v, 0, MAX_U32)
	if self:change(self.l.background, 'color', color{uint = v}) then
		if self.l.background.type == BACKGROUND_TYPE_COLOR then
			self.l:invalidate'pixels parent_content_shadows'
		end
	end
end

for i,FIELD in ipairs{'x1', 'y1', 'x2', 'y2', 'r1', 'r2'} do

	local MAX = FIELD:find'^r' and MAX_W or MAX_X

	Layer.methods['get_background_'..FIELD] = terra(self: &Layer): num
		return self.l.background.pattern.gradient.[FIELD]
	end

	Layer.methods['set_background_'..FIELD] = terra(self: &Layer, v: num)
		if self:change(self.l.background.pattern.gradient, FIELD,
			clamp(v, -MAX, MAX), 'background')
		then
			if self.l.background.is_gradient then
				self.l:invalidate'pixels parent_content_shadows'
			end
		end
	end

end

terra Layer:get_background_color_stop_count(): int
	return self.l.background.pattern.gradient.color_stops.len
end

terra Layer:set_background_color_stop_count(n: int)
	if self:changelen(self.l.background.pattern.gradient.color_stops,
		clamp(n, 0, MAX_COLOR_STOP_COUNT), ColorStop{0, 0}, 'background')
	then
		if self.l.background.is_gradient then
			self.l:invalidate'pixels parent_content_shadows'
		end
	end
end

terra Layer:get_background_color_stop_color(i: int): uint32
	return self.l.background.pattern.gradient.color_stops(i, ColorStop{0, 0}).color.uint
end

terra Layer:get_background_color_stop_offset(i: int): num
	return self.l.background.pattern.gradient.color_stops(i, ColorStop{0, 0}).offset
end

terra Layer:set_background_color_stop_color(i: int, v: uint32)
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

terra Layer:set_background_color_stop_offset(i: int, v: num)
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

terra Layer:set_background_image(w: int, h: int, format: enum, stride: int, pixels: &uint8)
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

terra Layer:get_background_image_w      (): num  return self.l.background.pattern.bitmap.w end
terra Layer:get_background_image_h      (): num  return self.l.background.pattern.bitmap.h end
terra Layer:get_background_image_stride (): int  return self.l.background.pattern.bitmap.stride end
terra Layer:get_background_image_format (): enum return self.l.background.pattern.bitmap.format end
terra Layer:get_background_image_pixels()
	var s = self.l.background.pattern.bitmap_surface
	if s ~= nil then s:flush() end
	return self.l.background.pattern.bitmap.pixels
end
terra Layer:background_image_invalidate()
	var s = self.l.background.pattern.bitmap_surface
	if s ~= nil then
		s:mark_dirty()
		self.l:invalidate'pixels parent_content_shadows'
	end
end
terra Layer:background_image_invalidate_rect(x: int, y: int, w: int, h: int)
	var s = self.l.background.pattern.bitmap_surface
	if s ~= nil then
		s:mark_dirty_rectangle(x, y, w, h)
		self.l:invalidate'pixels parent_content_shadows'
	end
end

terra Layer:get_background_x      (): num  return self.l.background.pattern.x end
terra Layer:get_background_y      (): num  return self.l.background.pattern.y end
terra Layer:get_background_extend (): enum return self.l.background.pattern.extend end

terra Layer:set_background_x      (v: num) self.l.background.pattern.x = clamp(v, -MAX_X, MAX_X) end
terra Layer:set_background_y      (v: num) self.l.background.pattern.y = clamp(v, -MAX_X, MAX_X) end
terra Layer:set_background_extend (v: enum)
	if self:checkrange('background_extend', v, BACKGROUND_EXTEND_MIN, BACKGROUND_EXTEND_MAX) then
		self:change(self.l.background.pattern, 'extend', v, 'pixels parent_content_shadows')
	end
end

terra Layer:get_background_rotation    (): num return self.l.background.pattern.transform.rotation    end
terra Layer:get_background_rotation_cx (): num return self.l.background.pattern.transform.rotation_cx end
terra Layer:get_background_rotation_cy (): num return self.l.background.pattern.transform.rotation_cy end
terra Layer:get_background_scale       (): num return self.l.background.pattern.transform.scale       end
terra Layer:get_background_scale_cx    (): num return self.l.background.pattern.transform.scale_cx    end
terra Layer:get_background_scale_cy    (): num return self.l.background.pattern.transform.scale_cy    end

terra Layer:set_background_rotation    (v: num) self:change(self.l.background.pattern.transform, 'rotation'   , v, 'pixels parent_content_shadows') end
terra Layer:set_background_rotation_cx (v: num) self:change(self.l.background.pattern.transform, 'rotation_cx', clamp(v, -MAX_X, MAX_X), 'pixels parent_content_shadows') end
terra Layer:set_background_rotation_cy (v: num) self:change(self.l.background.pattern.transform, 'rotation_cy', clamp(v, -MAX_X, MAX_X), 'pixels parent_content_shadows') end
terra Layer:set_background_scale       (v: num) self:change(self.l.background.pattern.transform, 'scale'      , clamp(v, MIN_SCALE, MAX_SCALE), 'pixels parent_content_shadows') end
terra Layer:set_background_scale_cx    (v: num) self:change(self.l.background.pattern.transform, 'scale_cx'   , clamp(v, -MAX_X, MAX_X), 'pixels parent_content_shadows') end
terra Layer:set_background_scale_cy    (v: num) self:change(self.l.background.pattern.transform, 'scale_cy'   , clamp(v, -MAX_X, MAX_X), 'pixels parent_content_shadows') end

do end --shadows

terra Layer:get_shadow_count(): int
	return self.l.shadows.len
end

local new_shadow = macro(function(self, s)
	return quote s:init(self) end
end)
terra Layer:set_shadow_count(n: int)
	self:changelen(self.l.shadows,
		clamp(n, 0, MAX_SHADOW_COUNT), new_shadow,
		'pixels parent_content_shadows')
end

local terra shadow(self: &Layer, i: int)
	return self.l.shadows:at(i, &self.l.lib.default_shadow)
end

terra Layer:get_shadow_x       (i: int): num    return shadow(self, i).offset_x end
terra Layer:get_shadow_y       (i: int): num    return shadow(self, i).offset_y end
terra Layer:get_shadow_color   (i: int): uint32 return shadow(self, i).color.uint end
terra Layer:get_shadow_blur    (i: int): int    return shadow(self, i).blur_radius end
terra Layer:get_shadow_passes  (i: int): int    return shadow(self, i).blur_passes end
terra Layer:get_shadow_inset   (i: int): bool   return shadow(self, i).inset end
terra Layer:get_shadow_content (i: int): bool   return shadow(self, i).content end

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

terra Layer:set_shadow_x       (i: int, v: num)    change_shadow(self, i, 'offset_x'   , clamp(v, -MAX_X, MAX_X)) end
terra Layer:set_shadow_y       (i: int, v: num)    change_shadow(self, i, 'offset_y'   , clamp(v, -MAX_X, MAX_X)) end
terra Layer:set_shadow_color   (i: int, v: uint32) change_shadow(self, i, 'color'      , color{uint = clamp(v, 0, MAX_U32)}) end
terra Layer:set_shadow_blur    (i: int, v: int)    change_shadow(self, i, 'blur_radius', clamp(v, 0, 255)) end
terra Layer:set_shadow_passes  (i: int, v: int)    change_shadow(self, i, 'blur_passes', clamp(v, 0, 10)) end
terra Layer:set_shadow_inset   (i: int, v: bool)   change_shadow(self, i, 'inset'      , v) end
terra Layer:set_shadow_content (i: int, v: bool)   change_shadow(self, i, 'content'    , v) end

do end --text

terra Layer:get_text() return self.l.text.layout.text end
terra Layer:get_text_len(): int return self.l.text.layout.text_len end

terra Layer:set_text(s: &codepoint, len: int)
	self.l.text.layout:set_text(s, len)
	self.l:invalidate'text'
end

terra Layer:set_text_utf8(s: rawstring, len: int)
	self.l.text.layout:set_text_utf8(s, len)
	self.l:invalidate'text'
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
	self.l:invalidate'text'
end

terra Layer:get_text_dir(): enum return self.l.text.layout.dir end
terra Layer:set_text_dir(v: enum)
	self.l.text.layout.dir = v
	self.l:invalidate'text'
end

terra Layer:get_text_align_x(): enum return self.l.text.layout.align_x end
terra Layer:get_text_align_y(): enum return self.l.text.layout.align_y end
terra Layer:set_text_align_x(v: enum) self.l.text.layout.align_x = v; self.l:invalidate'text' end
terra Layer:set_text_align_y(v: enum) self.l.text.layout.align_y = v; self.l:invalidate'text' end

terra Layer:get_line_spacing      (): num return self.l.text.layout.line_spacing end
terra Layer:get_hardline_spacing  (): num return self.l.text.layout.hardline_spacing end
terra Layer:get_paragraph_spacing (): num return self.l.text.layout.paragraph_spacing end

terra Layer:set_line_spacing      (v: num) self.l.text.layout.line_spacing      = clamp(v, -MAX_OFFSET, MAX_OFFSET); self.l:invalidate'text' end
terra Layer:set_hardline_spacing  (v: num) self.l.text.layout.hardline_spacing  = clamp(v, -MAX_OFFSET, MAX_OFFSET); self.l:invalidate'text' end
terra Layer:set_paragraph_spacing (v: num) self.l.text.layout.paragraph_spacing = clamp(v, -MAX_OFFSET, MAX_OFFSET); self.l:invalidate'text' end

do end --text spans

terra Layer:get_span_count(): int
	return self.l.text.layout.span_count
end

terra Layer:set_span_count(n: int)
	n = clamp(n, 0, MAX_SPAN_COUNT)
	if self.span_count ~= n then
		self.l.text.layout.span_count = n
		self.l:invalidate'text'
	end
end

local prefixed = {
	offset  =1,
	color   =1,
	opacity =1,
	operator=1,
}

for _,FIELD in ipairs(tr.SPAN_FIELDS) do

	local T = tr.SPAN_FIELD_TYPES[FIELD]
	local T = api_types[T] or T
	local PFIELD = prefixed[FIELD] and 'text_'..FIELD or FIELD

	Layer.methods['get_span_'..PFIELD] = terra(self: &Layer, span_i: int): T
		return self.l.text.layout:['get_span_'..FIELD](span_i)
	end

	Layer.methods['set_span_'..PFIELD] = terra(self: &Layer, span_i: int, v: T)
		if span_i < MAX_SPAN_COUNT then
			self.l.text.layout:['set_span_'..FIELD](span_i, v)
			self.l:invalidate'text'
		end
	end

end

terra Layer:get_span_offset(span_i: int): int
	return self.l.text.layout:get_span_offset(span_i)
end

terra Layer:set_span_offset(span_i: int, v: int)
	self.l.text.layout:set_span_offset(span_i, v)
	self.l:invalidate'text'
end

do end --text geometry

terra Layer:load_text_cursor_xs(line_i: int)
	self:sync()
	self.l.text.layout:load_cursor_xs(line_i)
end
terra Layer:get_text_cursor_xs() return self.l.text.layout.cursor_xs end
terra Layer:get_text_cursor_xs_len() return self.l.text.layout.cursor_xs_len end

do end --text cursor & selection

terra Layer:get_text_selectable(): bool
	return self.l.text.selectable
end

terra Layer:set_text_selectable(v: bool)
	if self:change(self.l.text, 'selectable', v) then
		var l = &self.l.text.layout
		l:set_caret_visible(0, v)
		l:set_selection_visible(0, v)
		self.l:invalidate'text'
	end
end

terra Layer:get_text_cursor_count(): int
	return self.l.text.layout.cursor_count
end
terra Layer:set_text_cursor_count(v: int): int
	self.l.text.layout.cursor_count = v
	self.l:invalidate'text'
end

terra Layer:get_text_cursor_offset     (c_i: int): int return self.l.text.layout:get_cursor_offset     (c_i) end
terra Layer:get_text_cursor_which      (c_i: int): int return self.l.text.layout:get_cursor_which      (c_i) end
terra Layer:get_text_cursor_sel_offset (c_i: int): int return self.l.text.layout:get_cursor_sel_offset (c_i) end
terra Layer:get_text_cursor_sel_which  (c_i: int): int return self.l.text.layout:get_cursor_sel_which  (c_i) end
terra Layer:get_text_cursor_x          (c_i: int): num return self.l.text.layout:get_cursor_x          (c_i) end

terra Layer:set_text_cursor_offset     (c_i: int, v: int) self.l.text.layout:set_cursor_offset     (c_i, v); self.l:invalidate'text' end
terra Layer:set_text_cursor_which      (c_i: int, v: int) self.l.text.layout:set_cursor_which      (c_i, v); self.l:invalidate'text' end
terra Layer:set_text_cursor_sel_offset (c_i: int, v: int) self.l.text.layout:set_cursor_sel_offset (c_i, v); self.l:invalidate'text' end
terra Layer:set_text_cursor_sel_which  (c_i: int, v: int) self.l.text.layout:set_cursor_sel_which  (c_i, v); self.l:invalidate'text' end
terra Layer:set_text_cursor_x          (c_i: int, v: num) self.l.text.layout:set_cursor_x          (c_i, v); self.l:invalidate'text' end

do end --text span field get/set through current selection.

terra Layer:get_text_valid() return self.l.text.layout.valid end
terra Layer:get_text_offsets_valid() return self.l.text.layout.offsets_valid end

for _,FIELD in ipairs(tr.SPAN_FIELDS) do

	local T = tr.SPAN_FIELD_TYPES[FIELD]
	local T = api_types[T] or T

	Layer.methods['text_selection_has_'..FIELD] = terra(self: &Layer, c_i: int)
		var o1 = self.l.text.layout:get_cursor_offset(c_i)
		var o2 = self.l.text.layout:get_cursor_sel_offset(c_i)
		return self.l.text.layout:['has_'..FIELD](o1, o2)
	end

	Layer.methods['get_text_selection_'..FIELD] = terra(self: &Layer, c_i: int): T
		var span_i = self.l.text.layout:get_selection_first_span(c_i)
		return self.l.text.layout:['get_span_'..FIELD](span_i)
	end

	Layer.methods['set_text_selection_'..FIELD] = terra(self: &Layer, c_i: int, v: T)
		var o1 = self.l.text.layout:get_cursor_offset(c_i)
		var o2 = self.l.text.layout:get_cursor_sel_offset(c_i)
		self.l.text.layout:['set_'..FIELD](o1, o2, v)
		self.l:invalidate'text'
	end
end

do end --text navigation & hit-testing

terra Layer:text_cursor_move_to(c_i: int, offset: int, which: enum, select: bool)
	self:sync()
	self.l.text.layout:cursor_move_to(c_i, offset, which, select)
	self.l:invalidate'text'
end

terra Layer:text_cursor_move_to_point(c_i: int, x: num, y: num, select: bool)
	self:sync()
	self.l.text.layout:cursor_move_to_point(c_i, x, y, select)
	self.l:invalidate'text'
end

terra Layer:text_cursor_move_near(c_i: int, dir: enum, mode: enum, which: enum, select: bool)
	self:sync()
	self.l.text.layout:cursor_move_near(c_i, dir, mode, which, select)
	self.l:invalidate'text'
end

terra Layer:text_cursor_move_near_line(c_i: int, delta_lines: int, x: num, select: bool)
	self:sync()
	self.l.text.layout:cursor_move_near_line(c_i, delta_lines, x, select)
	self.l:invalidate'text'
end

terra Layer:text_cursor_move_near_page(c_i: int, delta_pages: int, x: num, select: bool)
	self:sync()
	self.l.text.layout:cursor_move_near_page(c_i, delta_pages, x, select)
	self.l:invalidate'text'
end

do end --layouts

terra Layer:get_visible(): bool return self.l.visible end
terra Layer:set_visible(v: bool)
	if self:change(self.l, 'visible', v) then
		self.l.top_layer.pixels_valid = false
		if self.l.pos_parent == nil then
			self.l.top_layer.layout_valid = false
		end
	end
end

terra Layer:get_layout_type(): enum return self.l.layout_type end
terra Layer:set_layout_type(v: enum)
	self:change(self.l, 'layout_type', v, 'layout')
end

terra Layer:get_align_items_x (): enum return self.l.align_items_x end
terra Layer:get_align_items_y (): enum return self.l.align_items_y end
terra Layer:get_item_align_x  (): enum return self.l.item_align_x  end
terra Layer:get_item_align_y  (): enum return self.l.item_align_y  end
terra Layer:get_align_x       (): enum return self.l.align_x end
terra Layer:get_align_y       (): enum return self.l.align_y end

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
	if self:check('align_items_x', v, is_align_items(v)) then
		self:change(self.l, 'align_items_x', v, 'layout')
	end
end
terra Layer:set_align_items_y(v: enum)
	if self:check('align_items_y', v, is_align_items(v)) then
		self:change(self.l, 'align_items_y', v, 'layout')
	end
end
terra Layer:set_item_align_x(v: enum)
	if self:check('item_align_x', v, is_align(v)) then
		self:change(self.l, 'item_align_x', v, 'layout')
	end
end
terra Layer:set_item_align_y(v: enum)
	if self:check('item_align_y', v, is_align(v) or v == ALIGN_BASELINE) then
		self:change(self.l, 'item_align_y', v, 'layout')
	end
end

terra Layer:set_align_x(v: enum)
	if self:check('align_x', v, v == ALIGN_DEFAULT or is_align(v)) then
		self:change(self.l, 'align_x', v, 'parent_layout')
	end
end
terra Layer:set_align_y(v: enum)
	if self:check('align_y', v, v == ALIGN_DEFAULT or is_align(v)) then
		self:change(self.l, 'align_y', v, 'parent_layout')
	end
end

terra Layer:get_flex_flow(): enum return self.l.flex.flow end
terra Layer:set_flex_flow(v: enum)
	if self:checkrange('flex_flow', v, FLEX_FLOW_MIN, FLEX_FLOW_MAX) then
		self:change(self.l.flex, 'flow', v, 'layout')
	end
end

terra Layer:get_flex_wrap(): bool return self.l.flex.wrap end
terra Layer:set_flex_wrap(v: bool) self:change(self.l.flex, 'wrap', v, 'layout') end

terra Layer:get_fr(): num return self.l.fr end
terra Layer:set_fr(v: num) self:change(self.l, 'fr', max(v, 0), 'parent_layout') end

terra Layer:get_break_before (): bool return self.l.break_before end
terra Layer:get_break_after  (): bool return self.l.break_after  end

terra Layer:set_break_before (v: bool) self:change(self.l, 'break_before', v, 'parent_layout') end
terra Layer:set_break_after  (v: bool) self:change(self.l, 'break_after' , v, 'parent_layout') end

terra Layer:get_grid_col_fr_count(): num return self.l.grid.col_frs.len end
terra Layer:get_grid_row_fr_count(): num return self.l.grid.row_frs.len end

terra Layer:set_grid_col_fr_count(n: int)
	self:changelen(self.l.grid.col_frs, min(n, MAX_GRID_ITEM_COUNT), 1, 'layout')
end
terra Layer:set_grid_row_fr_count(n: int)
	self:changelen(self.l.grid.row_frs, min(n, MAX_GRID_ITEM_COUNT), 1, 'layout')
end

terra Layer:get_grid_col_fr(i: int): num return self.l.grid.col_frs(i, 1) end
terra Layer:get_grid_row_fr(i: int): num return self.l.grid.row_frs(i, 1) end

terra Layer:set_grid_col_fr(i: int, v: num)
	if i >= 0 and i < MAX_GRID_ITEM_COUNT then
		if self:get_grid_col_fr(i) ~= v then
			self.l.grid.col_frs:set(i, v, 1)
			self.l:invalidate'layout'
		end
	end
end
terra Layer:set_grid_row_fr(i: int, v: num)
	if i >= 0 and i < MAX_GRID_ITEM_COUNT then
		if self:get_grid_row_fr(i) ~= v then
			self.l.grid.row_frs:set(i, v, 1)
			self.l:invalidate'layout'
		end
	end
end

terra Layer:get_grid_col_gap(): num return self.l.grid.col_gap end
terra Layer:get_grid_row_gap(): num return self.l.grid.row_gap end

terra Layer:set_grid_col_gap(v: num) self:change(self.l.grid, 'col_gap', clamp(v, 0, MAX_W), 'layout') end
terra Layer:set_grid_row_gap(v: num) self:change(self.l.grid, 'row_gap', clamp(v, 0, MAX_W), 'layout') end

terra Layer:get_grid_flow(): enum return self.l.grid.flow end
terra Layer:set_grid_flow(v: enum)
	if v >= 0 and v <= GRID_FLOW_MAX then
		self:change(self.l.grid, 'flow', v, 'layout')
	else
		self.lib:error('invalid grid_flow: %d', v)
	end
end

terra Layer:get_grid_wrap(): int return self.l.grid.wrap end
terra Layer:set_grid_wrap(v: int)
	self:change(self.l.grid, 'wrap', clamp(v, 1, MAX_GRID_ITEM_COUNT), 'layout')
end

terra Layer:get_grid_min_lines(): int return self.l.grid.min_lines end
terra Layer:set_grid_min_lines(v: int)
	self:change(self.l.grid, 'min_lines', clamp(v, 1, MAX_GRID_ITEM_COUNT), 'layout')
end

terra Layer:get_min_cw(): num return self.l.min_cw end
terra Layer:get_min_ch(): num return self.l.min_ch end

terra Layer:set_min_cw(v: num) self:change(self.l, 'min_cw', clamp(v, 0, MAX_W), 'parent_layout') end
terra Layer:set_min_ch(v: num) self:change(self.l, 'min_ch', clamp(v, 0, MAX_W), 'parent_layout') end

terra Layer:get_grid_col(): int return self.l.grid_col end
terra Layer:get_grid_row(): int return self.l.grid_row end

terra Layer:set_grid_col(v: int) self:change(self.l, 'grid_col', clamp(v, -MAX_GRID_ITEM_COUNT, MAX_GRID_ITEM_COUNT), 'parent_layout') end
terra Layer:set_grid_row(v: int) self:change(self.l, 'grid_row', clamp(v, -MAX_GRID_ITEM_COUNT, MAX_GRID_ITEM_COUNT), 'parent_layout') end

terra Layer:get_grid_col_span(): int return self.l.grid_col_span end
terra Layer:get_grid_row_span(): int return self.l.grid_row_span end

terra Layer:set_grid_col_span(v: int) self:change(self.l, 'grid_col_span', clamp(v, 1, MAX_GRID_ITEM_COUNT), 'parent_layout') end
terra Layer:set_grid_row_span(v: int) self:change(self.l, 'grid_row_span', clamp(v, 1, MAX_GRID_ITEM_COUNT), 'parent_layout') end

do end --sync'ing, drawing & hit testing

terra Layer:sync()
	var layer = self.l.top_layer
	if not layer.layout_valid then
		layer:sync_layout()
		layer.layout_valid = true
	end
end

terra Layer:get_pixels_valid()
	return self.l.top_layer.pixels_valid
end

terra Layer:draw(cr: &context)
	self:sync()
	var top_layer = self.l.top_layer
	top_layer:draw(cr, false)
	top_layer.pixels_valid = true
end

terra Layer:get_hit_test_mask(): enum return self.l.hit_test_mask end
terra Layer:set_hit_test_mask(v: enum) self.l.hit_test_mask = v end

terra Layer:hit_test(cr: &context, x: num, y: num, reason: int)
	self:sync()
	fill(&self.l.lib.hit_test_result)
	return self.l:hit_test(cr, x, y, reason)
end

terra Layer:get_hit_test_layer       () return [&Layer](self.l.lib.hit_test_result.layer) end
terra Layer:get_hit_test_area        () return self.l.lib.hit_test_result.area             end
terra Layer:get_hit_test_x           () return self.l.lib.hit_test_result.x                end
terra Layer:get_hit_test_y           () return self.l.lib.hit_test_result.y                end
terra Layer:get_hit_test_text_offset () return self.l.lib.hit_test_result.text_offset      end
terra Layer:get_hit_test_text_cursor_which() return self.l.lib.hit_test_result.text_cursor_which end

--publish and build

function build(optimize)
	local layerlib = publish'layer'

	if memtotal then
		layerlib(memtotal)
		layerlib(memreport)
	end

	layerlib(layer)

	layerlib(layerlib_new, 'layerlib')

	layerlib(Lib, nil, {
		cname = 'layerlib_t',
		cprefix = 'layerlib_',
		opaque = true,
	})

	layerlib(Layer, nil, {
		cname = 'layer_t',
		cprefix = 'layer_',
		opaque = true,
	})

	layerlib:build{
		linkto = {'cairo', 'freetype', 'harfbuzz', 'fribidi', 'unibreak', 'boxblur', 'xxhash'},
		optimize = optimize,
	}
end

if not ... then
	print'Building non-optimized...'
	build(false)
	print('sizeof Layer', sizeof(Layer))
end

return _M
