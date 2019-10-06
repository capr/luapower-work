local nw = require'nw'
local glue = require'glue'

local win = nw:app():window{w = 500, h = 300}

function win:keydown(key) if key == 'esc' then self:close() end end

function win:repaint()
	local cr = win:bitmap():cairo()

	local x = 10
	local y = 0
	local w = self:client_size()-x*2
	local h = 30


	local f = (w / h) / 2
	local n = glue.round(f)
	local w = w / n / 2
	cr:rgba(1, 1, 1, 1)
	cr:new_path()
	cr:move_to(x, y + h)
	for i = 1, n do
		cr:rel_line_to(w, -h)
		cr:rel_line_to(w,  h)
	end
	cr:line_width(10)
	cr:stroke()
end

nw:app():run()

