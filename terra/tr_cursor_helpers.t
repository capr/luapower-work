
--Cursor navigation and hit testing.

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')
require'terra/tr_font'
require'terra/tr_align'

terra Layout:seg_line(seg: &Seg)
	if seg ~= nil then
		self.segs:index(seg)
		return self.lines:at(seg.line_index)
	else
		return self.lines:at(0)
	end
end

local terra cmp_offsets(seg1: &Seg, seg2: &Seg)
	return seg1.offset <= seg2.offset -- < < = = [>] >
end
terra Layout:seg_at_offset(offset: int)
	return self.segs:binsearch(Seg{offset = offset}, cmp_offsets) - 1
end

terra Layout:cursor_at_offset(offset: int)
	var seg_i = self:seg_at_offset(offset)
	var seg = self.segs:at(seg_i, nil) --nil only when segs.len == 0.
	if seg ~= nil then
		var i = offset - seg.offset
		assert(i >= 0)
		var run = self:glyph_run(seg)
		i = run.cursor_offsets:clamp(i) --fix if inside inter-segment gap.
		i = run.cursor_offsets(i) --normalize to the first cursor.
		return seg.offset + i
	else
		return 0
	end
end

--iterate all visually-unique cursor positions in visual order.
--useful for mapping editbox password bullet positions to actual positions.
terra Layout:cursor_xs(line_i: int)
	self.r.xsbuf.len = 0
	var line = self.lines:at(line_i, nil)
	if line ~= nil then
		var last_x = nan
		for seg in line do
			var run = self:glyph_run(seg)
			var i, j, step = 0, run.text.len, 1
			if run.rtl then
				i, j, step = j-1, i-1, -step
			end
			for i = i, j, step do
				var x = seg.x + run.cursor_xs(i)
				if x ~= last_x then
					self.r.xsbuf:add(x)
				end
				last_x = x
			end
		end
	end
	return self.r.xsbuf
end

--hit-test a line for a cursor position given a line number and an x-coord.
--a linear scan is required since segments are not kept in visual order.
terra Layout:hit_test_cursors(line_i: int, x: num)
	var line_i = self.lines:clamp(line_i)
	var line = self.lines:at(line_i)
	var x = clamp(x - self.x - line.x, 0, line.advance_x)
	var min_d: num = inf
	var cseg, ci = [&Seg](nil), 0 --closest cursor position
	var seg0, i0 = [&Seg](nil), 0 --previous cursor position
	var seg = line.first
	while seg ~= nil and seg.line_index == line_i do
		var xs = self:glyph_run(seg).cursor_xs.view
		var x = x - seg.x
		for i = 0, xs.len do
			var d = abs(xs(i) - x)
			if seg0 == nil or d < min_d then
				min_d = d
				cseg, ci = seg, i
			end
			seg0, i0 = seg, i
		end
		seg = self.segs:next(seg, nil)
	end
	return self:pos(cseg, ci)
end
