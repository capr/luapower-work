--[[

	Font loading and unloading and setting the font size.

	Fonts are kept in two LRU caches: one that is bytesize-limited for memory
	fonts and one that is count-limited for memory-mapped fonts.

]]

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')

terra Font:init(r: &Renderer, id: int)
	fill(self)
	self.id = id

	self.ft_load_flags =
		   FT_LOAD_COLOR
		or FT_LOAD_PEDANTIC
		--or FT_LOAD_NO_HINTING
		--or FT_LOAD_NO_AUTOHINT
		--or FT_LOAD_FORCE_AUTOHINT

	self.ft_render_flags = FT_RENDER_MODE_LIGHT

	r.load_font(self.id, &self.file_data, &self.file_size)
	assert(self.file_size >= 0) --should be zero for a mem-mapped font.

	if self.file_data == nil then
		return
	end

	if FT_New_Memory_Face(r.ft_lib,
		[&uint8](self.file_data),
		self.file_size, 0, &self.ft_face) ~= 0
	then
		self:free(r)
		return
	end

	self.hb_font = hb_ft_font_create_referenced(self.ft_face)
	if self.hb_font == nil then
		self:free(r)
		return
	end

	hb_ft_font_set_load_flags(self.hb_font, self.ft_load_flags)
end

terra Font:free(r: &Renderer)
	assert(self.file_data ~= nil)
	assert(self.file_size >= 0)
	if self.hb_font ~= nil then
		hb_font_destroy(self.hb_font)
		self.hb_font = nil
	end
	if self.ft_face ~= nil then
		FT_Done_Face(self.ft_face)
		self.ft_face = nil
	end
	r.unload_font(self.id, &self.file_data, &self.file_size)
	self.file_data = nil
	self.file_size = -1
	dealloc(self)
end

terra Font:setsize(size: num)

	--find the size index closest to input size.
	var size_index: int
	var fixed_size = size
	var found = false
	var best_diff: int16 = 0x7fff
	for i = 0, self.ft_face.num_fixed_sizes do
		var sz = self.ft_face.available_sizes[i]
		var this_size = sz.height
		var diff = abs(size - this_size)
		if diff < best_diff then
			size_index = i
			fixed_size = this_size
			found = true
		end
	end

	if found then
		self.scale = size / fixed_size
		assert(FT_Select_Size(self.ft_face, size_index) == 0)
	else
		self.scale = 1
		assert(FT_Set_Pixel_Sizes(self.ft_face, fixed_size, 0) == 0)
	end

	self.size = size
	var m = self.ft_face.size.metrics
	self.ascent  = [num](m.ascender ) * self.scale / 64.f
	self.descent = [num](m.descender) * self.scale / 64.f

	hb_ft_font_changed(self.hb_font)
end

--font cache -----------------------------------------------------------------

terra Renderer:font(font_id: int): &Font
	if font_id == -1 then
		return nil --reserve -1 as default "font not set" value.
	end
	var font_i, pair = self.mem_fonts:get(font_id)
	if font_i == -1 then
		font_i, pair = self.mmapped_fonts:get(font_id)
	end
	if font_i == -1 then
		var font: Font
		font:init(self, font_id)
		if font.file_data ~= nil then
			var cache = iif(font.file_size == 0,
				&self.mmapped_fonts, &self.mem_fonts)
			var mfont = alloc(Font)
			@mfont = font
			var font_i, pair = cache:put(font_id, mfont)
			return mfont
		else
			return nil
		end
	else
		return pair.val
	end
end

terra forget_font(self: &Renderer, font_id: int)
	if font_id == -1 then
		return
	end
	var font_i, pair = self.mem_fonts:get(font_id)
	--NOTE: we forget the font twice because get() increases refcount.
	if font_i ~= -1 then
		self.mem_fonts:forget(font_i)
		self.mem_fonts:forget(font_i)
		return
	end
	font_i, pair = self.mmapped_fonts:get(font_id)
	if font_i ~= -1 then
		self.mmapped_fonts:forget(font_i)
		self.mmapped_fonts:forget(font_i)
		return
	end
	assert(false)
end
