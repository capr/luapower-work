
setfenv(1, require'terra/tr_types')

require'terra/tr_shape'
require'terra/tr_linewrap'
require'terra/tr_align'
require'terra/tr_clip'

terra Layout:layout()
	if not self.visible then
		return
	end
	if self.state == STATE_ALIGNED then
		self:clip()
	elseif self.state == STATE_WRAPPED then
		self:align()
		self:clip()
	elseif self.state == STATE_SHAPED  then
		self:wrap()
		self:align()
		self:clip()
	else
		assert(self.state == 0)
		self:shape()
		self:wrap()
		self:align()
		self:clip()
	end
end
