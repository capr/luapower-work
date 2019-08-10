
--Fit line-wrapped text inside a box.

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')

terra Line:_update_vertical_metrics(
	line_spacing: num,
	run_ascent: num,
	run_descent: num,
	ascent_factor: num,
	descent_factor: num
)
	self.ascent = max(self.ascent, run_ascent)
	self.descent = min(self.descent, run_descent)
	var run_h = run_ascent - run_descent
	var half_line_gap = run_h * (line_spacing - 1) / 2
	self.spaced_ascent
		= max(self.spaced_ascent,
			(run_ascent + half_line_gap) * ascent_factor)
	self.spaced_descent
		= min(self.spaced_descent,
			(run_descent - half_line_gap) * descent_factor)
end

terra Layout:_align()

	--compute line vertical metrics -------------------------------------------

	self.h = 0
	self.spaced_h = 0
	self.baseline = 0

	--special-case empty text: we still want to set valid alignment output
	--in order to properly display a cursor.
	if self.segs.len == 0 then
		var span = self.spans:at(0)
		var font = self.r.fonts:at(span.font_id, nil)
		var line = self.lines:at(0)
		if font ~= nil then
			line:_update_vertical_metrics(
				self.hardline_spacing,
				font.ascent,
				font.descent,
				1,
				self.hardline_spacing
			)
		end
	end

	var prev_line: &Line = nil
	var prev_line_spacing = 1.0
	for _,line in self.lines do

		line.ascent  = 0
		line.descent = 0
		line.spaced_ascent  = 0
		line.spaced_descent = 0

		var line_spacing =
			iif(line.linebreak == BREAK_PARA,
				self.paragraph_spacing,
				iif(line.linebreak == BREAK_LINE,
					self.hardline_spacing,
					self.line_spacing))

		--compute line ascent and descent scaling based on paragraph spacing.
		var ascent_factor = prev_line_spacing
		var descent_factor = line_spacing

		var ax = 0
		var seg = line.first_vis
		while seg ~= nil do
			--compute line's vertical metrics.
			var run = self:glyph_run(seg)
			line:_update_vertical_metrics(
				self.line_spacing,
				run.ascent,
				run.descent,
				ascent_factor,
				descent_factor
			)
			seg = seg.next_vis
		end

		--compute line's y position relative to first line's baseline.
		if prev_line ~= nil then
			var baseline_h = line.spaced_ascent - prev_line.spaced_descent
			line.y = prev_line.y + baseline_h
		end
		prev_line = line
		prev_line_spacing = line_spacing
	end

	var first_line = self.lines:at(0)
	var last_line = self.lines:at(self.lines.len-1)
	--compute the bounding-box height excluding paragraph spacing.
	self.h =
		first_line.ascent
		+ last_line.y
		- last_line.descent
	--compute the bounding-box height including paragraph spacing.
	self.spaced_h =
		first_line.spaced_ascent
		+ last_line.y
		- last_line.spaced_descent

	--align lines -------------------------------------------------------------

	var w = self.align_w
	var h = self.align_h
	if w == -1 then w = self.max_ax end   --self-box
	if h == -1 then h = self.spaced_h end --self-box

	var align_x = self.align_x
	if align_x == ALIGN_START or align_x == ALIGN_END then
		var left  = iif(align_x == ALIGN_START, ALIGN_LEFT, ALIGN_RIGHT)
		var right = iif(align_x == ALIGN_START, ALIGN_RIGHT, ALIGN_LEFT)
		    if self.base_dir == DIR_AUTO then align_x = left
		elseif self.base_dir == DIR_LTR  then align_x = right
		elseif self.base_dir == DIR_RTL  then align_x = right
		elseif self.base_dir == DIR_WLTR then align_x = left
		elseif self.base_dir == DIR_WRTL then align_x = right
		end
	end

	self.min_x = inf
	for line_i, line in self.lines do
		--compute line's aligned x position relative to the textbox origin.
		if align_x == ALIGN_RIGHT then
			line.x = w - line.advance_x
		elseif align_x == ALIGN_CENTER then
			line.x = (w - line.advance_x) / 2.0
		else
			line.x = 0
		end
		self.min_x = min(self.min_x, line.x)
	end

	--compute first line's baseline based on vertical alignment.
	if self.align_y == ALIGN_TOP then
		self.baseline = first_line.spaced_ascent
	elseif self.align_y == ALIGN_BOTTOM then
		self.baseline = h - (last_line.y - last_line.spaced_descent)
	elseif self.align_y == ALIGN_CENTER then
		self.baseline = first_line.spaced_ascent + (h - self.spaced_h) / 2
	end

	self.clip_valid = false

end
