
--Module table with dependencies, enums and types.

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/low'.module'terra/tr_module')

--dependencies ---------------------------------------------------------------

assert(color, 'require the graphics adapter first, eg. terra/tr_paint_cairo')

low = require'terra/low'
require'terra/phf'
require'terra/fixedfreelist'
require'terra/lrucache'
require'terra/arrayfreelist'
require'terra/box2d'
require_h'freetype_h'
require_h'harfbuzz_h'
require_h'fribidi_h'
require_h'libunibreak_h'
require_h'xxhash_h'

linklibrary'freetype'
linklibrary'harfbuzz'
linklibrary'fribidi'
linklibrary'unibreak'
linklibrary'xxhash'

--replace the default hash function used by the hashmap with faster xxhash.
low.bithash = macro(function(size_t, k, h, len)
	local size_t = size_t:astype()
	local T = k:getpointertype()
	local len = len or 1
	local xxh = sizeof(size_t) == 8 and XXH64 or XXH32
	return `[size_t](xxh([&opaque](k), len * sizeof(T), h))
end)

--create getters and setters for converting from/to fixed-point decimal fields.
--all fields with the name `<name>_<digits>_<decimals>` will be processed.
function fixpointfields(T)
	for i,e in ipairs(T.entries) do
		local priv = e.field
		local pub, digits, decimals = priv:match'^(.-)_(%d+)_(%d+)$'
		if pub then
			local intbits = tonumber(digits) - tonumber(decimals)
			local factor = 2^decimals
			T.methods['get_'..pub] = macro(function(self)
				return `[num](self.[priv] / [num](factor))
			end)
			local maxn = 2^intbits * 64 - 1
			T.methods['set_'..pub] = macro(function(self, x)
				return quote self.[priv] = clamp(x * factor, 0, maxn) end
			end)
		end
	end
end

--enums ----------------------------------------------------------------------

--NOTE: starting enum values at 1 so that clients can reserve 0 for "default".
ALIGN_LEFT    = 1
ALIGN_RIGHT   = 2
ALIGN_CENTER  = 3
ALIGN_JUSTIFY = 4
ALIGN_TOP     = ALIGN_LEFT
ALIGN_BOTTOM  = ALIGN_RIGHT
ALIGN_START   = 5 --based on bidi dir; only for align_x
ALIGN_END     = 6 --based on bidi dir; only for align_x
ALIGN_MAX     = 6

--bidi paragraph directions (starting at 1, see above).
DIR_AUTO = 1 --auto-detect.
DIR_LTR  = 2
DIR_RTL  = 3
DIR_WLTR = 4 --weak LTR
DIR_WRTL = 5 --weak RTL

DIR_MIN = DIR_AUTO
DIR_MAX = DIR_WRTL

--linebreak codes
BREAK_NONE = 0 --soft line-break from line-wrapping
BREAK_LINE = 1 --explicit line break (CR, LF, etc.)
BREAK_PARA = 2 --explicit paragraph break (PS).

--base types -----------------------------------------------------------------

num = float --using floats for better cache utilization.
rect = rect(num)
font_id_t = int16 --max 64k fonts can be used at the same time.

struct Renderer;
struct Font;

--font type ------------------------------------------------------------------

struct Font (gettersandsetters) {
	r: &Renderer;
	--loading and unloading
	file_data: &opaque;
	file_size: size_t;
	refcount: int; --each Span keeps a ref. caches don't keep a ref.
	--freetype & harfbuzz font objects
	ft_face: FT_Face;
	hb_font: &hb_font_t; --represents a ft_face at a particular size.
	ft_load_flags: int;
	ft_render_flags: FT_Render_Mode;
	--font metrics per current size
	size: num;
	scale: num; --scaling factor for scaling raster glyphs.
	ascent: num;
	descent: num;
}

FontLoadFunc = {int, &&opaque, &size_t} -> {}
FontLoadFunc.cname = 'tr_font_load_func'

--layout type ----------------------------------------------------------------

hb_feature_arr_t = arr(hb_feature_t)

--a span is a set of rendering properties for a specific part of the text.
--spans are kept in an array and cover the whole text without holes by virtue
--of their `offset` field alone: a span ends where the next span begins.
struct Span (gettersandsetters) {
	offset: int; --offset in the text, in codepoints.
	font_id: font_id_t;
	font_size_16_6: uint16;
	features: hb_feature_arr_t;
	script: hb_script_t;
	lang: hb_language_t;
	paragraph_dir: enum; --bidi dir override for current paragraph.
	nowrap: bool; --disable word wrapping for this span.
	opacity: double; --the opacity level in 0..1.
	color: color;
	operator: int; --blending operator.
}
fixpointfields(Span)

Span.empty = constant(`Span {
	offset = 0;
	font_id = -1;
	font_size_16_6 = 0;
	features = [hb_feature_arr_t.empty];
	script = 0;
	lang = nil;
	paragraph_dir = 0;
	nowrap = false;
	color = DEFAULT_TEXT_COLOR;
	opacity = 1;
	operator = DEFAULT_TEXT_OPERATOR;
})

terra Span:init()
	@self = [Span.empty]
end

terra Span:free()
	self.features:free()
end

terra Span:copy()
	var s = @self
	s.features = self.features:copy()
	return s
end

--an embed is a reserved visual space at a specific offset in text,
--used to embed widgets and alike in the text.
struct Embed {
	offset: int; --offset in the text
	ascent: num;
	descent: num;
	advance_x: num;
}

--a sub-segment is a clipped part of a glyph image, used when a single glyph
--image covers two spans, eg. when the letters in a ligature have diff. colors.
struct SubSeg {
	i: int16;
	j: int16;
	span: &Span;
	clip_left: num;
	clip_right: num;
}

struct Layout;

--a segment is the result of shaping a single shaping-unit i.e. a single
--word as delimited by soft-breaks per unicode line-breaking algorithm.
--because shaping is expensive, shaping results are cached in a struct
--called "glyph run" which the segment references via its `glyph_run_id`.
--segs are kept in an array in logical text order.
struct Seg {
	--filled by shaping
	glyph_run_id: int;
	line_num: int;             --physical line number
	linebreak: enum;           --for line/paragraph breaking
	bidi_level: int8;          --for bidi reordering
	paragraph_dir: enum;       --computed paragraph bidi dir, for ALIGN_AUTO
	span: &Span;               --span of the first sub-segment
	offset: int;               --codepoint offset into the text
	--filled by layouting
	line_index: int;
	x: num;
	advance_x: num; --segment's x-axis boundaries
	next_vis: &Seg; --next segment <<on the same line>> in visual order
	wrapped: bool;  --segment is the last on a wrapped line
	visible: bool;  --segment is not entirely clipped
	subsegs: arr(SubSeg);
}

terra Seg:free()
	self.subsegs:free()
end

--a line is the result of line-wrapping the text. line segments can be
--iterated in visual order via `line.first_vis/seg.next_vis` or in logical
--order via `line.first/layout.segs:next(seg)`.
struct Line (gettersandsetters) {
	first: &Seg;     --first segment in text order
	first_vis: &Seg; --first segment in visual order
	x: num;
	y: num;
	advance_x: num;
	ascent: num;
	descent: num;
	spaced_ascent: num;
	spaced_descent: num;
	linebreak: enum; --set by wrap(), used by align()
}

--iterate a line's segments in visual order.
Line.metamethods.__for = function(self, body)
	if self:islvalue() then self = `&self end
	return quote
		var self = self
		var seg = self.first_vis
		while seg ~= nil do
			[body(seg)]
			seg = seg.next_vis
		end
	end
end

--a layout is a unit of multi-paragraph rich text to be shaped, layouted,
--rendered, navigated, hit-tested, edited, updated and re-rendered.
struct Layout (gettersandsetters) {
	r: &Renderer;
	spans: arr(Span);       --shape/in
	embeds: arr(Embed);     --shape/in
	text: arr(codepoint);   --shape/in
	align_w: num;           --wrap+align/in
	align_h: num;           --align/in
	align_x: enum;          --align/in
	align_y: enum;          --align/in
	dir: enum;              --shape/in:     default base paragraph direction.
	bidi: bool;             --shape/out:   `true` if the text is bidirectional.
	line_spacing: num;      --spaceout/in:  line spacing multiplication factor (m.f.).
	hardline_spacing: num;  --spaceout/in:  line spacing m.f. for hard-breaked lines.
	paragraph_spacing: num; --spaceout/in:  paragraph spacing m.f.
	clip_x: num;            --clip/in
	clip_y: num;            --clip/in
	clip_w: num;            --clip/in
	clip_h: num;            --clip/in
	x: num;                 --paint/in
	y: num;                 --paint/in
	segs: arr(Seg);         --shape/out
	lines: arr(Line);       --wrap+align/out
	max_ax: num;            --wrap/out:     maximum x-advance
	h: num;                 --spaceout/out: wrapped height.
	spaced_h: num;          --spaceout/out: wrapped height incl. line/paragraph spacing.
	baseline: num;
	min_x: num;
	first_visible_line: int; --clip/out
	last_visible_line: int;  --clip/out
	_min_w: num;             --get_min_w/cache
	_max_w: num;             --get_max_w/cache
}

--a span's ending offset is the starting offset of the next span.
terra Layout:span_end_offset(span_i: int)
	var next_span = self.spans:at(span_i+1, nil)
	return iif(next_span ~= nil, next_span.offset, self.text.len)
end

terra Layout:init(r: &Renderer)
	fill(self)
	self.r = r
	self.dir      =  DIR_AUTO
	self.align_x  =  ALIGN_CENTER
	self.align_y  =  ALIGN_CENTER
	self.line_spacing      = 1.0
	self.hardline_spacing  = 1.0
	self.paragraph_spacing = 2.0
	self.clip_x   = -inf
	self.clip_y   = -inf
	self.clip_w   =  inf
	self.clip_h   =  inf
end

--glyph run type -------------------------------------------------------------

--glyph runs hold the results of shaping individual words and are kept in a
--special LRU cache that can also ref-count its objects so that they're not
--evicted from the cache when its memory size limit is reached. segs keep
--their glyph run alive by holding a ref to it while they're alive.

struct GlyphInfo (gettersandsetters) {
	glyph_index: int; --in the font's charmap
	x: num; --glyph origin relative to glyph run's origin
	image_x_16_6: int16; --glyph image origin relative to glyph origin
	image_y_16_6: int16;
	cluster: int;
}
fixpointfields(GlyphInfo)

struct GlyphImage {
	surface: &surface;
 	x: int16; --image coordinates relative to the (first) glyph origin
	y: int16;
}
GlyphImage.empty = `GlyphImage{surface = nil, x = 0, y = 0}

terra GlyphImage.methods.free :: {&GlyphImage, &Renderer} -> {}

struct GlyphRun (gettersandsetters) {
	--cache key fields: no alignment holes allowed between fields `lang` and `rtl` !!!
	text            : arr(codepoint);
	features        : hb_feature_arr_t;
	lang            : hb_language_t;     --8
	script          : hb_script_t;       --4
	font_id         : font_id_t;         --2
	font_size_16_6  : uint16;            --2
	rtl             : bool;              --1
	--resulting glyphs and glyph metrics
	glyphs          : arr(GlyphInfo);
	--for vertical positioning in horizontal flow
	ascent          : num;
	descent         : num;
	advance_x       : num;
	wrap_advance_x  : num;
	--pre-rendered images for each subpixel offset.
	images          : arr{T = GlyphImage, context_t = &Renderer};
	images_memsize  : int;
	--for cursor positioning and hit testing.
	--these arrays hold exactly text.len+1 items, one for each codepoint.
	cursor_offsets  : arr(uint16); --navigable offsets, so some are duplicates.
	cursor_xs       : arr(num); --x-coords, so some are duplicates.
	trailing_space  : bool; --the text includes a trailing space (for wrapping).
}
fixpointfields(GlyphRun)

local key_offset = offsetof(GlyphRun, 'lang')
local key_size = offsetafter(GlyphRun, 'rtl') - key_offset

terra GlyphRun:__hash32(h: uint32) --for hashmap
	h = hash(uint32, [&char](self) + key_offset, h, key_size)
	h = hash(uint32, &self.text, h)
	h = hash(uint32, &self.features, h)
	return h
end

terra GlyphRun:__eq(other: &GlyphRun) --for hashmap
	return equal(
			[&char](self)  + key_offset,
			[&char](other) + key_offset, key_size)
		and equal(&self.text, &other.text)
		and equal(&self.features, &other.features)
end

terra GlyphRun:__memsize() --for lru cache
	return
		  memsize(self.text)
		+ memsize(self.features)
		+ memsize(self.glyphs)
		+ memsize(self.images)
		+ memsize(self.cursor_offsets)
		+ memsize(self.cursor_xs)
		+ self.images_memsize
end

terra GlyphRun.methods.free :: {&GlyphRun, &Renderer} -> {}

--glyph type -----------------------------------------------------------------

--rasterized glyphs are also cached, this time in a cache without ref counting
--since rasterization is done on-demand on paint().

struct Glyph (gettersandsetters) {
	--cache key: no alignment holes allowed between fields `font_id` and `subpixel_offset` !!!
	font_id         : font_id_t;   --2
	font_size_16_6  : uint16;      --2
	glyph_index     : uint;        --4
	subpixel_offset_x_8_6 : uint8; --1
	--glyph image
	image: GlyphImage;
}
fixpointfields(Glyph)

Glyph.empty = `Glyph {
	font_id = -1;
	font_size_16_6 = 0;
	glyph_index = 0;
	subpixel_offset_x_8_6 = 0;
	image = [GlyphImage.empty];
}

local key_offset = offsetof(Glyph, 'font_id')
local key_size = offsetafter(Glyph, 'subpixel_offset_x_8_6') - key_offset

terra Glyph:__hash32(h: uint32) --for hashmap
	return hash(uint32, [&char](self) + key_offset, h, key_size)
end

terra Glyph:__eq(other: &Glyph) --for hashmap
	return equal(
		[&char](self ) + key_offset,
		[&char](other) + key_offset, key_size)
end

terra Glyph:__memsize() --for lru cache
	return iif(self.image.surface ~= nil,
		1024 + self.image.surface:stride() * self.image.surface:height(), 0)
end

terra Glyph.methods.free :: {&Glyph, &Renderer} -> {}

--cursor & selection types ---------------------------------------------------

--visual position in shaped text and matching offset in logical text.
struct Pos (gettersandsetters) {
	layout: &Layout;
	seg: &Seg;
	i: int;
	offset: int; --offset in logical text, for repositioning after reshaping.
}

struct Cursor (gettersandsetters) {
	p: Pos;
	x: num; --x-coord to try to go to when navigating up and down.
	--park cursor to home or end if vertical navigation goes above or beyond
	--available text lines.
	park_home: bool;
	park_end: bool;
	--jump-through same-text-offset cursors: most text editors remove duplicate
	--cursors to keep a 1:1 relationship between text positions and cursor
	--positions, which gets funny with BiDi and you also can't tell if there's
	--a space at the end of a wrapped line or not.
	unique_offsets: bool;
	--keep a cursor after the last space char on a wrapped line: this cursor can
	--be trouble because it is outside the textbox and if there's not enough room
	--on the wrap-side of the textbox it can get clipped out.
	wrapped_space: bool;
	insert_mode: bool;
	--drawing attributes
	visible: bool;
	color: color;
	opacity: num;
	w: num;
}

terra Cursor:get_layout() return self.p.layout end
terra Cursor:set_layout(p: &Layout) self.p.layout = p end

struct Selection (gettersandsetters) {
	p1: Pos;
	p2: Pos;
	color: color;
	opacity: num;
}

terra Selection:get_layout() return self.p1.layout end
terra Selection:set_layout(p: &Layout)
	self.p1.layout = p
	self.p2.layout = p
end

--renderer type --------------------------------------------------------------

struct SegRange {
	left: &Seg;
	right: &Seg;
	prev: &SegRange;
	bidi_level: int8;
}

RangesFreelist = fixedfreelist(SegRange)

GlyphRunCache = lrucache {key_t = GlyphRun, context_t = &Renderer}
GlyphCache = lrucache {key_t = Glyph, context_t = &Renderer}

struct Renderer (gettersandsetters) {

	--rasterizer config
	font_size_resolution: num;
	subpixel_x_resolution: num;
	word_subpixel_x_resolution: num;

	ft_lib: FT_Library;

	fonts: arrayfreelist(Font, font_id_t);
	load_font: FontLoadFunc;
	unload_font: FontLoadFunc;

	glyphs: GlyphCache;
	glyph_runs: GlyphRunCache;

	--temporary arrays that grow as long as the longest input text.
	cpstack:         arr(codepoint);
	scripts:         arr(hb_script_t);
	langs:           arr(hb_language_t);
	bidi_types:      arr(FriBidiCharType);
	bracket_types:   arr(FriBidiBracketType);
	levels:          arr(int8);
	linebreaks:      arr(char);
	grapheme_breaks: arr(char);
	carets_buffer:   arr(hb_position_t);
	substack:        arr(SubSeg);
	ranges:          RangesFreelist;
	sbuf:            arr(char);
	xsbuf:           arr(double);
	paragraph_dirs:  arr(enum);

	--constants that neeed to be initialized at runtime.
	HB_LANGUAGE_EN: hb_language_t;
	HB_LANGUAGE_DE: hb_language_t;
	HB_LANGUAGE_ES: hb_language_t;
	HB_LANGUAGE_FR: hb_language_t;
	HB_LANGUAGE_RU: hb_language_t;
	HB_LANGUAGE_ZH: hb_language_t;

	paint_glyph_num: int;
}

terra Layout:glyph_run(seg: &Seg)
	return &self.r.glyph_runs:pair(seg.glyph_run_id).key
end


return _M
