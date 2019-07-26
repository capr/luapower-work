--[[

	HTML-like box-model layouting and rendering engine in Terra with a C API.
	Written by Cosmin Apreutesei. Public Domain.

	Uses cairo for path filling, stroking, clipping, masking and blending.
	Uses terra-tr for text shaping and rendering.
	Uses terra-boxblur and boxblur for shadows.

	How this box model works (and how it differs from the web's box model):

	* the "layer box" is defined by (x, y, w, h).
	* paddings are applied to the layer box, creating the "content box".
	* child layers are positioned relative to the content box.
	* child layers can be clipped to the content box or to the layer box,
	  subject to `clip_content`.
	* border can be inside or outside the layer box, subject to `border_offset`.
	* border and padding are independent as both are relative to the layer box
	  so to make room for an inner border, you need to add some padding.
	* background can be clipped to the inside or outside of the border outline,
	  subject to `background_clip_border_offset`.

]]

if not ... then require'terra/layer_api'.build(); return end

setfenv(1, require'terra/low'.module())
require'terra/memcheck'
require'terra/cairo'
require'terra/tr_paint_cairo'
tr = require'terra/tr_api'
require'terra/bitmap'
require'terra/boxblur'
require'terra/utf8'
require'terra/box2d'

--utils ----------------------------------------------------------------------

terra snapx(x: num, enable: bool)
	return iif(enable, floor(x + .5), x)
end

terra snapxw(x: num, w: num, enable: bool)
	if not enable then return x, w end
	var x1 = floor(x + .5)
	var x2 = floor(x + w + .5)
	return x1, x2 - x1
end

--external types -------------------------------------------------------------

color = cairo_argb32_color_t
matrix = cairo_matrix_t
pattern = cairo_pattern_t
context = cairo_t
surface = cairo_surface_t
create_surface = cairo_image_surface_create_for_bitmap

rect = rect(num)

Bitmap = bitmap.Bitmap

terra Bitmap:surface()
	return create_surface(self)
end

--common enums ---------------------------------------------------------------

ALIGN_DEFAULT       = 0                --only for align_x/y
ALIGN_AUTO          = tr.ALIGN_AUTO    --only for text_align_x
ALIGN_LEFT          = tr.ALIGN_LEFT
ALIGN_RIGHT         = tr.ALIGN_RIGHT
ALIGN_CENTER        = tr.ALIGN_CENTER
ALIGN_TOP           = tr.ALIGN_TOP     --needs to be same as ALIGN_LEFT!
ALIGN_BOTTOM        = tr.ALIGN_BOTTOM  --needs to be same as ALIGN_RIGHT!
ALIGN_STRETCH       = tr.ALIGN_MAX + 1
ALIGN_START         = tr.ALIGN_MAX + 2 --left for LTR text, right for RTL
ALIGN_END           = tr.ALIGN_MAX + 3 --right for LTR text, left for RTL
ALIGN_SPACE_EVENLY  = tr.ALIGN_MAX + 4
ALIGN_SPACE_AROUND  = tr.ALIGN_MAX + 5
ALIGN_SPACE_BETWEEN = tr.ALIGN_MAX + 6
ALIGN_BASELINE      = tr.ALIGN_MAX + 7 --only for item_align_y

local function map_enum(C, src_prefix, dst_prefix)
	for k,v in pairs(C) do
		local op = k:match('^'..src_prefix..'(.*)')
		if op then _M[dst_prefix..op] = v end
	end
end
map_enum(C, 'CAIRO_OPERATOR_', 'OPERATOR_')
map_enum(tr, 'DIR_', 'DIR_')

HIT_NONE           = 0
HIT_BORDER         = 1
HIT_BACKGROUND     = 2
HIT_TEXT           = 3
HIT_TEXT_SELECTION = 4

--overridable constants ------------------------------------------------------

DEFAULT_BORDER_COLOR = DEFAULT_BORDER_COLOR or `color {0xffffffff}
DEFAULT_SHADOW_COLOR = DEFAULT_SHADOW_COLOR or `color {0x000000ff}

--bool bitmap ----------------------------------------------------------------

struct BoolBitmap {
	rows: int;
	cols: int;
	bits: arr(bool);
}

terra BoolBitmap:init()
	fill(self)
end

terra BoolBitmap:free()
	self.bits:free()
end

--transform ------------------------------------------------------------------

struct Transform {
	rotation: num;
	rotation_cx: num;
	rotation_cy: num;
	scale: num;
	scale_cx: num;
	scale_cy: num;
}

terra Transform:init()
	self.scale = 1
end

terra Transform:apply(m: &matrix)
	if self.rotation ~= 0 then
		m:rotate_around(self.rotation_cx, self.rotation_cy, rad(self.rotation))
	end
	if self.scale ~= 1 then
		m:scale_around(self.scale_cx, self.scale_cy, self.scale, self.scale)
	end
end

--border ---------------------------------------------------------------------

struct Layer;

BorderLineToFunc = {&Layer, &context, num, num, num} -> {}
BorderLineToFunc.cname = 'll_border_lineto_func'

struct Border (gettersandsetters) {

	width_left   : num;
	width_right  : num;
	width_top    : num;
	width_bottom : num;

	corner_radius_top_left     : num;
	corner_radius_top_right    : num;
	corner_radius_bottom_left  : num;
	corner_radius_bottom_right : num;

	--draw rounded corners with a modified bezier for smoother line-to-arc
	--transitions. kappa=1 uses circle arcs instead.
	corner_radius_kappa: num;

	color_left   : color;
	color_right  : color;
	color_top    : color;
	color_bottom : color;

	dash: arr(double);
	dash_offset: int;

	-- border stroke positioning relative to box edge.
	-- -1..1 goes from inside to outside of box edge.
	offset: num;

	line_to: BorderLineToFunc;

}

terra Border:init()
	self.color_left   = DEFAULT_BORDER_COLOR
	self.color_right  = DEFAULT_BORDER_COLOR
	self.color_top    = DEFAULT_BORDER_COLOR
	self.color_bottom = DEFAULT_BORDER_COLOR
	self.corner_radius_kappa = 1.2
	self.offset = -1 --inner border
end

terra Border:free()
	self.dash:free()
end

--background -----------------------------------------------------------------

BACKGROUND_COLOR           = 0
BACKGROUND_PATTERN         = 4     --mask for LINEAR|RADIAL|IMAGE
BACKGROUND_GRADIENT        = 4+2   --mask for LINEAR|RADIAL
BACKGROUND_LINEAR_GRADIENT = 4+2
BACKGROUND_RADIAL_GRADIENT = 4+2+1
BACKGROUND_IMAGE           = 4

map_enum(C, 'CAIRO_EXTEND_', 'BACKGROUND_EXTEND_')

struct ColorStop {
	offset: num;
	color: color;
}

struct BackgroundGradient {
	color_stops: arr(ColorStop);
	x1: num; y1: num;
	x2: num; y2: num;
	r1: num; r2: num;
}

terra BackgroundGradient:free()
	self.color_stops:free()
end

struct BackgroundPattern {
	x: num;
	y: num;
	gradient: BackgroundGradient;
	bitmap: Bitmap;
	pattern: &pattern;
	transform: Transform;
	extend: enum; --BACKGROUND_EXTEND_*
}

terra BackgroundPattern:init()
	self.transform:init()
	self.extend = BACKGROUND_EXTEND_REPEAT
end

terra BackgroundPattern:free_pattern()
	if self.pattern ~= nil then
		self.pattern:free()
		self.pattern = nil
	end
end

terra BackgroundPattern:free()
	self:free_pattern()
	self.bitmap:free()
	self.gradient:free()
end

struct Background (gettersandsetters) {
	_type: enum; --BACKGROUND_*
	hittable: bool;
	operator: enum; --OPERATOR_*
	color_set: bool;
	-- overlapping between background clipping edge and border stroke.
	-- -1..1 goes from inside to outside of border edge.
	clip_border_offset: num;
	color: color;
	pattern: BackgroundPattern;
}

terra Background:init()
	self.hittable = true
	self.operator = OPERATOR_OVER
	self.clip_border_offset = 1 --border fully overlaps the background
	self.pattern:init()
end

terra Background:free()
	self.pattern:free()
end

terra Background:get_type() return self._type end

terra Background:set_type(v: enum)
	if v == self.type then return end
	self.pattern:free_pattern()
	self._type = v
end

--shadow ---------------------------------------------------------------------

struct Shadow (gettersandsetters) {
	--config
	layer: &Layer;
	offset_x: num; --relative to the shape that it is shadowing
	offset_y: num;
	color: color;
	blur_radius: uint8;
	blur_passes: uint8;
	inset: bool;
	content: bool;  --shadow the layer content vs its box
	--state
	blur: Blur;
	surface: &surface;
	surface_x: num; --relative to the origin of the shadow shape
	surface_y: num;
}

terra Shadow:init(layer: &Layer)
	fill(self)
	self.layer = layer
	self.color = DEFAULT_SHADOW_COLOR
	self.blur_passes = 3
	self.blur:init(BITMAP_G8)
end

terra Shadow:invalidate()
	self.blur:invalidate()
end

terra Shadow:free()
	self.blur:free()
	if self.surface ~= nil then
		self.surface:free()
		self.surface = nil
	end
end

terra Shadow:visible()
	return self.blur_radius > 0
		or self.offset_x ~= 0
		or self.offset_y ~= 0
end

terra Shadow:get_edge_size()
	return self.blur_passes * self.blur_radius
end

terra Shadow:get_spread()
	if self.inset then
		return max(abs(self.offset_x), abs(self.offset_y))
	else
		return self.edge_size
	end
end

--text -----------------------------------------------------------------------

struct Text (gettersandsetters) {
	layout: tr.Layout;
	selectable: bool;
}

terra Text:get_cursor()
	return self.layout.cursors(0, nil)
end

terra Text:get_selection()
	return self.layout.selections(0, nil)
end

terra Text:init(r: &tr.Renderer)
	self.layout:init(r)
	self.layout.maxlen = 4096
	self.selectable = false
end

terra Text:free()
	self.layout:free()
end

--layouting ------------------------------------------------------------------

struct LayoutSolver {
	type       : enum; --LAYOUT_*
	axis_order : enum; --AXIS_ORDER_*
	sync       : {&Layer} -> {};
	sync_min_w : {&Layer, bool} -> num;
	sync_min_h : {&Layer, bool} -> num;
	sync_x     : {&Layer, bool} -> bool;
	sync_y     : {&Layer, bool} -> bool;
	sync_top   : {&Layer, num, num} -> bool;
}

FLEX_FLOW_X = 0
FLEX_FLOW_Y = 1

struct FlexLayout {
	flow: enum; --FLEX_FLOW_*
	wrap: bool;
}

struct GridLayoutCol {
	x: num;
	w: num;
	fr: num;
	align_x: enum;
	_min_w: num;
	snap_x: bool;
	inlayout: bool;
}

terra GridLayoutCol:setxw(x: num, w: num, moving: bool)
	self.x, self.w = snapxw(x, w, self.snap_x)
end

struct GridLayout {
	col_frs: arr(num);
	row_frs: arr(num);
	col_gap: num;
	row_gap: num;
	flow: enum; --GRID_FLOW_* mask
	wrap: int;
	min_lines: int;

	--computed by the auto-positioning algorithm.
	_flip_rows: bool;
	_flip_cols: bool;
	_max_row: int;
	_max_col: int;
	_cols: arr(GridLayoutCol);
	_rows: arr(GridLayoutCol);
}

terra GridLayout:init()
	self.wrap = 1
	self.min_lines = 1
end

terra GridLayout:free()
	self.col_frs:free()
	self.row_frs:free()
	self._cols:free()
	self._rows:free()
end

--lib ------------------------------------------------------------------------

struct Lib (gettersandsetters) {
	text_renderer: tr.Renderer;
	grid_occupied: BoolBitmap;
	default_text_span: tr.Span;
	default_shadow: Shadow;
	default_layout_solver: &LayoutSolver;
}

--layer ----------------------------------------------------------------------

CLIP_NONE       = 0
CLIP_PADDING    = 1
CLIP_BACKGROUND = 2

terra Layer.methods.free :: {&Layer} -> {}

struct Layer (gettersandsetters) {

	lib: &Lib;
	_parent: &Layer;
	children: arr{T = &Layer, own_elements = true};

	_x: num;
	_y: num;
	_w: num;
	_h: num;

	visible      : bool;
	operator     : enum;
	clip_content : enum; --CLIP_*
	snap_x       : bool; --snap to pixels on x-axis
	snap_y       : bool; --snap to pixels on y-axis

	opacity: num;

	padding_left   : num;
	padding_right  : num;
	padding_top    : num;
	padding_bottom : num;

	transform  : Transform;
	border     : Border;
	background : Background;
	shadows    : arr(Shadow);
	text       : Text;

	--layouting -------------------

	layout_solver: &LayoutSolver;

	final_x: num;
	final_y: num;
	final_w: num;
	final_h: num;

	--setting this flag makes layouting set final_x,y,w,h instead of x,y,w,h
	--which allows the client to animate x,y,w,h towards final_x,y,w,h after
	--layouting and before redrawing.
	in_transition: bool;

	--flex & grid layout
	align_items_x: enum;  --ALIGN_*
	align_items_y: enum;  --ALIGN_*
 	item_align_x: enum;   --ALIGN_*
	item_align_y: enum;   --ALIGN_*
	flex: FlexLayout;
	grid: GridLayout;

	--child of flex & grid layout
	_min_w: num;
	_min_h: num;
	min_cw: num; --min client width
	min_ch: num; --min client height
	align_x: enum; --ALIGN_*
	align_y: enum; --ALIGN_*

	--child of flex layout
	fr: num;
	break_before: bool;
	break_after : bool;

	--child of grid layout
	grid_col: int;
	grid_row: int;
	grid_col_span: int;
	grid_row_span: int;
	--computed by the auto-positioning algorithm.
	_grid_col: int;
	_grid_row: int;
	_grid_col_span: int;
	_grid_row_span: int;

	--hit testing -----------------

	hit_test_mask: enum;
}

terra Layer.methods.init_layout :: {&Layer} -> {}

terra Layer:init(lib: &Lib, parent: &Layer)
	fill(self)
	self.lib = lib
	self._parent = parent

	self.visible = true
	self.operator = OPERATOR_OVER
	self.opacity = 1
	self.snap_x = true
	self.snap_y = true

	self.transform:init()
	self.border:init()
	self.background:init()
	self.text:init(&lib.text_renderer)

	self.align_items_x = ALIGN_STRETCH
	self.align_items_y = ALIGN_STRETCH
 	self.item_align_x  = ALIGN_STRETCH
	self.item_align_y  = ALIGN_STRETCH
	self.fr = 1

	self.grid:init()
	self.grid_col_span = 1
	self.grid_row_span = 1

	self:init_layout()
end

terra Layer:free()
	self.children:free()
	self.border:free()
	self.background:free()
	self.shadows:free()
	self.text:free()
	self.grid:free()
	dealloc(self)
end

terra Lib:layer()
	return new(Layer, self, nil)
end

terra Layer:get_parent() return self._parent end

terra Layer:get_index()
	return iif(self.parent ~= nil, self.parent.children:find(self), 0)
end

terra Layer:release()
	if self.parent ~= nil then
		self.parent.children:remove(self.index)
	else
		self:free()
	end
end

terra Layer:move(parent: &Layer, i: int)
	if parent == self.parent then
		if parent ~= nil then
			i = parent.children:clamp(i)
			parent.children:move(self.index, i)
		end
	else
		if self.parent ~= nil then
			self.parent.children:leak(self.index)
		end
		if parent ~= nil then
			i = clamp(i, 0, parent.children.len)
			parent.children:insert(i, self)
			self._parent = parent
		end
		self._parent = parent
	end
end

terra Layer:set_parent(parent: &Layer)
	self:move(parent, maxint)
end

terra Layer:set_index(i: int)
	self:move(self.parent, i)
end

terra Layer:layer()
	var e = self.lib:layer()
	e.parent = self
	return e
end

Layer.metamethods.__for = function(self, body)
	return quote
		var children = self.children --workaround for terra issue #368
		for i = 0, children.len do
			[ body(`children(i)) ]
		end
	end
end

terra Layer:get_child_count()
	return self.children.len
end

terra Layer:set_child_count(n: int)
	var new_elements = self.children:setlen(n)
	for _,e in new_elements do
		@e = self.lib:layer()
		(@e)._parent = self
	end
end

terra Layer:child(i: int)
	return self.children(i, nil)
end

terra Layer.methods.size_changed :: {&Layer} -> {}

--layer geometry -------------------------------------------------------------

terra Layer:get_x() return self._x end
terra Layer:get_y() return self._y end
terra Layer:get_w() return self._w end
terra Layer:get_h() return self._h end

terra Layer:set_x(x: num) if self.in_transition then self.final_x = x else self._x = x end end
terra Layer:set_y(y: num) if self.in_transition then self.final_y = y else self._y = y end end

terra Layer:set_w(w: num)
	w = max(w, 0)
	if self.in_transition then
		self.final_w = w
	elseif self.w ~= w then
		self._w = w
		self:size_changed()
	end
end
terra Layer:set_h(h: num)
	h = max(h, 0)
	if self.in_transition then
		self.final_h = h
	elseif self.h ~= h then
		self._h = h
		self:size_changed()
	end
end

terra Layer:get_px() return self.padding_left end
terra Layer:get_py() return self.padding_top end
terra Layer:get_pw() return self.padding_left + self.padding_right end
terra Layer:get_ph() return self.padding_top + self.padding_bottom end

terra Layer:get_cw() return self.w - self.pw end
terra Layer:get_ch() return self.h - self.ph end

terra Layer:set_cw(cw: num) self.w = cw + (self.w - self.cw) end
terra Layer:set_ch(ch: num) self.h = ch + (self.h - self.ch) end

terra Layer:get_cx() return self.x + self.padding_left end --in parent's content space
terra Layer:get_cy() return self.y + self.padding_top end

terra Layer:set_cx(cx: num) self.x = cx - self.w / 2 end
terra Layer:set_cy(cy: num) self.y = cy - self.h / 2 end

terra Layer:snapx(x: num) return snapx(x, self.snap_x) end
terra Layer:snapy(y: num) return snapx(y, self.snap_y) end
terra Layer:snapxw(x: num, w: num) return snapxw(x, w, self.snap_x) end
terra Layer:snapyh(y: num, h: num) return snapxw(y, h, self.snap_y) end

--layer relative geometry & matrix -------------------------------------------

terra Layer:rel_matrix() --box matrix relative to parent's content space
	var m: matrix; m:init()
	m:translate(self:snapx(self.x), self:snapy(self.y))
	self.transform:apply(&m)
	return m
end

terra Layer:abs_matrix(): matrix --box matrix in window space
	var am: matrix
	if self.parent ~= nil then
		am = self.parent:abs_matrix()
	else
		am:init()
	end
	var rm = self:rel_matrix()
	am:transform(&rm)
	return am
end

terra Layer:cr_abs_matrix(cr: &context) --box matrix in cr's current space
	var cm = cr:matrix()
	var rm = self:rel_matrix()
	cm:transform(&rm)
	return cm
end

--convert point from own box space to parent content space.
terra Layer:from_box_to_parent(x: num, y: num)
	var m = self:rel_matrix()
	return m:point(x, y)
end

--convert point from parent content space to own box space.
terra Layer:from_parent_to_box(x: num, y: num)
	var m = self:rel_matrix(); m:invert()
	return m:point(x, y)
end

--convert point from own content space to parent content space.
terra Layer:to_parent(x: num, y: num)
	var m = self:rel_matrix()
	m:translate(self.px, self.py)
	return m:point(x, y)
end

--convert point from parent content space to own content space.
terra Layer:from_parent(x: num, y: num)
	var m = self:rel_matrix()
	m:translate(self.px, self.py)
	m:invert()
	return m:point(x, y)
end

terra Layer:to_window(x: num, y: num): {num, num} --parent & child interface
	var x, y = self:to_parent(x, y)
	if self.parent ~= nil then
		return self.parent:to_window(x, y)
	else
		return x, y
	end
end

terra Layer:from_window(x: num, y: num): {num, num} --parent & child interface
	if self.parent ~= nil then
		x, y = self.parent:from_window(x, y)
	end
	return self:from_parent(x, y)
end

--content-box geometry, drawing and hit testing ------------------------------

--convert point from own box space to own content space.
terra Layer:to_content(x: num, y: num)
	return x - self.px, y - self.py
end

--content point from own content space to own box space.
terra Layer:from_content(x: num, y: num)
	return self.px + x, self.py + y
end

--border geometry and drawing ------------------------------------------------

--border edge widths relative to box rect at %-offset in border width.
--offset is in -1..1 where -1=inner edge, 0=center, 1=outer edge.
--returned widths are positive when inside and negative when outside box rect.
terra Border:edge_widths(offset: num, max_w: num, max_h: num)
	var o = self.offset + offset + 1
	var w1 = lerp(o, -1, 1, self.width_left,   0)
	var h1 = lerp(o, -1, 1, self.width_top,    0)
	var w2 = lerp(o, -1, 1, self.width_right,  0)
	var h2 = lerp(o, -1, 1, self.width_bottom, 0)
	--adjust overlapping widths by scaling them down proportionally.
	if w1 + w2 > max_w or h1 + h2 > max_h then
		var scale = min(max_w / (w1 + w2), max_h / (h1 + h2))
		w1 = w1 * scale
		h1 = h1 * scale
		w2 = w2 * scale
		h2 = h2 * scale
	end
	return w1, h1, w2, h2
end

--border rect at %-offset in border width.
terra Layer:border_rect(offset: num, size_offset: num)
	var w1, h1, w2, h2 = self.border:edge_widths(offset, self.w, self.h)
	var w = self.w - w2 - w1
	var h = self.h - h2 - h1
	return rect.offset(size_offset, w1, h1, w, h)
end

--corner radius at pixel offset from the stroke's center on one dimension.
local terra offset_radius(r: num, o: num)
	return iif(r > 0, max(0.0, r + o), 0.0)
end

--border rect at %-offset in border width, plus radii of rounded corners.
terra Layer:border_round_rect(offset: num, size_offset: num)

	var k = self.border.corner_radius_kappa

	var x1, y1, w, h = self:border_rect(0, 0) --at stroke center
	var X1, Y1, W, H = self:border_rect(offset, size_offset) --at offset

	var x2, y2 = x1 + w, y1 + h
	var X2, Y2 = X1 + W, Y1 + H

	var r1 = self.border.corner_radius_top_left
	var r2 = self.border.corner_radius_top_right
	var r3 = self.border.corner_radius_bottom_right
	var r4 = self.border.corner_radius_bottom_left

	--offset the radii to preserve curvature at offset.
	var r1x = offset_radius(r1, x1-X1)
	var r1y = offset_radius(r1, y1-Y1)
	var r2x = offset_radius(r2, X2-x2)
	var r2y = offset_radius(r2, y1-Y1)
	var r3x = offset_radius(r3, X2-x2)
	var r3y = offset_radius(r3, Y2-y2)
	var r4x = offset_radius(r4, x1-X1)
	var r4y = offset_radius(r4, Y2-y2)

	--remove degenerate arcs.
	if r1x == 0 or r1y == 0 then r1x = 0; r1y = 0 end
	if r2x == 0 or r2y == 0 then r2x = 0; r2y = 0 end
	if r3x == 0 or r3y == 0 then r3x = 0; r3y = 0 end
	if r4x == 0 or r4y == 0 then r4x = 0; r4y = 0 end

	--adjust overlapping radii by scaling them down proportionally.
	var maxx = max(r1x + r2x, r3x + r4x)
	var maxy = max(r1y + r4y, r2y + r3y)
	if maxx > W or maxy > H then
		var scale = min(W / maxx, H / maxy)
		r1x = r1x * scale
		r1y = r1y * scale
		r2x = r2x * scale
		r2y = r2y * scale
		r3x = r3x * scale
		r3y = r3y * scale
		r4x = r4x * scale
		r4y = r4y * scale
	end

	return
		X1, Y1, W, H,
		r1x, r1y, r2x, r2y, r3x, r3y, r4x, r4y,
		k
end

--De Casteljau split of a cubic bezier at time t (from path2d).
local terra bezier_split(
	first: bool, t: num,
	x1: num, y1: num,
	x2: num, y2: num,
	x3: num, y3: num,
	x4: num, y4: num
)
	var mt = 1-t
	var x12 = x1 * mt + x2 * t
	var y12 = y1 * mt + y2 * t
	var x23 = x2 * mt + x3 * t
	var y23 = y2 * mt + y3 * t
	var x34 = x3 * mt + x4 * t
	var y34 = y3 * mt + y4 * t
	var x123 = x12 * mt + x23 * t
	var y123 = y12 * mt + y23 * t
	var x234 = x23 * mt + x34 * t
	var y234 = y23 * mt + y34 * t
	var x1234 = x123 * mt + x234 * t
	var y1234 = y123 * mt + y234 * t
	if first then
		return x1, y1, x12, y12, x123, y123, x1234, y1234 --first curve
	else
		return x1234, y1234, x234, y234, x34, y34, x4, y4 --second curve
	end
end

local kappa = 4 / 3 * (sqrt(2) - 1)

--more-aesthetically-pleasing elliptic arc. only for 45deg and 90deg sweeps!
local terra bezier_qarc(cr: &context, cx: num, cy: num, rx: num, ry: num, q1: num, qlen: num, k: num)
	cr:save()
	cr:translate(cx, cy)
	cr:scale(rx / ry, 1)
	cr:rotate(floor(min(q1, q1 + qlen) - 2) * PI / 2)
	var r = ry
	var k = r * kappa * k
	var x1, y1, x2, y2, x3, y3, x4, y4 = 0, -r, k, -r, r, -k, r, 0
	if qlen < 0 then --reverse curve
		x1, y1, x2, y2, x3, y3, x4, y4 = x4, y4, x3, y3, x2, y2, x1, y1
		qlen = abs(qlen)
	end
	if qlen ~= 1 then
		assert(qlen == .5)
		var first = q1 == floor(q1)
		x1, y1, x2, y2, x3, y3, x4, y4 =
			bezier_split(first, qlen, x1, y1, x2, y2, x3, y3, x4, y4)
	end
	cr:line_to(x1, y1)
	cr:curve_to(x2, y2, x3, y3, x4, y4)
	cr:restore()
end

--draw a rounded corner: q1 is the quadrant starting top-left going clockwise.
--qlen is in 90deg units and can only be +/- .5 or 1 if k ~= 1.
terra Layer:corner_path(cr: &context, cx: num, cy: num, rx: num, ry: num, q1: num, qlen: num, k: num)
	if rx == 0 or ry == 0 then --null arcs need a line to the first endpoint
		assert(rx == 0 and ry == 0)
		cr:line_to(cx, cy)
	elseif k == 1 then --geometrically-correct elliptic arc
		var q2 = q1 + qlen
		var a1 = (q1 - 3) * PI / 2
		var a2 = (q2 - 3) * PI / 2
		if a1 < a2 then
			cr:elliptic_arc(cx, cy, rx, ry, 0, a1, a2)
		else
			cr:elliptic_arc_negative(cx, cy, rx, ry, 0, a1, a2)
		end
	else
		bezier_qarc(cr, cx, cy, rx, ry, q1, qlen, k)
	end
end

terra Layer:border_line_to(cr: &context, x: num, y: num, q: num)
	if self.border.line_to ~= nil then
		self.border.line_to(self, cr, x, y, q)
	end
end

--trace the border contour path at offset.
--offset is in -1..1 where -1=inner edge, 0=center, 1=outer edge.
terra Layer:border_path(cr: &context, offset: num, size_offset: num)
	var x1, y1, w, h, r1x, r1y, r2x, r2y, r3x, r3y, r4x, r4y, k =
		self:border_round_rect(offset, size_offset)
	var x2, y2 = x1 + w, y1 + h
	cr:move_to(x1, y1+r1y)
	self:corner_path    (cr, x1+r1x, y1+r1y, r1x, r1y, 1, 1, k) --tl
	self:border_line_to (cr, x2-r2x, y1, 1)
	self:corner_path    (cr, x2-r2x, y1+r2y, r2x, r2y, 2, 1, k) --tr
	self:border_line_to (cr, x2, y2-r3y, 2)
	self:corner_path    (cr, x2-r3x, y2-r3y, r3x, r3y, 3, 1, k) --br
	self:border_line_to (cr, x1+r4x, y2, 3)
	self:corner_path    (cr, x1+r4x, y2-r4y, r4x, r4y, 4, 1, k) --bl
	self:border_line_to (cr, x1, y1+r1y, 4)
	cr:close_path()
end

terra Layer:border_visible()
	return
		   self.border.width_left   ~= 0
		or self.border.width_top    ~= 0
		or self.border.width_right  ~= 0
		or self.border.width_bottom ~= 0
end

terra Layer:draw_border(cr: &context)
	if not self:border_visible() then return end

	cr:operator(self.operator)

	--seamless drawing when all side colors are the same.
	if self.border.color_left.uint == self.border.color_top.uint
		and self.border.color_left.uint == self.border.color_right.uint
		and self.border.color_left.uint == self.border.color_bottom.uint
	then
		cr:new_path()
		cr:rgba(self.border.color_bottom)
		if self.border.width_left == self.border.width_top
			and self.border.width_left == self.border.width_right
			and self.border.width_left == self.border.width_bottom
		then --stroke-based drawing (doesn't require path offseting; supports dashing)
			self:border_path(cr, 0, 0)
			cr:line_width(self.border.width_left)
			if self.border.dash.len > 0 then
				cr:dash(
					self.border.dash.elements,
					self.border.dash.len,
					self.border.dash_offset)
			end
			cr:stroke()
		else --fill-based drawing (requires path offsetting; supports patterns)
			cr:fill_rule(CAIRO_FILL_RULE_EVEN_ODD)
			self:border_path(cr, -1, 0)
			self:border_path(cr,  1, 0)
			cr:fill()
		end
		return
	end

	--complicated drawing of each side separately.
	--still shows seams on adjacent sides of the same color.
	var x1, y1, w, h, r1x, r1y, r2x, r2y, r3x, r3y, r4x, r4y, k =
		self:border_round_rect(-1, 0)
	var X1, Y1, W, H, R1X, R1Y, R2X, R2Y, R3X, R3Y, R4X, R4Y, K =
		self:border_round_rect( 1, 0)

	var x2, y2 = x1 + w, y1 + h
	var X2, Y2 = X1 + W, Y1 + H

	if self.border.color_left.alpha > 0 then
		cr:new_path()
		cr:move_to(x1, y1+r1y)
		self:corner_path(cr, x1+r1x, y1+r1y, r1x, r1y, 1, .5, k)
		self:corner_path(cr, X1+R1X, Y1+R1Y, R1X, R1Y, 1.5, -.5, K)
		cr:line_to(X1, Y2-R4Y)
		self:corner_path(cr, X1+R4X, Y2-R4Y, R4X, R4Y, 5, -.5, K)
		self:corner_path(cr, x1+r4x, y2-r4y, r4x, r4y, 4.5, .5, k)
		cr:close_path()
		cr:rgba(self.border.color_left)
		cr:fill()
	end

	if self.border.color_top.alpha > 0 then
		cr:new_path()
		cr:move_to(x2-r2x, y1)
		self:corner_path(cr, x2-r2x, y1+r2y, r2x, r2y, 2, .5, k)
		self:corner_path(cr, X2-R2X, Y1+R2Y, R2X, R2Y, 2.5, -.5, K)
		cr:line_to(X1+R1X, Y1)
		self:corner_path(cr, X1+R1X, Y1+R1Y, R1X, R1Y, 2, -.5, K)
		self:corner_path(cr, x1+r1x, y1+r1y, r1x, r1y, 1.5, .5, k)
		cr:close_path()
		cr:rgba(self.border.color_top)
		cr:fill()
	end

	if self.border.color_right.alpha > 0 then
		cr:new_path()
		cr:move_to(x2, y2-r3y)
		self:corner_path(cr, x2-r3x, y2-r3y, r3x, r3y, 3, .5, k)
		self:corner_path(cr, X2-R3X, Y2-R3Y, R3X, R3Y, 3.5, -.5, K)
		cr:line_to(X2, Y1+R2Y)
		self:corner_path(cr, X2-R2X, Y1+R2Y, R2X, R2Y, 3, -.5, K)
		self:corner_path(cr, x2-r2x, y1+r2y, r2x, r2y, 2.5, .5, k)
		cr:close_path()
		cr:rgba(self.border.color_right)
		cr:fill()
	end

	if self.border.color_bottom.alpha > 0 then
		cr:new_path()
		cr:move_to(x1+r4x, y2)
		self:corner_path(cr, x1+r4x, y2-r4y, r4x, r4y, 4, .5, k)
		self:corner_path(cr, X1+R4X, Y2-R4Y, R4X, R4Y, 4.5, -.5, K)
		cr:line_to(X2-R3X, Y2)
		self:corner_path(cr, X2-R3X, Y2-R3Y, R3X, R3Y, 4, -.5, K)
		self:corner_path(cr, x2-r3x, y2-r3y, r3x, r3y, 3.5, .5, k)
		cr:close_path()
		cr:rgba(self.border.color_bottom)
		cr:fill()
	end
end

--background drawing ---------------------------------------------------------

terra Layer:background_visible()
	return not (self.background.type == BACKGROUND_COLOR and not self.background.color_set)
end

terra Layer:background_rect(size_offset: num)
	return self:border_rect(self.background.clip_border_offset, size_offset)
end

terra Layer:background_round_rect(size_offset: num)
	return self:border_round_rect(self.background.clip_border_offset, size_offset)
end

terra Layer:background_path(cr: &context, size_offset: num)
	self:border_path(cr, self.background.clip_border_offset, size_offset)
end

terra Layer:background_changed()
	self.background.pattern:free_pattern()
end

terra Background:pattern()
	var p = &self.pattern
	if p.pattern == nil then
		if (self.type and BACKGROUND_GRADIENT) ~= 0 then
			var g = p.gradient
			if self.type == BACKGROUND_LINEAR_GRADIENT then
				p.pattern = cairo_pattern_create_linear(g.x1, g.y1, g.x2, g.y2)
			else
				p.pattern = cairo_pattern_create_radial(g.x1, g.y1, g.r1, g.x2, g.y2, g.r2)
			end
			for _,c in g.color_stops do
				p.pattern:add_color_stop_rgba(c.offset, c.color)
			end
		elseif self.type == BACKGROUND_IMAGE then
			p.pattern = cairo_pattern_create_for_surface(p.bitmap:surface())
		end
	end
	return p.pattern
end

terra Background:paint(cr: &context)
	cr:operator(self.operator)
	if self.type == BACKGROUND_COLOR then
		cr:rgba(self.color)
		cr:paint()
	else
		var m: matrix; m:init()
		m:translate(self.pattern.x, self.pattern.y)
		self.pattern.transform:apply(&m)
		m:invert()
		var patt = self:pattern()
		patt:matrix(&m)
		patt:extend(self.pattern.extend)
		cr:source(patt)
		cr:paint()
		cr:rgb(0, 0, 0) --release source
	end
end

terra Layer:paint_background(cr: &context)
	self.background:paint(cr)
end

--shadow drawing -------------------------------------------------------------

terra Shadow:bitmap_rect()
	if self.content then
		var x, y, w, h = self.layer:content_bbox(true)
		return rect.offset(self.spread, x, y, w, h)
	else
		if self.layer:border_visible() then
			return self.layer:border_rect(iif(self.inset, -1, 1), self.spread)
		else
			return self.layer:background_rect(self.spread)
		end
	end
end

terra Layer:size_changed()
	self.shadows:call'invalidate'
end

terra Shadow:path(cr: &context)
	if self.layer:border_visible() then
		self.layer:border_path(cr, iif(self.inset, -1, 1), 0)
	else
		self.layer:background_path(cr, 0)
	end
end

terra Shadow:clip_path(cr: &context)
	if self.content then
		return false --TODO
	else
		self:path(cr)
		if not self.inset then
			cr:fill_rule(CAIRO_FILL_RULE_EVEN_ODD)
			var m = cr:matrix()
			cr:identity_matrix()
			cr:rectangle(0, 0, cr:target():width(), cr:target():height())
			cr:matrix(&m)
			return true
		end
	end
end

terra Shadow:draw_shape(cr: &context)
	cr:new_path()
	self:path(cr)
	if self.inset then
		cr:fill_rule(CAIRO_FILL_RULE_EVEN_ODD)
		cr:identity_matrix()
		cr:rectangle(0, 0, cr:target():width(), cr:target():height())
	end
	cr:operator(CAIRO_OPERATOR_SOURCE)
	cr:rgba(0, 0, 0, 1)
	cr:fill()
end

terra Shadow:draw(cr: &context)
	if not self.blur.valid then
		if not self:visible() then return end
		var bx, by, bw, bh = self:bitmap_rect()
		if not (bw > 0 and bh > 0) then return end
		self.surface_x = bx
		self.surface_y = by
		var src_bmp = self.blur:invalidate(bw, bh, self.blur_radius, self.blur_passes)
		if src_bmp ~= nil then
			var mask_bmp: Bitmap
			var mask_sr: &surface = nil
			var sr = src_bmp:surface()
			var cr = sr:context()
			cr:translate(-self.surface_x, -self.surface_y)
			cr:operator(CAIRO_OPERATOR_SOURCE)
			cr:rgba(0, 0, 0, 0)
			cr:paint()
			if self.content then
				self.layer:draw_content(cr)
				if self.inset then
					sr:flush()
					mask_bmp = src_bmp:copy()
					mask_sr = mask_bmp:surface()
					cr:rgba(1, 1, 1, 1)
					cr:operator(CAIRO_OPERATOR_XOR)
					cr:paint()
				end
			else
				self:draw_shape(cr)
			end
			cr:free()
			sr:free()

			var dst_bmp = self.blur:blur()
			if self.surface ~= nil then
				self.surface:free()
			end
			self.surface = dst_bmp:surface()

			if mask_sr ~= nil then
				var cr = self.surface:context()
				cr:translate(-self.offset_x, -self.offset_y)
				cr:operator(CAIRO_OPERATOR_DEST_IN)
				cr:source(mask_sr, 0, 0)
				cr:paint()
				cr:free()
				mask_sr:free()
				mask_bmp:free()
			end
		end
	end

	var sx = self.surface_x + self.offset_x
	var sy = self.surface_y + self.offset_y
	cr:save()
	cr:new_path()
	if self:clip_path(cr) then
		cr:clip()
	end
	cr:rgba(self.color)
	cr:operator(self.layer.operator)
	cr:mask(self.surface, sx, sy)
	cr:restore()
end

terra Layer:draw_shadows(cr: &context, inset: bool, content: bool)
	for _,s in self.shadows do
		if s.content == content and s.inset == inset then
			s:draw(cr)
		end
	end
end
terra Layer:draw_inset_content_shadows(cr: &context)
	self:draw_shadows(cr, true, true)
end
terra Layer:draw_outset_content_shadows(cr: &context)
	self:draw_shadows(cr, false, true)
end
terra Layer:draw_inset_box_shadows(cr: &context)
	self:draw_shadows(cr, true, false)
end
terra Layer:draw_outset_box_shadows(cr: &context)
	self:draw_shadows(cr, false, false)
end

--text drawing & hit testing -------------------------------------------------

terra Layer:get_caret()
	return self.text.layout.cursors(0, nil)
end

terra Layer:get_text_selection()
	return self.text.layout.selections(0, nil)
end

terra Layer:get_text_selectable()
	return self.text.selectable
end

terra Layer:set_text_selectable(v: bool)
	if self.text.selectable ~= v then
		self.text.selectable = v
		if self.caret ~= nil and not v then
			self.caret:release()
			self.text_selection:release()
		end
	end
end

terra Layer:sync_text_shape()
	self.text.layout:shape()
	if self.caret == nil and self.text.selectable then
		self.text.layout:cursor()
		self.text.layout:selection()
	end
end

terra Layer:sync_text_wrap()
	self.text.layout.align_w = self.cw
	self.text.layout:wrap()
end

terra Layer:sync_text_align()
	self.text.layout.align_h = self.ch
	self.text.layout:align()
end

terra Layer:get_baseline()
	if not self.text.layout.visible then return self.h end
	return self.text.layout.baseline
end

terra Layer:draw_text(cr: &context)
	if not self.text.layout.visible then return end
	var x1, y1, x2, y2 = cr:clip_extents()
	self.text.layout:set_clip_extents(x1, y1, x2, y2)
	self.text.layout:clip()
	self.text.layout:paint(cr)
end

terra Layer:text_bbox()
	if not self.text.layout.visible then
		return 0.0, 0.0, 0.0, 0.0
	end
	return self.text.layout:bbox() --float->double conversion!
end

terra Layer:hit_test_text(cr: &context, x: num, y: num, reason: enum)
	if self.text.layout.visible then
		var line_i, x_flag = self.text.layout:hit_test(x, y)
		if line_i >= 0 and line_i < self.text.layout.lines.len and x_flag == 0 then
			return HIT_TEXT
		end
	end
	return HIT_NONE
end

terra Layer:caret_rect()
	return self.caret:rect()
end

terra Layer:caret_visibility_rect()
	var x, y, w, h = self:caret_rect()
	--enlarge the caret rect to contain the line spacing.
	var line = self.text.cursor.line
	y = y + line.ascent - line.spaced_ascent
	h = line.spaced_ascent - line.spaced_descent
	return x, y, w, h
end

--[[
terra Layer:make_visible_caret()
	local segs = self.text.segments
	local lines = segs.lines
	local sx, sy = lines.x, lines.y
	local cw, ch = self:client_size()
	local x, y, w, h = self:caret_visibility_rect()
	lines.x, lines.y = box2d.scroll_to_view(x-sx, y-sy, w, h, cw, ch, sx, sy)
	self:make_visible(self:caret_visibility_rect())
end
]]

--layer bbox -----------------------------------------------------------------

terra Layer:content_bbox(strict: bool) --in self content space
	var bb = rect{0, 0, 0, 0}
	for layer in self do
		bb:bbox(rect(layer:bbox(strict)))
	end
	bb:bbox(rect(self:text_bbox()))
	return bb()
end

terra Layer.methods.bbox :: {&Layer, bool} -> {num, num, num, num}

terra Layer:bbox(strict: bool) --in parent's content space
	var bb = rect{0, 0, 0, 0}
	if self.visible then
		if strict or self.clip_content == CLIP_NONE then
			var cbb = rect(self:content_bbox(strict))
			inc(cbb.x, self.cx)
			inc(cbb.y, self.cy)
			if self.clip_content ~= CLIP_NONE then
				cbb:intersect(rect(self:background_rect(0)))
				if self.clip_content == CLIP_PADDING then
					cbb:intersect(rect{self.px, self.py, self.cw, self.ch})
				end
			end
			bb:bbox(cbb)
		end
		if (not strict and self.clip_content ~= CLIP_NONE)
			or self.background.hittable
			or self:background_visible()
		then
			bb:bbox(rect(self:background_rect(0)))
		end
		if self:border_visible() then
			bb:bbox(rect(self:border_rect(1, 0)))
		end
	end
	inc(bb.x, self.x)
	inc(bb.y, self.y)
	return bb()
end

--children drawing & hit testing ---------------------------------------------

terra Layer.methods.draw :: {&Layer, &context} -> {}
terra Layer.methods.hit_test :: {&Layer, &context, num, num, enum} -> {&Layer, enum}

terra Layer:draw_children(cr: &context) --called in own content space
	for e in self do
		e:draw(cr)
	end
end

terra Layer:hit_test_children(cr: &context, x: num, y: num, reason: enum) --called in content space
	for i = self.children.len-1, -1, -1 do
		var e, area = self.children(i):hit_test(cr, x, y, reason)
		if area ~= HIT_NONE then
			return e, area
		end
	end
	return nil, HIT_NONE
end

--content drawing & hit testing ----------------------------------------------

terra Layer:draw_content(cr: &context) --called in own content space
	self:draw_children(cr)
	if self.layout_solver.type < 2 then
		self:draw_text(cr)
	end
end

terra Layer:hit_test_content(cr: &context, x: num, y: num, reason: enum)
	var area = self:hit_test_text(cr, x, y, reason)
	if area ~= HIT_NONE then
		return self, area
	else
		return self:hit_test_children(cr, x, y, reason)
	end
end

--layer drawing & hit testing ------------------------------------------------

terra Layer:draw(cr: &context) --called in parent's content space

	if not self.visible or self.opacity <= 0 then
		return
	end

	var compose = self.opacity < 1
	if compose then
		cr:push_group()
	else
		cr:save()
	end

	var bm = self:cr_abs_matrix(cr)
	cr:matrix(&bm)

	self:draw_outset_box_shadows(cr)

	if self:background_visible() then
		cr:save()
		cr:new_path()
		self:background_path(cr, 0)
		cr:clip()
		self:paint_background(cr)
		cr:restore()
	end

	if self.clip_content ~= CLIP_NONE then
		cr:save()
		cr:new_path()
		self:background_path(cr, 0)
		cr:clip()
		if self.clip_content == CLIP_PADDING then
			cr:new_path()
			cr:rectangle(self.px, self.py, self.cw, self.ch)
			cr:clip()
		end
	end

	var cm = bm:copy()
	cm:translate(self.px, self.py)

	cr:matrix(&cm)
	self:draw_outset_content_shadows(cr)

	if self.clip_content == CLIP_NONE then
		cr:matrix(&bm)
		self:draw_border(cr)
	end

	cr:matrix(&cm)
	self:draw_content(cr)
	self:draw_inset_content_shadows(cr)

	if self.clip_content ~= CLIP_NONE then
		cr:restore()
		self:draw_border(cr)
	end

	self:draw_inset_box_shadows(cr)

	if compose then
		cr:pop_group_to_source()
		cr:operator(self.operator)
		cr:paint_with_alpha(self.opacity)
		cr:rgb(0, 0, 0) --release source
	else
		cr:restore()
	end
end

--called in parent's content space; child interface.
terra Layer:hit_test(cr: &context, x: num, y: num, reason: enum): {&Layer, enum}

	if not self.visible or self.opacity <= 0 then
		return nil, HIT_NONE
	end

	var self_allowed = (self.hit_test_mask and reason) ~= 0

	var x, y = self:from_parent_to_box(x, y)
	cr:save()
	cr:identity_matrix()

	--hit the content first if it's not clipped
	if self.clip_content == CLIP_NONE then
		var cx, cy = self:to_content(x, y)
		var e, area = self:hit_test_content(cr, cx, cy, reason)
		if e ~= nil then
			cr:restore()
			return e, area
		end
	end

	--border is drawn last so hit it first
	if self:border_visible() then
		cr:new_path()
		self:border_path(cr, 1, 0)
		if cr:in_fill(x, y) then --inside border outer edge
			cr:new_path()
			self:border_path(cr, -1, 0)
			if not cr:in_fill(x, y) then --outside border inner edge
				cr:restore()
				if self_allowed then
					return self, HIT_BORDER
				else
					return nil, HIT_NONE
				end
			end
		elseif self.clip_content ~= CLIP_NONE then --outside border outer edge when clipped
			cr:restore()
			return nil, HIT_NONE
		end
	end

	--hit background's clip area
	var in_bg = false
	if self.clip_content ~= CLIP_NONE or self.background.hittable or self:background_visible() then
		cr:new_path()
		self:background_path(cr, 0)
		in_bg = cr:in_fill(x, y)
	end

	--hit content's clip area
	var in_cc = false
	if self.clip_content ~= CLIP_NONE and in_bg then --CLIP_BACKGROUND is implicit here
		if self.clip_content == CLIP_PADDING then
			cr:new_path()
			cr:rectangle(self.px, self.py, self.cw, self.ch)
			if cr:in_fill(x, y) then
				in_cc = true
			end
		else
			in_cc = true
		end
	end

	--hit the content if inside the clip area.
	if in_cc then
		var cx, cy = self:to_content(x, y)
		var e, area = self:hit_test_content(cr, cx, cy, reason)
		if e ~= nil then
			cr:restore()
			return e, area
		end
	end

	--hit the background if any
	if self_allowed and in_bg then
		return self, HIT_BACKGROUND
	end
end

--layouts --------------------------------------------------------------------

terra snap_up(x: num, enable: bool)
	return iif(enable, ceil(x), x)
end

--layout plugin interface ----------------------------------------------------

LAYOUT_NULL    = 0
LAYOUT_TEXTBOX = 1
LAYOUT_FLEXBOX = 2
LAYOUT_GRID    = 2+1

--layout interface forwarders
terra Layer:sync_layout()          self.layout_solver.sync(self) end
terra Layer:sync_min_w(b: bool)    return self.layout_solver.sync_min_w(self, b) end
terra Layer:sync_min_h(b: bool)    return self.layout_solver.sync_min_h(self, b) end
terra Layer:sync_layout_x(b: bool) return self.layout_solver.sync_x(self, b) end
terra Layer:sync_layout_y(b: bool) return self.layout_solver.sync_y(self, b) end
terra Layer:sync_top(w: num, h: num)
	if self.layout_solver.sync_top(self, w, h) then
		self:sync_layout()
	end
end

--layout utils ---------------------------------------------------------------

AXIS_ORDER_XY = 1
AXIS_ORDER_YX = 2

--used by layers that need to solve their layout on one axis completely
--before they can solve it on the other axis. any content-based layout with
--wrapped content is like that: can't know the height until wrapping the
--content which needs to know the width (and viceversa for vertical flow).
terra Layer:sync_layout_separate_axes(axis_order: enum, min_w: num, min_h: num)
	if not self.visible then return end
	axis_order = iif(axis_order ~= 0, axis_order, self.layout_solver.axis_order)
	var sync_x = axis_order == AXIS_ORDER_XY
	var axis_synced = false
	var other_axis_synced = false
	for phase = 0, 3 do
		other_axis_synced = axis_synced
		if sync_x then
			--sync the x-axis.
			self.w = max(self:sync_min_w(other_axis_synced), min_w)
			axis_synced = self:sync_layout_x(other_axis_synced)
		else
			--sync the y-axis.
			self.h = max(self:sync_min_h(other_axis_synced), min_h)
			axis_synced = self:sync_layout_y(other_axis_synced)
		end
		if axis_synced and other_axis_synced then
			break --both axes were solved before last phase.
		end
		sync_x = not sync_x
	end
	assert(axis_synced and other_axis_synced)
end

terra Layer:sync_layout_children()
	for layer in self do
		layer:sync_layout() --recurse
	end
end

local terra sync_top(self: &Layer, w: num, h: num) --for all other layout types
	var min_cw = w - self.pw
	var min_ch = h - self.ph
	if self.min_cw ~= min_cw or self.min_ch ~= min_ch then
		self.min_cw = min_cw
		self.min_ch = min_ch
		return true
	else
		return false
	end
end

--null layout ----------------------------------------------------------------

--layouting system entry point: called on the top layer.
--called by null-layout layers to layout themselves and their children.
local terra null_sync(self: &Layer)
	if not self.visible then return end
	self.x, self.w = self:snapxw(self.x, self.w)
	self.y, self.h = self:snapyh(self.y, self.h)
	self:sync_text_shape()
	self:sync_text_wrap()
	self:sync_text_align()
	self:sync_layout_children()
end

--called by flexible layouts to know the minimum width of their children.
--width-in-height-out layouts call this before h and y are sync'ed.
local terra null_sync_min_w(self: &Layer, other_axis_synced: bool)
	self._min_w = snap_up(self.min_cw + self.pw, self.snap_x)
	return self._min_w
end

--called by flexible layouts to know the minimum height of their children.
--width-in-height-out layouts call this only after w and x are sync'ed.
local terra null_sync_min_h(self: &Layer, other_axis_synced: bool)
	self._min_h = snap_up(self.min_ch + self.ph, self.snap_y)
	return self._min_h
end

--called by flexible layouts to sync their children on one axis. in response,
--null-layouts sync themselves and their children on both axes when the
--second axis is synced.
local terra null_sync_x(self: &Layer, other_axis_synced: bool)
	if other_axis_synced then
		self:sync_layout()
	end
	return true
end

local terra null_sync_top(self: &Layer, w: num, h: num)
	if self.x ~= 0 or self.y ~= 0 or self.w ~= w or self.h ~= h then
		self.x = 0
		self.y = 0
		self.w = w
		self.h = h
		return true
	else
		return false
	end
end

local null_layout = constant(`LayoutSolver {
	type       = LAYOUT_NULL;
	axis_order = 0;
	sync       = null_sync;
	sync_min_w = null_sync_min_w;
	sync_min_h = null_sync_min_h;
	sync_x     = null_sync_x;
	sync_y     = null_sync_x;
	sync_top   = null_sync_top;
})

--textbox layout -------------------------------------------------------------

local terra text_sync(self: &Layer)
	if not self.visible then return end
	self:sync_text_shape()
	self.cw = max(self.text.layout:min_w(), self.min_cw)
	self:sync_text_wrap()
	self.cw = max(self.text.layout.max_ax, self.min_cw)
	self.ch = max(self.min_ch, self.text.layout.spaced_h)
	self.x, self.w = self:snapxw(self.x, self.w)
	self.y, self.h = self:snapyh(self.y, self.h)
	self:sync_text_align()
	self:sync_layout_children()
end

terra Layer:get_nowrap()
	var nowrap: bool
	if self.text.layout:get_nowrap(0, -1, &nowrap) then
		return nowrap
	else
		return false
	end
end

local terra text_sync_min_w(self: &Layer, other_axis_synced: bool)
	var min_cw: num
	if not other_axis_synced or self.nowrap then
		self:sync_text_shape()
		min_cw = self.text.layout:min_w()
	else
		--height-in-width-out parent layout with wrapping text not supported
		min_cw = 0
	end
	min_cw = max(min_cw, self.min_cw)
	var min_w = snap_up(min_cw + self.pw, self.snap_x)
	self._min_w = min_w
	return min_w
end

local terra text_sync_min_h(self: &Layer, other_axis_synced: bool)
	var min_ch: num
	if other_axis_synced or self.nowrap then
		min_ch = self.text.layout.spaced_h
	else
		--height-in-width-out parent layout with wrapping text not supported
		min_ch = 0
	end
	min_ch = max(min_ch, self.min_ch)
	var min_h = snap_up(min_ch + self.ph, self.snap_y)
	self._min_h = min_h
	return min_h
end

local terra text_sync_x(self: &Layer, other_axis_synced: bool)
	if not other_axis_synced then
		self:sync_text_wrap()
		return true
	end
end

local terra text_sync_y(self: &Layer, other_axis_synced: bool)
	if other_axis_synced then
		self:sync_text_align()
		self:sync_layout_children()
		return true
	end
end

local text_layout = constant(`LayoutSolver {
	type       = LAYOUT_TEXTBOX;
	axis_order = 0;
	sync       = text_sync;
	sync_min_w = text_sync_min_w;
	sync_min_h = text_sync_min_h;
	sync_x     = text_sync_x;
	sync_y     = text_sync_y;
	sync_top   = sync_top;
})

--stuff common to flex & grid layouts ----------------------------------------

terra Layer:setxw(x: num, w: num, moving: bool)
	self.x, self.w = self:snapxw(x, w)
end

terra Layer:setyh(y: num, h: num, moving: bool)
	self.y, self.h = self:snapyh(y, h)
end

terra Layer:get_inlayout()
	return self.visible --TODO: and (not self.dragging or self.moving)
end

local function stretch_items_main_axis_func(items_T, GET_ITEM, T, X, W)

	local _MIN_W = '_min_'..W
	local ALIGN_X = 'align_'..X
	local SETXW = 'set'..X..W

	--compute a single item's stretched width and aligned width.
	local terra stretched_item_widths(item: &T, total_w: num,
		total_fr: num, total_overflow_w: num, total_free_w: num, align: enum
	)
		var min_w = item.[_MIN_W]
		var flex_w = total_w * item.fr / total_fr
		var sw: num --stretched width
		if min_w > flex_w then --overflow
			sw = min_w
		else
			var free_w = flex_w - min_w
			var free_p = free_w / total_free_w
			var shrink_w = total_overflow_w * free_p
			if isnan(shrink_w) then --total_free_w == 0
				shrink_w = 0
			end
			sw = flex_w - shrink_w
		end
		return sw, iif(align == ALIGN_STRETCH, sw, min_w)
	end

	--stretch a line of items on the main axis.
	local terra stretch_items_main_axis(
		self: &items_T, i: int, j: int, total_w: num, item_align_x: enum,
		moving: bool
		--, set_item_x, set_moving_item_x
	)
		--compute the fraction representing the total width.
		var total_fr: num = 0.0
		for i = i, j do
			var item = self:[GET_ITEM](i)
			if item.inlayout then
				total_fr = total_fr + max(0.0, item.fr)
			end
		end
		total_fr = max(1.0, total_fr) --treat sub-unit fractions like css flex

		--compute the total overflow width and total free width.
		var total_overflow_w: num = 0.0
		var total_free_w: num = 0.0
		for i = i, j do
			var item = self:[GET_ITEM](i)
			if item.inlayout then
				var min_w = item.[_MIN_W]
				var flex_w = total_w * max(0.0, item.fr) / total_fr
				var overflow_w = max(0.0, min_w - flex_w)
				var free_w = max(0.0, flex_w - min_w)
				total_overflow_w = total_overflow_w + overflow_w
				total_free_w = total_free_w + free_w
			end
		end

		--compute the stretched width of the moving layer to make room for it.
		--[[
		var moving_layer, moving_x, moving_w, moving_sw
		if moving then
			var layer = self:[GET_ITEM](j)
			assert(layer.moving)
			var align = layer.[ALIGN_X] or item_align_x
			var sw, w = stretched_item_widths(
				layer, total_w, total_fr, total_overflow_w, total_free_w, align
			)

			moving_layer = layer
			moving_x = layer[X]
			moving_w = w
			moving_sw = sw
			j = j-1
		end
		]]

		--distribute the overflow to children which have free space to
		--take it. each child shrinks to take in a part of the overflow
		--proportional to its percent of free space.
		var sx: num = 0.0 --stretched x-coord
		for i = i, j do
			var item = self:[GET_ITEM](i)
			if item.inlayout then

				--compute item's stretched width.
				var align = iif(item.[ALIGN_X] ~= 0, item.[ALIGN_X], item_align_x)
				var sw, w = stretched_item_widths(
					item, total_w, total_fr, total_overflow_w, total_free_w, align
				)

				--align item inside the stretched segment defined by (sx, sw).
				var x = sx
				if align == ALIGN_END or align == ALIGN_RIGHT then
					x = sx + sw - w
				elseif align == ALIGN_CENTER then
					x = sx + (sw - w) / 2
				end

				--[[
				if moving_x and moving_x < x + w / 2 then
					set_moving_item_x(moving_layer, i, x, moving_w)

					--reserve space for the moving layer.
					sx = sx + moving_sw
					x = x + moving_sw
					moving_x = false
				end
				]]

				item:[SETXW](x, w, moving)
				sx = sx + sw
			end
		end
	end

	return stretch_items_main_axis
end

--start offset and inter-item spacing for aligning items on the main-axis.
local terra align_metrics(align: enum, container_w: num, items_w: num, item_count: int)
	var x: num = 0
	var spacing: num = 0
	if align == ALIGN_END or align == ALIGN_RIGHT then
		x = container_w - items_w
	elseif align == ALIGN_CENTER then
		x = (container_w - items_w) / 2
	elseif align == ALIGN_SPACE_EVENLY then
		spacing = (container_w - items_w) / (item_count + 1)
		x = spacing
	elseif align == ALIGN_SPACE_AROUND then
		spacing = (container_w - items_w) / item_count
		x = spacing / 2
	elseif align == ALIGN_SPACE_BETWEEN then
		spacing = (container_w - items_w) / (item_count - 1)
	end
	return x, spacing
end

--align a line of items on the main axis.
local function align_items_main_axis_func(items_T, GET_ITEM, T, X, W)
	local _MIN_W = '_min_'..W
	local SETXW = 'set'..X..W
	return terra(
		self: &items_T, i: int, j: int,
		sx: num, spacing: num,
		moving: bool
		--set_item_x, set_moving_item_x
	)
		--compute the spaced width of the moving layer to make room for it.
		--[[
		var moving_layer, moving_x, moving_w, moving_sw
		if moving then
			var layer = items[j]
			assert(layer.moving)
			var w = layer[_MIN_W]

			moving_layer = layer
			moving_x = layer[X]
			moving_w = w
			moving_sw = w + spacing
			j = j-1
		end
		]]

		for i = i, j do
			var item = self:[GET_ITEM](i)
			if item.inlayout then
				var x, w = sx, item.[_MIN_W]
				var sw = w + spacing

				--[[
				if moving_x and moving_x < x + w / 2 then
					set_moving_item_x(moving_layer, i, x, moving_w)

					--reserve space for the moving layer.
					sx = sx + moving_sw
					x = x + moving_sw
					moving_x = false
				end
				]]

				item:[SETXW](x, w, moving)
				sx = sx + sw
			end
		end
	end
end

--flexbox layout -------------------------------------------------------------

local function items_max_w(_MIN_W)
	return terra(self: &Layer, i: int, j: int)
		var max_w: num = 0.0
		var item_count = 0
		for i = i, j do
			var item = self.children(i)
			if item.visible then
				max_w = max(max_w, item.[_MIN_W])
				item_count = item_count + 1
			end
		end
		return max_w, item_count
	end
end

items_max_x = items_max_w'_min_w'
items_max_y = items_max_w'_min_h'

--generate pairs of methods for vertical and horizontal flex layouts.
local function gen_funcs(X, Y, W, H)

	local CW = 'c'..W
	local CH = 'c'..H
	local _MIN_W = '_min_'..W
	local _MIN_H = '_min_'..H
	local SNAP_X = 'snap_'..X
	local SNAP_Y = 'snap_'..Y

	local ALIGN_ITEMS_X = 'align_items_'..X
	local ALIGN_ITEMS_Y = 'align_items_'..Y
	local ITEM_ALIGN_X = 'item_align_'..X
	local ITEM_ALIGN_Y = 'item_align_'..Y
	local ALIGN_Y = 'align_'..Y

	local items_max_x = X == 'x' and items_max_x or items_max_y
	local items_max_y = X == 'x' and items_max_y or items_max_x

	local terra items_sum_x(self: &Layer, i: int, j: int)
		var sum_w: num = 0.0
		var item_count = 0
		for i = i, j do
			var item = self.children(i)
			if item.visible then
				sum_w = sum_w + item.[_MIN_W]
				item_count = item_count + 1
			end
		end
		return sum_w, item_count
	end

	local stretch_items_main_axis_x = stretch_items_main_axis_func(Layer, 'child', Layer, X, W)
	local align_items_main_axis_x = align_items_main_axis_func(Layer, 'child', Layer, X, W)

	--special items_min_h() for baseline align.
	--requires that the children are already sync'ed on y-axis.
	local terra items_min_h_baseline(self: &Layer, i: int, j: int)
		var max_ascent  : num = -inf
		var max_descent : num = -inf
		for i = i, j do
			var layer = self.children(i)
			if layer.visible then
				var baseline = layer.baseline
				max_ascent = max(max_ascent, baseline)
				max_descent = max(max_descent, layer._min_h - baseline)
			end
		end
		return max_ascent + max_descent, max_ascent
	end

	local terra items_min_h(self: &Layer, i: int, j: int, align_baseline: bool)
		if align_baseline then
			return items_min_h_baseline(self, i, j)
		end
		return items_max_y(self, i, j)._0, nan
	end

	local terra linewrap_next(self: &Layer, i: int): {int, int}
		i = i + 1
		if i >= self.children.len then
			return -1, -1
		elseif not self.flex.wrap then
			return i, self.children.len
		end
		var wrap_w = self.[CW]
		var line_w: num = 0.0
		for j = i, self.children.len do
			var layer = self.children(j)
			if layer.visible then
				if j > i and layer.break_before then
					return i, j
				end
				if layer.break_after then
					return i, j+1
				end
				var item_w = layer.[_MIN_W]
				if line_w + item_w > wrap_w then
					return i, j
				end
				line_w = line_w + item_w
			end
		end
		return i, self.children.len
	end

	local struct linewrap {layer: &Layer}
	linewrap.metamethods.__for = function(self, body)
		return quote
			var layer = self.layer --workaround for terra issue #368
			var i = -1
			var j = 0
			while true do
				i, j = linewrap_next(layer, j-1)
				if j == -1 then break end
				[ body(i, j) ]
			end
		end
	end

	Layer.methods['flex_min_cw_'..X] = terra(
		self: &Layer, other_axis_synced: bool, align_baseline: bool
	)
		if self.flex.wrap then
			return items_max_x(self, 0, self.children.len)._0
		else
			return items_sum_x(self, 0, self.children.len)._0
		end
	end

	Layer.methods['flex_min_ch_'..X] = terra(
		self: &Layer, other_axis_synced: bool, align_baseline: bool
	)
		if not other_axis_synced and self.flex.wrap then
			--width-in-height-out parent layout requesting min_w on a y-axis
			--wrapping flex (which is a height-in-width-out layout).
			return 0
		end
		var lines_h: num = 0.0
		for i, j in linewrap{self} do
			var line_h, _ = items_min_h(self, i, j, align_baseline)
			lines_h = lines_h + line_h
		end
		return lines_h
	end

	local terra set_item_x(layer: &Layer, x: num, w: num, moving: bool)
		x, w = snapxw(x, w, layer.[SNAP_X])
		--TODO
		--var set = moving and layer.transition or layer.end_value
		--set(layer, X, x)
		--set(layer, W, w)
	end

	local terra set_moving_item_x(layer: &Layer, i: int, x: num, w: num)
		--layer[X] = x
		--layer[W] = w
	end

	--stretch and align a line of items on the main axis.
	local terra stretch_items_x(self: &Layer, i: int, j: int, moving: bool)
		stretch_items_main_axis_x(
			self, i, j, self.[CW], self.[ITEM_ALIGN_X], moving)
			--TODO: set_item_x, set_moving_item_x)
	end

	--align a line of items on the main axis.
	local terra align_items_x(self: &Layer, i: int, j: int, align: enum, moving: bool)
		if align == ALIGN_STRETCH then
			stretch_items_x(self, i, j, moving)
		else
			var sx: num, spacing: num
			if align == ALIGN_START or align == ALIGN_LEFT then
				sx, spacing = 0, 0
			else
				var items_w, item_count = items_sum_x(self, i, j)
				sx, spacing = align_metrics(align, self.[CW], items_w, item_count)
			end
			align_items_main_axis_x(
				self, i, j, sx, spacing, moving)
				--TODO: set_item_x, set_moving_item_x)
		end
	end

	--stretch or align a flex's items on the main-axis.
	Layer.methods['flex_sync_x_'..X] = terra(
		self: &Layer, other_axis_synced: bool, align_baseline: bool
	)
		var align = self.[ALIGN_ITEMS_X]
		var moving = false --TODO: self.moving_layer and true or false
		for i, j in linewrap{self} do
			align_items_x(self, i, j, align, moving)
		end
		return true
	end

	--align a line of items on the cross-axis.
	local terra align_items_y(self: &Layer, i: int, j: int,
		line_y: num, line_h: num, line_baseline: num
	)
		var snap_y = self.[SNAP_Y]
		var align = self.[ITEM_ALIGN_Y]
		for i = i, j do
			var layer = self.children(i)
			if layer.visible then
				var align = layer.[ALIGN_Y] or align
				var y: num
				var h: num
				if align == ALIGN_STRETCH then
					y = line_y
					h = line_h
				else
					var item_h = layer.[_MIN_H]
					if align == ALIGN_TOP or align == ALIGN_START then
						y = line_y
						h = item_h
					elseif align == ALIGN_BOTTOM or align == ALIGN_END then
						y = line_y + line_h - item_h
						h = item_h
					elseif align == ALIGN_CENTER then
						y = line_y + (line_h - item_h) / 2
						h = item_h
					elseif not isnan(line_baseline) then
						y = line_baseline - layer.baseline
					end
				end
				if not isnan(line_baseline) then
					y = snapx(y, snap_y)
				else
					y, h = snapxw(y, h, layer.[SNAP_Y])
					layer.[H] = h
				end
				layer.[Y] = y
			end
		end
	end

	--stretch or align a flex's items on the cross-axis.
	Layer.methods['flex_sync_y_'..X] = terra(
		self: &Layer, other_axis_synced: bool, align_baseline: bool
	)
		if not other_axis_synced and self.flex.wrap then
			--trying to lay out the y-axis before knowing the x-axis:
			--dismiss and wait for the 3rd pass.
			return false
		end

		var lines_y: num
		var line_spacing: num
		var line_h: num = nan
		var align = self.[ALIGN_ITEMS_Y]
		if align == ALIGN_STRETCH then
			var lines_h = self.[CH]
			var line_count = 0
			for _1,_2 in linewrap{self} do
				line_count = line_count + 1
			end
			line_h = lines_h / line_count
			lines_y = 0
			line_spacing = 0
		elseif align == ALIGN_TOP or align == ALIGN_START then
			lines_y, line_spacing = 0, 0
		else
			var lines_h: num = 0.0
			var line_count: int = 0
			for i, j in linewrap{self} do
				var line_h, _ = items_min_h(self, i, j, align_baseline)
				lines_h = lines_h + line_h
				line_count = line_count + 1
			end
			lines_y, line_spacing =
				align_metrics(align, self.[CH], lines_h, line_count)
		end
		var y = lines_y
		for i, j in linewrap{self} do
			var line_h = line_h
			var line_baseline: num = nan
			if isnan(line_h) then
				line_h, line_baseline = items_min_h(self, i, j, align_baseline)
			end
			align_items_y(self, i, j, y, line_h, line_baseline)
			y = y + line_h + line_spacing
		end

		return true
	end

end
gen_funcs('x', 'y', 'w', 'h')
gen_funcs('y', 'x', 'h', 'w')

local terra flex_sync_min_w(self: &Layer, other_axis_synced: bool)

	--sync all children first (bottom-up sync).
	for layer in self do
		if layer.visible then
			layer:sync_min_w(other_axis_synced) --recurse
		end
	end

	var min_cw = iif(self.flex.flow == FLEX_FLOW_X,
			self:flex_min_cw_x(other_axis_synced, false),
			self:flex_min_ch_y(other_axis_synced, false))

	min_cw = max(min_cw, self.min_cw)
	var min_w = min_cw + self.pw
	self._min_w = min_w
	return min_w
end

local terra flex_sync_min_h(self: &Layer, other_axis_synced: bool)

	var align_baseline = self.flex.flow == FLEX_FLOW_X
		and self.item_align_y == ALIGN_BASELINE

	--sync all children first (bottom-up sync).
	for layer in self do
		if layer.visible then
			var item_h = layer:sync_min_h(other_axis_synced) --recurse
			--for baseline align also layout the children because we need
			--their baseline. we can do this here because we already know
			--we won't stretch them beyond their min_h in this case.
			if align_baseline then
				layer.h = snapx(item_h, self.snap_y)
				layer:sync_layout_y(other_axis_synced)
			end
		end
	end

	var min_ch = iif(self.flex.flow == FLEX_FLOW_X,
		self:flex_min_ch_x(other_axis_synced, align_baseline),
		self:flex_min_cw_y(other_axis_synced, false))

	min_ch = max(min_ch, self.min_ch)
	var min_h = min_ch + self.ph
	self._min_h = min_h
	return min_h
end

local terra flex_sync_x(self: &Layer, other_axis_synced: bool)

	var synced = iif(self.flex.flow == FLEX_FLOW_X,
			self:flex_sync_x_x(other_axis_synced, false),
			self:flex_sync_y_y(other_axis_synced, false))

	if synced then
		--sync all children last (top-down sync).
		for layer in self do
			if layer.visible then
				layer:sync_layout_x(other_axis_synced) --recurse
			end
		end
	end
	return synced
end

local terra flex_sync_y(self: &Layer, other_axis_synced: bool)

	if self.flex.flow == FLEX_FLOW_X and self.item_align_y == ALIGN_BASELINE then
		--chilren already sync'ed in sync_min_h().
		return self:flex_sync_y_x(other_axis_synced, true)
	end

	var synced = self.flex.flow == FLEX_FLOW_Y
		and self:flex_sync_x_y(other_axis_synced, false)
		 or self:flex_sync_y_x(other_axis_synced, false)

	if synced then
		--sync all children last (top-down sync).
		for layer in self do
			if layer.visible then
				layer:sync_layout_y(other_axis_synced) --recurse
			end
		end
	end

	return synced
end

local terra flex_sync(self: &Layer)
	self:sync_layout_separate_axes(0, -inf, -inf)
end

local flex_layout = constant(`LayoutSolver {
	type       = LAYOUT_FLEXBOX;
	axis_order = AXIS_ORDER_XY;
	sync       = flex_sync;
	sync_min_w = flex_sync_min_w;
	sync_min_h = flex_sync_min_h;
	sync_x     = flex_sync_x;
	sync_y     = flex_sync_y;
	sync_top   = sync_top;
})

--[[
--faster hit-testing for non-wrapped flexboxes.
local terra cmp_ys(items, i, y)
	return items[i].visible and items[i].y < y -- < < [=] = < <
end
var terra cmp_xs(items, i, x)
	return items[i].visible and items[i].x < x -- < < [=] = < <
end
terra flex:hit_test_flex_item(x, y)
	var cmp = self.flex_flow == 'y' and cmp_ys or cmp_xs
	var coord = self.flex_flow == 'y' and y or x
	return max(1, (binsearch(coord, self, cmp) or #self + 1) - 1)
end

terra flex:override_hit_test_children(inherited, x, y, reason)
	if #self < 2 or self.flex_wrap then
		return inherited(self, x, y, reason)
	end
	var i = self:hit_test_flex_item(x, y)
	return self[i]:hit_test(x, y, reason)
end

--faster clipped drawing for non-wrapped flexboxes.
terra flex:override_draw_children(inherited, cr)
	if #self < 1 or self.flex_wrap then
		return inherited(self, cr)
	end
	var x1, y1, x2, y2 = cr:clip_extents()
	var i = self:hit_test_flex_item(x1, y1)
	var j = self:hit_test_flex_item(x2, y2)
	for i = i, j do
		self[i]:draw(cr)
	end
end
]]

--bitmap-of-bools object -----------------------------------------------------

terra BoolBitmap:bitindex(row: int, col: int)
	return (row - 1) * self.cols + col - 1
end

terra BoolBitmap:set(row: int, col: int, val: bool)
	self.bits:set(self:bitindex(row, col), val, false)
end

terra BoolBitmap:get(row: int, col: int)
	return self.bits(self:bitindex(row, col), false)
end

terra BoolBitmap:widen(min_rows: int, min_cols: int)
	var rows = max(min_rows, self.rows)
	var cols = max(min_cols, self.cols)
	if rows > self.rows or cols > self.cols then
		self.bits:setlen(rows * cols, false)
		if cols > self.cols then --move the rows down to widen them
			for row = self.rows-1, -1, -1 do
				var dst = self.bits:sub(row * cols, (row + 1) * cols)
				var src = self.bits:sub(row * self.cols, (row + 1) * self.cols)
				src:copy(dst)
				self.bits:sub(row * cols + self.cols, (row + 1) * cols):fill(false)
			end
		end
		self.rows = rows
		self.cols = cols
	end
end

terra BoolBitmap:mark(row1: int, col1: int, row_span: int, col_span: int, val: bool)
	var row2 = row1 + row_span
	var col2 = col1 + col_span
	self:widen(row2-1, col2-1)
	for row = row1, row2 do
		for col = col1, col2 do
			self:set(row, col, val)
		end
	end
end

terra BoolBitmap:hasmarks(row1: int, col1: int, row_span: int, col_span: int)
	var row2 = row1 + row_span
	var col2 = col1 + col_span
	for row = row1, row2 do
		for col = col1, col2 do
			if self:get(row, col) then
				return true
			end
		end
	end
	return false
end

terra BoolBitmap:clear()
	self.rows = 0
	self.cols = 0
	self.bits.len = 0
end

--grid layout ----------------------------------------------------------------

--NOTE: row and column numbering starts from 1, but the arrays are 0-indexed.

--these flags can be combined: X|Y + L|R + T|B
GRID_FLOW_X = 0; GRID_FLOW_Y = 2 --main axis
GRID_FLOW_L = 0; GRID_FLOW_R = 4 --horizontal direction
GRID_FLOW_T = 0; GRID_FLOW_B = 8 --vertical direction

--auto-positioning algorithm

local terra clip_span(
	row1: int, col1: int, row_span: int, col_span: int,
	max_row: int, max_col: int
)
	var row2 = row1 + row_span - 1
	var col2 = col1 + col_span - 1
	--clip the span to grid boundaries
	row1 = clamp(row1, 1, max_row)
	col1 = clamp(col1, 1, max_col)
	row2 = clamp(row2, 1, max_row)
	col2 = clamp(col2, 1, max_col)
	--support negative spans
	if row1 > row2 then
		row1, row2 = row2, row1
	end
	if col1 > col2 then
		col1, col2 = col2, col1
	end
	row_span = row2 - row1 + 1
	col_span = col2 - col1 + 1
	return row1, col1, row_span, col_span
end

terra Layer:sync_layout_grid_autopos()

	var flow = self.grid.flow
	var col_first = (flow and GRID_FLOW_Y) == 0
	var row_first = not col_first
	var flip_cols = (flow and GRID_FLOW_R) ~= 0
	var flip_rows = (flow and GRID_FLOW_B) ~= 0

	var occupied = &self.lib.grid_occupied

	var grid_wrap = max(1, self.grid.wrap)
	var min_lines = max(1, self.grid.min_lines)
	var max_col = iif(col_first, grid_wrap, min_lines)
	var max_row = iif(row_first, grid_wrap, min_lines)

	--position explicitly-positioned layers first, mark occupied cells
	--and grow the grid bounds to include these layers fully.
	var missing_indices = false
	var negative_indices = false
	for layer in self do
		if layer.visible then
			var row = layer.grid_row
			var col = layer.grid_col
			var row_span = max(1, layer.grid_row_span)
			var col_span = max(1, layer.grid_col_span)

			if row ~= 0 or col ~= 0 then --explicit position
				row = iif(row == 0, 1, row)
				col = iif(col == 0, 1, col)
				if row > 0 and col > 0 then
					row, col, row_span, col_span =
						clip_span(row, col, row_span, col_span, maxint, maxint)

					occupied:mark(row, col, row_span, col_span, true)

					max_row = max(max_row, row + row_span - 1)
					max_col = max(max_col, col + col_span - 1)
				else
					negative_indices = true --solve these later
				end
			else --auto-positioned
				--negative spans are treated as positive.
				row_span = abs(row_span)
				col_span = abs(col_span)

				--grow the grid bounds on the main axis to fit the widest layer.
				if col_first then
					max_col = max(max_col, col_span)
				else
					max_row = max(max_row, row_span)
				end

				missing_indices = true --solve these later
			end

			layer._grid_row = row
			layer._grid_col = col
			layer._grid_row_span = row_span
			layer._grid_col_span = col_span
		end
	end

	--position explicitly-positioned layers with negative indices
	--now that we know the grid bounds. these types of spans do not enlarge
	--the grid bounds, but instead are clipped to it.
	if negative_indices then
		for layer in self do
			if layer.visible then
				var row = layer._grid_row
				var col = layer._grid_col
				if row < 0 or col < 0 then
					var row_span = layer._grid_row_span
					var col_span = layer._grid_col_span
					if row < 0 then
						row = max_row + row + 1
					end
					if col < 0 then
						col = max_col + col + 1
					end
					row, col, row_span, col_span =
						clip_span(row, col, row_span, col_span, max_row, max_col)

					occupied:mark(row, col, row_span, col_span, true)

					layer._grid_row = row
					layer._grid_col = col
					layer._grid_row_span = row_span
					layer._grid_col_span = col_span
				end
			end
		end
	end

	--auto-wrap layers with missing explicit indices over non-occupied cells.
	--grow grid bounds on the cross-axis if needed but not on the main axis.
	--these types of spans are never clipped to the grid bounds.
	if missing_indices then
		var row, col = 1, 1
		for layer in self do
			if layer.visible and layer._grid_row == 0 then
				var row_span = layer._grid_row_span
				var col_span = layer._grid_col_span

				while true do
					--check for wrapping.
					if col_first and col + col_span - 1 > max_col then
						col = 1
						row = row + 1
					elseif row_first and row + row_span - 1 > max_row then
						row = 1
						col = col + 1
					end
					if occupied:hasmarks(row, col, row_span, col_span) then
						--advance cursor by one cell.
						if col_first then
							col = col + 1
						else
							row = row + 1
						end
					else
						break
					end
				end

				occupied:mark(row, col, row_span, col_span, true)

				layer._grid_row = row
				layer._grid_col = col

				--grow grid bounds on the cross-axis.
				if col_first then
					max_row = max(max_row, row + row_span - 1)
				else
					max_col = max(max_col, col + col_span - 1)
				end

				--advance cursor to right after the span, without wrapping.
				if col_first then
					col = col + col_span
				else
					row = row + row_span
				end
			end
		end
	end

	--reverse the order of rows and/or columns depending on grid_flow.
	if flip_rows or flip_cols then
		for layer in self do
			if layer.visible then
				if flip_rows then
					layer._grid_row = max_row
						- layer._grid_row
						- layer._grid_row_span
						+ 2
				end
				if flip_cols then
					layer._grid_col = max_col
						- layer._grid_col
						- layer._grid_col_span
						+ 2
				end
			end
		end
	end

	occupied:clear()

	self.grid._flip_rows = flip_rows
	self.grid._flip_cols = flip_cols
	self.grid._max_row = max_row
	self.grid._max_col = max_col
end

--layouting algorithm

local stretch_cols_main_axis = stretch_items_main_axis_func(arr(GridLayoutCol), 'at', GridLayoutCol, 'x', 'w')
local align_cols_main_axis = align_items_main_axis_func(arr(GridLayoutCol), 'at', GridLayoutCol, 'x', 'w')

local function gen_funcs(X, Y, W, H, COL)

	local CW = 'c'..W
	local PW = 'p'..W
	local MIN_CW = 'min_'..CW
	local _MIN_W = '_min_'..W
	local SNAP_X = 'snap_'..X
	local COL_FRS = COL..'_frs'
	local COL_GAP = COL..'_gap'
	local ALIGN_ITEMS_X = 'align_items_'..X
	local ITEM_ALIGN_X = 'item_align_'..X
	local ALIGN_X = 'align_'..X
	local _COLS = '_'..COL..'s'
	local _MAX_COL = '_max_'..COL
	local _COL = '_grid_'..COL
	local _COL_SPAN = '_grid_'..COL..'_span'
	local _FLIP_COLS = '_flip_'..COL..'s'

	local terra sync_min_w(self: &Layer, other_axis_synced: bool)

		if not other_axis_synced then
			self:sync_layout_grid_autopos()
		end

		--sync all children first (bottom-up sync).
		for layer in self do
			if layer.visible then
				layer:['sync_min_'..W](other_axis_synced) --recurse
			end
		end

		var gap_w = self.grid.[COL_GAP]
		var max_col = self.grid.[_MAX_COL]
		var frs = &self.grid.[COL_FRS] --{fr1, ...}

		--compute the fraction representing the total width.
		var total_fr: num = 0.0
		for layer in self do
			if layer.inlayout then
				var col1 = layer.[_COL]
				var col2 = col1 + layer.[_COL_SPAN]
				for col = col1, col2 do
					total_fr = total_fr + frs(col-1, 1)
				end
			end
		end

		--create pseudo-layers to apply flex stretching to.
		var cols = &self.grid.[_COLS]
		cols.len = max_col

		for col = 0, max_col do
			cols:set(col, GridLayoutCol{
				inlayout = true,
				fr = frs(col, 1),
				_min_w = 0,
				x = 0,
				w = 0,
				align_x = 0,
				snap_x = self.[SNAP_X],
			})
		end

		--compute the minimum widths for each column.
		for layer in self do
			if layer.inlayout then
				var col1 = layer.[_COL]
				var col2 = col1 + layer.[_COL_SPAN] - 1
				var span_min_w = layer.[_MIN_W]

				var gap_col1: num
				if col2 == 1 and col2 == max_col then
					gap_col1 = 0
				elseif (col2 == 1 or col2 == max_col) then
					gap_col1 = gap_w * .5
				else
					gap_col1 = gap_w
				end

				var gap_col2: num
				if col2 == 1 and col2 == max_col then
					gap_col2 = 0
				elseif (col2 == 1 or col2 == max_col) then
					gap_col2 = gap_w * .5
				else
					gap_col2 = gap_w
				end

				if col1 == col2 then
					var item = cols:at(col1-1)
					var col_min_w = span_min_w + gap_col1 + gap_col2
					item._min_w = max(item._min_w, col_min_w)
				else --merged columns: unmerge
					var span_fr: num = 0.0
					for col = col1, col2 do
						span_fr = span_fr + frs(col-1, 1)
					end
					for col = col1, col2 do
						var item = cols:at(col-1)
						var col_min_w =
							frs(col-1, 1) / span_fr * span_min_w
							+ iif(col == col1, gap_col1, 0.0)
							+ iif(col == col2, gap_col2, 0.0)
						item._min_w = max(item._min_w, col_min_w)
					end
				end
			end
		end

		var min_cw: num = 0.0
		for _,item in cols do
			min_cw = min_cw + item._min_w
		end

		min_cw = max(min_cw, self.[MIN_CW])
		var min_w = min_cw + self.[PW]
		self.[_MIN_W] = min_w

		return min_w
	end

	--[[
	local terra set_item_x(layer, x, w, moving)
		x, w = snapxw(x, w, layer[SNAP_X])
		var set = moving and layer.transition or layer.end_value
		set(layer, X, x)
		set(layer, W, w)
	end

	local terra set_moving_item_x(layer, i, x, w)
		--moving NYI
	end
	]]

	local terra sum_min_w(cols: &arr(GridLayoutCol))
		var w: num = 0.0
		for _,col in cols do
			w = w + col._min_w
		end
		return w
	end

	local terra sync_x(self: &Layer, other_axis_synced: bool)

		var cols = &self.grid.[_COLS]
		var gap_w = self.grid.[COL_GAP]
		var container_w = self.[CW]
		var align_items_x = self.[ALIGN_ITEMS_X]
		var item_align_x = self.[ITEM_ALIGN_X]
		var snap_x = self.[SNAP_X]

		var ALIGN_START, ALIGN_END = ALIGN_START, ALIGN_END
		if self.grid.[_FLIP_COLS] then
			ALIGN_START, ALIGN_END = ALIGN_END, ALIGN_START
		end

		if align_items_x == ALIGN_STRETCH then
			stretch_cols_main_axis(
				cols, 0, cols.len, container_w, ALIGN_STRETCH, false)
				--set_item_x, set_moving_item_x,
				--X, W, ALIGN_END, ALIGN_RIGHT)
		else
			var sx: num, spacing: num
			if align_items_x == ALIGN_START or align_items_x == ALIGN_LEFT then
				sx, spacing = 0, 0
			else
				var items_w = sum_min_w(cols)
				var items_count = cols.len
				sx, spacing = align_metrics(align_items_x, self.[CW], items_w, items_count)
			end
			align_cols_main_axis(cols, 0, cols.len, sx, spacing, false)
				--TODO: set_item_x, set_moving_item_x
		end

		var x: num = 0.0
		for layer in self do
			if layer.inlayout then

				var col1 = layer.[_COL]
				var col2 = col1 + layer.[_COL_SPAN] - 1
				var col_item1 = cols:at(col1-1)
				var col_item2 = cols:at(col2-1)
				var x1 = col_item1.x
				var x2 = col_item2.x + col_item2.w

				var gap1 = iif(col1 ~= 1,        gap_w * 0.5, 0.0)
				var gap2 = iif(col2 ~= cols.len, gap_w * 0.5, 0.0)
				x1 = x1 + gap1
				x2 = x2 - gap2

				var align = iif(layer.[ALIGN_X] ~= 0, layer.[ALIGN_X], item_align_x)
				var x: num, w: num
				if align == ALIGN_STRETCH then
					x, w = x1, x2 - x1
				elseif align == ALIGN_START or align == ALIGN_LEFT then
					x, w = x1, layer.[_MIN_W]
				elseif align == ALIGN_END or align == ALIGN_RIGHT then
					w = layer.[_MIN_W]
					x = x2 - w
				elseif align == ALIGN_CENTER then
					w = layer.[_MIN_W]
					x = x1 + (x2 - x1 - w) / 2
				end
				layer.[X], layer.[W] = snapxw(x, w, snap_x)
			end
		end

		--sync all children last (top-down sync).
		for layer in self do
			if layer.visible then
				layer:['sync_layout_'..X](other_axis_synced) --recurse
			end
		end

		return true
	end

	return sync_min_w, sync_x
end
local grid_sync_min_w, grid_sync_x = gen_funcs('x', 'y', 'w', 'h', 'col')
local grid_sync_min_h, grid_sync_y = gen_funcs('y', 'x', 'h', 'w', 'row')

local terra grid_sync(self: &Layer)
	self:sync_layout_separate_axes(0, -inf, -inf)
end

local grid_layout = constant(`LayoutSolver {
	type       = LAYOUT_GRID;
	axis_order = AXIS_ORDER_XY;
	sync       = grid_sync;
	sync_min_w = grid_sync_min_w;
	sync_min_h = grid_sync_min_h;
	sync_x     = grid_sync_x;
	sync_y     = grid_sync_y;
	sync_top   = sync_top;
})

--layout plugin vtable -------------------------------------------------------

--NOTE: layouts must be added in the order of LAYOUT_* constants.
local layouts = constant(`arrayof(LayoutSolver,
	null_layout,
	text_layout,
	flex_layout,
	grid_layout
))

terra Layer:get_layout_type() return self.layout_solver.type end

terra Layer:set_layout_type(type: enum)
	self.layout_solver = &layouts[type]
end

terra Layer:init_layout()
	self.layout_solver = &null_layout
end

--lib ------------------------------------------------------------------------

terra Lib:init(load_font: tr.FontLoadFunc, unload_font: tr.FontLoadFunc)
	self.text_renderer:init(load_font, unload_font)
	self.grid_occupied:init()
	self.default_layout_solver = &null_layout
	self.default_text_span:init()
	self.default_shadow:init(nil)
end

terra Lib:free()
	self.text_renderer:free()
	self.grid_occupied:free()
end

--text rendering engine configuration

terra Lib:get_font_size_resolution       (): num return self.text_renderer.font_size_resolution end
terra Lib:get_subpixel_x_resolution      (): num return self.text_renderer.subpixel_x_resolution end
terra Lib:get_word_subpixel_x_resolution (): num return self.text_renderer.word_subpixel_x_resolution end
terra Lib:get_glyph_cache_size           () return self.text_renderer.glyph_cache_size end
terra Lib:get_glyph_run_cache_size       () return self.text_renderer.glyph_run_cache_size end

terra Lib:set_font_size_resolution       (v: num) self.text_renderer.font_size_resolution = v end
terra Lib:set_subpixel_x_resolution      (v: num) self.text_renderer.subpixel_x_resolution = v end
terra Lib:set_word_subpixel_x_resolution (v: num) self.text_renderer.word_subpixel_x_resolution = v end
terra Lib:set_glyph_cache_size           (v: int) self.text_renderer.glyph_cache_max_size = v end
terra Lib:set_glyph_run_cache_size       (v: int) self.text_renderer.glyph_run_cache_max_size = v end

--font registration

terra Lib:font()
	return self.text_renderer:font()
end

--debugging stuff

terra Lib:dump_stats()
	pfn('Glyph cache size     : %d', self.text_renderer.glyphs.size)
	pfn('Glyph cache count    : %d', self.text_renderer.glyphs.count)
	pfn('GlyphRun cache size  : %d', self.text_renderer.glyph_runs.size)
	pfn('GlyphRun cache count : %d', self.text_renderer.glyph_runs.count)
end

return _M
