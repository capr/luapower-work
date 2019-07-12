
local t = {}

function t:__newindex(k, v)
	print(self, k, v)
end

local o = {}
setmetatable(o, o)
o.__index = t
o.__newindex = o.__newindex
print(o.__newindex)

o.x = 1

