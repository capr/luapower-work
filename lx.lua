
--lx ffi binding.
--Written by Cosmin Apreutesei. Public Domain.

if not ... then require'lx_test'; return end

local ffi = require'ffi'
local C = ffi.load'lx'
local M = {C = C}
local push, pop = table.insert, table.remove

local function inherit(t)
	local dt = {}; for k,v in pairs(t) do dt[k] = v end
	return setmetatable(dt, {parent = t})
end

local function getparent(t)
	return getmetatable(t).parent
end


--number parsing options
M.STRSCAN_OPT_TOINT = 0x01
M.STRSCAN_OPT_TONUM = 0x02
M.STRSCAN_OPT_IMAG  = 0x04
M.STRSCAN_OPT_LL    = 0x08
M.STRSCAN_OPT_C     = 0x10

ffi.cdef[[
/* Token types. */
enum {
	TK_EOF = -100, TK_ERROR,
	TK_NUM, TK_IMAG, TK_INT, TK_U32, TK_I64, TK_U64, /* number types */
	TK_NAME, TK_STRING, TK_LABEL,
	TK_EQ, TK_LE, TK_GE, TK_NE, TK_DOTS, TK_CONCAT,
	TK_FUNC_PTR, TK_LSHIFT, TK_RSHIFT,
};

/* Error codes. */
enum {
	LX_ERR_NONE    ,
	LX_ERR_XLINES  , /* chunk has too many lines */
	LX_ERR_XNUMBER , /* malformed number */
	LX_ERR_XLCOM   , /* unfinished long comment */
	LX_ERR_XLSTR   , /* unfinished long string */
	LX_ERR_XSTR    , /* unfinished string */
	LX_ERR_XESC    , /* invalid escape sequence */
	LX_ERR_XLDELIM , /* invalid long string delimiter */
};

typedef int LX_Token;
typedef struct LX_State LX_State;

typedef const char* (*LX_Reader)  (void*, size_t*);

LX_State* lx_state_create            (LX_Reader, void*);
LX_State* lx_state_create_for_file   (struct FILE*);
LX_State* lx_state_create_for_string (const char*, size_t);
void      lx_state_free              (LX_State*);

LX_Token lx_next          (LX_State*);
char*    lx_string_value  (LX_State*, int*);
double   lx_double_value  (LX_State*);
int32_t  lx_int32_value   (LX_State*);
uint64_t lx_uint64_value  (LX_State*);
int      lx_error         (LX_State *ls);
int      lx_line          (LX_State *ls);
int      lx_pos           (LX_State *ls);

void lx_set_strscan_opt   (LX_State*, int);
]]

local intbuf = ffi.new'int[1]'
local function to_str(ls)
	local s = C.lx_string_value(ls, intbuf)
	return ffi.string(s, intbuf[0])
end

local msg = {
	[C.LX_ERR_XLINES ] = 'chunk has too many lines';
	[C.LX_ERR_XNUMBER] = 'malformed number';
	[C.LX_ERR_XLCOM  ] = 'unfinished long comment';
	[C.LX_ERR_XLSTR  ] = 'unfinished long string';
	[C.LX_ERR_XSTR   ] = 'unfinished string';
	[C.LX_ERR_XESC   ] = 'invalid escape sequence';
	[C.LX_ERR_XLDELIM] = 'invalid long string delimiter';
}
local function errmsg(ls)
	return msg[ls:error()]
end

ffi.metatype('LX_State', {__index = {
	free     = C.lx_state_free;
	next     = C.lx_next;
	string   = to_str;
	num      = C.lx_double_value;
	int      = C.lx_int32_value;
	u64      = C.lx_uint64_value;
	error    = C.lx_error;
	errmsg   = errmsg;
	line     = C.lx_line;
	pos      = C.lx_pos;
}})

--lexer API inspired by Terra's lexer for extension languages.

local lua_keywords = {}
for i,k in ipairs{
	'and', 'break', 'do', 'else', 'elseif',
	'end', 'false', 'for', 'function', 'goto', 'if',
	'in', 'local', 'nil', 'not', 'or', 'repeat',
	'return', 'then', 'true', 'until', 'while',
	'import', --extension
} do
	lua_keywords[k] = true
end

local token_names = {
	[C.TK_STRING  ] = '<string>',
	[C.TK_LABEL   ] = '::', --extension
	[C.TK_NUM     ] = '<number>',
	[C.TK_IMAG    ] = '<imag>',
	[C.TK_INT     ] = '<int>',
	[C.TK_U32     ] = '<u32>',
	[C.TK_I64     ] = '<i64>',
	[C.TK_U64     ] = '<u64>',
	[C.TK_EQ      ] = '==',
	[C.TK_LE      ] = '<=',
	[C.TK_GE      ] = '>=',
	[C.TK_NE      ] = '~=',
	[C.TK_DOTS    ] = '...',
	[C.TK_CONCAT  ] = '..',
	[C.TK_FUNC_PTR] = '->', --extension
	[C.TK_LSHIFT  ] = '<<', --extension
	[C.TK_RSHIFT  ] = '>>', --extension
	[C.TK_EOF     ] = '<eof>',
}

function M.lexer(arg, filename)

	local lx = {} --lexer polymorphic object

	local s, read, file, ls
	if type(arg) == 'string' then
		s = arg
		ls = C.lx_state_create_for_string(arg, #arg)
	elseif type(arg) == 'function' then
		read = ffi.cast('LX_Reader', arg)
		ls = C.lx_state_create(read, nil)
	else
		file = arg
		ls = C.lx_state_create_for_file(arg)
	end

	local function free()
		if read then read:free() end
		ls:free()
	end

	--lexer API ---------------------------------------------------------------

	local keywords = lua_keywords --reserved words in current scope

	local tk, v, ln, ps --current token type, value and line:pos
	local tk1 --next token

	local function line()
		if ln == nil then ln = ls:line() end; return ln
	end
	local function pos()
		if ps == nil then ps = ls:pos() end; return ps
	end

	--convert all token codes to Lua strings.
	--this makes lexing 2x slower but simplifies the parsing API.
	local function token(tk)
		if tk >= 0 then
			return string.char(tk)
		elseif tk == C.TK_NAME then
			v = ls:string()
			return keywords[v] and v or '<name>'
		else
			return token_names[tk] or tk
		end
	end

	local function val() --get the parsed value of literal tokens.
		if v == nil then
			if tk == '<name>' or tk == '<string>' or tk == '::' then
				v = ls:string()
			elseif tk == '<number>' then
				v = ls:num()
			elseif tk == '<imag>' then
				error'NYI'
			elseif tk == '<int>' then
				v = ls:int()
			elseif tk == '<u64>' then
				v = ls:u64()
			else
				v = true
			end
		end
		return v
	end

	local ntk = 0

	local function next()
		if tk1 ~= nil then
			tk, tk1 = tk1, nil
		else
			tk = ls:next()
			tk = token(tk)
		end
		v, ln, ps = nil
		ntk = ntk + 1
		return tk
	end

	local function lookahead()
		assert(tk1 == nil)
		val(); line(); pos() --save current state because ls:next() changes it.
		tk1 = ls:next()
		local tk0 = tk
		tk = tk1
		tk1 = token(tk1)
		tk = tk0
		return tk1
	end

	local function cur() return tk end

	local function nextif(tk1)
		if tk == tk1 then
			return next()
		else
			return false
		end
	end

	function lx:error(msg) --stub
		_G.error(string.format('%s:%d:%d: %s', filename or '@string', line(), pos(), msg), 0)
	end

	local function error(msg)
		lx:error(msg)
	end

	local function errorexpected(what)
		error(what..' expected')
	end

	local function expect(tk1)
		local tk = nextif(tk1)
		if not tk then
			errorexpected(tk1)
		end
		return tk
	end

	local function expectmatch(tk1, openingtk, ln)
		local tk = nextif(tk1)
		if not tk then
			if line() == ln then
				errorexpected(tostring(tk1))
			else
				error(string.format('%s expected (to close %s at line %d)',
					tostring(tk1), tostring(openingtk), ln))
			end
		end
		return tk
	end

	--language extension API --------------------------------------------------

	local scope_level = 0
	local lang_stack = {} --{lang1,...}
	local imported = {} --{lang_name->true}
	local entrypoints = {statement = {}, expression = {}} --{token->lang}

	local function push_entrypoints(lang, kind)
		entrypoints[kind] = inherit(entrypoints[kind])
		local tokens = lang.entrypoints[kind]
		if tokens then
			for i,tk in ipairs(tokens) do
				entrypoints[kind][tk] = lang
			end
		end
	end

	local function pop_entrypoints(kind)
		entrypoints[kind] = getparent(entrypoints[kind])
	end

	function lx:import(lang) --stub
		return require(lang)
	end

	local function import(lang_name)
		if imported[lang_name] then return end --already in scope
		local lang = assert(lx:import(lang_name))
		push(lang_stack, lang)
		imported[lang_name] = true
		lang.scope_level = scope_level
		lang.name = lang_name
		push_entrypoints(lang, 'statement')
		push_entrypoints(lang, 'expression')
		keywords = inherit(keywords)
		if lang.keywords then
			for i,k in ipairs(lang.keywords) do
				keywords[k] = true
			end
		end
	end

	local function ref(name)
		--
	end

	local function luaexpr()
		return function(env)
			--
		end
	end

	local function enter_scope()
		scope_level = scope_level + 1
	end

	local function exit_scope()
		for i = #lang_stack, 1, -1 do
			local lang = lang_stack[i]
			if lang.scope_level == scope_level then
				lang_stack[i] = nil
				imported[lang.name] = false
				lang.scope_level = false
				pop_entrypoints'statement'
				pop_entrypoints'expression'
				keywords = getparent(keywords)
			else
				assert(lang.scope_level < scope_level)
				break
			end
		end
		scope_level	= scope_level - 1
	end

	local function lang_expr(lang)
		lang:expression(lx)
	end

	local function lang_stmt(lang)
		lang:statement(lx)
	end

	--Lua parser --------------------------------------------------------------

	local indent = 0
	local function D(s,...)
		print(string.format('%-14s %-14s %s %s', tk, val(), ('  '):rep(indent), s), ...)
	end
	local function D1(...)
		D(...)
		indent = indent + 1
	end
	local function D0()
		indent = indent - 1
	end

	local noop = function() end
	local D, D0, D1 = noop, noop, noop

	local expr, expr_binop, block --fw. decl.

	--check for end of block.
	local function isend()
		if tk == 'else' or tk == 'elseif' or tk == 'end'
			or tk == 'until' or tk == '<eof>'
		then
			exit_scope()
			return true
		else
			return false
		end
	end

	local priority = {
		['^'  ] = {11,10},
		['*'  ] = {8,8},
		['/'  ] = {8,8},
		['%'  ] = {8,8},
		['+'  ] = {7,7},
		['-'  ] = {7,7},
		['..' ] = {6,5},
		['<<' ] = {4,4},
		['>>' ] = {4,4},
		['==' ] = {3,3},
		['~=' ] = {3,3},
		['<'  ] = {3,3},
		['<=' ] = {3,3},
		['>'  ] = {3,3},
		['>=' ] = {3,3},
		['->' ] = {3,2},
		['and'] = {2,2},
		['or' ] = {1,1},
	}
	local UNARY_PRIORITY = 9 -- priority for unary operators.

	local function params() --parse function parameters.
		expect'('
		if tk ~= ')' then
			repeat
				if tk == '<name>' then
					next()
				elseif tk == '...' then
					next()
					break
				else
					errorexpected'<name> or "..."'
				end
			until not nextif','
		end
		expect')'
	end

	local function body(line) --parse body of a function.
		params()
		block()
		if tk ~= 'end' then
			expectmatch('end', 'function', line)
		end
		next()
	end

	local function name()
		--D1(val())
		nextif'<name>'
		--D0()
	end

	local function expr_field()
		next() --skip dot or colon
		name()
	end

	local function expr_bracket() --parse index expression with brackets.
		next() --skip '['
		expr()
		expect']'
	end

	local function expr_table() --parse table constructor expression.
		local line = line()
		expect('{')
		while tk ~= '}' do
			if tk == '[' then
				expr_bracket() --already calls expr_toval.
				expect('=')
			elseif tk == '<name>' and lookahead() == '=' then
				name()
				expect('=')
			end
			expr()
			if not nextif',' and not nextif';' then break end
		end
		expectmatch('}', '{', line)
	end

	local function expr_list() --parse expression list; last expression left open.
		--D1'expr_list'
		expr()
		while nextif',' do
			expr()
		end
		--D0()
	end

	local function args() --farse function argument list.
		local line = line()
		if tk == '(' then
			next()
			if tk == ')' then --f()
			else
				expr_list()
			end
			expectmatch(')', '(', line)
		elseif tk == '{' then
			expr_table()
		elseif tk == '<string>' then
			next()
		else
			errorexpected'function arguments'
		end
	end

	local function expr_bracket() --parse index expression with brackets.
		next() --skip '['.
		expr()
		expect(']')
	end

	local function expr_primary() --parse primary expression.
		--D1'expr_primary'
		local vcall
		--parse prefix expression.
		if tk == '(' then
			local line = line()
			next()
			expr()
			expectmatch(')', '(', line)
		elseif tk == '<name>' then
			next()
		else
			error'unexpected symbol'
		end
		while true do --parse multiple expression suffixes.
			if tk == '.' then
				expr_field()
				vcall = false
			elseif tk == '[' then
				expr_bracket()
				vcall = false
			elseif tk == ':' then
				next()
				name()
				args()
				vcall = true
			elseif tk == '(' or tk == '<string>' or tk == '{' then
				args()
				vcall = true
			else
				break
			end
		end
		--D0()
		return vcall
	end

	local function expr_simple() --parse simple expression.
		if tk == '<number>' then
		elseif tk == '<imag>' then
		elseif tk == '<int>' then
		elseif tk == '<u32>' then
		elseif tk == '<i64>' then
		elseif tk == '<u64>' then
		elseif tk == '<string>' then
		elseif tk == 'nil' then
		elseif tk == 'true' then
		elseif tk == 'false' then
		elseif tk == '...' then --vararg
		elseif tk == '{' then --table constructor
			expr_table()
			return
		elseif tk == 'function' then
			next()
			body(line())
			return
		else
			expr_primary()
			return
		end
		next()
	end

	local function expr_unop()
		--D1('expr_unop', tk)
		if tk == 'not' then
		elseif tk == '-' then
		elseif tk == '#' then
		elseif tk == '&' then
		else
			expr_simple()
			--D0()
			return
		end
		next()
		expr_binop(UNARY_PRIORITY)
		--D0()
	end

	--parse binary expressions with priority higher than the limit.
	function expr_binop(limit)
		--D1('expr_binop', limit)
		expr_unop()
		local pri = priority[tk]
		while pri and pri[1] > limit do
			next()
			--parse binary expression with higher priority.
			op = expr_binop(pri[2])
			pri = priority[op]
		end
		--D0()
		return tk --return unconsumed binary operator (if any).
	end

	function expr() --parse expression.
		local lang = entrypoints.expression[tk]
		if lang then
			lang_expr(lang)
		else
			expr_binop(0) --priority 0: parse whole expression.
		end
	end

	local expr_cond = expr --parse conditional expression.

	local function then_() --parse condition and 'then' block.
		next() --skip 'if' or 'elseif'.
		expr_cond()
		expect'then'
		block()
	end

	local function if_(line) --parse 'if' statement.
		--D1'if'
		then_()
		while tk == 'elseif' do --parse multiple 'elseif' blocks.
			then_()
		end
		if tk == 'else' then --parse optional 'else' block.
			next() --skip 'else'.
			block()
		end
		expectmatch('end', 'if', line)
		--D0()
	end

	local function while_(line)
		next() --skip 'while'.
		expr_cond()
		expect'do'
		block()
		expectmatch('end', 'while', line)
	end

	local function assignment() --recursively parse assignment statement.
		--D1'assignment'
		if nextif',' then --collect LHS list and recurse upwards.
			expr_primary()
			assignment()
		else --parse RHS.
			expect('=')
			expr_list()
		end
		--D0()
	end

	local function call_assign() --parse call statement or assignment.
		if expr_primary() then --function call statement.
		else --start of an assignment.
			assignment()
		end
	end

	local function return_() --parse 'return' statement.
		--D1'return'
		next() --skip 'return'.
		if isend() or tk == ';' then --bare return.
		else --return with one or more values.
			expr_list()
		end
		--D0()
	end

	local function local_() --parse 'local' statement.
		if nextif'function' then --local function declaration.
			name()
			body(line())
		else --local variable declaration.
			repeat -- collect LHS.
				name()
			until not nextif','
		end
		if nextif'=' then --optional RHS.
			expr_list()
		else --or implicitly set to nil.
		end
	end

	local function func(line) --parse 'function' statement.
		--D1'func'
		next() --skip 'function'
		name() --parse function name
		while tk == '.' do --multiple dot-separated fields.
			expr_field()
		end
		if tk == ':' then --optional colon to signify method call.
			expr_field()
		end
		body(line)
		--D0()
	end

	local function for_num(line) --parse numeric 'for'.
		expect'='; expr()
		expect','; expr()
		if nextif',' then expr() end
		expect'do'
		block()
	end

	local function for_iter() --parse 'for' iterator.
		while nextif',' do
			name()
		end
		expect'in'
		expr_list()
		expect'do'
		block()
	end

	local function for_(line) --parse 'for' statement.
		next() --skip 'for'.
		name() --get first variable name.
		if tk == '=' then
			for_num(line)
		elseif tk == ',' or tk == 'in' then
			for_iter()
		else
			errorexpected'"=" or "in"'
		end
		expectmatch('end', 'for', line)
	end

	local function repeat_(line) --parse 'repeat' statement.
		next() --skip 'repeat'.
		block()
		expectmatch('until', 'repeat', line)
		expr_cond() --parse condition (still inside inner scope).
	end

	local function label()
		next() --skip '::'.
		name()
		expect'::'
		--recursively parse trailing statements: labels and ';' (Lua 5.2 only).
		while true do
			if tk == '::' then
				label()
			elseif tk == ';' then
				next()
			else
				break
			end
		end
	end

	--parse a statement. returns true if it must be the last one in a chunk.
	local function stmt()
		--D1'stmt'
		local line = line()
		if tk == 'if' then
			if_(line)
		elseif tk == 'while' then
			while_(line)
		elseif tk == 'do' then
			next()
			block()
			expectmatch('end', 'do', line)
		elseif tk == 'for' then
			for_(line)
		elseif tk == 'repeat' then
			repeat_(line)
		elseif tk == 'function' then
			func(line)
		elseif tk == 'local' then
			next()
			local_()
		elseif tk == 'return' then
			return_()
			--D0()
			return true --must be last
		elseif tk == 'break' then
			next()
			--D0()
			return --must be last in Lua 5.1
		elseif tk == ';' then
			next()
		elseif tk == '::' then
			label()
		elseif tk == 'goto' then
			next() --skip 'goto'
			name()
		elseif tk == 'import' then --extension
			next() --skip 'import'
			if tk == '<string>' then
				import(val())
				next() --skip string
			else
				error'string expected'
			end
		else
			local lang = entrypoints.statement[tk]
			if lang then
				lang_stmt(lang)
			else
				call_assign()
			end
		end
		--D0()
		return false
	end

	function block()
		enter_scope()
		--D1'block'
		local islast
		while not islast and not isend() do
			islast = stmt()
			nextif';'
		end
		--D0()
	end

	local function luastats()
		next()
		block()
	end

	lx.free = free
	lx.errorexpected = errorexpected
	--lexer API
	lx.cur = cur
	lx.val = val
	lx.line = line
	lx.next = next
	lx.nextif = nextif
	lx.lookahead = lookahead
	lx.expect = expect
	lx.expectmatch = expectmatch
	--language extension API
	lx.ref = ref
	lx.luaexpr = luaexpr
	lx.luastats = luastats
	--debugging
	lx.token_count = function() return ntk end


	return lx
end

return M
