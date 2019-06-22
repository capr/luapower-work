
--LLVM 8 C API ffi binding (x86 target).
--Written by Cosmin Apreutesei. Public Domain.

if not ... then require'llvm_test'; return end

local ffi = require'ffi'
local glue = require'glue'
local type, select = type, select
local print = print
local free = ffi.C.free
require'llvm_h'
local C = ffi.load'llvm'
local M = setmetatable({}, {__index = C})
setfenv(1, M)

local sp = ffi.new'char*[1]'
local sizep = ffi.new'size_t[1]'

local function retbool(f)
	return function(...)
		return f(...) == 1
	end
end

local function retstring(f)
	return function(...)
		local p = f(...)
		return p ~= nil and ffi.string(p) or nil
	end
end

local function getset(get, set)
	return function(self, arg)
		if arg then
			set(self, arg)
		else
			return get(self)
		end
	end
end

--memory buffers -------------------------------------------------------------

function membuffer(s, name) --NOTE: s must be pinned externally!
	return C.LLVMCreateMemoryBufferWithMemoryRange(s, #s, name or '<buffer>', false)
end

ffi.metatype('struct LLVMOpaqueMemoryBuffer', {__index = {
	free = LLVMDisposeMemoryBuffer,
	data = LLVMGetBufferStart,
	size = LLVMGetBufferSize,
}})

--types ----------------------------------------------------------------------

function types(...)
	local n = select('#', ...)
	return ffi.new('LLVMTypeRef[?]', n, ...), n
end

local function LLVMFunctionType_(vararg, ret_type, ...)
	local param_types, n = types(...)
	return C.LLVMFunctionType(ret_type, param_types, n, vararg)
end
function LLVMFunctionType(...)
	if type((...)) ~= 'boolean' then
		return LLVMFunctionType_(false, ...)
	else
		return LLVMFunctionType_(...)
	end
end
fn = LLVMFunctionType

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
void     = LLVMVoidType()
label    = LLVMLabelType()
mmx      = LLVMX86MMXType()

function LLVMPrintTypeToString(M)
	local sp = C.LLVMPrintTypeToString(M)
	local s = ffi.string(sp)
	free(sp)
	return s
end

LLVMIsFunctionVarArg = retbool(LLVMIsFunctionVarArg)

function LLVMGetParamTypes(T)
	local n = T:param_count()
	local types = ffi.new('LLVMTypeRef[?]', n)
	C.LLVMGetParamTypes(T, types)
	return types, n
end

local function LLVMStructType_(packed, ...)
	local types, n = types(...)
	return C.LLVMStructType(types, n, packed)
end
function LLVMStructType(...)
	if type((...)) ~= 'boolean' then
		return LLVMStructType_(false, ...)
	else
		return LLVMStructType_(...)
	end
end
struct = LLVMStructType

function LLVMGetStructElementTypes(T)
	local n = T:elem_count()
	local types = ffi.new('LLVMTypeRef[?]', n)
	C.LLVMGetStructElementTypes(T, types)
	return types, n
end

local function LLVMStructSetBody_(T, packed, ...)
	local types, n = types(...)
	C.LLVMStructSetBody(T, types, n, packed)
end
function LLVMStructSetBody(T, ...)
	if type((...)) ~= 'boolean' then
		return LLVMStructSetBody_(false, ...)
	else
		return LLVMStructSetBody_(...)
	end
end

function LLVMGetSubtypes(T)
	local n = T:subtype_count()
	local types = ffi.new('LLVMTypeRef[?]', n)
	C.LLVMGetSubtypes(T, types)
	return types, n
end

array = LLVMArrayType
ptr = LLVMPointerType
vec = LLVMVectorType

LLVMIsOpaqueStruct = retbool(LLVMIsOpaqueStruct)

ffi.metatype('struct LLVMOpaqueType', {__index = {
	kind = LLVMGetTypeKind,
	is_sized = LLVMTypeIsSized,
	tostring = LLVMPrintTypeToString,
	align = LLVMAlignOf,
	size = LLVMSizeOf,
	--integer types
	int_width = LLVMGetIntTypeWidth,
	--function types
	is_vararg = LLVMIsFunctionVarArg,
	ret_type = LLVMGetReturnType,
	param_count = LLVMCountParamTypes,
	param_types = LLVMGetParamTypes,
	--struct types
	elem_count = LLVMCountStructElementTypes,
	elem_types = LLVMGetStructElementTypes,
	elem_type = LLVMStructGetTypeAtIndex,
	is_packed = LLVMIsPackedStruct,
	is_opaque = LLVMIsOpaqueStruct,
	is_literal = LLVMIsLiteralStruct,
	set_elems = LLVMStructSetBody,
	--sequential types
	elem_type = LLVMGetElementType,
	subtype_count = LLVMGetNumContainedTypes,
	subtypes = LLVMGetSubtypes,
	--array types
	len = LLVMGetArrayLength,
	--pointer types
	addr_space = LLVMGetPointerAddressSpace,
	--vector types
	vec_size = LLVMGetVectorSize,
}})

--constants ------------------------------------------------------------------

function LLVMConstString(s, dont_null_terminate)
	return C.LLVMConstString(s, #s, dont_null_terminate or false)
end

function LLVMConstStruct_(packed, ...)
	local values, n = values(...)
	return C.LLVMConstStruct(values, n, packed)
end
function LLVMConstStruct(...)
	if type((...)) ~= 'boolean' then
		return LLVMConstStruct_(false, ...)
	else
		return LLVMConstStruct_(...)
	end
end

function LLVMConstArray(T, ...)
	local values, n = values(...)
	return C.LLVMConstArray(T, values, n)
end

function LLVMConstVector(...)
	local values, n = values(...)
	return C.LLVMConstVector(values, n)
end

const_null     = LLVMConstNull
const_all_ones = LLVMConstAllOnes
undef          = LLVMGetUndef
const_ptr_null = LLVMConstPointerNull
const_int      = LLVMConstInt
const_real     = LLVMConstReal
const_string   = LLVMConstString
const_struct   = LLVMConstStruct
const_array    = LLVMConstArray
const_vec      = LLVMConstVector

--const_apint    = LLVMConstIntOfArbitraryPrecision --TODO: wrap
--TODO: LLVMConstIntOfString, LLVMConstIntOfStringAndSize
--TODO: LLVMConstRealOfString

--values ---------------------------------------------------------------------

LLVMIsNull = retbool(LLVMIsNull)
LLVMIsDeclaration = retbool(LLVMIsDeclaration)
LLVMGetSection = retstring(LLVMGetSection)
LLVMHasUnnamedAddr = retbool(LLVMHasUnnamedAddr)
LLVMValueIsBasicBlock = retbool(LLVMValueIsBasicBlock)

function LLVMGetBasicBlocks(V)
	local n = V:block_count()
	local blocks = ffi.new('LLVMOpaqueBasicBlock[?]', n)
	C.LLVMGetBasicBlocks(V, blocks)
	return blocks, n
end

ffi.metatype('struct LLVMOpaqueValue', {__index = {
	block = LLVMAppendBasicBlock,
	param_count = LLVMCountParams,
	param = LLVMGetParam,
	param_align = LLVMSetParamAlignment,
	type  = LLVMTypeOf,
	is_block = LLVMValueIsBasicBlock,
	as_block = LLVMValueAsBasicBlock,
	block_count = LLVMCountBasicBlocks,
	blocks = LLVMGetBasicBlocks,
	is_null = LLVMIsNull,
	is_decl = LLVMIsDeclaration,
	linkage = getset(LLVMGetLinkage, LLVMSetLinkage),
	section = getset(LLVMSetSection, LLVMGetSection),
	visibility = getset(LLVMGetVisibility, LLVMSetVisibility),
	dll_storage_class = getset(LLVMGetDLLStorageClass, LLVMSetDLLStorageClass),
	unnamed_addr = getset(LLVMGetUnnamedAddress, LLVMSetUnnamedAddress),
	has_unnamed_addr = getset(LLVMHasUnnamedAddr, LLVMSetUnnamedAddr),
	alignment = getset(LLVMGetAlignment, LLVMSetAlignment),
	init = getset(LLVMGetInitializer, LLVMSetInitializer),
	is_thread_local = getset(LLVMIsThreadLocal, LLVMSetThreadLocal),
	is_global_const = getset(LLVMIsGlobalConstant, LLVMSetGlobalConstant),
	thread_local_mode = getset(LLVMGetThreadLocalMode, LLVMSetThreadLocalMode),
	is_ext_init = getset(LLVMIsExternallyInitialized, LLVMSetExternallyInitialized),
	call_conv = getset(LLVMGetFunctionCallConv, LLVMSetFunctionCallConv),
	is_tail_call = getset(LLVMIsTailCall, LLVMSetTailCall),
	--instructions
	opcode = LLVMGetInstructionOpcode,
	--conditions
	cond = getset(LLVMGetCondition, LLVMSetCondition),
}})

--generic values -------------------------------------------------------------

function values(...)
	local n = select('#', ...)
	return ffi.new('LLVMGenericValueRef[?]', n, ...), n
end

function intval(ty, n) return LLVMCreateGenericValueOfInt(ty, n, true) end
function uintval(ty, n) return LLVMCreateGenericValueOfInt(ty, n, false) end

ptrval = LLVMCreateGenericValueOfPointer
floatval = LLVMCreateGenericValueOfFloat

local int64_t = ffi.typeof'int64_t'
ffi.metatype('struct LLVMOpaqueGenericValue', {__index = {
	int_width = LLVMGenericValueIntWidth,
	toint = function(GenVal) return ffi.cast(int64_t, LLVMGenericValueToInt(GenVal, true)) end,
	touint = function (GenVal) return LLVMGenericValueToInt(GenVal, false) end,
	toptr = LLVMGenericValueToPointer,
	tofloat = LLVMGenericValueToFloat,
}})

--builders -------------------------------------------------------------------

builder = LLVMCreateBuilder

ffi.metatype('struct LLVMOpaqueBuilder', {__index = {

	free = LLVMDisposeBuilder,

	position_at     = LLVMPositionBuilder,
	position_before = LLVMPositionBuilderBefore,
	position_at_end = LLVMPositionBuilderAtEnd,

	add = LLVMBuildAdd,

	ret_void = LLVMBuildRetVoid,
	ret = LLVMBuildRet,

	debug_location = getset(LLVMGetCurrentDebugLocation, LLVMSetCurrentDebugLocation),
	inst_debug_location = LLVMSetInstDebugLocation,

}})

--execution engines ----------------------------------------------------------

local function LLVMLinkInMCJIT()
	C.LLVMLinkInMCJIT()
	LLVMLinkInMCJIT = glue.noop
end

local function LLVMInitializeX86Target()
	C.LLVMInitializeX86Target()
	LLVMInitializeX86Target = glue.noop
end

function LLVMCreateExecutionEngineForModule(mod)
	LLVMLinkInMCJIT()
	LLVMInitializeX86Target()
	local engine_buf = ffi.new'LLVMExecutionEngineRef[1]'
	if C.LLVMCreateExecutionEngineForModule(engine_buf, mod, sp) ~= 0 then
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

	add_module = LLVMAddModule,

}})

--targets --------------------------------------------------------------------

target = LLVMGetTargetFromName

function LLVMGetTargetFromTriple(s)
	local t = ffi.new'LLVMTargetRef[1]'
	if C.LLVMGetTargetFromTriple(s, t, sp) ~= 0 then
		local s = ffi.string(sp[0])
		free(sp[0])
		return nil, s
	else
		return t[0]
	end
end
target_from_triple = LLVMGetTargetFromTriple

LLVMGetTargetName = retstring(LLVMGetTargetName)
LLVMGetTargetDescription = retstring(LLVMGetTargetDescription)
LLVMTargetHasJIT = retbool(LLVMTargetHasJIT)
LLVMTargetHasTargetMachine = retbool(LLVMTargetHasTargetMachine)
LLVMTargetHasAsmBackend = retbool(LLVMTargetHasAsmBackend)

ffi.metatype('struct LLVMTarget', {__index = {
	name = LLVMGetTargetName,
	descr = LLVMGetTargetDescription,
	has_jit = LLVMTargetHasJIT,
	has_machine = LLVMTargetHasTargetMachine,
	has_asm_backend = LLVMTargetHasAsmBackend,
	machine = LLVMCreateTargetMachine,
}})

LLVMGetTargetMachineTriple = retstring(LLVMGetTargetMachineTriple)
LLVMGetTargetMachineCPU = retstring(LLVMGetTargetMachineCPU)
LLVMGetTargetMachineFeatureString = retstring(LLVMGetTargetMachineFeatureString)

function LLVMTargetMachineEmitToString(TM, M, codegen)
	local membufp = ffi.new'LLVMMemoryBufferRef[1]'
	if C.LLVMTargetMachineEmitToMemoryBuffer(TM, M, codegen, sp, membufp) ~= 0 then
		local s = ffi.string(sp[0])
		free(sp[0])
		return nil, s
	else
		return membuf:tostring()
	end
end

ffi.metatype('struct LLVMOpaqueTargetMachine', {__index = {
	free = LLVMDisposeTargetMachine,
	target = LLVMGetTargetMachineTarget,
	triple = LLVMGetTargetMachineTriple,
	cpu = LLVMGetTargetMachineCPU,
	features = LLVMGetTargetMachineFeatureString,
	data_layout = LLVMCreateTargetDataLayout,
	asm_verbosity = LLVMSetTargetMachineAsmVerbosity,
	tostring = LLVMTargetMachineEmitToString,
	add_analysis_passes = LLVMAddAnalysisPasses,
}})

LLVMGetDefaultTargetTriple = retstring(LLVMGetDefaultTargetTriple)
default_target_triple = LLVMGetDefaultTargetTriple

LLVMNormalizeTargetTriple = retstring(LLVMNormalizeTargetTriple)
normalize_target_triple = LLVMNormalizeTargetTriple

LLVMGetHostCPUName = retstring(LLVMGetHostCPUName)
LLVMGetHostCPUFeatures = retstring(LLVMGetHostCPUFeatures)

target_data = C.LLVMCreateTargetData

function LLVMCopyStringRepOfTargetData(TD)
	local sp = C.LLVMCopyStringRepOfTargetData(TD)
	local s = ffi.string(sp)
	free(sp)
	return s
end

ffi.metatype('struct LLVMOpaqueTargetData', {__index = {
	free = LLVMDisposeTargetData,
	byte_order = LLVMByteOrder,
	pointer_size = LLVMPointerSize,
	pointer_size_for_as = LLVMPointerSizeForAS,
	int_ptr_type = LLVMIntPtrType,
	int_ptr_type_for_as = LLVMIntPtrTypeForAS,
	bit_sizeof = LLVMSizeOfTypeInBits,
	sizeof = LLVMStoreSizeOfType,
	abi_sizeof = LLVMABISizeOfType,
	abi_align = LLVMABIAlignmentOfType,
	call_frame_align = LLVMCallFrameAlignmentOfType,
	preferred_align = LLVMPreferredAlignmentOfType,
	global_preferred_align = LLVMPreferredAlignmentOfGlobal,
	elem_at_offset = LLVMElementAtOffset,
	elem_offset = LLVMOffsetOfElement,
	tostring = LLVMCopyStringRepOfTargetData,
}})

--modules --------------------------------------------------------------------

function LLVMParseBitcode(s)
	local membuf = membuffer(s) --TODO: does the module get to own the membuf?
	local modp = ffi.new'LLVMModuleRef[1]'
	if C.LLVMParseBitcode(membuf, modp, sp) ~= 0 then
		local s = ffi.string(sp)
		free(sp[0])
		return nil, s
	else
		return modp[0]
	end
end
bitcode = LLVMParseBitcode
module = LLVMModuleCreateWithName

function LLVMVerifyModule(M, Action)
	if C.LLVMVerifyModule(M, Action or LLVMAbortProcessAction, sp) ~= 0 then
		local s = ffi.string(sp[0])
		LLVMDisposeMessage(sp[0])
		return false, s
	end
	return true
end

function LLVMPrintModuleToString(M)
	local sp = C.LLVMPrintModuleToString(M)
	local s = ffi.string(sp)
	free(sp)
	return s
end

function LLVMSetModuleInlineAsm(M, s)
	C.LLVMSetModuleInlineAsm2(M, s, #s)
end

function LLVMGetModuleInlineAsm(M, ip)
	local s = C.LLVMGetModuleInlineAsm(M, sizep)
	return ffi.string(s, sizep[0])
end

function LLVMParseIR(s, name)
	local membuf = membuffer(s, name) --gets owned by the module
	local modp = ffi.new'LLVMModuleRef[1]'
	if C.LLVMParseIRInContext(LLVMGetGlobalContext(), membuf, modp, sp) ~= 0 then
		local s = ffi.string(sp[0])
		free(sp[0])
		return nil, s
	else
		return modp[0]
	end
end
ir = LLVMParseIR

function LLVMLinkModules(M, SM)
	return C.LLVMLinkModules2(M, SM) == 0
end

function LLVMWriteBitcodeToString(M)
	local membuf = C.LLVMWriteBitcodeToMemoryBuffer(M)
	local s = ffi.string(membuf:data(), membuf:size())
	membuf:free()
	return s
end

LLVMGetTarget = retstring(LLVMGetTarget)

ffi.metatype('struct LLVMOpaqueModule', {__index = {
	free = LLVMDisposeModule,
	fn = LLVMAddFunction,
	global = LLVMAddGlobal,
	type = LLVMGetTypeByName,
	verify = LLVMVerifyModule,
	tostring = LLVMPrintModuleToString,
	asm = getset(LLVMGetModuleInlineAsm, LLVMSetModuleInlineAsm),
	exec_engine = LLVMCreateExecutionEngineForModule,
	strip = LLVMStripModuleDebugInfo,
	link_module = LLVMLinkModules,
	bitcode = LLVMWriteBitcodeToString,
	source_filename = getset(LLVMGetSourceFileName, LLVMSetSourceFileName),
	target = getset(LLVMGetTarget, LLVMSetTarget),
	data_layout = getset(LLVMGetModuleDataLayout, LLVMSetModuleDataLayout),

}})

return M
