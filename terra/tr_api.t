
--C/ffi API

require'terra/tr_paint_cairo'
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

function build()
	local trlib = publish'tr'

	trlib(tr_renderer_sizeof)
	trlib(tr_renderer_new)

	trlib(Renderer, {
		init=1,
		free=1,
		release=1,

		get_glyph_run_cache_size=1,
		set_glyph_run_cache_size=1,
		get_glyph_cache_size=1,
		set_glyph_cache_size=1,

		font=1,
		free_font=1,

		layout=1, --must call layout:release() if created this way!
	}, {
		cname = 'trlib_t',
		cprefix = 'trlib_',
		opaque = true,
	})

	trlib(tr_layout_sizeof)

	trlib(Layout, {
		init=1,
		free=1,
		release=1,

		shape=1,
		wrap=1,
		align=1,

		set_text_utf32=1,
		set_text_utf8=1,

		get_font_id           =1,
		get_font_size         =1,
		get_features          =1,
		get_script            =1,
		get_lang              =1,
		get_dir               =1,
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
		set_dir               =1,
		set_line_spacing      =1,
		set_hardline_spacing  =1,
		set_paragraph_spacing =1,
		set_nowrap            =1,
		set_color             =1,
		set_opacity           =1,
		set_operator          =1,

	}, {
		cname = 'tr_layout_t',
		cprefix = 'tr_layout_',
		opaque = true,
	})

	trlib:build{
		linkto = {'cairo', 'freetype', 'harfbuzz', 'fribidi', 'unibreak', 'xxhash'},
		optimize = false,
	}

end

if not ... then
	build()
end
