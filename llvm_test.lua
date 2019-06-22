
local ffi = require'ffi'
local llvm = require'llvm'

local mod = llvm.module'my_module'

local sum = mod:fn('sum', llvm.fn_type(llvm.int32, llvm.int32, llvm.int32))
local entry = sum:block'entry'

local builder = llvm.builder()

builder:position_at_end(entry)

local tmp = builder:add(sum:param(0), sum:param(1), 'tmp')
builder:ret(tmp)

assert(mod:verify())

local engine = assert(llvm.exec_engine(mod))

local x = 6
local y = 42

local args = llvm.values(
	llvm.intval(llvm.int32, x),
	llvm.intval(llvm.int32, y))

local ret = engine:run(sum, args):toint()

assert(mod:write_bitcode_to_file'sum.bc')

assert(ret == x + y)

builder:free()
engine:free()
