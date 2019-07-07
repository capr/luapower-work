
--get/set Span attributes between two arbitrary text offsets.

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')
require'terra/rawstringview'

local FIELDS = {
	'font_id',
	'font_size',
	'features',
	'script',
	'lang',
	'dir',
	'line_spacing',
	'hardline_spacing',
	'paragraph_spacing',
	'nowrap',
	'color',
	'opacity',
	'operator',
}

local FIELD_INDICES = index(FIELDS)

local BIT = function(field)
	local i = type(field) == 'string' and FIELD_INDICES[field] or field
	return 2^(i-1)
end
local BIT_ALL = 2^(#FIELDS)-1

local hasbit = macro(function(mask, bit)
	return `(mask and bit) ~= 0
end)

--compare s<->d and return a bitmask showing which field values are the same.
terra Layout:compare_spans(d: &Span, s: &Span)
	var mask = 0
	escape
		for i,FIELD in ipairs(FIELDS) do
			emit quote
				if d.[FIELD] == s.[FIELD] then
					mask = mask or [BIT(i)]
				end
			end
		end
	end
	return mask
end

local terra cmp_spans_after(s1: &Span, s2: &Span)
	return s1.offset <= s2.offset  -- < < = = [>] >
end
terra Layout:find_span(offset: int) --always returns a valid span index
	offset = max(0, offset)
	return self.spans:binsearch(Span{offset = offset}, cmp_spans_after) - 1
end

terra Layout:split_spans(offset: int)
	if offset >= self.text.len then
		return self.spans.len --return the would-be index without creating the span
	end
	var i = self:find_span(offset)
	var s = self.spans:at(i)
	if s.offset < offset then
		inc(i)
		var s1 = s:copy()
		s1.offset = offset
		self.spans:insert(i, s1)
	else
		assert(s.offset == offset)
	end
	return i
end

terra Layout:remove_duplicate_spans(i1: int, i2: int)
	i1 = clamp(i1, 0, self.spans.len-1)
	i2 = clamp(i2, 0, self.spans.len-1)
	var s = self.spans:at(i2)
	var i = i2 - 1
	while i >= i1 do
		var d = self.spans:at(i)
		if self:compare_spans(d, s) == BIT_ALL then
			self.spans:remove(i+1)
		end
		s = d
		dec(i)
	end
end

--get a span and a bitmask showing which values are the same for an offset range.
terra Layout:get_span_common_values(offset1: int, offset2: int)
	var mask = BIT_ALL --presume all field values are equal
	var i = self:find_span(offset1)
	var s = self.spans:at(i)
	if offset2 > offset1 then
		var i2 = self:find_span(offset2-1)+1
		for i = i+1, i2 do
			var d = self.spans:at(i)
			mask = mask and self:compare_spans(s, d)
		end
	end
	return s, mask
end

terra Span:load_features(layout: &Layout, s: rawstring)
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

terra Span:save_features(layout: &Layout, out: &rawstring)
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
	@out = sbuf.elements
end

terra Span:load_lang(layout: &Layout, s: rawstring)
	self.lang = hb_language_from_string(s, -1)
end

terra Span:save_lang(layout: &Layout, out: &rawstring)
	@out = hb_language_to_string(self.lang)
end

terra Span:load_script(layout: &Layout, s: rawstring)
	self.script = hb_script_from_string(s, -1)
end

terra Span:save_script(layout: &Layout, out: &rawstring)
	var tag = hb_script_to_iso15924_tag(self.script)
	copy(@out, [rawstring](&tag), sizeof(tag))
end

terra Layout:offset_args(o1: int, o2: int)
	if o1 < 0 then o1 = self.text.len + o1 + 1 end
	if o2 < 0 then o2 = self.text.len + o2 + 1 end
	if o1 > o2 then o1, o2 = o2, o1 end
	return o1, o2
end

local config = {
	font_id           = {int       , 0},
	font_size         = {double    , 0},
	features          = {rawstring , 0},
	script            = {rawstring , 0},
	lang              = {rawstring , 0},
	dir               = {int       , 0},
	line_spacing      = {double    , STATE_WRAPPED},
	hardline_spacing  = {double    , STATE_WRAPPED},
	paragraph_spacing = {double    , STATE_WRAPPED},
	nowrap            = {bool      , STATE_SHAPED},
	color             = {uint32    , STATE_ALIGNED},
	opacity           = {double    , STATE_ALIGNED},
	operator          = {enum      , STATE_ALIGNED},
}

--generate getters and setters for each text attr that can be set on an offset range.
for i,FIELD in ipairs(FIELDS) do

	local T, MAX_STATE = unpack(config[FIELD])
	T = T or Span:getfield(FIELD).type

	local SAVE = Span:getmethod('save_'..FIELD)
		or macro(function(self, layout, out) return quote @out = self.[FIELD] end end)

	Layout.methods['get_'..FIELD] = terra(self: &Layout, offset1: int, offset2: int, val: &T)
		offset1, offset2 = self:offset_args(offset1, offset2)
		var span, mask = self:get_span_common_values(offset1, offset2)
		if hasbit(mask, [BIT(i)]) then
			SAVE(span, self, val)
			return true
		else
			return false
		end
	end

	local LOAD = Span:getmethod('load_'..FIELD)
		or macro(function(self, layout, val) return quote self.[FIELD] = val end end)

	Layout.methods['set_'..FIELD] = terra(self: &Layout, offset1: int, offset2: int, val: T)
		offset1, offset2 = self:offset_args(offset1, offset2)
		var i1 = self:split_spans(offset1)
		var i2 = self:split_spans(offset2)
		for i = i1, i2 do
			var span = self.spans:at(i)
			LOAD(span, self, val)
		end
		self:remove_duplicate_spans(i1-1, i2+1)
		self.state = min(self.state, MAX_STATE)
	end

end
