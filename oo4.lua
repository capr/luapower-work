
local Object = {classname = 'Object'}

function Object:__index(k)
	local getters = rawget(self, '__getters')
	local get = getters and getters[k]
	if get then return get(self) end
	local super = rawget(self, 'super')
	local v = super and super[k]
	if v ~= nil then return v end
	if type(k) == 'string' then
		local methods = rawget(self, '__prefix_getters')
		if methods then
			local prefix, k = k:match'^([^_]+)_(.*)'
			local method = methods[prefix]
			if method then
				return method(self, k)
			end
		end
	end
	local get = rawget(self, 'get')
	if get then return get(self, k) end
end

function Object:__newindex(k, v)
	local setters = rawget(self, '__setters')
	local set = setters and setters[k]
	if set then set(self, v); return end
	if type(k) == 'string' then
		local methods = rawget(self, '__prefix_setters')
		if methods then
			local prefix, k = k:match'^([^_]+)_(.*)'
			local method = methods[prefix]
			if method then
				method(self, k, v)
				return
			end
		end
	end
	local set = rawget(self, 'set')
	if set then
		set(self, k, v)
		return
	end
	rawset(self, k, v)
end

Object.__getters = {}
Object.__setters = {}
Object.__prefix_setters = {}
Object.__instance_getters = {}
Object.__instance_setters = {}

Object.__class = {}
Object.__class.__prefix_getters = {}
Object.__class.__prefix_setters = {} --all C.class_<prefix> = v
Object.__class.__newindex = Object.__newindex

Object.__instance = {}
Object.__instance.__prefix_getters = {}
Object.__instance.__prefix_setters = {}
Object.__instance.__newindex = Object.__newindex

Object.super = Object.__class

Object.__class.class = Object
Object.__instance.class = Object

setmetatable(Object, Object)
setmetatable(Object.__class   , Object.__class)
setmetatable(Object.__instance, Object.__instance)

--when the table self[k] needs to inherit from self.super[k], it is initially
--directly assigned to self.super[k] instead of inheriting from it; proper
--inheritance chain is only set later when needed by calling split().
--TODO: this means no patching of classes after subclassing or instantiating.
local function split(self, k)
	local t = rawget(self, k)
	if not t then
		t = {}
		rawset(self, k, t)
	elseif self.super and t == self.super[k] then
		local super_t = split(self.super, k)
		t = {__index = super_t}
		setmetatable(t, t)
		rawset(self, k, t)
	end
	return t
end

local function prefixset(self, k, v)
	split(self, '__prefix_setters')[k] = v
end
Object           .__prefix_setters.prefixset = prefixset --C.prefix_<prefix> = f
Object.__class   .__prefix_setters.prefixset = prefixset --C.class_prefix_<prefix> = f
Object.__instance.__prefix_setters.prefixset = prefixset --C.prefix_<prefix> = f

local function prefixget(self, k, v)
	split(self, '__prefix_getters')[k] = v
end
Object           .__prefix_setters.prefixget = prefixget --C.prefix_<prefix> = f
Object.__class   .__prefix_setters.prefixget = prefixget --C.class_prefix_<prefix> = f
Object.__instance.__prefix_setters.prefixget = prefixget --C.prefix_<prefix> = f

function Object.__instance:prefixset_get(k, v) --C.get_<field> = f
	split(self.class, '__instance_getters')[k] = v
end

function Object.__instance:prefixget_get(k) --C.get_<field>
	return self.class.__instance_getters[k]
end

function Object.__instance:prefixset_set(k, v) --C.set_<field> = f
	split(self.class, '__instance_setters')[k] = v
end

function Object.__instance:prefixget_set(k) --C.set_<field>
	return self.class.__instance_setters[k]
end

function Object.__class:prefixset_get(k, v) --C.class_get_<field> = f
	split(self.class, '__getters')[k] = v
end

function Object.__class:prefixset_set(k, v) --C.class_set_<field> = f
	split(self.class, '__setters')[k] = v
end

local function before(self, method_name, hook)
	local method = self[method_name]
	self[method_name] = method and function(self, ...)
		hook(self, ...)
		return method(self, ...)
	end or hook
end
Object.__instance.          before = before --C:before(method, f)
Object.__instance.prefixset_before = before --C.before_<method> = f
Object.__class.             before = before --C:class_before(class_method, f)
Object.__class.   prefixset_before = before --C.class_before_<class_method> = f

local function after(self, method_name, hook)
	local method = self[method_name]
	self[method_name] = method and function(self, ...)
		method(self, ...)
		return hook(self, ...)
	end or hook
end
Object.__instance.          after = after --C:after(method, f)
Object.__instance.prefixset_after = after --C.after_<method> = f
Object.__class.             after = after --C:class_after(class_method, f)
Object.__class.   prefixset_after = after --C.class_after<class_method> = f

local function override(self, method_name, hook)
	local method = self[method_name]
	self[method_name] = method and function(self, ...)
		method(self, ...)
		return hook(self, ...)
	end or hook
end
Object.__instance.          override = override --C:override(method, f)
Object.__instance.prefixset_override = override --C.override_<method> = f
Object.__class.             override = override --C:class_override(class_method, f)
Object.__class.   prefixset_override = override --C.class_override<class_method> = f

function Object.__instance:init() end --stub

function Object.__class:create(...)
	local o = {}
	o.__index          = self.__index
	o.__newindex       = self.__newindex
	o.__getters        = self.__instance_getters
	o.__setters        = self.__instance_setters
	o.__prefix_getters = self.__instance.__prefix_getters
	o.__prefix_setters = self.__instance.__prefix_setters
	o.get              = self.__instance.get
	o.set              = self.__instance.set
	o.super = self.__instance
	setmetatable(o, o)
	o:init(...)
	return o
end

function Object.__class:subclass(classname, overrides)
	local c = {}
	c.classname = classname or ''
	c.__index            = self.__index
	c.__newindex         = self.__newindex
	c.__getters          = self.__getters
	c.__setters          = self.__setters
	c.__prefix_getters   = self.__prefix_getters
	c.__prefix_setters   = self.__prefix_setters
	c.__instance_getters = self.__instance_getters
	c.__instance_setters = self.__instance_setters
	c.__class = {}
	c.__class.__prefix_getters = self.__class.__prefix_getters
	c.__class.__prefix_setters = self.__class.__prefix_setters
	c.__class.__index          = self.__class
	c.__class.__newindex       = self.__class.__newindex
	c.__class.class = c
	setmetatable(c.__class, c.__class)
	c.__instance = {}
	c.__instance.__setters = self.__instance.__setters
	c.__instance.__prefix_getters = self.__instance.__prefix_getters
	c.__instance.__prefix_setters = self.__instance.__prefix_setters
	c.__instance.class = c
	c.__instance.__index    = self.__instance
	c.__instance.__newindex = self.__instance.__newindex
	setmetatable(c.__instance, c.__instance)
	c.super = c.__class
	c.get = self.get
	c.set = self.set
	setmetatable(c, c)
	if overrides then
		for k,v in pairs(overrides) do
			c[k] = v
		end
	end
	return c
end

function Object:prefixset_class(k, v) --C.class_<class_field> = v
	self.__class[k] = v
end

function Object:set(k, v) --C.<instance_field> = v
	self.__instance[k] = v
end






local c1 = Object:subclass()

function c1:class_before_subclass()
	print'c1:before_subclass'
end

function c1:set_x(v) print'set_x'; self._x = v * 2 end
function c1:get_x(v) return self._x / 3 end

function c1:before_init()
	print'c1:before_init'
end

local c2 = c1:subclass()

o = c2:create(1, 2, 3)

print(o.set_x)
function o:after_set_x(x)
	print('o:after_set_x', x)
end

o.x = 6

print(o.x)

for k,v in pairs(c2) do print('', k,v) end
print()
for k,v in pairs(o) do print('', k,v) end

