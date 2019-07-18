
--C/ffi API.

require'terra/memcheck'
require'terra/tr_paint_cairo'
require'terra/tr_layoutedit'
require'terra/tr_spanedit'
require'terra/tr_selection'
setfenv(1, require'terra/tr')

terra tr_renderer_sizeof()
	return [int](sizeof(Renderer))
end
terra tr_renderer_new(load_font: FontLoadFunc, unload_font: FontLoadFunc)
	return new(Renderer, load_font, unload_font)
end
terra Renderer:release()
	release(self)
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

terra Layout:cursor_xs_c(line_i: int, outlen: &int)
	var xs = self:cursor_xs(line_i)
	@outlen = xs.len
	return xs.elements
end

terra tr_cursor_sizeof()
	return [int](sizeof(Cursor))
end
terra Layout:cursor()
	return new(Cursor, self)
end
terra Cursor:release()
	release(self)
end

terra Cursor:rect_c(caret_w: num, x: &num, y: &num, w: &num, h: &num)
	@x, @y, @w, @h = self:rect(caret_w)
end

function build()
	local trlib = publish'tr'

	trlib(tr_renderer_sizeof)
	trlib(tr_renderer_new)

	if memtotal then
		trlib(memtotal)
		trlib(memreport)
	end

	trlib(Renderer, {
		init=1,
		free=1,
		release=1,

		get_glyph_run_cache_max_size=1,
		set_glyph_run_cache_max_size=1,
		get_glyph_run_cache_size=1,
		get_glyph_run_cache_count=1,

		get_glyph_cache_max_size=1,
		set_glyph_cache_max_size=1,
		get_glyph_cache_size=1,
		get_glyph_cache_count=1,

		font=1,
		free_font=1,

		layout=1, --must call layout:release() if created this way!

		get_paint_glyph_num=1,
		set_paint_glyph_num=1,

	}, {
		cname = 'tr_renderer_t',
		cprefix = 'tr_renderer_',
		opaque = true,
	})

	trlib(tr_layout_sizeof)

	trlib(Layout, {
		init=1,
		free=1,
		release=1,

		get_text=1,
		get_text_len=1,
		set_text=1,

		get_text_utf8=1,
		set_text_utf8=1,

		get_maxlen=1,
		set_maxlen=1,

		get_dir=1,
		set_dir=1,

		get_align_w=1,
		get_align_h=1,
		get_align_x=1,
		get_align_y=1,

		set_align_w=1,
		set_align_h=1,
		set_align_x=1,
		set_align_y=1,

		get_clip_x=1,
		get_clip_y=1,
		get_clip_w=1,
		get_clip_h=1,

		set_clip_x=1,
		set_clip_y=1,
		set_clip_w=1,
		set_clip_h=1,
		set_clip_extents=1,

		get_x=1,
		get_y=1,
		set_x=1,
		set_y=1,

		get_font_id           =1,
		get_font_size         =1,
		get_features          =1,
		get_script            =1,
		get_lang              =1,
		get_paragraph_dir     =1,
		get_line_spacing      =1,
		get_hardline_spacing  =1,
		get_paragraph_spacing =1,
		get_nowrap            =1,
		get_color             =1,
		get_opacity           =1,
		get_operator          =1,

		set_font_id           =1,
		set_font_size         =1,
		set_features          =1,
		set_script            =1,
		set_lang              =1,
		set_paragraph_dir     =1,
		set_line_spacing      =1,
		set_hardline_spacing  =1,
		set_paragraph_spacing =1,
		set_nowrap            =1,
		set_color             =1,
		set_opacity           =1,
		set_operator          =1,

		get_visible=1,
		get_clipped=1,

		shape=1,
		wrap=1,
		align=1,
		clip=1,
		layout=1,
		paint=1,

		cursor_xs_c='cursor_xs',
		cursor=1,

	}, {
		cname = 'tr_layout_t',
		cprefix = 'tr_layout_',
		opaque = true,
	})

	trlib(Cursor, {
		release=1,

		get_offset=1,
		get_rtl=1,

		rect_c='rect',

		move_to_offset=1,
		move_to_rel_cursor=1,
		move_to_line=1,
		move_to_pos=1,
		move_to_page=1,
		move_to_rel_page=1,

		insert=1,
		remove=1,

	})

	trlib:getenums(_M, nil, 'TR_')

	trlib:build{
		linkto = {'cairo', 'freetype', 'harfbuzz', 'fribidi', 'unibreak', 'xxhash'},
		--optimize = false,
	}

end

if not ... then
	build()
end

return _M
