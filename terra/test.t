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
