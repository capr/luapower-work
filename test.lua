local ffi = require'ffi'

ffi.cdef[[
typedef struct S S;
typedef void (*fp) (S);
struct S {
	int x;
};
]]

s = ffi.new'S'
fp = ffi.cast('fp', 0)
fp(s)
