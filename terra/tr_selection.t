
--Text selection.

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')
require'terra/tr_cursor'

terra Selection:init(layout: &Layout)
	self.cursor:init(layout)
	self.len = 0
	self.color = DEFAULT_SELECTION_COLOR
end

terra Selection:free()
	self.cursor:free()
	dealloc(self)
end

terra Layout:selection()
	var sel = new(Selection, self)
	self.selections:add(sel) --takes ownership
	return sel
end

terra Selection:release()
	self.cursor.layout.selections:remove(&self) --calls Selection:free()
end
