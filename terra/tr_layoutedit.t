
--get/set Layout attributes.

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')
require'terra/tr_spanedit'
require'terra/utf8'

terra Layout:text_changed()
	var i = self.spans.len-1
	while i >= 0 do
		var s = self.spans:at(i)
		if s.offset < self.text.len then
			break
		end
	end
	if self.spans:remove(i+1, maxint) > 0 then
		self.state = 0
	end
end

terra Layout:get_text_len()
	return self.text.len
end

terra Layout:get_text()
	return self.text.elements
end

terra Layout:set_text(s: &codepoint, len: int)
	self.state = 0
	self.text.len = 0
	self.text:add(s, min(self.maxlen, len))
	self:text_changed()
end

terra Layout:text_to_utf8(out: rawstring)
	if out == nil then --out buffer size requested
		return utf8.encode.count(self.text.elements, self.text.len,
			maxint, utf8.REPLACE, utf8.INVALID)._0
	else
		return utf8.encode.tobuffer(self.text.elements, self.text.len, out,
			maxint, utf8.REPLACE, utf8.INVALID)._0
	end
end

terra Layout:text_from_utf8(s: rawstring, len: int)
	self.state = 0
	if len < 0 then
		len = strnlen(s, self.maxlen)
	end
	utf8.decode.toarr(s, len, &self.text,
		self.maxlen, utf8.REPLACE, utf8.INVALID)
	self:text_changed()
end

terra Layout:get_maxlen(v: int)
	return self.maxlen
end

terra Layout:set_maxlen(v: int)
	self.maxlen = v
	if self.text.len > v then --truncate the text
		self.text.len = v
		self:text_changed()
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
