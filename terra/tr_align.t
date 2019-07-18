
--Fit line-wrapped text inside a box.

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')

terra Layout:_align()

	var w = self.align_w
	var h = self.align_h
	if w == -1 then w = self.max_ax end   --self-box
	if h == -1 then h = self.spaced_h end --self-box

	var align_x = self.align_x
	if align_x == ALIGN_AUTO then
		    if self.base_dir == DIR_AUTO then align_x = ALIGN_LEFT
		elseif self.base_dir == DIR_LTR  then align_x = ALIGN_LEFT
		elseif self.base_dir == DIR_RTL  then align_x = ALIGN_RIGHT
		elseif self.base_dir == DIR_WLTR then align_x = ALIGN_LEFT
		elseif self.base_dir == DIR_WRTL then align_x = ALIGN_RIGHT
		end
	end

	self.min_x = inf
	for line_i, line in self.lines do
		--compute line's aligned x position relative to the textbox origin.
		if align_x == ALIGN_RIGHT then
			line.x = w - line.advance_x
		elseif align_x == ALIGN_CENTER then
			line.x = (w - line.advance_x) / 2.0
		end
		self.min_x = min(self.min_x, line.x)
	end

	--compute first line's baseline based on vertical alignment.
	var first_line = self.lines:at(0)
	var last_line  = self.lines:at(self.lines.len-1)
	if self.align_y == ALIGN_TOP then
		self.baseline = first_line.spaced_ascent
	elseif self.align_y == ALIGN_BOTTOM then
		self.baseline = h - (last_line.y - last_line.spaced_descent)
	elseif self.align_y == ALIGN_CENTER then
		self.baseline = first_line.spaced_ascent + (h - self.spaced_h) / 2
	end

	self.clip_valid = false

end
