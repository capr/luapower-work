
local llvm = require'llvm'

local mod = llvm.module'my_module'

local sum_fn = mod:fn('sum', llvm.fn_type(llvm.int32, llvm.int32, llvm.int32))
local entry = sum_fn:block'entry'

local builder = llvm.builder()

builder:position_at_end(entry)

builder:ret(builder:add(sum_fn:param(0), sum_fn:param(1), 'tmp'))

assert(mod:verify())

local engine = assert(llvm.exec_engine(mod))

local x = 6
local y = 42

local ret = engine:run(sum_fn, llvm.values(
	llvm.intval(llvm.int32, x),
	llvm.intval(llvm.int32, y))):toint()

assert(ret == x + y)

assert(mod:write_bitcode_to_file'sum.bc')

builder:free()
engine:free()

print'test ok'
