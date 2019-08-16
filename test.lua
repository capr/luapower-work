local ffi = require'ffi'

local b = ffi.new'int[1]'

b[0] = 2^50
print(b[0])
print(-2^31)
