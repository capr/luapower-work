--[[

	Text shaping, layouting and rendering engine in Terra with a C API.
	Written by Cosmin Apreutesei. Public Domain.

	A pure-Lua prototype of this library is at github.com/luapower/tr.
	Discuss at luapower.com/forum or at github.com/luapower/terra-tr/issues.

	Leverages harfbuzz, freetype, fribidi and libunibreak for text shaping,
	glyph rasterization, bidi reordering and line breaking respectively.

	Scaling and blitting a raster image onto another is out of the scope of
	the library. A module for doing that with `cairo` is included separately.

	NOTE: This is the implementation module. In here, invalid input data is
	undefined behavior and changing layout properties does not keep the
	internal state consistent. Use `tr_api` instead which takes care of that.

	Processing stages from rich text description to pixels on screen:

	* itemization     : split text into an array of segments (or segs).
	* shaping         : shape segments into an arrays of glyphs (called glyph runs).
	* line-wrapping   : word-wrap segments and group them into an array of lines.
	* bidi-reordering : re-order mixed-direction segments on each line.
	* line-spacing    : compute each line's `y` based on the heights of its segments.
	* aligning        : align lines horizontally and vertically inside a box.
	* clipping        : mark which lines and segments as visible inside a box.
	* rasterization   : convert glyph outlines into little bitmaps that are cached.
	* painting        : draw the visible text plus any selections and carets.

	The API for driving this process is:

	tr_itemize.t   shape()     itemization and shaping.
	tr_wrap.t      wrap()      line-wrapping.
	tr_align.t     spaceout()  line-spacing.
	tr_align.t     align()     justification and aligning.
	tr_clip.t      clip()      clipping.
	tr_paint.t     paint()     painting, with on-demand rasterization.

	The renderer object keeps two bytesize-limited LRU caches: one for glyph
	runs and one for glyph images. Shaping consults the glyph run cache
	and rasterization consults the glyph image cache.

	Also, there's two levels of rasterization: for glyph images and for entire
	glyph runs. With subpixel resolution, more than one image might end up
	being created for each subpixel offset encountered, which is why
	rasterization is done on-demand by painting.

]]

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')
require'terra/tr_itemize'
require'terra/tr_wrap'
require'terra/tr_align'
require'terra/tr_clip'
require'terra/tr_paint'

terra Renderer:init(load_font: FontLoadFunc, unload_font: FontLoadFunc)
	fill(self) --this initializes all arr() types.
	self.font_size_resolution  = 1.0/8  --in pixels
	self.subpixel_x_resolution = 1.0/16 --1/64 pixels is max with freetype
	self.word_subpixel_x_resolution = 1.0/4
	self.fonts:init()
	self.load_font = load_font
	self.unload_font = unload_font
	self.glyphs:init(self)
	self.glyphs.max_size = 1024 * 1024 * 20 --20 MB net (arbitrary default)
	self.glyph_runs:init(self)
	self.glyph_runs.max_size = 1024 * 1024 * 10 --10 MB net (arbitrary default)
	self.ranges.min_capacity = 64
	self.cpstack.min_capacity = 64
	assert(FT_Init_FreeType(&self.ft_lib) == 0)
	init_ub_lang()
	init_script_lang_map()
	init_linebreak()
end

terra Renderer:free()
	self.glyphs          :free()
	self.glyph_runs      :free()
	self.fonts           :free()
	self.cpstack         :free()
	self.scripts         :free()
	self.langs           :free()
	self.bidi_types      :free()
	self.bracket_types   :free()
	self.levels          :free()
	self.linebreaks      :free()
	self.grapheme_breaks :free()
	self.carets_buffer   :free()
	self.substack        :free()
	self.ranges          :free()
	self.sbuf            :free()
	self.xsbuf           :free()
	self.paragraph_dirs  :free()
	FT_Done_FreeType(self.ft_lib)
end

terra Layout:free()
	self.lines:free()
	for _,seg in self.segs do
		self.r.glyph_runs:forget(seg.glyph_run_id)
	end
	self.segs:free()
	self.text:free()
	for _,span in self.spans do
		if span.font_id ~= -1 then
			self.r.fonts:at(span.font_id):unref()
		end
	end
	self.spans:free()
end

terra Renderer:font()
	assert(self.fonts.items.len <= 32000)
	var font, font_id = self.fonts:alloc()
	font:init(self)
	return [int](font_id)
end

terra Renderer:free_font(font_id: int)
	assert(self.fonts:at(font_id).refcount == 0)
	self.fonts:release(font_id)
end

return _M
