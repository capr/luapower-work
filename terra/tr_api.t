--[[

	Text Renderer C/Terra API.
	Implements a flat API tailored for C or Terra use.

	- self-allocating constructors.
	- non-fatal error checking and reporting.
	- enum validation, number clamping to range.
	- state invalidation when input values are changed.
	- state checking when computed values are read.
	- utf8 text input/output.
	- text representation for: features, lang, script.
	- checking if a span property has the same value across an offset range.
	- updating a span property for an offset range with auto-collapsing
	  of duplicate spans.

	- simplified and enlarged number types for forward ABI compatibility.
	- consecutive enum values for forward ABI compatibility.
	- functions and types are renamed and prefixed to C conventions.
	- methods and virtual properties are bound back to types via ffi.metatype.

]]

require'terra/memcheck'
require'terra/tr_paint_cairo'
require'terra/utf8'
require'terra/rawstringview'
require'terra/tr_cursor'
local tr = require'terra/tr'
setfenv(1, require'terra/low'.module(tr))

num = double
MAX_CURSOR_COUNT = 2^16

FontLoadFunc.cname = 'tr_font_load_func'

struct Layout;
struct Renderer;

--Renderer & Layout wrappers and self-allocating constructors ----------------

ErrorFunction = {rawstring} -> {}
ErrorFunction.cname = 'error_function_t'

local terra default_error_function(message: rawstring)
	fprintf(stderr(), '%s\n', message)
end

struct Renderer (gettersandsetters) {
	r: tr.Renderer;
	error_function: ErrorFunction;
}

terra Renderer:init(load_font: FontLoadFunc, unload_font: FontLoadFunc)
	self.r:init(load_font, unload_font)
	self.error_function = default_error_function
end

terra Renderer:free()
	self.r:free()
end

terra tr_renderer_sizeof()
	return [int](sizeof(Renderer))
end

terra tr_renderer(load_font: FontLoadFunc, unload_font: FontLoadFunc)
	return new(Renderer, load_font, unload_font)
end

terra Renderer:release()
	release(self)
end

struct Layout (gettersandsetters) {
	l: tr.Layout;
	cursors: arr(Cursor);
	_min_w: num;
	_max_w: num;
	_maxlen: int;
	state: enum; --STATE_*
	_offsets_valid: bool; --span offsets are good so spans can be split/merged.
	_values_valid: bool;  --span values are good so shaping won't crash.
}

terra Layout:get_r() return [&Renderer](self.l.r) end

terra Layout:init(r: &Renderer)
	self.l:init(&r.r)
	self.cursors:init()
	self._min_w = -inf
	self._max_w =  inf
	self._maxlen = maxint
	self.state = 0
	self._offsets_valid = false
	self._values_valid = false
end

terra Layout:free()
	self.cursors:free()
	self.l:free()
end

terra tr_layout_sizeof()
	return [int](sizeof(Layout))
end

terra Renderer:layout()
	return new(Layout, self)
end

terra Layout:release()
	release(self)
end

--Renderer config ------------------------------------------------------------

local terra subpixel_resolution(v: num)
	return 1.0 / nextpow2(int(1.0 / clamp(v, 1.0/64, 1.0)))
end

terra Renderer:get_subpixel_x_resolution(): num
	return self.r.subpixel_x_resolution
end
terra Renderer:set_subpixel_x_resolution(v: num)
	self.r.subpixel_x_resolution = subpixel_resolution(v)
end

terra Renderer:get_word_subpixel_x_resolution(): num
	return self.r.word_subpixel_x_resolution
end
terra Renderer:set_word_subpixel_x_resolution(v: num)
	self.r.word_subpixel_x_resolution = subpixel_resolution(v)
end

terra Renderer:get_font_size_resolution(): num
	return self.r.font_size_resolution
end
terra Renderer:set_font_size_resolution(v: num)
	self.r.font_size_resolution = subpixel_resolution(v)
end

terra Renderer:get_glyph_run_cache_max_size (): int return self.r.glyph_runs.max_size end
terra Renderer:set_glyph_run_cache_max_size (size: int)    self.r.glyph_runs.max_size = size end

terra Renderer:get_glyph_cache_max_size(): int return self.r.glyphs.max_size end
terra Renderer:set_glyph_cache_max_size(size: int)    self.r.glyphs.max_size = size end

--Renderer statistics API ----------------------------------------------------

terra Renderer:get_glyph_run_cache_size (): int return self.r.glyph_runs.size end
terra Renderer:get_glyph_run_cache_count(): int return self.r.glyph_runs.count end
terra Renderer:get_glyph_cache_size     (): int return self.r.glyphs.size end
terra Renderer:get_glyph_cache_count    (): int return self.r.glyphs.count end

terra Renderer:get_paint_glyph_num(): int return self.r.paint_glyph_num end
terra Renderer:set_paint_glyph_num(n: int)       self.r.paint_glyph_num = n end

--Renderer font API ----------------------------------------------------------

terra Renderer:font() return self.r:font() end
terra Renderer:free_font(font_id: int) self.r:free_font(font_id) end

--non-fatal error checking and reporting -------------------------------------

Renderer.methods.error = macro(function(self, ...)
	local args = args(...)
	return quote
		if self.error_function ~= nil then
			var s: char[256]
			snprintf(s, 256, [args])
			self.error_function(s)
		end
	end
end)

Layout.methods.check = macro(function(self, NAME, v, valid)
	NAME = NAME:asvalue()
	FORMAT = 'invalid '..NAME..': %d'
	return quote
		if not valid then
			self.r:error(FORMAT, v)
		end
		in valid
	end
end)

Layout.methods.checkrange = macro(function(self, NAME, v, MIN, MAX)
	NAME = NAME:asvalue()
	MIN = MIN:asvalue()
	MAX = MAX:asvalue()
	FORMAT = 'invalid '..NAME..': %d (range: '..MIN..'..'..MAX..')'
	return quote
		var ok = v >= MIN and v <= MAX
		if not ok then
			self.r:error(FORMAT, v)
		end
		in ok
	end
end)

--state validation and invalidation ------------------------------------------

--macro to generate multiple invalidation calls in one go.
Layout.methods.invalidate = macro(function(self, WHAT)
	WHAT = WHAT and WHAT:asvalue() or 'valid'
	return quote
		escape
			for s in WHAT:gmatch'[^%s]+' do
				emit quote self:['_invalidate_'..s]() end
			end
		end
	end
end)

STATE_VALID   = 1
STATE_SHAPED  = 2
STATE_WRAPPED = 3
STATE_SPACED  = 4
STATE_ALIGNED = 5
STATE_CLIPPED = 6
STATE_PAINTED = 7

terra Layout:_invalidate_valid   () self.state = min(self.state, STATE_VALID   - 1) end
terra Layout:_invalidate_shape   () self.state = min(self.state, STATE_SHAPED  - 1) end
terra Layout:_invalidate_wrap    () self.state = min(self.state, STATE_WRAPPED - 1) end
terra Layout:_invalidate_spaceout() self.state = min(self.state, STATE_SPACED  - 1) end
terra Layout:_invalidate_align   () self.state = min(self.state, STATE_ALIGNED - 1) end
terra Layout:_invalidate_clip    () self.state = min(self.state, STATE_CLIPPED - 1) end
terra Layout:_invalidate_paint   () self.state = min(self.state, STATE_PAINTED - 1) end

terra Layout:_invalidate_min_w()
	self._min_w = -inf
end

terra Layout:_invalidate_max_w()
	self._max_w =  inf
end

--check that there's at least one span and it has offset zero.
--check that spans have monotonically increasing, in-range offsets.
--check that all spans can be displayed (font and font size it set).
terra Layout:_do_validate()
	if self.l.spans.len == 0 or self.l.spans:at(0).offset ~= 0 then
		self._offsets_valid = false
		self._values_valid = false
	else
		self._offsets_valid = true
		self._values_valid = true
		var prev_offset = -1
		for _,s in self.l.spans do
			if s.offset <= prev_offset         --offset overlapping
				or s.offset >= self.l.text.len  --offset out-of-range
			then
				self._offsets_valid = false
			end
			if s.font_id == -1      --font not set
				or s.font_size <= 0  --font size not set
			then
				self._values_valid = false
			end
			prev_offset = s.offset
		end
	end
end

terra Layout:_validate()
	if self.state < STATE_VALID then
		assert(self.state == STATE_VALID - 1)
		self:_do_validate()
		self.state = STATE_VALID
	end
end

terra Layout:get_offsets_valid()
	self:_validate()
	return self._offsets_valid
end

terra Layout:get_valid()
	self:_validate()
	return self._offsets_valid and self._values_valid
end

terra Layout:shape()
	if self.state < STATE_SHAPED and self.valid then
		assert(self.state == STATE_SHAPED - 1)
		self:_invalidate_min_w()
		self:_invalidate_max_w()
		self.l:shape()
		self.state = STATE_SHAPED
	end
end

terra Layout:wrap()
	if self.state >= STATE_VALID and self.state < STATE_WRAPPED then
		assert(self.state == STATE_WRAPPED - 1)
		self.l:wrap()
		self.state = STATE_WRAPPED
	end
end

terra Layout:spaceout()
	if self.state >= STATE_VALID and self.state < STATE_SPACED then
		assert(self.state == STATE_SPACED - 1)
		self.l:spaceout()
		self.state = STATE_SPACED
	end
end

terra Layout:align()
	if self.state >= STATE_VALID and self.state < STATE_ALIGNED then
		assert(self.state == STATE_ALIGNED - 1)
		self.l:align()
		self.state = STATE_ALIGNED
	end
end

terra Layout:clip()
	if self.state >= STATE_VALID and self.state < STATE_CLIPPED then
		assert(self.state == STATE_CLIPPED - 1)
		self.l:clip()
		self.state = STATE_CLIPPED
	end
end

terra Layout:layout()
	self:shape()
	self:wrap()
	self:spaceout()
	self:align()
	self:clip()
end

terra Layout:paint(cr: &context)
	if self.state >= STATE_VALID then
		assert(self.state >= STATE_CLIPPED)
		for i,c in self.cursors do
			c:draw_selection(cr, true)
		end
		self.l:paint_text(cr)
		for i,c in self.cursors do
			c:draw_caret(cr)
		end
		self.state = STATE_PAINTED
	end
end

--macros to a update value when changed and invalidate state -----------------

local change = macro(function(self, FIELD, v)
	FIELD = FIELD:asvalue()
	return quote
		var changed = (self.[FIELD] ~= v)
		if changed then
			self.[FIELD] = v
		end
		in changed
	end
end)

Layout.methods.change = macro(function(self, target, FIELD, v, WHAT)
	WHAT = WHAT or `nil
	return quote
		var changed = change(target, FIELD, v)
		if changed then
			self:invalidate(WHAT)
		end
		in changed
	end
end)

--layout editing -------------------------------------------------------------

terra Layout:get_maxlen(): int return self._maxlen end

terra Layout:set_maxlen(v: int)
	if self:change(self, '_maxlen', max(v, 0)) then
		if self.l.text.len > self.maxlen then --truncate the text
			self.l.text.len = v
			self:invalidate()
		end
	end
end

terra Layout:get_text_len(): int return self.l.text.len end
terra Layout:get_text() return self.l.text.elements end

terra Layout:set_text(s: &codepoint, len: int)
	if s == nil then
		assert(len == 0)
		self.l.text.len = 0
	else
		self.l.text.len = 0
		self.l.text:add(s, min(self.maxlen, len))
	end
	self:invalidate()
end

terra Layout:get_text_utf8(out: rawstring, max_outlen: int)
	if max_outlen < 0 then
		max_outlen = maxint
	end
	if out == nil then --out buffer size requested
		return utf8.encode.count(self.l.text.elements, self.l.text.len,
			max_outlen, utf8.REPLACE, utf8.INVALID)._0
	else
		return utf8.encode.tobuffer(self.l.text.elements, self.l.text.len, out,
			max_outlen, utf8.REPLACE, utf8.INVALID)._0
	end
end

terra Layout:get_text_utf8_len(): int
	return self:get_text_utf8(nil, -1)
end

terra Layout:set_text_utf8(s: rawstring, len: int)
	if s == nil then
		assert(len == 0)
		self.l.text.len = 0
	else
		if len < 0 then
			len = strnlen(s, self.maxlen)
		end
		utf8.decode.toarr(s, len, &self.l.text,
			self.maxlen, utf8.REPLACE, utf8.INVALID)
	end
	self:invalidate()
end

terra Layout:get_dir(): enum return self.l.dir end

terra Layout:set_dir(v: enum)
	if self:checkrange('dir', v, DIR_MIN, DIR_MAX) then
		self:change(self.l, 'dir', v, 'shape')
	end
end

terra Layout:get_align_w(): num return self.l.align_w end
terra Layout:get_align_h(): num return self.l.align_h end

terra Layout:set_align_w(v: num) self:change(self.l, 'align_w', v, 'wrap') end
terra Layout:set_align_h(v: num) self:change(self.l, 'align_h', v, 'align') end

terra Layout:get_align_x(): enum return self.l.align_x end
terra Layout:get_align_y(): enum return self.l.align_y end

terra Layout:set_align_x(v: enum)
	if self:check('align_x', v,
			   v == ALIGN_LEFT
			or v == ALIGN_RIGHT
			or v == ALIGN_CENTER
			or v == ALIGN_JUSTIFY
			or v == ALIGN_START
			or v == ALIGN_END
	) then
		self:change(self.l, 'align_x', v, 'align')
	end
end

terra Layout:set_align_y(v: enum)
	if self:check('align_y', v,
			   v == ALIGN_TOP
			or v == ALIGN_BOTTOM
			or v == ALIGN_CENTER
	) then
		self:change(self.l, 'align_y', v, 'align')
	end
end

terra Layout:get_line_spacing      (): num return self.l.line_spacing      end
terra Layout:get_hardline_spacing  (): num return self.l.hardline_spacing  end
terra Layout:get_paragraph_spacing (): num return self.l.paragraph_spacing end

terra Layout:set_line_spacing      (v: num) self:change(self.l, 'line_spacing'     , v, 'spaceout') end
terra Layout:set_hardline_spacing  (v: num) self:change(self.l, 'hardline_spacing' , v, 'spaceout') end
terra Layout:set_paragraph_spacing (v: num) self:change(self.l, 'paragraph_spacing', v, 'spaceout') end

terra Layout:get_clip_x(): num return self.l.clip_x end
terra Layout:get_clip_y(): num return self.l.clip_y end
terra Layout:get_clip_w(): num return self.l.clip_w end
terra Layout:get_clip_h(): num return self.l.clip_h end

terra Layout:set_clip_x(v: num) self:change(self.l, 'clip_x', v, 'clip') end
terra Layout:set_clip_y(v: num) self:change(self.l, 'clip_y', v, 'clip') end
terra Layout:set_clip_w(v: num) self:change(self.l, 'clip_w', v, 'clip') end
terra Layout:set_clip_h(v: num) self:change(self.l, 'clip_h', v, 'clip') end

terra Layout:set_clip_extents(x1: num, y1: num, x2: num, y2: num)
	self.clip_x = x1
	self.clip_y = y1
	self.clip_w = x2-x1
	self.clip_h = y2-y1
end

terra Layout:get_x(): num return self.l.x end
terra Layout:get_y(): num return self.l.y end

terra Layout:set_x(v: num) self:change(self.l, 'x', v, 'clip') end
terra Layout:set_y(v: num) self:change(self.l, 'y', v, 'clip') end

--span editing ---------------------------------------------------------------

SPAN_FIELDS = {
	'font_id',
	'font_size',
	'features',
	'script',
	'lang',
	'paragraph_dir',
	'nowrap',
	'color',
	'opacity',
	'operator',
}
local SPAN_FIELD_INDICES = index(SPAN_FIELDS)

local BIT = function(field)
	local i = SPAN_FIELD_INDICES[field]
	return 2^(i-1)
end
local BIT_ALL = 2^(#SPAN_FIELDS)-1

local span_mask_has_bit = macro(function(mask, FIELD)
	local bit = BIT(FIELD:asvalue())
	return `(mask and bit) ~= 0
end)

--compare s<->d and return a bitmask showing which field values are the same.
local terra compare_spans(d: &Span, s: &Span)
	var mask = 0
	escape
		for _,FIELD in ipairs(SPAN_FIELDS) do
			emit quote
				if d.[FIELD] == s.[FIELD] then
					mask = mask or [BIT(FIELD)]
				end
			end
		end
	end
	return mask
end

--always returns a valid span index except it returns -1 when spans.len == 0.
local terra cmp_spans(s1: &Span, s2: &Span)
	return s1.offset <= s2.offset  -- < < = = [>] >
end
terra tr.Layout:span_at_offset(offset: int)
	offset = max(0, offset)
	return self.spans:binsearch(Span{offset = offset}, cmp_spans) - 1
end

--NOTE: -1 is two positions outside the text, not one. This allows
--range (0, -1) on empty text to have length 1 otherwise setting span
--attributes on range (0, -1) would not have any effect on empty text.
terra tr.Layout:offset_range(o1: int, o2: int)
	if o1 < 0 then o1 = self.text.len + o1 + 2 end
	if o2 < 0 then o2 = self.text.len + o2 + 2 end
	if o2 < o1 then o1, o2 = o2, o1 end
	return o1, o2
end

terra Layout:split_spans(offset: int, allow_add: bool)
	if allow_add and self.l.spans.len == 0 then
		self.l.spans:add([Span.empty])
		self:invalidate()
	end
	if not allow_add and self.l.spans:at(self.l.spans.len-1).offset < offset then
		return self.l.spans.len --return that span that would have been added
	end
	var i = self.l:span_at_offset(offset)
	var s = self.l.spans:at(i)
	if s.offset < offset then
		inc(i)
		var s1 = s:copy()
		s1.offset = offset
		self.l.spans:insert(i, s1)
		self:invalidate()
	else
		assert(s.offset == offset)
	end
	return i
end

terra Layout:remove_duplicate_spans(i1: int, i2: int)
	i1 = self.l.spans:clamp(i1)
	i2 = self.l.spans:clamp(i2)
	var s = self.l.spans:at(i2)
	var i = i2 - 1
	while i >= i1 do
		var d = self.l.spans:at(i)
		if compare_spans(d, s) == BIT_ALL then
			self.l.spans:remove(i+1) --TODO: remove in chunks to avoid O(n^2)
			self:invalidate()
		end
		s = d
		dec(i)
	end
end

--remove all spans that are out of the text range.
terra Layout:remove_trailing_spans()
	for i,s in self.l.spans:backwards() do
		if s.offset < self.l.text.len then
			self.l.spans:remove(i+1, maxint)
			self:invalidate()
			break
		end
	end
end

--get a bitmask showing which span values are the same for an offset range
--and the span id at o1 for which to get the actual values.
terra tr.Layout:get_span_same_mask(o1: int, o2: int)
	o1, o2 = self:offset_range(o1, o2)
	var mask: uint32 = BIT_ALL --presume all field values are the same.
	var i = self:span_at_offset(o1)
	var s = self.spans:at(i)
	if o2 > o1 then
		var i2 = self:span_at_offset(o2-1)+1
		for i = i+1, i2 do
			var d = self.spans:at(i)
			mask = mask and compare_spans(s, d)
			if mask == 0 then break end --all field values are different.
		end
	end
	return mask, i
end

terra Span:load_features(layout: &tr.Layout, s: rawstring)
	self.features.len = 0
	var sview = rawstringview(s)
	var j = 0
	var gs = sview:gsplit' '
	for i,len in gs do
		var feat: hb_feature_t
		if hb_feature_from_string(sview:at(i), len, &feat) ~= 0 then
			self.features:add(feat)
		end
	end
end

terra Span:save_features(layout: &tr.Layout)
	var sbuf = &layout.r.sbuf
	sbuf.len = 0
	for i,feat in self.features do
		sbuf.min_capacity = sbuf.len + 128
		var p = sbuf:at(sbuf.len)
		hb_feature_to_string(feat, p, 128)
		var n = strnlen(p, 128)
		sbuf.len = sbuf.len + n
		if i < self.features.len-1 then
			sbuf:add(32) --space char
		end
	end
	sbuf:add(0) --null-terminate
	return iif(sbuf.len > 1, sbuf.elements, nil)
end

terra Span:load_lang(layout: &tr.Layout, s: rawstring)
	self.lang = hb_language_from_string(s, -1)
end

terra Span:save_lang(layout: &tr.Layout)
	return hb_language_to_string(self.lang)
end

terra Span:load_script(layout: &tr.Layout, s: rawstring)
	self.script = hb_script_from_string(s, -1)
end

terra Span:save_script(layout: &tr.Layout)
	var sbuf = &layout.r.sbuf
	sbuf.len = 5
	var tag = hb_script_to_iso15924_tag(self.script)
	hb_tag_to_string(tag, sbuf.elements)
	return iif(sbuf(0) ~= 0, sbuf.elements, nil)
end

terra Span:load_font_id(layout: &tr.Layout, font_id: font_id_t)
	var cur_font = layout.r.fonts:at(self.font_id, nil)
	if cur_font ~= nil then
		cur_font:unref()
	end
	var font = layout.r.fonts:at(font_id, nil)
	self.font_id = iif(font ~= nil, iif(font:ref(), font_id, -1), -1)
end

SPAN_FIELD_TYPES = {
	font_id           = int       ,
	font_size         = double    ,
	features          = rawstring ,
	script            = rawstring ,
	lang              = rawstring ,
	paragraph_dir     = int       ,
	nowrap            = bool      ,
	color             = uint32    ,
	opacity           = double    ,
	operator          = enum      ,
}

local SPAN_FIELD_INVALIDATE = {
	features          = 'shape',
	script            = 'shape',
	lang              = 'shape',
	paragraph_dir     = 'wrap',
	nowrap            = 'wrap min_w',
	color             = 'paint',
	opacity           = 'paint',
	operator          = 'paint',
}

--Generate getters and setters for each text attr that can be set on an offset range.
--Uses Layout:save_<field>() and Layout:load_<field> methods if available.
for _,FIELD in ipairs(SPAN_FIELDS) do

	local T = SPAN_FIELD_TYPES[FIELD] or Span:getfield(FIELD).type
	local INVALIDATE = SPAN_FIELD_INVALIDATE[FIELD] or `nil

	local SAVE = Span:getmethod('save_'..FIELD)
		or macro(function(self) return `self.[FIELD] end)

	--API for getting/setting span properties on a text offset range.

	Layout.methods['has_'..FIELD] = terra(self: &Layout, o1: int, o2: int)
		if self.offsets_valid then
			var mask, span_i = self.l:get_span_same_mask(o1, o2)
			return span_mask_has_bit(mask, FIELD)
		else
			self.r:error('has_%s() error: invalid span offsets', FIELD)
			return false
		end
	end

	local LOAD = Span:getmethod('load_'..FIELD)
		or macro(function(self, layout, val) return quote self.[FIELD] = val end end)

	Layout.methods['set_'..FIELD] = terra(self: &Layout, o1: int, o2: int, val: T)
		if self.l.spans.len == 0 or self.offsets_valid then
			o1, o2 = self.l:offset_range(o1, o2)
			var i1 = self:split_spans(o1, true)
			var i2 = self:split_spans(o2, false)
			for i = i1, i2 do
				var span = self.l.spans:at(i)
				LOAD(span, &self.l, val)
			end
			self:remove_duplicate_spans(i1-1, i2+1)
			self:invalidate(INVALIDATE)
		else
			self.r:error('set_%s() error: invalid span offsets', FIELD)
		end
	end

	--API for getting/setting spans directly as an array (for (de)serialization).

	Layout.methods['get_span_'..FIELD] = terra(self: &Layout, span_i: int): T
		var span = self.l.spans:at(span_i, &[Span.empty])
		return SAVE(span, &self.l)
	end

	Layout.methods['set_span_'..FIELD] = terra(self: &Layout, span_i: int, val: T)
		var span = self.l.spans:getat(span_i, [Span.empty])
		LOAD(span, &self.l, val)
		self:invalidate(INVALIDATE)
	end

end

terra Layout:get_span_offset(span_i: int): int
	return self.l.spans:at(span_i, &[Span.empty]).offset
end

terra Layout:set_span_offset(span_i: int, val: int)
	self.l.spans:getat(span_i, [Span.empty]).offset = val
	self:invalidate()
end

terra Layout:get_span_count(): int
	return self.l.spans.len
end

terra Layout:set_span_count(n: int)
	n = max(n, 0)
	if self.l.spans.len ~= n then
		self.l.spans:setlen(n, [Span.empty])
		self:invalidate()
	end
end

terra Layout:span_at_offset(offset: int): int
	assert(self.offsets_valid)
	return self.l:span_at_offset(offset)
end

--text editing ---------------------------------------------------------------

--[[
--remove text between two offsets. return offset at removal point.
local terra cmp_remove_first(s1: &Span, s2: &Span)
	return s1.offset < s2.offset  -- < < [=] = > >
end
local terra cmp_remove_last(s1: &Span, s2: &Span)
	return s1.offset <= s2.offset  -- < < = = [>] >
end
terra Layout:remove(i1: int, i2: int)
	i1 = self.spans:clamp(i1)
	i2 = self.spans:clamp(i2)
	self.text:remove(i1, i2-i1)
	--adjust/remove affected spans.
	--NOTE: this includes all zero-length text runs at both ends.

	--1. find the first and last text runs which need to be entirely removed.
	local tr_i1 = self.spans:binsearch(Span{offset = i1}, cmp_remove_first) or #self + 1
	local tr_i2 = self.spans:binsearch(Span{offset = i2}, cmp_remove_last) or #self + 1) - 1
	--NOTE: clamping to #self-1 so that the last text run cannot be removed.
	local tr_remove_count = clamp(tr_i2 - tr_i1 + 1, 0, #self-1)

	local offset = 0

	--2. adjust the length of the run before the first run that needs removing.
	if tr_i1 > 1 then
		local run = self[tr_i1-1]
		local part_before_i1 = i1 - run.offset
		local part_after_i2 = max(run.offset + run.len - i2, 0)
		local new_len = part_before_i1 + part_after_i2
		changed = changed or run.len ~= new_len
		run.len = new_len
		offset = run.offset + run.len
	end

	if tr_remove_count > 0 then

		--3. adjust the offset of all runs after the last run that needs removing.
		for tr_i = tr_i2+1, #self do
			self[tr_i].offset = offset
			offset = offset + self[tr_i].len
		end

		--4. remove all text runs that need removing from the text run list.
		shift(self, tr_i1, -tr_remove_count)
		for tr_i = #self, tr_i1 + tr_remove_count, -1 do
			self[tr_i] = nil
		end

		changed = true
	end

	return i1, changed
end
]]

--[[
--insert text at offset. return offset after inserted text.
local function cmp_insert(text_runs, i, offset)
	return text_runs[i].offset <= offset -- < < = = [>] >
end
function text_runs:insert(i, s, sz, charset, maxlen)
	sz = sz or #s
	charset = charset or 'utf8'
	if sz <= 0 then return i, false end

	--get the length of the inserted text in codepoints.
	local len
	if charset == 'utf8' then
		maxlen = maxlen and max(0, floor(maxlen))
		len = utf8.decode(s, sz, false, maxlen) or maxlen
	elseif charset == 'utf32' then
		len = sz
	else
		assert(false, 'Invalid charset: %s', charset)
	end
	if len <= 0 then return i, false end

	--reallocate the codepoints buffer and copy over the existing codepoints
	--and copy/convert the new codepoints at the insert point.
	local old_len = self.len
	local old_str = self.codepoints
	local new_len = old_len + len
	local new_str = self.alloc_codepoints(new_len + 1)
	i = clamp(i, 0, old_len)
	ffi.copy(new_str, old_str, i * 4)
	ffi.copy(new_str + i + len, old_str + i, (old_len - i) * 4)
	if charset == 'utf8' then
		utf8.decode(s, sz, new_str + i, len)
	else
		ffi.copy(new_str + i, ffi.cast(const_char_ct, s), len * 4)
	end
	self.len = new_len
	self.codepoints = new_str

	--adjust affected text runs.

	--1. find the text run which needs to be extended to include the new text.
	local tr_i = (binsearch(i, self, cmp_insert) or #self + 1) - 1
	assert(tr_i >= 0)

	--2. adjust the length of that run to include the length of the new text.
	self[tr_i].len = self[tr_i].len + len

	--3. adjust offset for all runs after the extended run.
	for tr_i = tr_i+1, #self do
		self[tr_i].offset = self[tr_i].offset + len
	end

	return i+len, true
end
]]

--[[

--Layout API

terra Layout:get_bidi()
	assert(self.state >= STATE_SHAPE)
	return self.l.bidi
end

terra Layout:get_dir(): enum
	assert(self.state >= STATE_SHAPE)
	return self.l.dir
end

terra Layout:get_line_count(): int
	assert(self.state >= STATE_WRAP)
	return self.l.lines.len
end

terra Layout:get_max_ax(): num
	assert(self.state >= STATE_WRAP)
	return self.l.max_ax
end

terra Layout:get_h(): num
	assert(self.state >= STATE_WRAP)
	return self.l.h
end

terra Layout:get_min_x(): num
	assert(self.state >= STATE_WRAP)
	return self.l.min_x
end

terra Layout:get_first_visible_line(): int
	assert(self.state >= STATE_CLIP)
	return self.l.first_visible_line
end

terra Layout:get_last_visible_line(): int
	assert(self.state >= STATE_CLIP)
	return self.l.last_visible_line
end

--line API

terra Layout:cursor_xs(line_i: int)
	var xs = self.l:cursor_xs(line_i)
	return xs.elements, xs.len
end

terra Layout:get_line_x             (line_i: int): num return self.l.lines:at(line_i).x end
terra Layout:get_line_y             (line_i: int): num return self.l.lines:at(line_i).y end
terra Layout:get_line_advance_x     (line_i: int): num return self.l.lines:at(line_i).advance_x end
terra Layout:get_line_ascent        (line_i: int): num return self.l.lines:at(line_i).ascent end
terra Layout:get_line_descent       (line_i: int): num return self.l.lines:at(line_i).descent end
terra Layout:get_line_spaced_ascent (line_i: int): num return self.l.lines:at(line_i).spaced_ascent end
terra Layout:get_line_spaced_descent(line_i: int): num return self.l.lines:at(line_i).spaced_descent end

--segment API

terra Layout:get_seg_line_num  (seg_i: int) end
terra Layout:get_seg_linebreak (seg_i: int) end
terra Layout:get_seg_span      (seg_i: int) end
terra Layout:get_seg_offset    (seg_i: int) end
terra Layout:get_seg_line      (seg_i: int) end
terra Layout:get_seg_x         (seg_i: int) end
terra Layout:get_seg_advance_x (seg_i: int) end
terra Layout:get_seg_wrapped   (seg_i: int) end
terra Layout:get_seg_visible   (seg_i: int) end
terra Layout:get_seg_next_vis  (seg_i: int) end
]]

--layouting helper APIs ------------------------------------------------------

terra Layout:get_min_size_valid() --text box might need re-layouting.
	return self.state >= STATE_SPACED
end

terra Layout:get_align_valid() --text needs re-aligning.
	return self.state >= STATE_ALIGNED
end

terra Layout:get_pixels_valid() --text needs repainting.
	return self.state >= STATE_PAINTED
end

terra Layout:get_visible() --check if the text and/or cursor is visible.
	return (self.l.text.len > 0 or self.cursors.len > 0) and self.valid
end

terra Layout:get_min_w(): num --for page layouting min-size constraints.
	assert(self.state >= STATE_SHAPED)
	if self._min_w == -inf then
		self._min_w = self.l:min_w()
	end
	return self._min_w
end

terra Layout:get_max_w(): num --not used yet
	assert(self.state >= STATE_SHAPED)
	if self._max_w == -inf then
		self._max_w = self.l:max_w()
	end
	return self._max_w
end

terra Layout:get_baseline(): num --for page layouting baseline alignment.
	assert(self.state >= STATE_ALIGNED)
	return self.l.baseline
end

terra Layout:get_spaced_h(): num --for page layouting min-size constraints.
	assert(self.state >= STATE_SPACED)
	return self.l.spaced_h
end

terra Layout:bbox(): {num, num, num, num}
	return self.l:bbox()
end

--cursor & selection API -----------------------------------------------------

terra Layout:get_cursor_count(): int
	return self.cursors.len
end
terra Layout:set_cursor_count(n: int): int
	n = clamp(n, 0, MAX_CURSOR_COUNT)
	if self.cursors.len ~= n then
		for _,c in self.cursors:setlen(n) do
			(@c):init(&self.l)
		end
		self:invalidate'paint'
	end
end

terra Layout:_cursor(c_i: int)
	c_i = clamp(c_i, 0, MAX_CURSOR_COUNT-1)
	var c, new_cursors = self.cursors:getat(c_i)
	for _,c in new_cursors do
		(@c):init(&self.l)
		self:invalidate'paint'
	end
	return c
end

terra Layout:get_cursor_offset     (c_i: int): int return self.cursors:at(c_i, &[Cursor.empty]).state.offset     end
terra Layout:get_cursor_which      (c_i: int): int return self.cursors:at(c_i, &[Cursor.empty]).state.which      end
terra Layout:get_cursor_sel_offset (c_i: int): int return self.cursors:at(c_i, &[Cursor.empty]).state.sel_offset end
terra Layout:get_cursor_sel_which  (c_i: int): int return self.cursors:at(c_i, &[Cursor.empty]).state.sel_which  end
terra Layout:get_cursor_x          (c_i: int): num return self.cursors:at(c_i, &[Cursor.empty]).state.x          end

terra Layout:set_cursor_offset(c_i: int, v: int)
	self:change(self:_cursor(c_i).state, 'offset', v, 'paint')
end
terra Layout:set_cursor_which(c_i: int, v: int)
	if self:checkrange('cursor_which', v, CURSOR_WHICH_FIRST, CURSOR_WHICH_LAST) then
		self:change(self:_cursor(c_i).state, 'which', v, 'paint')
	end
end
terra Layout:set_cursor_sel_offset(c_i: int, v: int)
	self:change(self:_cursor(c_i).state, 'sel_offset', v, 'paint')
end
terra Layout:set_cursor_sel_which(c_i: int, v: int)
	if self:checkrange('cursor_sel_which', v, CURSOR_WHICH_FIRST, CURSOR_WHICH_LAST) then
		self:change(self:_cursor(c_i).state, 'sel_which' , v, 'paint')
	end
end
terra Layout:set_cursor_x(c_i: int, v: num)
	self:change(self:_cursor(c_i).state, 'x', v, 'paint')
end

terra Layout:cursor_move_to(c_i: int, offset: int, which: enum, select: bool)
	assert(self.state >= STATE_ALIGNED)
	var c = self:_cursor(c_i)
	if c:move_to(offset, which, select) then
		self:invalidate'paint'
	end
end

terra Layout:cursor_move_to_point(c_i: int, x: num, y: num, select: bool)
	assert(self.state >= STATE_ALIGNED)
	var c = self:_cursor(c_i)
	if c:move_to_point(x, y, select) then
		self:invalidate'paint'
	end
end

terra Layout:cursor_move_near(
	c_i: int, dir: enum, mode: enum, which: enum, select: bool
)
	if     self:checkrange('text cursor dir'  , dir  , CURSOR_DIR_MIN  , CURSOR_DIR_MAX)
		and self:checkrange('text cursor mode' , mode , CURSOR_MODE_MIN , CURSOR_MODE_MAX)
		and self:checkrange('text cursor which', which, CURSOR_WHICH_MIN, CURSOR_WHICH_MAX)
	then
		assert(self.state >= STATE_ALIGNED)
		var c = self:_cursor(c_i)
		if c:move_near(dir, mode, which, select) then
			self:invalidate'paint'
		end
	end
end

terra Layout:cursor_move_near_line(c_i: int, delta_lines: int, x: num, select: bool)
	assert(self.state >= STATE_ALIGNED)
	var c = self:_cursor(c_i)
	if c:move_near_line(delta_lines, x, select) then
		self:invalidate'paint'
	end
end

terra Layout:cursor_move_near_page(c_i: int, delta_pages: int, x: num, select: bool)
	assert(self.state >= STATE_ALIGNED)
	var c = self:_cursor(c_i)
	if c:move_near_page(delta_pages, x, select) then
		self:invalidate'paint'
	end
end

terra Layout:get_caret_visible(c_i: int)
	var c = self.cursors:at(c_i, nil)
	return iif(c ~= nil, c.caret_visible, false)
end

terra Layout:get_selection_visible(c_i: int)
	var c = self.cursors:at(c_i, nil)
	return iif(c ~= nil, c.selection_visible, false)
end

terra Layout:set_caret_visible(c_i: int, v: bool)
	self:change(self:_cursor(c_i), 'caret_visible', v, 'paint')
end

terra Layout:set_selection_visible(c_i: int, v: bool)
	self:change(self:_cursor(c_i), 'selection_visible', v, 'paint')
end

terra Layout:get_selection_first_span(c_i: int): int
	var c = self.cursors:at(c_i, nil)
	if c ~= nil then
		var is_forward = c.state.sel_offset < c.state.offset
		var offset = iif(is_forward, c.state.sel_offset, c.state.offset)
		return self:span_at_offset(offset)
	else
		return 0
	end
end

terra Layout:load_cursor_xs(line_i: int)
	assert(self.state >= STATE_ALIGNED)
	self.l:cursor_xs(line_i)
end
terra Layout:get_cursor_xs() return self.l.r.xsbuf.elements end
terra Layout:get_cursor_xs_len(): int return self.l.r.xsbuf.len end

--publish and build ----------------------------------------------------------

function build(optimize)
	local trlib = publish'tr'

	if memtotal then
		trlib(memtotal)
		trlib(memreport)
	end

	trlib(tr, '^ALIGN_')
	trlib(tr, '^DIR_')
	trlib(tr, '^CURSOR_')

	trlib(tr_renderer_sizeof)
	trlib(tr_layout_sizeof)
	trlib(tr_renderer)

	trlib(Renderer, nil, {
		cname = 'renderer_t',
		cprefix = 'tr_',
		opaque = true,
	})

	trlib(Layout, nil, {
		cname = 'layout_t',
		cprefix = 'tr_',
		opaque = true,
	})

	trlib:build{
		linkto = {'cairo', 'freetype', 'harfbuzz', 'fribidi', 'unibreak', 'xxhash'},
		optimize = optimize,
	}
end

if not ... then
	print'Building non-optimized...'
	build(false)
	print('sizeof Layout', sizeof(Layout))
end

return _M
