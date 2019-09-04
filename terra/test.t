require'low'

terra f()
	return 1, 2
end

terralib.printraw(#f.type.returntype.entries)

do return end

setfenv(1, require'terra/low')
local color = require'terra/cairo'.cairo_argb32_color_t
terra f()
	var c1 = color{uint = 1}
	var c2 = color{uint = 1}
	print(c1 ~= c2)
end
f()


do return end

local xx = require'low'.module'xx'
local xx2 = require'low'.module'xx'
assert(xx == xx2)
os.exit()

setfenv(1, require'low')

local assign = macro(function(lvalue, v)
	print(lvalue, type(lvalue))
	return quote lvalue = v end
end)

struct S (gettersandsetters) {_x: int}
struct V (gettersandsetters) {_y: int}

terra S:get_x() return self._x end
terra S:set_x(v: int) self._x = v end

terra V:get_y() return self._y end
terra V:set_y(v: int) self._y = v end

struct T (extends(S)) {a: int}

terra f()
	--var x = 1
	--assign(x, 2)
	--print(x)
	var s: T
	s.x = 5
	print(s.x)
	--assign(s.x, 5)
end

f()
