local binsearch = require'glue'.binsearch

local t = {0, 5, 5, 10}
print((binsearch(6, t, function(t, i, v) return t[i] <= v end) or #t+1)-2)
