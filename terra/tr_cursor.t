
--Cursor navigation and hit testing.

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')

terra Layout:line_pos(line_i: int)
	var line = self.lines:at(line_i)
	var x = self.x + line.x
	var y = self.y + self.baseline + line.y
	return x, y
end

terra Layout:cursor_x(seg: &Seg, i: int) --relative to line_pos().
	var run = self:glyph_run(seg)
	var i = clamp(i, 0, run.text.len)
	return seg.x + run.cursor_xs(i)
end

local terra cmp_offsets(seg1: &Seg, seg2: &Seg)
	return seg1.offset <= seg2.offset -- < < = = [<] <
end
terra Layout:cursor_at_offset(offset: int)
	var seg_i = self.segs:binsearch(Seg{offset = offset}, cmp_offsets) - 1
	var seg = self.segs:at(seg_i)
	var i = offset - seg.offset
	assert(i >= 0)
	var run = self:glyph_run(seg)
	i = min(i, run.text.len) --fix if inside inter-segment gap.
	i = run.cursor_offsets(i) --normalize to the first cursor.
	return seg, i
end

terra Layout:offset_at_cursor(seg: &Seg, i: int)
	var run = self:glyph_run(seg)
	assert(i >= 0)
	assert(i <= run.text.len)
	return seg.offset + run.cursor_offsets(i)
end

--iterate all visually-unique cursor positions in visual order.
terra Layout:cursor_xs(line_i: int)
	self.r.xsbuf.len = 0
	var line = self.lines:at(line_i, nil)
	if line ~= nil then
		var seg = line.first_vis
		var last_x = nan
		while seg ~= nil do
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
			seg = seg.next_vis
		end
	end
	return self.r.xsbuf
end

diff_t  = {&opaque, &Seg, int, &Seg, int} -> {bool}
valid_t = {&opaque, &Seg, int} -> {bool}

--hit-test a line for a cursor position given a line number and an x-coord.
terra Layout:hit_test_cursors(line_i: int, x: num, diff: diff_t, valid: valid_t, obj: &opaque)
	var line_i = self.lines:clamp(line_i)
	var line = self.lines:at(line_i)
	--find the cursor position closest to x.
	var x = x - self.x - line.x
	var min_d: num = 1/0
	var cseg: &Seg, ci: int --closest cursor
	var seg, i = line.first, 0
	var seg0: &Seg, i0: int
	while seg ~= nil do
		var x = x - seg.x
		var d = abs(self:glyph_run(seg).cursor_xs(i) - x)
		if seg0 == nil
			or (d < min_d
				and (valid == nil or valid(obj, seg, i))
				and (diff == nil or diff(obj, seg, i, seg0, i0)))
		then
			min_d = d
			cseg, ci = seg, i
		end
		seg0, i0 = seg, i
		i = i + 1
		if i > self:glyph_run(seg).text.len then
			seg = seg.next
			i = 0
		end
	end
	return cseg, ci
end

local NEXT, PREV, CURR = 1, 2, 3
CURSOR_DIR_NEXT = NEXT
CURSOR_DIR_PREV = PREV
CURSOR_DIR_CURR = CURR

--next/prev valid cursor position.
terra Layout:rel_physical_cursor(seg: &Seg, i: int, dir: enum, valid: valid_t, obj: &opaque)
	if dir == 0 then dir = NEXT end
	repeat
		if dir == NEXT then
			if i >= self:glyph_run(seg).text.len then
				seg = self.segs:next(seg, nil)
				if seg == nil then return seg, 0 end
				i = 0
			else
				i = i+1
			end
		elseif dir == PREV then
			if i <= 0 then
				seg = self.segs:prev(seg, nil)
				if seg == nil then return seg, 0 end
				i = self:glyph_run(seg).text.len
			else
				i = i-1
			end
		else
			assert(false)
		end
	until valid == nil or valid(obj, seg, i)
	return seg, i
end

local FIRST, LAST = 1, 2
CURSOR_WHICH_FIRST = FIRST
CURSOR_WHICH_LAST  = LAST

--next/prev cursor position filtered by a is-different-than-other-position
--question and a is-valid-position question.
--`dir` controls which distinct cursor to return. `which` controls which
--non-distinct cursor to return once a distinct cursor was found.
terra Layout:rel_cursor(
	seg: &Seg, i: int,
	dir: enum, which: enum,
	diff: diff_t, valid: valid_t, obj: &opaque
)
	if dir == 0 then dir = CURR end
	if which == 0 then which = FIRST end
	assert(which == FIRST or which == LAST)
	if dir == NEXT or dir == PREV then --find prev/next distinct
		::again::
		var seg1, i1 = self:rel_physical_cursor(seg, i, dir, valid, obj)
		if seg1 == nil then --bos/eos
			return seg1, i1
		elseif diff ~= nil and not diff(obj, seg1, i1, seg, i) then
			seg, i = seg1, i1
			goto again
		elseif which == iif(dir == NEXT, FIRST, LAST) then --already there
			return seg1, i1
		end
		var last = iif(dir == NEXT, LAST, FIRST)
		return self:rel_cursor(seg1, i1, CURR, last, diff, valid, obj)
	elseif dir == CURR then --find first/last non-distinct position
		if diff == nil then
			return seg, i
		end
		var dir = iif(which == FIRST, PREV, NEXT)
		var seg1, i1 = self:rel_physical_cursor(seg, i, dir, valid, obj)
		if seg1 == nil then --bos/eos
			return seg, i
		elseif diff(obj, seg1, i1, seg, i) then --distinct position
			return seg, i
		end
		return self:rel_cursor(seg1, i1, CURR, which, diff, valid, obj)
	else
		assert(false)
	end
end

struct Cursor {
	layout: &Layout;
	seg: &Seg;
	i: int;
}

terra Cursor:rel_physical_cursor(dir: enum, valid: valid_t, obj: &opaque): Cursor
	var seg, i = self.layout:rel_physical_cursor(self.seg, self.i, dir, valid, obj)
	return Cursor {self.layout, seg, i}
end

