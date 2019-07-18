
--Text selection.

if not ... then require'terra/tr_test'; return end

setfenv(1, require'terra/tr_types')
require'terra/tr_cursor'

struct Selection {
	layout: &Layout;
	cursor: Cursor;
	len: int;
	color: color;
}

terra Selection:init(layout: &Layout)
	self.layout = layout
	self.cursor:init(layout)
	self.color = DEFAULT_SELECTION_COLOR
end

