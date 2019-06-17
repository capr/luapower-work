
--get/set Layout attributes.

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')
require'terra/utf8'

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

