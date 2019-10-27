
local ffi = require'ffi'
local hid = require'hidapi'
local nw = require'nw'
local app = nw:app()

local win = app:window{
	w = 1200,
	h = 800,
	x = 'center-active',
	y = 'center-active',
}

--[[
local view = win:view{
	x = 200,
	y = 10,
	w = 500,
	h = 500,
}
]]

local dev
local buf = ffi.new'uint16_t[32]'

function win:repaint()
	local cr = self:bitmap():cairo()
	cr:rgb(0, 0, 0)
	cr:paint()

	::retry::
	dev = dev or hid.open(4660, 1)

	if dev then
		dev:block(false)
		while true do
			local i = 0
			while i < 64 do
				local n, err = dev:read(ffi.cast('uint8_t*', buf) + i, 64 - i)
				if not n then
					dev:close()
					dev = nil
					goto retry
				elseif n == 0 then
					goto continue
				end
				i = i + n
			end
		end
		::continue::

		local cw, ch = self:client_size()
		for i = 0, 31 do
			cr:circle(cw / 2, ch / 2, buf[i] / 2)
			cr:rgb(1, 1, 1)
			cr:stroke()
		end
	end

	self:title(app:fps()..' fps')
	self:invalidate()
end

function win:keypress(key)
	if key == 'esc' then
		win:close()
	end
end

app:run()
dev:close()
