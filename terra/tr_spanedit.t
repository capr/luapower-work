
--get/set Span attributes between arbitrary text offsets.

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')

--whole text properties ------------------------------------------------------

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

--compare s<->d and return a bitmask with bits for the fields that differ.
terra Layout:_spans_inequality_mask(d: &Span, s: &Span)
	var mask = 0
	escape
		for i,FIELD in ipairs(FIELDS) do
			emit quote
				if d.[FIELD] ~= s.[FIELD] then
					mask = mask + [BIT(i)]
				end
			end
		end
	end
	return mask
end

local terra cmp_spans_after(s1: &Span, s2: &Span)
	return s1.offset <= s2.offset  -- < < = = [>] >
end
terra Layout:find_span(offset: int)
	offset = max(0, offset)
	return self.spans:binsearch(Span{offset = offset}, cmp_spans_after) - 1
end

terra Layout:split_spans(offset: int)
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
		if self:_spans_inequality_mask(d, s) == 0 then
			self.spans:remove(i+1)
		end
		s = d
		dec(i)
	end
end

--get the span with a bitmask for values that are the same for an offset range.
terra Layout:get_span_common_values(offset1: int, offset2: int)
	var mask = BIT_ALL --presume all field values are equal
	var i = self:find_span(offset1)
	var s = self.spans:at(i)
	if offset2 > offset1 then
		var i2 = self:find_span(offset2-1)+1
		for i = i+1, i2 do
			var d = self.spans:at(i)
			mask = mask - self:_spans_inequality_mask(s, d)
		end
	end
	return s, mask
end

terra Span:load_features(layout: &Layout, s: rawstring)

	--
end

terra Span:save_features(layout: &Layout, out: &rawstring)
	var sbuf = &layout.r.sbuf
	sbuf.len = 0
	if self.features.len > 0 then
		--
	end
	sbuf:add(0)
	@out = sbuf.elements
end

local config = {
	font_id           = {int},
	font_size         = {double},
	features          = {rawstring, 'load_features', 'save_features'},
	script            = {},
	lang              = {},
	dir               = {int},
	line_spacing      = {double},
	hardline_spacing  = {double},
	paragraph_spacing = {double},
	nowrap            = {bool},
	color             = {uint32},
	opacity           = {double},
	operator          = {enum},
}

--generate getters and setters for each text attr that can be set on an offset range.
for i,FIELD in ipairs(FIELDS) do

	local T = unpack(config[FIELD])
	T = T or Span:getfield(FIELD).type

	local SAVE = Span:getmethod('save_'..FIELD)
		or macro(function(self, layout, out) return quote @out = self.[FIELD] end end)

	Layout.methods['get_'..FIELD] = terra(self: &Layout, offset1: int, offset2: int, val: &T)
		if offset1 > offset2 then
			offset1, offset2 = offset2, offset1
		end
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
		if offset1 > offset2 then
			offset1, offset2 = offset2, offset1
		end
		var i1 = self:split_spans(offset1)
		var i2 = self:split_spans(offset2)
		for i = i1, i2 do
			var span = self.spans:at(i)
			LOAD(span, self, val)
		end
		self:remove_duplicate_spans(i1-1, i2+1)
	end

end
