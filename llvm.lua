
--LLVM 8 C API ffi binding (x86 target).
--Written by Cosmin Apreutesei. Public Domain.

if not ... then require'llvm_test'; return end

local ffi = require'ffi'
local glue = require'glue'
local type, select = type, select
local print = print
require'llvm_h'
local C = ffi.load'llvm'
local M = setmetatable({}, {__index = C})
setfenv(1, M)

function module(name)
	return C.LLVMModuleCreateWithName(name)
end

builder = LLVMCreateBuilder

function types(...)
	local n = select('#', ...)
	return ffi.new('LLVMTypeRef[?]', n, ...), n
end

function values(...)
	local n = select('#', ...)
	return ffi.new('LLVMGenericValueRef[?]', n, ...), n
end

function intval(ty, n) return LLVMCreateGenericValueOfInt(ty, n, true) end
function uintval(ty, n) return LLVMCreateGenericValueOfInt(ty, n, false) end

ptrval = LLVMCreateGenericValueOfPointer
floatval = LLVMCreateGenericValueOfFloat

function fn_type(...)
	if type((...)) ~= 'boolean' then
		return fn_type(false, ...)
	end
	local vararg, ret_type = ...
	local param_types, n = types(select(3, ...))
	return C.LLVMFunctionType(ret_type, param_types, n, vararg)
end

int1     = LLVMInt1Type()
int8     = LLVMInt8Type()
int16    = LLVMInt16Type()
int32    = LLVMInt32Type()
int64    = LLVMInt64Type()
int128   = LLVMInt128Type()
int      = LLVMIntType
half     = LLVMHalfType()
float    = LLVMFloatType()
double   = LLVMDoubleType()
fp80     = LLVMX86FP80Type()
fp128    = LLVMFP128Type()

local sp = ffi.new'char*[1]'
function LLVMVerifyModule(M, Action)
	sp[0] = nil
	local ok = C.LLVMVerifyModule(M, Action or LLVMAbortProcessAction, sp) == 0
	if not ok then
		local s = ffi.string(sp[0])
		LLVMDisposeMessage(sp[0])
		return false, s
	end
	return true
end

ffi.metatype('struct LLVMOpaqueModule', {__index = {
	fn = LLVMAddFunction,

	verify = LLVMVerifyModule,

	write_bitcode_to_file = function(M, file) return LLVMWriteBitcodeToFile(M, file) == 0 end,
	write_bitcode_to_fd = function(M, fd) return LLVMWriteBitcodeToFD(M, fd) == 0 end,
	write_bitcode_to_file_handle = function(M, H) return LLVMWriteBitcodeToFileHandle(M, H) == 0 end,
	write_bitcode_to_memory_buffer = LLVMWriteBitcodeToMemoryBuffer,
}})

ffi.metatype('struct LLVMOpaqueValue', {__index = {
	block = LLVMAppendBasicBlock,
	param = LLVMGetParam,

}})

ffi.metatype('struct LLVMOpaqueBuilder', {__index = {

	free = LLVMDisposeBuilder,

	position_at     = LLVMPositionBuilder,
	position_before = LLVMPositionBuilderBefore,
	position_at_end = LLVMPositionBuilderAtEnd,

	add = LLVMBuildAdd,

	ret_void = LLVMBuildRetVoid,
	ret = LLVMBuildRet,

}, __gc = LLVMDisposeBuilder})

local int64_t = ffi.typeof'int64_t'
ffi.metatype('struct LLVMOpaqueGenericValue', {__index = {
	int_width = LLVMGenericValueIntWidth,
	toint = function(GenVal) return ffi.cast(int64_t, LLVMGenericValueToInt(GenVal, true)) end,
	touint = function (GenVal) return LLVMGenericValueToInt(GenVal, false) end,
	toptr = LLVMGenericValueToPointer,
	tofloat = LLVMGenericValueToFloat,
}})

local function LLVMLinkInMCJIT()
	C.LLVMLinkInMCJIT()
	LLVMLinkInMCJIT = glue.noop
end

local function LLVMInitializeX86Target()
	C.LLVMInitializeX86Target()
	LLVMInitializeX86Target = glue.noop
end

function exec_engine(mod)
	LLVMLinkInMCJIT()
	LLVMInitializeX86Target()
	sp[0] = nil
	local engine_buf = ffi.new'LLVMExecutionEngineRef[1]'
	if LLVMCreateExecutionEngineForModule(engine_buf, mod, sp) ~= 0 then
		local s = ffi.string(sp[0])
		C.LLVMDisposeMessage(sp[0])
		return nil, s
	end
	return engine_buf[0]
end

function LLVMRunFunction(EE, F, args)
	local nargs = ffi.sizeof(args) / ffi.sizeof'LLVMGenericValueRef'
	return C.LLVMRunFunction(EE, F, nargs, args)
end

ffi.metatype('struct LLVMOpaqueExecutionEngine', {__index = {

	free = LLVMDisposeExecutionEngine,

	run = LLVMRunFunction,

}, __gc = LLVMDisposeExecutionEngine})

return M
