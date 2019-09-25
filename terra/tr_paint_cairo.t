--[[

	Cairo graphics adapter for terra/tr.
	Paints (and scales) rasterized glyph runs into a cairo surface.

]]

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/low'.module'terra/tr_module')
require'terra/cairo'
color = cairo_argb32_color_t
surface = cairo_surface_t
context = cairo_t

OPERATOR_XOR  = CAIRO_OPERATOR_XOR
OPERATOR_OVER = CAIRO_OPERATOR_OVER

DEFAULT_TEXT_COLOR        = DEFAULT_TEXT_COLOR        or `color {0xffffffff}
DEFAULT_SELECTION_COLOR   = DEFAULT_SELECTION_COLOR   or `color {0x6666ff66}
DEFAULT_TEXT_OPERATOR     = DEFAULT_TEXT_OPERATOR     or OPERATOR_OVER
DEFAULT_SELECTION_OPACITY = DEFAULT_SELECTION_OPACITY or 1

terra create_surface(w: int, h: int)
	return cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h)
end

setfenv(1, require'terra/tr_types')

terra Renderer:create_glyph_surface(glyph: &Glyph, bmp: &FT_Bitmap, scale: num, font_size: num)

	var w = bmp.width
	var h = bmp.rows

	var format = iif(bmp.pixel_mode == FT_PIXEL_MODE_GRAY,
		CAIRO_FORMAT_A8, CAIRO_FORMAT_ARGB32)

	var sr0 = cairo_image_surface_create_for_data(
		bmp.buffer, format, w, h, bmp.pitch)

	if scale ~= 1 then
		--scale raster glyphs which freetype cannot scale by itself.
		var bw = font_size
		var w1, h1 = rect.fit(w, h, bw, bw)
		var sr = create_surface(ceil(w1), ceil(h1))
		var cr = sr:context()
		cr:translate(glyph.subpixel_offset_x, 0)
		cr:scale(w1 / w, h1 / h)
		cr:source(sr0, 0, 0)
		cr:paint()
		cr:rgb(0, 0, 0) --release source
		cr:free()
		glyph.image.surface = sr
	else
		var sr = create_surface(w, h)
		var cr = sr:context()
		if bmp.pixel_mode == FT_PIXEL_MODE_GRAY then
			cr:rgb(1, 1, 1)
			cr:mask(sr0, 0, 0)
		else
			cr:source(sr0, 0, 0)
			cr:paint()
			cr:rgb(0, 0, 0) --release source
		end
		cr:free()
		glyph.image.surface = sr
	end

	sr0:free()
end

terra Renderer:setcontext(cr: &context, span: &Span)
	var c = cairo_color_t(span.color)
	c.alpha = c.alpha * span.opacity
	cr:rgba(c)
	cr:operator(span.operator)
end

terra Renderer:paint_surface(cr: &context, sr: &surface, x: num, y: num)
	--cr:rgba(1, 1, 1, .5)
	--cr:line_width(1)
	--cr:rectangle(x, y, sr:width(), sr:height())
	--cr:stroke()
	cr:mask(sr, x, y)
end

terra Renderer:paint_surface_clipped(
	cr: &context, sr: &surface, x: num, y: num,
	clip_left: num, clip_right: num
)
	cr:save()
	cr:new_path()
	cr:rectangle(clip_left, y, clip_right, sr:height())
	cr:clip()
	cr:mask(sr, x, y)
	cr:restore()
end

terra Renderer:paint_rect(cr: &context,
	x: num, y: num, w: num, h: num,
	color: color, opacity: num
)
	cr:rgba(color:apply_alpha(opacity))
	cr:new_path()
	cr:rectangle(x, y, w, h)
	cr:fill()
end
