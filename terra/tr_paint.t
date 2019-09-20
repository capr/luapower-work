
--Painting rasterized glyph runs into a cairo surface.

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')
require'terra/tr_rasterize'

terra Renderer:paint_glyph_run(cr: &context, run: &GlyphRun, font: &Font, ax: num, ay: num)
	if run.glyphs.len > 1 and run.font_size < 50 then
		var sr, sx, sy = self:rasterize_glyph_run(run, font, ax, ay)
		self:paint_surface(cr, sr, sx, sy)
	else
		for sr, sx, sy in self:glyph_surfaces(run, 0, run.glyphs.len, font, ax, ay) do
			self:paint_surface(cr, sr, sx, sy)
		end
	end
	inc(self.paint_glyph_num, run.glyphs.len)
end

terra Renderer:paint_glyph_run_subseg(cr: &context, run: &GlyphRun, sub: &SubSeg, ax: num, ay: num)
	var surfaces = self:glyph_surfaces(run, sub.glyph_index1, sub.glyph_index2, sub.span.font, ax, ay)
	if sub.clip then
		var clip1 = ax + sub.clip_left
		var clip2 = ax + sub.clip_right
		for sr, sx, sy in surfaces do
			self:paint_surface_clipped(cr, sr, sx, sy, clip1, clip2)
		end
	else
		for sr, sx, sy in surfaces do
			self:paint_surface(cr, sr, sx, sy)
		end
	end
	inc(self.paint_glyph_num, run.glyphs.len)
end

terra Layout:paint_text(cr: &context)

	var segs = &self.segs
	var lines = &self.lines

	for line_i = self.first_visible_line, self.last_visible_line + 1 do
		var line = lines:at(line_i)

		var ax = self.x + line.x
		var ay = self.y + self.baseline + line.y

		for seg in line do
			if seg.visible then
				var run = self:glyph_run(seg)
				var x, y = ax + seg.x, ay
				if seg.subsegs.len > 0 then --has sub-segments, paint those instead.
					for i, sub in seg.subsegs do
						self.r:setcontext(cr, sub.span)
						self.r:paint_glyph_run_subseg(cr, run, sub, x, y)
					end
				else
					self.r:setcontext(cr, seg.span)
					self.r:paint_glyph_run(cr, run, seg.span.font, x, y)
				end
			end
		end
	end
end

