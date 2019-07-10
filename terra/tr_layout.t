
setfenv(1, require'terra/tr_types')

require'terra/tr_shape'
require'terra/tr_linewrap'
require'terra/tr_align'
require'terra/tr_clip'

terra Layout:layout()
	if self.state == STATE_ALIGNED then
		self:clip()
	elseif self.state == STATE_WRAPPED then
		self:align():clip()
	elseif self.state == STATE_SHAPED  then
		self:wrap():align():clip()
	else
		assert(self.state == 0)
		self:shape():wrap():align():clip()
	end
end
