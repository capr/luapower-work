
local ffi = require'ffi'
local hid = require'hidapi'
local glue = require'glue'
local time = require'time'
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

local function logbuffer()
	local grow = glue.growbuffer('uint16_t[?]', true)
	local size = 0
	local read = 0
	return {
		allocate = function(self, n)
			local buf
			buf, size = grow(read + n)
			return buf + read, n
		end,
		commit = function(self, n)
			assert(read + n <= size)
			read = read + n
		end,
		get = function(self)
			return grow(0), read
		end,
	}
end

local log = logbuffer()

local function try_open()
	if not dev then
		dev = hid.open(4660, 1)
		if dev then
			dev:block(false)
		end
	end
	return dev and true or false
end

local function retry_open()
	dev:close()
	dev = nil
	try_open()
end

local function close_dev()
	if dev then dev:close() end
end

local function read_all()
	while try_open() do
		local buf, n = log:allocate(4096)
		local n, err = dev:read(ffi.cast('uint8_t*', buf), n)
		if not n then
			return retry_open()
		elseif n == 0 then
			return
		else
			log:commit(n)
		end
	end
end

local function draw_log(cr, w, h)
	local buf, n = log:get()
	local w = w - 100
	local nc = 64 * 600
	local i0 = math.max(n - nc, 0)
	local i1 = n-1
	local w = (i1 - i0) / nc * w
	for i = i0, i1, 64 do
		local x = glue.lerp(i, i0, i1, 0, w)
		local y = glue.lerp(buf[i], 0, 1023, h, 0)
		if i == i0 then
			cr:move_to(x, y)
		else
			cr:line_to(x, y)
		end
	end
	cr:rgb(1, 1, 1)
	local x, y = cr:current_point()
	cr:stroke()
	cr:rgb(1, 0, 0)
	cr:circle(x, y, 5)
	cr:fill()
	--print(string.format('%.2f MB recorded', n / 1024 / 1024))
end

function win:repaint()
	local cr = self:bitmap():cairo()
	cr:rgb(0, 0, 0)
	cr:paint()

	read_all()
	draw_log(cr, self:client_size())

	self:title(app:fps()..' fps')
	self:invalidate()
end

function win:keypress(key)
	if key == 'esc' then
		win:close()
	end
end

app:run()
close_dev()
