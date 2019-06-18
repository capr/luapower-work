--[[

	Raw string arrayview and dynarray type for Terra.

	TODO: make these overloads of the arrayview and dynarray constructors instead.

	var s = V(rawstring|'string constant')      cast from C string
	v:onrawstring(rawstring) -> &v              init with C string

	var a = A(rawstring|'string constant')      cast from C string
	a:fromrawstring(rawstring)                  init with C string

]]

setfenv(1, require'terra/low')

rawstringview = arrview(char)

newcast(rawstringview, rawstring, function(exp)
	return quote var v = [rawstringview.empty]; v:onrawstring(exp) in v end
end)

--declaring this this way to avoid triggering addmethods().
rawstringview.methods.onrawstring = terra(self: &rawstringview, s: rawstring)
	self.len = strnlen(s, [size_t:max()]-1)
	self.elements = s
	return self
end

local struct gsplit_iter{
	view: rawstringview;
	issep: {char} -> {bool};
}
function gsplit_iter.metamethods.__for(self, body)
	return quote
		var self = &self
		var i = 0
		var k = -1
		var len = self.view.len
		for j,c in self.view do
			if self.issep(@c) then
				if k == -1 then k = j end
			elseif k ~= -1 or j == len-1 then
				if k == -1 then k = len end
				[body(i, `k-i)]
				k = -1
				i = j
			end
		end
	end
end

local issep_func = memoize(function(s)
	assert(#s == 1)
	local b = s:byte(1)
	return terra(c: char) return c == [char]([uint8](b)) end
end)

rawstringview.methods.gsplit = macro(function(self, issep)
	if issep:isliteral() then issep = issep_func(issep:asvalue()) end
	return `gsplit_iter {view = self, issep = issep}
end)

------------------------------------------------------------------------------

rawstringarr = arr(char)

newcast(rawstringarr, rawstring, function(exp)
	return quote var a = [rawstringarr.empty]; a:fromrawstring(exp) in a end
end)

--declaring this this way to avoid triggering addmethods().
rawstringarr.methods.fromrawstring = terra(self: &rawstringarr, s: rawstring)
	var v = rawstringview(s)
	self.len = v.len
	v:copy(self.elements)
	return self
end

--self-test ------------------------------------------------------------------

if not ... then

terra test_gsplit()

	do
		var sv = rawstringview(['hello  world !!!'])
		var gs = sv:gsplit' '
		for i,len in gs do
			printf('"%.*s"\n', len, sv:at(i))
		end
	end

	do --empty string
		var sv = rawstringview(nil)
		var gs = sv:gsplit' '
		for i,len in gs do
			assert(false)
		end
	end
end
test_gsplit()

end

return _M
