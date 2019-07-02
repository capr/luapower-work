
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
	[C.TK_LABEL   ] = '::',
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

	local lx = {} --polymorphic lexer object

	local read, ls
	if type(arg) == 'string' then
		ls = C.lx_state_create_for_string(arg, #arg)
	elseif type(arg) == 'function' then
		read = ffi.cast('LX_Reader', arg)
		ls = C.lx_state_create(read, nil)
	else
		ls = C.lx_state_create_for_file(arg)
	end

	local function free()
		if read then read:free() end
		ls:free()
	end

	--lexer API ---------------------------------------------------------------

	local keywords = lua_keywords --reserved words in current scope

	local tk, v, ln, ps --current token type, value, line and cursor position.
	local tk1 --next token

	local function line()
		if ln == nil then
			ln, ps = ls:line(), ls:pos()
		end
		return ln, ps
	end

	--convert '<name>' tokens for reserved words to the actual keyword.
	--also, convert token codes to Lua strings.
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
			if tk == '<name>' or tk == '<string>' then
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
		val(); line() --save current state because ls:next() changes it.
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
		local line, pos = line()
		_G.error(string.format('%s:%d:%d: %s', filename or '@string', line, pos, msg), 0)
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

	local function expectmatch(tk1, openingtk, ln, ps)
		local tk = nextif(tk1)
		if not tk then
			if line() == ln then
				errorexpected(tostring(tk1))
			else
				error(string.format('%s expected (to close %s at %d:%d)',
					tostring(tk1), tostring(openingtk), ln, ps))
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

	local expr, expr_binop, block --fw. decl.

	--check for end of block.
	local function isend()
		return tk == 'else' or tk == 'elseif' or tk == 'end'
			or tk == 'until' or tk == '<eof>'
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
	local unary_priority = 9 -- priority for unary operators.

	local function params() --(name,...[,...])
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

	local function body(line, pos) --(params) block end
		params()
		block()
		if tk ~= 'end' then
			expectmatch('end', 'function', line, pos)
		end
		next()
	end

	local function name()
		expect'<name>'
	end

	local function expr_field() --.:name
		next()
		name()
	end

	local function expr_bracket() --[expr]
		next()
		expr()
		expect']'
	end

	local function expr_table() --{[expr]|name=expr,;...}
		local line, pos = line()
		expect'{'
		while tk ~= '}' do
			if tk == '[' then
				expr_bracket()
				expect'='
			elseif tk == '<name>' and lookahead() == '=' then
				name()
				expect'='
			end
			expr()
			if not nextif',' and not nextif';' then break end
		end
		expectmatch('}', '{', line, pos)
	end

	local function expr_list() --expr,...
		expr()
		while nextif',' do
			expr()
		end
	end

	local function args() --(expr,...)|{table}|string
		if tk == '(' then
			local line, pos = line()
			next()
			if tk == ')' then --f()
			else
				expr_list()
			end
			expectmatch(')', '(', line, pos)
		elseif tk == '{' then
			expr_table()
		elseif tk == '<string>' then
			next()
		else
			errorexpected'function arguments'
		end
	end

	local function expr_primary() --(expr)|name .name|[expr]|:nameargs|args ...
		local vcall
		--parse prefix expression.
		if tk == '(' then
			local line, pos = line()
			next()
			expr()
			expectmatch(')', '(', line, pos)
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
		return vcall
	end

	local function expr_simple() --literal|...|{table}|function(params) end|expr_primary
		if tk == '<number>' then
			next()
		elseif tk == '<imag>' then
			next()
		elseif tk == '<int>' then
			next()
		elseif tk == '<u32>' then
			next()
		elseif tk == '<i64>' then
			next()
		elseif tk == '<u64>' then
			next()
		elseif tk == '<string>' then
			next()
		elseif tk == 'nil' then
			next()
		elseif tk == 'true' then
			next()
		elseif tk == 'false' then
			next()
		elseif tk == '...' then --vararg
			next()
		elseif tk == '{' then --{table}
			expr_table()
		elseif tk == 'function' then --function body
			local line, pos = line()
			next()
			body(line, pos)
		else
			local lang = entrypoints.expression[tk]
			if lang then --entrypoint token for extension language.
				lang_expr(lang)
			else
				expr_primary()
			end
		end
	end

	local function expr_unop() --not|-|#|expr_simple...
		if tk == 'not' then
		elseif tk == '-' then
		elseif tk == '#' then
		else
			expr_simple()
			return
		end
		next()
		expr_binop(unary_priority)
	end

	--parse binary expressions with priority higher than the limit.
	function expr_binop(limit)
		expr_unop()
		local pri = priority[tk]
		while pri and pri[1] > limit do
			next()
			--parse binary expression with higher priority.
			op = expr_binop(pri[2])
			pri = priority[op]
		end
		return tk --return unconsumed binary operator (if any).
	end

	function expr() --parse expression.
		expr_binop(0) --priority 0: parse whole expression.
	end

	local function assignment() --expr_primary,... = expr,...
		if nextif',' then --collect LHS list and recurse upwards.
			expr_primary()
			assignment()
		else --parse RHS.
			expect('=')
			expr_list()
		end
	end

	local function call_assign() --funcall|assignment
		if expr_primary() then --funcall
		else --assignment
			assignment()
		end
	end

	local function for_num(line) -- = expr, expr [,expr] do block
		expect'='; expr(); expect','; expr()
		if nextif',' then expr() end
		expect'do'
		block()
	end

	local function for_iter() -- ,name... in expr,... do block
		while nextif',' do
			name()
		end
		expect'in'
		expr_list()
		expect'do'
		block()
	end

	local function label() --::name::
		next()
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
		if tk == 'if' then --if expr then block [elseif expr then block]... [else block] end
			local line, pos = line()
			next()
			expr()
			expect'then'
			block()
			while tk == 'elseif' do --elseif expr then block...
				next()
				expr()
				expect'then'
				block()
			end
			if tk == 'else' then --else block
				next()
				block()
			end
			expectmatch('end', 'if', line, pos)
		elseif tk == 'while' then --while expr do block end
			local line, pos = line()
			next()
			expr()
			expect'do'
			block()
			expectmatch('end', 'while', line, pos)
		elseif tk == 'do' then  --do block end
			local line, pos = line()
			next()
			block()
			expectmatch('end', 'do', line, pos)
		elseif tk == 'for' then
			--for name = expr, expr [,expr] do block end
			--for name,... in expr,... do block end
			local line, pos = line()
			next()
			name()
			if tk == '=' then -- = expr, expr [,expr]
				next()
				expr()
				expect','
				expr()
				if nextif',' then expr() end
			elseif tk == ',' or tk == 'in' then -- ,name... in expr,...
				while nextif',' do
					name()
				end
				expect'in'
				expr_list()
			else
				errorexpected'"=" or "in"'
			end
			expect'do'
			block()
			expectmatch('end', 'for', line, pos)
		elseif tk == 'repeat' then --repeat block until expr
			local line, pos = line()
			next()
			block(false)
			expectmatch('until', 'repeat', line, pos)
			expr() --parse condition (still inside inner scope).
			exit_scope()
		elseif tk == 'function' then --function name[.name...][:name] body
			local line, pos = line()
			next()
			name()
			while tk == '.' do --.name...
				expr_field()
			end
			if tk == ':' then --:name
				expr_field()
			end
			body(line, pos)
		elseif tk == 'local' then
			--local function name body
			--local name,...[=expr,...]
			local line, pos = line()
			next()
			if nextif'function' then
				name()
				body(line, pos)
			else
				repeat --name,...
					name()
				until not nextif','
				if nextif'=' then -- =expr,...
					expr_list()
				end
			end
		elseif tk == 'return' then --return [expr,...]
			next()
			if not (isend() or tk == ';') then
				expr_list()
			end
			return true --must be last
		elseif tk == 'break' then
			next()
			return --must be last in Lua 5.1
		elseif tk == ';' then
			next()
		elseif tk == '::' then
			label()
		elseif tk == 'goto' then --goto name
			next()
			name()
		elseif tk == 'import' then --import 'lang_name'
			next()
			if tk == '<string>' then
				import(val())
				next()
			else
				error'string expected'
			end
		else
			local lang = entrypoints.statement[tk]
			if lang then --entrypoint token for extension language.
				lang_stmt(lang)
			else
				call_assign()
			end
		end
		return false
	end

	function block(do_exit_scope) --stmt[;]...
		enter_scope()
		local islast
		while not islast and not isend() do
			islast = stmt()
			nextif';'
		end
		if do_exit_scope ~= false then
			exit_scope()
		end
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
