
--Cursor navigation and hit testing.

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')
require'terra/tr_font'
require'terra/tr_hit_test'

local DEFAULT = 0
local DEFAULT_NUM = nan

terra Layout:line_pos(line_i: int)
	var line = self.lines:at(line_i)
	var x = self.x + line.x
	var y = self.y + self.baseline + line.y
	return x, y
end

terra Layout:cursor_x(seg: &Seg, i: int) --relative to line_pos().
	var run = self:glyph_run(seg)
	var i = run.cursor_xs:clamp(i)
	return seg.x + run.cursor_xs(i)
end

terra Layout:cursor_rect(seg: &Seg, i: int, w: num, forward: bool) --relative to line_pos().
	var ascent: num
	var descent: num
	var x: num
	if seg ~= nil then
		var line = self.lines:at(seg.line_index)
		ascent = line.ascent
		descent = line.descent
		x = self:cursor_x(seg, i)
	else
		var span = self.spans:at(0)
		var font_id = span.font_id
		var font = self.r.fonts:at(font_id, nil)
		if font ~= nil and font:ref() then
			font:setsize(span.font_size)
			ascent = font.ascent
			descent = font.descent
			font:unref() --TODO: delay unref
		else
			ascent = 0
			descent = 0
		end
		x = 0
	end
	var y = -ascent
	var w = iif(forward ~= false, 1, -1) * iif(w ~= DEFAULT_NUM, w, 1)
	var h = ascent - descent
	if w < 0 then
		x, w = x + w, -w
	end
	return x, y, w, h
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
	i = run.cursor_offsets:clamp(i) --fix if inside inter-segment gap.
	i = run.cursor_offsets(i) --normalize to the first cursor.
	return seg, i
end

terra Layout:offset_at_cursor(seg: &Seg, i: int)
	var run = self:glyph_run(seg)
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

--custom function that responds to the question:
-- "is this cursor position different than other cursor position?"
diff_t  = {&opaque, &Seg, int, &Seg, int, enum} -> {bool}

--custom function that responds to the question:
--	"is this cursor position a valid cursor position?"
valid_t = {&opaque, &Seg, int, enum} -> {bool}

--hit-test a line for a cursor position given a line number and an x-coord.
terra Layout:hit_test_cursors(line_i: int, x: num,
	diff: diff_t, valid: valid_t, obj: &opaque, mode: enum
)
	var line_i = self.lines:clamp(line_i)
	var line = self.lines:at(line_i)
	--find the cursor position closest to x.
	var x = x - self.x - line.x
	var min_d: num = 1/0
	var cseg: &Seg, ci: int --closest cursor
	var seg, i = line.first, 0
	var seg0: &Seg, i0: int
	while seg ~= nil do
		var xs = self:glyph_run(seg).cursor_xs
		var x = x - seg.x
		var d = abs(xs(i) - x)
		if seg0 == nil
			or (d < min_d
				and (valid == nil or valid(obj, seg, i, mode))
				and (diff == nil or diff(obj, seg, i, seg0, i0, mode)))
		then
			min_d = d
			cseg, ci = seg, i
		end
		seg0, i0 = seg, i
		i = i + 1
		if i >= xs.len then
			seg = self.segs:next(seg)
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
terra Layout:rel_physical_cursor(seg: &Seg, i: int, dir: enum,
	valid: valid_t, obj: &opaque, mode: enum
)
	if dir == DEFAULT then dir = NEXT end
	repeat
		if dir == NEXT then
			if i >= self:glyph_run(seg).cursor_xs.len-1 then
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
				i = self:glyph_run(seg).cursor_xs.len-1
			else
				i = i-1
			end
		else
			assert(false)
		end
	until valid == nil or valid(obj, seg, i, mode)
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
	diff: diff_t, valid: valid_t, obj: &opaque, mode: enum
): {&Seg, int}
	if dir == DEFAULT then dir = CURR end
	if which == DEFAULT then which = FIRST end
	assert(which == FIRST or which == LAST)
	if dir == NEXT or dir == PREV then --find prev/next distinct position
		::again::
		var seg1, i1 = self:rel_physical_cursor(seg, i, dir, valid, obj, mode)
		if seg1 == nil then --bos/eos
			return seg1, i1
		elseif diff ~= nil and not diff(obj, seg1, i1, seg, i, mode) then
			seg, i = seg1, i1
			goto again
		elseif which == iif(dir == NEXT, FIRST, LAST) then --already there
			return seg1, i1
		end
		var last = iif(dir == NEXT, LAST, FIRST)
		return self:rel_cursor(seg1, i1, CURR, last, diff, valid, obj, mode)
	elseif dir == CURR then --find first/last non-distinct position
		if diff == nil then
			return seg, i
		end
		var dir = iif(which == FIRST, PREV, NEXT)
		var seg1, i1 = self:rel_physical_cursor(seg, i, dir, valid, obj, mode)
		if seg1 == nil then --bos/eos
			return seg, i
		elseif diff(obj, seg1, i1, seg, i, mode) then --distinct position
			return seg, i
		end
		return self:rel_cursor(seg1, i1, CURR, which, diff, valid, obj, mode)
	else
		assert(false)
	end
end

--cursor objects -------------------------------------------------------------

struct Cursor (gettersandsetters) {

	--cursor state that stays valid between re-layouts.
	layout: &Layout;
	offset: int; --offset in logical text.

	--cursor state that needs updating after re-layouting.
	seg: &Seg;
	i: int;
	x: num;

	--park cursor to home/end if vertical nav goes above/beyond available lines.
	park_home: bool;
	park_end: bool;

	--jump-through same-text-offset cursors: most text editors remove duplicate
	--cursors to keep a 1:1 relationship between text positions and cursor
	--positions, which gets funny with BiDi and you also can't tell if there's
	--a space at the end of a wrapped line or not.
	unique_offsets: bool;

	--keep a cursor after the last space char on a wrapped line: this cursor can
	--be trouble because it is outside the textbox and if there's not enough room
	--on the wrap-side of the textbox it can get clipped out.
	wrapped_space: bool;

	insert_mode: bool;
}

terra Cursor:init(layout: &Layout)
	fill(self)
	self.layout = layout
	self.park_home = true
	self.park_end = true
	self.insert_mode = true
	self.seg = self.layout.segs:at(0, nil)
end

terra Cursor:get_line()
	return iif(self.seg ~= nil, self.layout.lines:at(self.seg.line_index), nil)
end

terra Cursor:rel_physical_cursor(dir: enum,
	valid: valid_t, obj: &opaque, mode: enum
)
	return self.layout:rel_physical_cursor(self.seg, self.i, dir, valid, obj, mode)
end

terra Cursor:assign(c: &Cursor)
	assert(c.layout == self.layout)
	self.seg  = c.seg
	self.i    = c.i
	self.x    = c.x
end

terra Cursor:set(seg: &Seg, i: int, x: num)
	if seg ~= self.seg or i ~= self.i then
		self.seg = seg
		self.i = i
		if x ~= DEFAULT_NUM then
			self.x = x
		end
		self.offset = iif(seg ~= nil, self.layout:offset_at_cursor(seg, i), 0)
		return true
	else
		return false
	end
end

terra Cursor:set2(pos: {&Seg, int}, x: num)
	self:set(pos._0, pos._1, x)
end

terra Cursor:get_offset()
	return iif(self.seg ~= nil, self.layout:offset_at_cursor(self.seg, self.i), 0)
end

terra Cursor:get_rtl()
	return iif(self.seg ~= nil, self.layout:glyph_run(self.seg).rtl, false)
end

local POS, CHAR, WORD, LINE = 1, 2, 3, 4
CURSOR_MODE_POS  = POS
CURSOR_MODE_CHAR = CHAR
CURSOR_MODE_WORD = WORD
CURSOR_MODE_LINE = LINE

terra Cursor.methods.find_rel_cursor :: {&Cursor, enum, enum, enum, bool} -> {&Seg, int}

terra Cursor:rect(w: num)
	if not self.insert_mode then
		--wide caret (spanning two adjacent cursor positions).
		var seg1, i1 = self:find_rel_cursor(NEXT, DEFAULT, DEFAULT, false)
		if seg1 ~= nil and seg1.line_index == self.seg.line_index then
			var x, y, _, h = self.layout:cursor_rect(self.seg, self.i, DEFAULT_NUM, false)
			var x1 = self.layout:cursor_rect(seg1, i1, DEFAULT_NUM, false)._0
			var w = x1 - x
			if w < 0 then
				x, w = x + w, -w
			end
			var x0, y0 = self.layout:line_pos(self.seg.line_index)
			return x0 + x, y0 + y, w, h
		end
	end
	--normal caret, `w`-wide to the left or right of a cursor position.
	var forward = not self.rtl and self.layout.align_x ~= ALIGN_RIGHT
	var x, y, w, h = self.layout:cursor_rect(self.seg, self.i, w, forward)
	var x0, y0 = self.layout:line_pos(self.seg.line_index)
	return x0 + x, y0 + y, w, h
end

local terra valid(obj: &opaque, seg: &Seg, i: int, mode: enum)
	var self = [&Cursor](obj)
	return not (
		not self.wrapped_space
		and seg.wrapped
		and i == self.layout:glyph_run(seg).cursor_xs.len-1
		and self.layout:glyph_run(seg).trailing_space
	)
end

local terra diff(obj: &opaque, seg: &Seg, i: int, seg0: &Seg, i0: int, mode: enum)
	var self = [&Cursor](obj)
	if seg0 == nil then
		return true
	end
	if mode == DEFAULT then mode = POS end
	if mode == POS and self.unique_offsets then
		mode = CHAR
	end
	if mode == POS then
		return
			seg.line_index ~= seg0.line_index
			or self.layout:cursor_x(seg, i) ~= self.layout:cursor_x(seg0, i0)
			or self.layout:offset_at_cursor(seg, i) ~= self.layout:offset_at_cursor(seg0, i0)
	elseif mode == CHAR then
		return self.layout:offset_at_cursor(seg, i) ~= self.layout:offset_at_cursor(seg0, i0)
	elseif mode == WORD then
		return seg ~= seg0
	elseif mode == LINE then
		return seg.line_num ~= seg0.line_num
	else
		assert(false)
	end
end

terra Cursor.methods.find_offset :: {&Cursor, int, enum} -> {&Seg, int}

terra Cursor:find_cursor(seg: &Seg, i: int, dir: enum, mode: enum, which: enum, clamp: bool)
	var seg, i = self.layout:rel_cursor(seg, i, dir, which, diff, valid, self, mode)
	if seg == nil and clamp then
		var last = dir == NEXT or (dir == CURR and which == LAST)
		return self:find_offset(iif(last, 1/0, 0), DEFAULT)
	end
	return seg, i
end

terra Cursor:find_offset(offset: int, which: enum)
	var seg, i = self.layout:cursor_at_offset(offset)
	if which ~= 0 then
		return self:find_cursor(seg, i, CURR, CHAR, which, false)
	else
		return seg, i
	end
end
terra Cursor:move_to_offset(offset: int, which: enum)
	self:set2(self:find_offset(offset, which), DEFAULT_NUM)
end

terra Cursor:reposition()
	self:move_to_offset(self.offset, DEFAULT)
end

terra Cursor:find_rel_cursor(dir: enum, mode: enum, which: enum, clamp: bool)
	return self:find_cursor(self.seg, self.i, dir, mode, which, clamp)
end
terra Cursor:move_to_rel_cursor(dir: enum, mode: enum, which: enum, clamp: bool)
	self:set2(self:find_rel_cursor(dir, mode, which, clamp), DEFAULT_NUM)
end

terra Cursor:find_line(line_i: int, x: num)
	if x == DEFAULT_NUM then x = self.x end
	if line_i < 1 and self.park_home then
		return self:find_offset(0, DEFAULT)
	elseif line_i > self.layout.lines.len and self.park_end then
		return self:find_offset(1/0, DEFAULT)
	end
	return self.layout:hit_test_cursors(line_i, x, diff, valid, self, DEFAULT)
end
terra Cursor:move_to_line(line_i: int, x: num)
	self:set2(self:find_line(line_i, x), x)
end

terra Cursor:find_rel_line(delta_lines: int, x: num)
	var line_i = self.seg.line_index + (delta_lines or 0)
	return self:find_line(line_i, x)
end
terra Cursor:move_to_rel_line(line_i: int, x: num)
	self:set2(self:find_rel_line(line_i, x), x)
end

terra Cursor:find_pos(x: num, y: num)
	var line_i = self.layout:hit_test_lines(y)
	return self:find_line(line_i, x)
end
terra Cursor:move_to_pos(x: num, y: num)
	self:set2(self:find_pos(x, y), x)
end

terra Cursor:find_page(page: int, x: num)
	var _, line1_y = self.layout:line_pos(0)
	var y = line1_y + (page - 1) * self.layout.h
	return self:find_pos(x, y)
end
terra Cursor:move_to_page(page: int, x: num)
	self:set2(self:find_page(page, x), x)
end

terra Cursor:find_rel_page(delta_pages: int, x: num)
	var _, line_y = self.layout:line_pos(self.seg.line_index)
	var y = line_y + (delta_pages or 0) * self.layout.h
	return self:find_pos(x, y)
end
terra Cursor:move_to_rel_page(delta_pages: int, x: num)
	self:set2(self:find_rel_page(delta_pages, x), x)
end

--[[
function cursor:insert(...) --insert text at cursor.
	local offset = self.seg.offset + self.i
	local offset, changed = self.segments:insert(offset, ...)
	if changed then
		self:move('offset', offset, 'first')
	end
	return changed
end

function cursor:remove(delta) --remove delta cursor positions of text.
	local i1 = self.seg.offset + self.i
	local i2 = self:next_cursor(delta, 'char')
	local offset, changed = self.segments:remove(i1, i2)
	if changed then
		self:move('offset', offset)
	end
	return changed
end
]]

