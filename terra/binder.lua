--[[

	Terra build system, C header generator and LuaJIT ffi binding generator.
	Written by Cosmin Apreutesei. Public Domain.

Features:

	* compiles and links shared libraries.
	* creates C header files and LuaJIT ffi bindings.
	* supports structs, methods, global functions and global vars.
	* dependent struct and function pointer types are declared automatically.
	* tuples and function pointers are typedef'ed with friendly unique names.
	* struct typedefs are anonymous (except when forward declarations are
	  needed because of circular references) which allows the same struct
	  definition to appear in multiple ffi bindings without raising an error.
	* auto-assigns methods to types via ffi.metatype.
	* enables getters and setters via ffi.metatype.
	* publishes global numbers and bitmask values as enums.
	* diff-friendly deterministic output.

Options controlling the output:

	* `cname`   : type/function name override.
	* `opaque`  : declare a type but don't define it.
	* `cprefix` : prefix method names.
	* `private` : tag method as private.
	* `methods` : provide options for methods.
	* `public_methods`: specify which methods to publish.

Conventions:

	* method names that start with an underscore are private by default.

Usage:

	local lib = publish'mylib'

	--publish Terra struct MyStruct.
	lib(MyStruct, {
		opaque=true,             --don't emit a fields definition
		cname='my_struct_t',     --publish MyStruct as C struct my_struct_t
		methods={                --provide options for methods
			myMethod='my_method', --name myMethod as my_method if publishing it
			myPrivMethod={private=true}, --specify that myPrivMethod is private
		},
		public_methods={         --publish only the methods in this map
			myMethod=1,           --publish myMethod as C function myMethod
			myMethod='my_method', --publish myMethod as C function my_method
			myMethod={cname='my_method', ...} --...same but with more options
			myMethod={            --publish overloaded myMethod as two C functions
				'my_method1',      --my_method1 and my_method2
				'my_method2',
			},
		},
	})

	--publish Terra function MyFunc.
	lib(MyFunc, 'my_func') --publish MyFunc as C function my_func

	--publish all all-uppercase string keys with number values from _M as C enums.
	lib(_M)

	--publish all keys in _M starting with `PREFIX_` and prefix them with `CPREFIX_`.
	lib(_M, '^PREFIX_', 'CPREFIX_')

	--publishing options can also be added to the Terra objects themselves:
	MyStruct.cname = 'my_struct_t'
	MyFunc.methods.myMethod.cname = 'my_method'
	MyFunc.cname = 'my_func'
	MyFunc.cname = {'my_func_overload1', 'my_func_overload2'}

Note:

	C and LuaJIT ffi cannot handle all types of circular struct dependencies
	that Terra can handle, in particular you can't declare a struct with
	forward-declared struct fields (unlike Terra, C eager-completes types).
	This means that you might need to add some types manually in some rare cases.

]]

if not ... then require'terra/binder_test'; return end

setfenv(1, require'terra/low'.module())

--C defs generator -----------------------------------------------------------

function cdefs(cnames, opaque)

	--C type name generation --------------------------------------------------

	cnames = cnames or {}
	opaque = opaque or {}
	local ctype --fw. decl. (used recursively)

	local function clean_cname(s)
		return s:gsub('[%.%${},()]+', '_')
	end

	local function cname_fragment(T)
		return T:isintegral() and tostring(T):gsub('32$', '')
			or T == rawstring and 'string'
			or T:ispointer() and 'p' .. cname_fragment(T.type)
			or clean_cname(ctype(T))
	end

	local function append_cname_fragment(s, T, n)
		if not T then return s end
		local t = cname_fragment(T)
		return s .. (s ~= '' and  '_' or '') .. t .. (n > 1 and n or '')
	end
	local function unique_cname(types)
		local type0, n = nil, 0
		local s = ''
		for i,type in ipairs(types) do
			if type ~= type0 then
				s = append_cname_fragment(s, type0, n)
				type0, n = type, 1
			else
				n = n + 1
			end
		end
		return append_cname_fragment(s, type0, n)
	end

	local function tuple_cname(T)
		--each tuple entry is the array {name, type}, hence plucking index 2.
		return unique_cname(glue.map(T.entries, 2))
	end

	local function funcptr_cname(T)
		local s = unique_cname(T.parameters)
		s = s .. (s ~= '' and '_' or 'void_') .. 'to'
		return append_cname_fragment(s, T.returntype, 1)
	end

	local function func_cname(func)
		assert(not func.name:find'^anon ', 'unnamed function')
		return clean_cname(func.name)
	end

	local function overload_cname(over)
		local t = {}
		local over_name = func_cname(over)
		for i,func in ipairs(over.definitions) do
			t[i] = func.cname or over_name..(i ~= 1 and i or '')
		end
		return t
	end

	local function globalvar_cname(glob)
		assert(glob.name ~= '<global>', 'unnamed global')
		return clean_cname(glob.name)
	end

	function ctype(v) --(fw. declared)
		if	   type(v) == 'terrafunction'
			or type(v) == 'overloadedterrafunction'
			or type(v) == 'terraglobalvariable'
		then
			return cnames[v] or v.cname
				or type(v) == 'terrafunction'           and func_cname(v)
				or type(v) == 'overloadedterrafunction' and overload_cname(v)
				or type(v) == 'terraglobalvariable'     and globalvar_cname(v)
		else
			assert(type(v) == 'terratype', 'invalid arg type ', type(v))
			local T = v
			if T == terralib.types.opaque or T:isunit() then
				return 'void'
			elseif T:isintegral() then
				return tostring(T)..'_t'
			elseif T:isfloat() or T:islogical() then
				return tostring(T)
			elseif T == rawstring then
				return 'const char *'
			elseif T:ispointer() then
				if T.type:isfunction() then
					return ctype(T.type) --C's funcptr is its own type.
				else
					return ctype(T.type)..'*'
				end
			elseif T:isarray() then
				return ctype(T.type)..'['..T.N..']'
			elseif T:isstruct() or T:isfunction() then
				return cnames[T] or T.cname
					or T:istuple() and tuple_cname(T)
					or T:isstruct() and clean_cname(tostring(T))
					or T:isfunction() and funcptr_cname(T)
			else
				assert(false, 'unsupported type ', T)
			end
		end
	end
	ctype = memoize(ctype)

	--C def generation --------------------------------------------------------

	local cdefs = {} --{str1, ...}; C def string accumulation buffer.
	local tdefs --typedefs at current level in typedef stack.
	local tdefstack = {}

	local function start_def()
		push(tdefstack, tdefs)
		tdefs = {}
	end

	local function end_def()
		extend(cdefs, tdefs)
		tdefs = pop(tdefstack)
	end

	local cdef --fw. decl. (used recursively)

	local function cdef_args(T)
		if #T.parameters == 0 then
			add(tdefs, 'void')
		else
			for i,arg in ipairs(T.parameters) do
				add(tdefs, cdef(arg, false))
				if i < #T.parameters then
					add(tdefs, ', ')
				end
				if T.isvararg then
					add(tdefs, ', ...')
				end
			end
		end
	end

	local function cdef_func(func, cname)
		local T = func:gettype()
		start_def()
		append(tdefs, cdef(T.returntype, false), ' ', cname, '(')
		cdef_args(T)
		add(tdefs, ');\n')
		end_def()
	end

	local function cdef_overload(over, cname)
		for i,func in ipairs(over.definitions) do
			cdef_func(func, cname[i])
		end
	end

	local function cdef_globalvar(glob, cname)
		local T = glob:gettype()
		assert(glob:isextern(), glob, ':isextern() is false')
		start_def()
		append(tdefs, cdef(T, false), ' ', cname, ';\n')
		end_def()
	end

	--recursive struct typedefs -----------------------------------------------

	local decl  = {} --{T->false|true}

	local function cdef_entries(tdefs, entries, indent)
		for i,e in ipairs(entries) do
			for i=1,indent do add(tdefs, '\t') end
			if #e > 0 and type(e[1]) == 'table' then --union
				add(tdefs, 'union {\n')
				cdef_entries(tdefs, e, indent + 1)
				for i=1,indent do add(tdefs, '\t') end
				add(tdefs, '};\n')
			else --struct or tuple
				local field = e.field or e[1]
				local type  = e.type  or e[2]
				append(tdefs, cdef(type, false), ' ', field, ';\n')
			end
		end
	end

	local function declare_struct(T, cname)
		start_def()
		append(tdefs, 'typedef struct ', cname, ' ', cname, ';\n')
		end_def()
	end

	local function define_struct(T, cname, nodef)
		local opaque = opaque[T]
		if opaque == nil then opaque = T.opaque end
		if opaque then
			assert(nodef ~= false, T, ' is opaque but its definition is needed')
			declare_struct(T, cname)
		else
			start_def()
			local entries = {}
			cdef_entries(entries, T.entries, 1)
			if decl[T] then --fw. declared: define it.
				append(tdefs, 'struct ', cname, ' {\n')
				extend(tdefs, entries)
				append(tdefs, '};\n')
			else --declare it as anonymous.
				append(tdefs, 'typedef struct {\n')
				extend(tdefs, entries)
				append(tdefs, '} ', cname, ';\n')
			end
			end_def()
		end
	end

	local function typedef_funcptr(T, cname)
		start_def()
		append(tdefs, 'typedef ', cdef(T.returntype, false), ' (*', cname, ') (')
		cdef_args(T)
		add(tdefs, ');\n')
		end_def()
	end

	local function typedef(T, cname, nodef) --fw. decl.
		local declared = decl[T]
		local defined = declared == 'defined'
		if defined or (declared and nodef) then return end
			local defining = declared == false
		if defining or nodef then
			if T:isstruct() then
				declare_struct(T, cname)
			elseif T:isfunction() then
				assert(not defining) --funcptr decls can't be cyclical.
				typedef_funcptr(T, cname)
			else
				assert(false)
			end
			decl[T] = true --mark as declared.
		else
			decl[T] = false --mark as "defining".
			assert(T:isstruct()) --only structs can be defined.
			define_struct(T, cname, nodef)
			decl[T] = 'defined' --mark as defined.
		end
	end

	function cdef(v, nodef) --(fw. declared)
		local cname = ctype(v)
		if type(v) == 'terrafunction' then
			cdef_func(v, cname)
		elseif type(v) == 'overloadedterrafunction' then
			cdef_overload(v, cname)
		elseif type(v) == 'terraglobalvariable' then
			cdef_globalvar(v, cname)
		else
			local T = v
			if T:ispointer() then
				cdef(T.type, true)
			elseif T:isarray() then
				cdef(T.type, false)
			elseif T:isstruct() and not T:isunit() then
				typedef(T, cname, nodef)
			elseif T:isfunction() then
				typedef(T, cname, true)
			end
		end
		return cname
	end

	--enums -------------------------------------------------------------------

	function cdef_enum(t, match, prefix)
		local function find(k, v, match)
			if type(k) == 'string' and type(v) == 'number' then
				if match then
					return k:sub(1, #match) == match
				else --by default, all all-uppercase keys match as enums
					return k:upper() == k
				end
			end
		end
		local enums = {}
		local function add_enums(match, prefix)
			local keys = {}
			for k,v in pairs(t) do
				if find(k, v, match) then
					add(keys, k)
				end
			end
			sort(keys)
			for i,k in ipairs(keys) do
				local v = tostring(t[k])
				if match then k = k:sub(#match + 1) end
				if prefix then k = prefix .. k end
				append(enums, '\t', k:upper(), ' = ', v, last and '\n' or ',\n')
			end
		end
		if type(match) == 'table' then --{match -> prefix}
			for match, prefix in pairs(match) do
				add_enums(match, prefix)
			end
		else
			add_enums(match, prefix)
		end
		if #enums > 0 then
			add(cdefs, 'enum {\n')
			extend(cdefs, enums)
			add(cdefs, '};\n')
		end
	end

	--user API ----------------------------------------------------------------

	local self = {}
	setmetatable(self, self)

	local function opt(v, cname, opaq)
		if cname then cnames[v] = cname end
		if opaque then opaque[v] = opaq end
	end
	function self:enum(...) cdef_enum(...) end
	function self:ctype(v, ...) opt(v, ...); return ctype(v) end
	function self:cdef(v, ...) opt(v, ...); return cdef(v) end
	function self:dump() return concat(cdefs) end
	function self:__call(arg, ...)
		if type(arg) == 'table' then
			return self:enum(arg, ...)
		elseif arg then
			return self:cdef(arg, ...)
		else
			return self:dump()
		end
	end

	return self
end

--shared lib builder ---------------------------------------------------------

function lib(modulename)

	local self = {}
	setmetatable(self, self)

	local cdefs = cdefs()

	local symbols = {} --{cname->func}; in saveobj() format.
	local objects = {} --{{obj=,cname=}|{obj=,cname=,methods|getters|setters={name->cname},...}

	local function add_symbols(func, cname, cprefix)
		if type(cname) == 'table' then --overloaded
			local t = {}
			for i,cname in ipairs(cname) do
				local cname = cprefix and cprefix .. cname or cname
				t[i] = cname
				symbols[cname] = func.definitions[i]
			end
			return t
		else
			local cname = cprefix and cprefix .. cname or cname
			symbols[cname] = func
			return cname
		end
	end

	local function cname_opt(opt) --'cname' | {'cname1',...} | {cname=}
		return type(opt) == 'string' and opt
			or type(opt) == 'table' and (opt.cname or #opt > 1 and opt)
	end

	local function publish_func(func, opt)
		local cname = cname_opt(opt)
		local cname = cdefs:cdef(func, cname)
		local cname = add_symbols(func, cname)
		add(objects, {obj = func, cname = cname})
	end

	local function method_is_private(func, name, opt)
		if type(func) == 'terramacro' then return true end
		local private = type(opt) == 'table' and opt.private
		if private == nil then private = func.private end
		if private ~= nil then return private end
		return name:find'^_' and true or false
	end

	local function publish_struct(T, opt)
		opt = opt or T
		local pub = opt.public_methods
		local met = opt.methods
		if pub then
			for method in sortedpairs(pub) do
				if not getmethod(T, method) then
					print('Warning: method missing '..tostring(T)..':'..method..'()')
				end
			end
		end
		local struct_cname = cdefs:cdef(T, opt.cname, opt.opaque)
		local cprefix = opt.cprefix or struct_cname .. '_'
		local st = {obj = T, cname = struct_cname,
			methods = {}, getters = {}, setters = {}}
		add(objects, st)
		cancall(T, '') --force getmethod() to add all the methods.
		for name, func in pairs(T.methods) do
			local pub = pub and pub[name]
			local met = met and met[name]
			if pub or not method_is_private(func, name, met) then
				local cname = cname_opt(pub) or cname_opt(met) or name
				local cname = add_symbols(func, cname, cprefix)
				local cname = cdefs:cdef(func, cname)
				if T.gettersandsetters then
					if name:starts'get_' and #func.type.parameters == 1 then
						st.getters[name:gsub('^get_', '')] = cname
					elseif name:starts'set_' and #func.type.parameters == 2 then
						st.setters[name:gsub('^set_', '')] = cname
					else
						st.methods[name] = cname
					end
				else
					st.methods[name] = cname
				end
			end
		end
	end

	function self:publish(v, ...)
		if type(v) == 'terrafunction' or type(v) == 'overloadedterrafunction' then
			publish_func(v, ...)
		elseif type(v) == 'terratype' and v:isstruct() then
			publish_struct(v, ...)
		elseif type(v) == 'table' then --enums
			cdefs:enum(v, ...) --match, prefix
		else
			assert(false, 'invalid arg type ', type(v))
		end
	end

	self.__call = self.publish

	function self:cdefs()
		return cdefs:dump()
	end

	function self:c_header()
		return [[
/* This file was auto-generated. Modify at your own risk. */

]] .. cdefs:dump()
	end

	--generating LuaJIT ffi binding -------------------------------------------

	function self:ffi_binding()
		local t = {}
		append(t, [=[
-- This file was auto-generated. Modify at your own risk.

local ffi = require'ffi'
local C = ffi.load']=], modulename, [=['
ffi.cdef[[
]=])
		add(t, cdefs:dump())
		add(t, ']]\n')

		local function defmap(rs)
			for name, cname in sortedpairs(rs) do
				if type(cname) == 'string' then --not overloaded
					append(t, '\t', name, ' = C.', cname, ',\n')
				end
			end
		end

		for i,o in ipairs(objects) do
			if next(o.getters or empty) or next(o.setters or empty) then
				add(t, 'local getters = {\n'); defmap(o.getters); add(t, '}\n')
				add(t, 'local setters = {\n'); defmap(o.setters); add(t, '}\n')
				add(t, 'local methods = {\n'); defmap(o.methods); add(t, '}\n')
				append(t, [[
ffi.metatype(']], o.cname, [[', {
	__index = function(self, k)
		local getter = getters[k]
		if getter then return getter(self) end
		return methods[k]
	end,
	__newindex = function(self, k, v)
		local setter = setters[k]
		if not setter then
			error(('field not found: %s'):format(tostring(k)), 2)
		end
		setter(self, v)
	end,
})
]])
			elseif next(o.methods or empty) then
				append(t, 'ffi.metatype(\'', o.cname, '\', {__index = {\n')
				defmap(o.methods)
				add(t, '}})\n')
			end
		end

		add(t, [=[

return C
]=])
		return concat(t)
	end

	--building ----------------------------------------------------------------

	function self:binpath(filename)
		return terralib.terrahome..(filename and '/'..filename or '')
	end

	function self:luapath(filename)
		return terralib.terrahome..'/../..'..(filename and '/'..filename or '')
	end

	function self:objfile()
		return self:binpath(modulename..'.o')
	end

	function self:sofile()
		local soext = {Windows = 'dll', OSX = 'dylib', Linux = 'so'}
		return self:binpath(modulename..'.'..soext[ffi.os])
	end

	function self:afile()
		return self:binpath(modulename..'.a')
	end

	function self:saveobj(optimize)
		zone'saveobj'
		terralib.saveobj(self:objfile(), 'object', symbols, nil, nil, optimize ~= false)
		zone()
	end

	function self:removeobj()
		os.remove(self:objfile())
	end

	function self:linkobj(linkto)
		zone'linkobj'
		local linkargs = linkto and '-l'..concat(linkto, ' -l') or ''
		local cmd = 'gcc '..self:objfile()..' -shared '..'-o '..self:sofile()
			..' -L'..self:binpath()..' '..linkargs
		os.execute(cmd)
		local cmd = 'ar rcs '..self:afile()..' '..self:objfile()
		os.execute(cmd)
		zone()
	end

	--TODO: make this work. Doesn't export symbols on Windows.
	function self:savelibrary(linkto)
		zone'savelibrary'
		local linkargs = linkto and '-l'..concat(linkto, ' -l') or ''
		terralib.saveobj(self:sofile(), 'sharedlibrary', symbols, linkargs)
		zone()
	end

	function self:build(opt)
		opt = opt or {}
		if true then
			self:saveobj(opt.optimize)
			self:linkobj(opt.linkto)
			self:removeobj()
		else
			self:savelibrary(opt.linkto)
		end
	end

	function self:gen_c_header(opt)
		zone'gen_c_header'
		if type(opt) == 'string' then opt = {filename = opt} end
		local filename = self:luapath(opt.filename or modulename .. '.h')
		writefile(filename, self:c_header(), nil, filename..'.tmp')
		zone()
	end

	function self:gen_ffi_binding(opt)
		zone'gen_ffi_binding'
		if type(opt) == 'string' then opt = {filename = opt} end
		local filename = self:luapath(opt.filename or modulename .. '_h.lua')
		writefile(filename, self:ffi_binding(), nil, filename..'.tmp')
		zone()
	end

	return self
end

return _M
