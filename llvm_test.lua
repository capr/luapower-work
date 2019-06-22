
local llvm = require'llvm'

local mod = llvm.module'my_module'

local sum_fn = mod:fn('sum', llvm.fn(llvm.int32, llvm.int32, llvm.int32))
local entry = sum_fn:block'entry'

local builder = llvm.builder()

builder:position_at_end(entry)

builder:ret(builder:add(sum_fn:param(0), sum_fn:param(1), 'tmp'))

assert(mod:verify())

local engine = mod:exec_engine()

local x = 6
local y = 42

local ret = engine:run(sum_fn, llvm.values(
	llvm.intval(llvm.int32, x),
	llvm.intval(llvm.int32, y))):toint()

assert(ret == x + y)

print(mod:tostring())
print(mod:asm())

local m2 = assert(llvm.ir[[
	define i32 @f() {
		block:
			ret i32 1234
	}
]])

assert(mod:link_module(m2))

assert(llvm.bitcode(mod:bitcode()))

print(llvm.default_target_triple())
--local target = assert(llvm.target_from_triple'x86_64-w64-windows-gnu')
--print(target:tostring())

--assert(engine:run(m2:get_fn()))

builder:free()
engine:free() --frees the module

print'test ok'
