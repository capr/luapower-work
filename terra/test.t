setfenv(1, require'low')

struct safeint { x: int; }
safeint.metamethods.__div = macro(function(a, b)
	return `iif(b.x ~= 0, safeint{a.x / b.x}, safeint{0})
end)

terra f(x: int, y: int)
	print(safeint{x} / safeint{y})
end

f(7, 0)
