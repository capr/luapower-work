
if not ... then require'terra/tr_test'; return end

--API for setting the Layout object safely.

setfenv(1, require'terra/tr_types')
require'terra/utf8'

--whole text properties ------------------------------------------------------

terra Layout:set_text_utf32(s: &codepoint, len: int)
	self.state = 0
	self.text.len = 0
	self.text:add(s, min(self.maxlen, len))
end

terra Layout:set_text_utf8(s: rawstring, len: int)
	self.state = 0
	if len < 0 then
		len = strnlen(s, self.maxlen)
	end
	utf8.decode.toarr(s, len, &self.text, self.maxlen, utf8.REPLACE, utf8.INVALID)
end

terra Layout:get_maxlen(v: int)
	return self.maxlen
end

terra Layout:set_maxlen(v: int)
	self.maxlen = v
	if self.text.len > v then --truncate the text
		self.text.len = v
		self.state = 0
	end
end

terra Layout:get_base_dir()
	return self.base_dir
end

terra Layout:set_base_dir(v: FriBidiParType)
	if self.base_dir ~= v then
		assert(
			   v == FRIBIDI_PAR_LTR
			or	v == FRIBIDI_PAR_RTL
			or v == FRIBIDI_PAR_ON
			or v == FRIBIDI_PAR_WLTR
			or v == FRIBIDI_PAR_WRTL
		)
		self.base_dir = v
		self.state = 0
	end
end

--text span attributes -------------------------------------------------------

--span mask bits
SM_FONT_ID           = 2^ 0
SM_FONT_SIZE         = 2^ 1
SM_FEATURES          = 2^ 2
SM_SCRIPT            = 2^ 3
SM_LANG              = 2^ 4
SM_DIR               = 2^ 5
SM_LINE_SPACING      = 2^ 6
SM_HARDLINE_SPACING  = 2^ 7
SM_PARAGRAPH_SPACING = 2^ 8
SM_NOWRAP            = 2^ 9
SM_COLOR             = 2^10
SM_OPACITY           = 2^11
SM_OPERATOR          = 2^12
SM_ALL               = 2^13-1

local hasbit = macro(function(mask, bit) return `(mask and bit) ~= 0 end)

terra Layout:_spans_inequality_mask(d: &Span, s: &Span)
	var mask = 0
	if d.font_id           ~= s.font_id            then mask = mask + SM_FONT_ID           end
	if d.font_size         ~= s.font_size          then mask = mask + SM_FONT_SIZE         end
	if d.features          ~= s.features           then mask = mask + SM_FEATURES          end
	if d.script            ~= s.script             then mask = mask + SM_SCRIPT            end
	if d.lang              ~= s.lang               then mask = mask + SM_LANG              end
	if d.dir               ~= s.dir                then mask = mask + SM_DIR               end
	if d.line_spacing      ~= s.line_spacing       then mask = mask + SM_LINE_SPACING      end
	if d.hardline_spacing  ~= s.hardline_spacing   then mask = mask + SM_HARDLINE_SPACING  end
	if d.paragraph_spacing ~= s.paragraph_spacing  then mask = mask + SM_PARAGRAPH_SPACING end
	if d.nowrap            ~= s.nowrap             then mask = mask + SM_NOWRAP            end
	if d.color             ~= s.color              then mask = mask + SM_COLOR             end
	if d.opacity           ~= s.opacity            then mask = mask + SM_OPACITY	         end
	if d.operator          ~= s.operator           then mask = mask + SM_OPERATOR          end
	return mask
end

terra Layout:_set_span_values(i: int, s: &Span, mask: int)
	var d = self.spans:at(i)
	if (mask and SM_FONT_ID          ) ~= 0 then
		self.r.fonts:index(s.font_id) --check if font_id is valid
	end
	if hasbit(mask, SM_FONT_ID          ) then d.font_id           = s.font_id           end
	if hasbit(mask, SM_FONT_SIZE        ) then d.font_size         = s.font_size         end
	if hasbit(mask, SM_FEATURES         ) then d.features          = s.features:copy()   end
	if hasbit(mask, SM_SCRIPT           ) then d.script            = s.script            end
	if hasbit(mask, SM_LANG             ) then d.lang              = s.lang              end
	if hasbit(mask, SM_DIR              ) then d.dir               = s.dir               end
	if hasbit(mask, SM_LINE_SPACING     ) then d.line_spacing      = s.line_spacing      end
	if hasbit(mask, SM_HARDLINE_SPACING ) then d.hardline_spacing  = s.hardline_spacing  end
	if hasbit(mask, SM_PARAGRAPH_SPACING) then d.paragraph_spacing = s.paragraph_spacing end
	if hasbit(mask, SM_NOWRAP           ) then d.nowrap            = s.nowrap            end
	if hasbit(mask, SM_COLOR            ) then d.color             = s.color             end
	if hasbit(mask, SM_OPACITY          ) then d.opacity           = s.opacity           end
	if hasbit(mask, SM_OPERATOR         ) then d.operator          = s.operator          end
end

local terra cmp_spans_after(s1: &Span, s2: &Span)
	return s1.offset <= s2.offset  -- < < = = [>] >
end

terra Layout:_find_span(offset: int)
	offset = max(0, offset)
	return self.spans:binsearch(Span{offset = offset}, cmp_spans_after) - 1
end

terra Layout:_split_spans(offset: int)
	var i = self:_find_span(offset)
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

terra Layout:_remove_duplicate_spans(i1: int, i2: int)
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

terra Layout:_get_text_attrs(offset1: int, offset2: int)
	if offset2 == offset1 then
		var i = self:_find_span(offset1)
		return self.spans:at(i), SM_ALL
	else
		var i1 = self:_find_span(offset1)
		var i2 = self:_find_span(offset2-1)+1
		var s = self.spans:at(i1)
		var mask = SM_ALL
		for i = i1+1, i2 do
			var d = self.spans:at(i)
			mask = mask - self:_spans_inequality_mask(s, d)
		end
		return s, mask
	end
end

terra Layout:_set_text_attrs(offset1: int, offset2: int, s: &Span, mask: int)
	if offset1 == offset2 then return end
	var i1 = self:_split_spans(offset1)
	var i2 = self:_split_spans(offset2)
	if i1 < i2 then i1, i2 = i2, i1 end
	for i = i1, i2 do
		self:_set_span_values(i, s, mask)
	end
	self:_remove_duplicate_spans(i1-1, i2+1)
end

terra Layout:get_font_id(offset1: int, offset2: int)
	var s, mask = self:_get_text_attrs(offset1, offset2)
	return iif(hasbit(mask, SM_FONT_ID), [int](s.font_id), -1)
end
terra Layout:set_font_id(offset1: int, offset2: int, font_id: int)
	var s: Span; s.font_id = font_id
	self:_set_text_attrs(offset1, offset2, s, SM_FONT_ID)
end




