local oo = require'oo'
local clock = require'time'.clock

--inheritance
local c1 = oo.class()
c1.classname = 'c1'
c1.a = 1
c1.b = 1
local c2 = oo.class(c1)
c2.classname = 'c2'
c2.b = 2
c2.c = 2
assert(c2.super == c1)
assert(c2.unknown == nil)
assert(c2.a == 1)
assert(c2.b == 2)
assert(c2.c == 2)
assert(c2.init == c1.init)

--polymorphism
function c1:before_init(...)
	print('c1 before_init',...)
	self.b = ...
	assert(self.b == 'o')
	return self.b
end
function c1:after_init() print('c1 after_init') end
function c2:before_init(...) print('c2 before_init',...); return ... end
function c2:after_init() print('c2 after_init') end
function c2:override_init(inherited, ...)
	print('c2 overriden init', ...)
	return inherited(self, ...)
end
assert(c2.init ~= c1.init)
local o = c2('o')
assert(o.a == 1)
assert(o.b == 'o')
assert(o.c == 2)
assert(o.super == c2)
assert(o.unknown == nil)

assert(o:is'c1')
assert(o:is'c2')
assert(o:is(o))
assert(c2:is(c1))
assert(c1:is(c1))
assert(c1:is'c1')
assert(o:is'o' == false)
assert(oo.Object:is(oo.Object))

local o2 = c1('o')
assert(oo.closest_ancestor(c1, c2) == c1) --subject is target's super
assert(oo.closest_ancestor(o, o2) == c1) --target's super
assert(oo.closest_ancestor(o2, o) == c1) --subject's super
assert(oo.closest_ancestor(c1, c2) == c1) --subject
assert(oo.closest_ancestor(o2, c1) == c1) --target
assert(oo.closest_ancestor(o2, oo.Object) == oo.Object) --subject's super, root
assert(oo.closest_ancestor(oo.Object, oo.Object) == oo.Object) --root

--arg passing through hooks
local t = {}
function c1:test_args(x, y) t[#t+1] = 'test'; assert(x + y == 5) end
function c2:before_test_args(x, y) t[#t+1] = 'before'; assert(x + y == 5) end
function c2:after_test_args(x, y) t[#t+1] = 'after'; return x + y end
function c2:override_test_args(inherited, x, y)
	t[#t+1] = 'override1'
	assert(inherited(self, x, y) == x + y)
	t[#t+1] = 'override2'
	return x + y + 1
end
assert(o:test_args(2, 3) == 2 + 3 + 1)
assert(#t == 5)
assert(t[1] == 'override1')
assert(t[2] == 'before')
assert(t[3] == 'test')
assert(t[4] == 'after')
assert(t[5] == 'override2')

--virtual properties
local getter_called, setter_called
function c2:get_x() getter_called = true; return self.__x end
function c2:set_x(x) setter_called = true; self.__x = x end
o.x = 42
assert(setter_called)
assert(o.x == 42)
assert(getter_called)

--stored properties
--function o:set_s(s) print('set_s', s) assert(s == 13) end
--o.s = 13
--assert(o.s == 13)

--virtual properties and inheritance
local getter_called, setter_called
function c1:get_c1x() getter_called = true; return self.__c1x end
function c1:set_c1x(x) setter_called = true; self.__c1x = x end
o.c1x = 43
assert(setter_called)
assert(o.c1x == 43)
assert(getter_called)
assert(o.__c1x == 43)

--registering
local MyClass = oo.MyClass()
assert(MyClass == oo.MyClass)
assert(MyClass.classname == 'MyClass')
local MySubClass = oo.MySubClass'MyClass'
assert(MySubClass == oo.MySubClass)
assert(MySubClass.classname == 'MySubClass')
assert(MySubClass.super == MyClass)

--inspect
print'-------------- (before collapsing) -----------------'
o:inspect()

--detach
o:detach()
assert(rawget(o, 'a') == 1)
assert(rawget(o, 'b') == 'o')
assert(rawget(o, 'c') == 2)

--inherit, not overriding
local c3 = oo.class()
c3.c = 3
o:inherit(c3)
assert(o.c == 2)

--inherit, overriding
o:inherit(c3, true)
assert(o.c == 3)

print'--------------- (after collapsing) -----------------'
o:inspect()

do
print'-------------- (all reserved fields) ---------------'
local c = oo.TestClass()
local o = c()
function c:set_x() end
o:inspect(true)
end

--performance
print'------------------ (performance) -------------------'

local chapter
local results_t = {}

local function perf_tests(title, inherit_depth, iter_count, detach)

	local function perf_test(sub_title, test_func)
		local root = oo.class()
		local super = root
		for i=1,inherit_depth do --inheritance depth
			super = oo.class(super)
		end
		local o = super()

		local rw
		function root:get_rw() return rw end
		function root:set_rw(v) rw = v end
		local ro = 'ro'
		function root:get_ro(v) return ro end
		function root:set_wo(v) end
		function root:method(i) end
		o.rw = 'rw'
		assert(rw == 'rw')
		o.own = 'own'
		o.wo = 'wo'

		if detach == 'copy_gp' then
			o.__getters = o.__getters
			o.__setters = o.__setters
		elseif detach then
			o:detach()
		end

		local t0 = clock()
		test_func(o, iter_count)
		local t1 = clock()

		local speed = iter_count / (t1 - t0) / 10^6

		local title = chapter..title
		results_t[sub_title] = results_t[sub_title] or {}
		results_t[sub_title][title] = speed
		local title = title..sub_title
		print(string.format('%-20s: %10.1f mil iter', title, speed))
	end

	perf_test('method', function(o, n)
		for i=1,n do
			o:method(i)
		end
	end)
	perf_test('rw/r', function(o, n)
		for i=1,n do
			assert(o.rw == 'rw')
		end
	end)
	perf_test('rw/w', function(o, n)
		for i=1,n do
			o.rw = i
		end
	end)
	perf_test('rw/r+w', function(o, n)
		for i=1,n do
			o.rw = i
			assert(o.rw == i)
		end
	end)
	perf_test('ro/r', function(o, n)
		for i=1,n do
			assert(o.ro == 'ro')
		end
	end)
	perf_test('wo/w', function(o, n)
		for i=1,n do
			o.wo = i
		end
	end)

	do return end --instance fields are fast in all cases

	perf_test('own/r', function(o, n)
		for i=1,n do
			assert(o.own == 'own')
		end
	end)
	perf_test('own/w', function(o, n)
		for i=1,n do
			o.own = i
		end
	end)
	perf_test('own/r+w', function(o, n)
		for i=1,n do
			o.own = i
			assert(o.own == i)
		end
	end)
end

local function run_tests(mag)
	perf_tests('0_d',   0, 10^6 * mag, true)
	perf_tests('0+1_p', 0, 10^6 * mag, 'copy_gp')
	perf_tests('0+1',   0, 10^6 * mag, false)
	perf_tests('2+1',   2, 10^5 * mag, false)
	perf_tests('6+1',   6, 10^5 * mag, false)
	perf_tests('6+1_p', 6, 10^5 * mag, 'copy_gp')
end

chapter = 'J_'
run_tests(4)

chapter = 'I_'
jit.off(true, true)
run_tests(0.5)

local function sortedpairs(t, cmp)
	local kt={}
	for k in pairs(t) do
		kt[#kt+1]=k
	end
	table.sort(kt)
	local i = 0
	return function()
		i = i + 1
		return kt[i], t[kt[i]]
	end
end

print()
for chapter, speeds in sortedpairs(results_t) do
	local t = {}
	for title, speed in sortedpairs(speeds) do
		t[#t+1] = string.format('%8s', title)
	end
	print(string.format('%-7s: %s', 'TEST', table.concat(t)))
	break
end
for chapter, speeds in sortedpairs(results_t) do
	local t = {}
	for title, speed in sortedpairs(speeds) do
		t[#t+1] = string.format('%8.1f', speed)
	end
	print(string.format('%-7s: %s', chapter, table.concat(t)))
end

print()
print'LEGEND:'
print'I      : interpreter mode'
print'J      : JIT mode'
print'0_d    : called detach() on instance'
print'N+1    : N+1-level deep dynamic inheritance'
print'_p     : copied __getters and __setters to instance'
