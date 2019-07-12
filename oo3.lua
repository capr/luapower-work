
--Object system with virtual properties and method overriding hooks.
--Written by Cosmin Apreutesei. Public Domain.

if not ... then require'oo3_test'; return end

--getters and setters

local function get_value_specific_getter(self, k)
	if type(k) == 'string' then
		local getter = 'get_'..k --compiled in LuaJIT2.1
		local get = rawget(self, getter)
		if get then return get(self) end
		local get = rawget(self, 'super')[getter]
		if get then return get(self) end
	end
end

local function set_value_specific_setter(self, k, v)
	if type(k) == 'string' then
		local setter = 'set_'..k --compiled in LuaJIT2.1
		local set = rawget(self, setter)
		if set then set(self, v); return true end
		local set = rawget(self, 'super')[setter]
		if set then set(self, v); return true end
	end
end

local function get_value_default_getter(self, k)
	local get = rawget(self, 'get')
	if get then return get(self, k) end
	local get = rawget(self, 'super').get
	if get then return get(self, k) end
end

local function set_value_default_setter(self, k, v)
	local set = rawget(self, 'set')
	if set then set(self, k, v); return true end
	local set = rawget(self, 'super').set
	if set then set(self, k, v); return true end
end

local function get_value(self, k)
	local v = get_value_specific_getter(self, k); if v ~= nil then return v end
	local v = get_value_default_getter(self, k); if v ~= nil then return v end
	return rawget(self, 'super')[k]
end

local function set_value(self, k, v)
	if not set_value_specific_setter(self, k, v) then
		if not set_value_default_setter(self, k, v) then
			rawset(self, k, v)
		end
	end
end

local function add_prefixed_field(self, k, v)
	if type(k) == 'string' then
		local cmd, k = k:match'^([^_]+)_(.*)'
		local cmd = cmd and self.__commands[cmd]
		if cmd then
			self[cmd](self, k, v)
			return true
		end
	end
end

local function add_class_field(self, k, v)
	if not add_prefixed_field(self, k, v) then
		rawset(self, k, v)
	end
end

local function add_instance_field(self, k, v)
	if not add_prefixed_field(self, k, v) then
		self.fields[k] = v
	end
end

--subclassing and instantiation

local function subclass(self, classname, overrides)
	local c = {}
	c.__newindex = self and self.__newindex --C.F -> C.fields.F
	c.__call = self and self.__call --C(...)
	c.super = self
	c.classname = classname or ''
	c.isclass = true
	c.class = {class = c}
	setmetatable(c.class, c.class)
	c.__index = c.class --C.F <- C.class.F
	c.class.__index = self and self.class --C.class.F <- S.class.F
	c.class.__newindex = self and self.class.__newindex --C.class.F -> C.class.F
	c.fields = {class = c}
	setmetatable(c.fields, c.fields)
	c.fields.__index = self and self.fields --C.fields.F <- S.fields.F
	if classname then c['is'..classname] = true end
	setmetatable(c, c)
	if overrides then
		for k,v in pairs(overrides) do
			c[k] = v
		end
	end
	return c
end

local function create(self, ...)
	local o = {}
	o.__index    = self.__instance_index
	o.__newindex = self.__instance_newindex
	o.__call     = self.__instance_call
	o.super      = self.fields
	setmetatable(o, o)
	o:init(...)
	return o
end

local Object = subclass(nil, 'Object')
Object.__newindex = add_instance_field
Object.class.__newindex = add_class_field
Object.class.__instance_index    = get_value
Object.class.__instance_newindex = set_value

Object.class.subclass = subclass
Object.class.create = create
Object.class.__call = function(self, ...)
	return self:create(...)
end

function Object:init(...) end

--overriding

function Object.class:before(method_name, hook)
	local method = self.fields[method_name]
	self[method_name] = method and function(self, ...)
		hook(self, ...)
		return method(self, ...)
	end or hook
end

function Object.class:after(method_name, hook)
	local method = self.fields[method_name]
	self[method_name] = method and function(self, ...)
		method(self, ...)
		return hook(self, ...)
	end or hook
end

local function noop() return end
function Object.class:override(method_name, hook)
	local method = self.fields[method_name] or noop
	self[method_name] = function(self, ...)
		return hook(self, method, ...)
	end
end

Object.class.__commands = {
	before   = 'before';
	after    = 'after';
	override = 'override';
}

--type reflection

function Object.class:is(class)
	assert(type(class) == 'table' or type(class) == 'string')
	if self == class or self.classname == class then return true end
	local super = rawget(self, 'super')
	if super then return super:is(class) end
	return false
end

function Object:is(class)
	return self.class:is(class)
end

function Object.class:isinstance()
	return false
end

function Object:isinstance(class)
	return not class or self:is(class)
end

--closest ancestor that `other` has in self's hierarchy.
function Object.class:closest_ancestor(other)
	while not other:is(self) do
		self = rawget(self, 'super')
		if not self then
			return nil --other is not an Object
		end
	end
	return self
end

function Object:closest_ancestor(other)
	if other:isinstance() then
		other = other.class
	end
	return self.class:closest_ancestor(other)
end

--property reflection

--returns iterator<k,v,source>; iterates bottom-up in the inheritance chain
function Object:allpairs(stop_super)
	local source = self
	if source == stop_super then
		return function() return nil end
	end
	local k,v
	return function()
		k,v = next(source,k)
		if k == nil then
			source = rawget(source, 'super')
			if source == nil then return nil end
			if source == stop_super then return nil end
			k,v = next(source)
		end
		return k,v,source
	end
end

--returns all properties including the inherited ones and their current values
function Object.class:properties(stop_super)
	local values = {}
	for k,v,source in self:allpairs(stop_super) do
		if values[k] == nil then
			values[k] = v
		end
	end
	return values
end

--static inheritance

function Object.class:inherit(other, override, stop_super)
	if other and not oo.is(other, Object) then --plain table, treat as mixin
		for k,v in pairs(other) do
			if override or not self:hasproperty(k) then
				self[k] = v --not rawsetting so that meta-methods apply
			end
		end
	else --oo class or instance
		if other and not oo.is(self, other) then --mixin
			--prevent inheriting fields from common ancestors by default!
			if stop_super == nil then --pass false to disable this filter.
				stop_super = self:closest_ancestor(other)
			end
		else --superclass
			other = rawget(self, 'super')
		end
		local properties = other:properties(stop_super)
		for k,v in pairs(properties) do
			if (override or rawget(self, k) == nil)
				and k ~= 'isclass'   --don't set the isclass flag
				and k ~= 'classname' --keep the classname (preserve identity)
				and k ~= 'super' --keep super (preserve dynamic inheritance)
				and k ~= '__index'
				and k ~= '__newindex'
			then
				rawset(self, k, v)
			end
		end
	end
	return self
end

Object.inherit = Object.class.inherit

function Object.class:detach()
	self:inherit()
	self.classname = self.classname --store the classname
	rawset(self, 'super', nil)
	return self
end

function Object.class:gen_properties(names, getter, setter)
	for k in pairs(names) do
		if getter then
			self['get_'..k] = function(self) return getter(self, k) end
		end
		if setter then
			self['set_'..k] = function(self, v) return setter(self, k, v) end
		end
	end
end

--debugging

--....

--module object

local oo = {}

oo.Object = Object

function oo.class(super,...)
	return (super or Object):subclass(...)
end

local function isfunc(test)
	return function(obj, class)
		if type(obj) ~= 'table' then return false end
		local test = obj[test]
		if type(test) ~= 'function' then return false end
		return test(obj, class)
	end
end
oo.is = isfunc'is'
oo.isinstance = isfunc'isinstance'
oo.issubclass = isfunc'issubclass'
oo.closest_ancestor = isfunc'closest_ancestor'

return setmetatable(oo, {
	__index = function(oo, k) --create named classes with oo.ClassName([super], ...)
		return function(super, ...)
			return oo.class(super, k, ...)
		end
	end
})
