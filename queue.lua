
local ffi  = require'ffi'
local glue = require'glue'
local time = require'time'

local function counter(filename)
	local n = tonumber(glue.readfile(filename) or 0)
	return n, function()
		n = n + 1
		assert(glue.writefile(filename, n))
		return n
	end
end

local function queue(dir)

	local first, inc_first = counter(dir..'/first')
	local last , inc_last  = counter(dir..'/last')

	local q = {}

	function q:push(msg)
		local ok, err = glue.writefile(dir..'/'..(last + 1), msg, nil, dir..'/tmp')
		if ok then
			last = inc_last()
			if first == 0 then
				first = inc_first()
			end
		end
		return ok, err
	end

	function q:peek()
		return (glue.readfile(dir..'/'..first))
	end

	function q:pull()
		first = inc_first()
		assert(os.remove(dir..'/'..(first-1)))
	end

	return q
end

--speed-test -----------------------------------------------------------------

local function probe()
	local bytes, messages, t0, mt0
	local function reset(t)
		bytes = 0
		messages = 0
		t0 = t
		mt0 = t
	end
	reset(time.clock())
	return function(msg)
		messages = messages + 1
		bytes = bytes + #msg
		local t = time.clock()
		if t - mt0 > 1 then --more than a second has passed since last print
			local dt = t - t0
			print(string.format('messages/second: %6.2f, MB/second: %6.2f',
				messages / dt, bytes / dt / 1024^2))
			reset(t)
		end
	end
end

local q = queue(ffi.abi'win' and 'q' or '/home/cosmin/q')

local msg = (' hello'):rep(1000)

if ... == 'test-push' then

	local probe = probe()
	while true do
		q:push(msg)
		probe(msg)
	end

elseif ... == 'test-pull' then

	local probe = probe()
	while true do
		local msg = q:peek()
		if msg then
			q:pull()
			probe(msg or '')
		end
	end

end

