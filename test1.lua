local oo = require'oo'
local c1 = oo.Object:subclass()

function c1:class_before_subclass()
	print'c1:before_subclass'
end

function c1:set_x(v) print'set_x'; self._x = v * 2 end
function c1:get_x(v) return self._x / 3 end

function c1:before_init()
	print'c1:before_init'
end

local c2 = c1:subclass()

o = c2:create(1, 2, 3)


o.x = 6

print(o.x)

for k,v in pairs(c2) do print('', k,v) end
print()
for k,v in pairs(o) do print('', k,v) end

print(getmetatable(o) == getmetatable(c1))
