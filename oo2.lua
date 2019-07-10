
--object system with virtual properties and method overriding hooks.
--Written by Cosmin Apreutesei. Public Domain.

if not ... then require'oo2_test'; return end

local Object = {classname = 'Object'}

local function class(super,...)
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
local is = isfunc'is'
local isinstance = isfunc'isinstance'
local issubclass = isfunc'issubclass'
local closest_ancestor = isfunc'closest_ancestor'

function Object:subclass(classname, overrides)
	local subclass = {
		__index = self,
		__newindex = self.__newindex,
		__call = self.create,
		classname = classname or '',
		isclass = true,
	}
	if classname then
		subclass['is'..classname] = true
	end
	setmetatable(subclass, subclass)
	if overrides then
		for k,v in pairs(overrides) do
			subclass[k] = v
		end
	end
	return subclass
end

function Object:init(...) return ... end

function Object:create(...)
	local o = {
		__index = self,
		__newindex = self.__newindex,
		__call = self.__call_instance,
	}
	setmetatable(o, o)
	o:init(...)
	return o
end

--slower __index with getter lookup.
local function index_no_get(self, k)
	if not rawget(self, 'isclass') then --instance: find a getter.
		if type(k) == 'string' then --find a specific getter.
			local getter = 'get_'..k --compiled in LuaJIT2.1
			local super = self
			repeat
				local get = rawget(super, getter)
				if get then
					return get(self) --virtual property
				end
				super = rawget(super, 'super')
			until not super
		end
	end
	local super = rawget(self, 'super')
	return super and super[k] --inherited property
end

--slowest __index with getter fallback lookup.
local function index_get(self, k)
	if not rawget(self, 'isclass') then --instance: find a getter.
		do --find getter fallback.
			local super = self
			repeat
				local get = rawget(super, 'get')
				if get then
					return get(self, k) --virtual property
				end
				super = rawget(super, 'super')
			until not super
		end
		if type(k) == 'string' then --find a specific getter.
			local getter = 'get_'..k --compiled in LuaJIT2.1
			local super = self
			repeat
				local get = rawget(super, getter)
				if get then
					return get(self) --virtual property
				end
				super = rawget(super, 'super')
			until not super
		end
	end
	local super = rawget(self, 'super')
	return super and super[k] --inherited property
end

local newindex_class --fw. decl.

--fastest __newindex when there are not properties.
local function newindex_no_prop(self, k, v)
	if not rawget(self, 'isclass') then
		rawset(self, k, v)
	else
		newindex_class(self, k, v)
	end
end

--slower __newindex with setter lookup.
local function newindex_no_set(self, k, v)
	if not rawget(self, 'isclass') then --instance: find a setter. hot!
		if type(k) == 'string' then --find a specific setter.
			local setter = 'set_'..k --compiled in LuaJIT2.1
			local super = self
			repeat
				local set = rawget(super, setter)
				if set then
					set(self, v) --virtual property
					return
				end
				super = rawget(super, 'super')
			until not super
		end
		rawset(self, k, v)
	else
		newindex_class(self, k, v)
	end
end

--slowest __newindex with fallback setter lookup.
local function newindex_set(self, k, v)
	if not rawget(self, 'isclass') then --instance: find a setter. hot!
		do --find a setter fallback.
			local super = self
			repeat
				local set = rawget(super, 'set')
				if set then
					set(self, k, v) --virtual property
					return
				end
				super = rawget(super, 'super')
			until not super
		end
		if type(k) == 'string' then --find a specific setter.
			local setter = 'set_'..k --compiled in LuaJIT2.1
			local super = self
			repeat
				local set = rawget(super, setter)
				if set then
					set(self, v) --virtual property
					return
				end
				super = rawget(super, 'super')
			until not super
		end
		rawset(self, k, v)
	else
		newindex_class(self, k, v)
	end
end

function newindex_class(self, k, v) --__newindex for classes.
	if type(k) == 'string' then
		if k:find'^before_' then --install before hook
			local method_name = k:match'^before_(.*)'
			self:before(method_name, v)
			return
		elseif k:find'^after_' then --install after hook
			local method_name = k:match'^after_(.*)'
			self:after(method_name, v)
			return
		elseif k:find'^override_' then --install override hook
			local method_name = k:match'^override_(.*)'
			self:override(method_name, v)
			return
		elseif k:find'^get_' then --use slower __index
			if getmetatable(self).__index == rawget(self, 'super') then
				getmetatable(self).__index = index_no_get
			end
		elseif k == 'get' then --use even slower __index
			getmetatable(self).__index = index_get
		elseif k:find'^set_' then --use slower __newindex
			if getmetatable(self).__newindex == newindex_no_prop then
				getmetatable(self).__newindex = newindex_no_set
			end
		elseif k == 'set' then --use even slower __newindex
			getmetatable(self).__newindex = newindex_set
		end
	end
	rawset(self, k, v)
end

meta.__newindex = newindex_no_prop

function Object:before(method_name, hook)
	local method = self[method_name]
	self[method_name] = method and function(self, ...)
		hook(self, ...)
		return method(self, ...)
	end or hook
end

function Object:after(method_name, hook)
	local method = self[method_name]
	self[method_name] = method and function(self, ...)
		method(self, ...)
		return hook(self, ...)
	end or hook
end

local function noop() return end
function Object:override(method_name, hook)
	local method = self[method_name] or noop
	self[method_name] = function(self, ...)
		return hook(self, method, ...)
	end
end

function Object:is(class)
	assert(type(class) == 'table' or type(class) == 'string')
	local super = rawget(self, 'super')
	if super == class or self == class or self.classname == class then
		return true
	elseif super then
		return super:is(class)
	else
		return false
	end
end

function Object:hasproperty(k)
	if rawget(self, k) ~= nil then return true, 'field' end
	if type(k) == 'string' and k ~= '__getters' and k ~= '__setters' then
		if k == 'super' then return false end
		local getters = self.__getters
		local get = getters and getters[k]
		if get then return true, 'property' end
		local setters = self.__setters
		local set = setters and setters[k]
		if set then return true, 'property' end
	end
	local super = rawget(self, 'super')
	if not super then return false end
	return super:hasproperty(k)
end

function Object:isinstance(class)
	return rawget(self, 'isclass') == nil and (not class or self:is(class))
end

function Object:issubclass(class)
	return rawget(self, 'isclass') and (not class or self:is(class))
end

--closest ancestor that `other` has in self's hierarchy.
function Object:closest_ancestor(other)
	while not is(other, self) do
		self = rawget(self, 'super')
		if not self then
			return nil --other is not an Object
		end
	end
	return self
end

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
function Object:properties(stop_super)
	local values = {}
	for k,v,source in self:allpairs(stop_super) do
		if values[k] == nil then
			values[k] = v
		end
	end
	return values
end

local function copy_table(dst, src, k, override)
	create_table(dst, k)
	local st = rawget(src, k)
	if st then
		local dt = rawget(dst, k)
		if dt == nil then
			dt = {}
			rawset(dst, k, dt)
		end
		for k,v in pairs(st) do
			if override or rawget(dt, k) == nil then
				rawset(dt, k, v)
			end
		end
	else
		local super = rawget(src, 'super')
		if super then
			return copy_table(dst, super, k)
		end
	end
end

function Object:inherit(other, override, stop_super)
	if other and not is(other, Object) then --plain table, treat as mixin
		for k,v in pairs(other) do
			if override or not self:hasproperty(k) then
				self[k] = v --not rawsetting so that meta-methods apply
			end
		end
	else --oo class or instance
		if other and not is(self, other) then --mixin
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
			then
				rawset(self, k, v)
			end
		end
	end

	--copy metafields if metatables are different
	local src_meta = getmetatable(other)
	local dst_meta = getmetatable(self)
	if src_meta and src_meta ~= dst_meta then
		for k,v in pairs(src_meta) do
			if override or rawget(dst_meta, k) == nil then
				rawset(dst_meta, k, v)
			end
		end
	end
	return self
end

function Object:detach()
	self:inherit()
	self.classname = self.classname --store the classname
	rawset(self, 'super', nil)
	return self
end

function Object:gen_properties(names, getter, setter)
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

local function pad(s, n) return s..(' '):rep(n - #s) end

local props_conv = {g = 'r', s = 'w', gs = 'rw', sg = 'rw'}
local oo_state_fields = {super=1, __getters=1, __setters=1, __observers=1}

function Object:inspect(show_oo)
	local glue = require'glue'
	--collect data
	local supers = {} --{super1,...}
	local keys = {} --{super = {key1 = true,...}}
	local props = {} --{super = {prop1 = true,...}}
	local sources = {} --{key = source}
	local source, keys_t, props_t
	for k,v,src in self:allpairs() do
		if sources[k] == nil then sources[k] = src end
		if src ~= source then
			source = src
			keys_t = {}
			props_t = {}
			keys[source] = keys_t
			props[source] = props_t
			supers[#supers+1] = source
		end
		if sources[k] == src then
			keys_t[k] = true
		end
	end
	if self.__getters then
		for prop in pairs(self.__getters) do
			if prop ~= '__index' then
				props_t[prop] = 'g'
			end
		end
	end
	if self.__setters then
		for prop in pairs(self.__setters) do
			if prop ~= '__index' then
				props_t[prop] = (props_t[prop] or '')..'s'
			end
		end
	end

	--print values
	for i,super in ipairs(supers) do
		if show_oo or super ~= Object then
			print('from '..(
				super == self and
					('self'..(super.classname ~= ''
						and ' ('..super.classname..')' or ''))
					or 'super #'..tostring(i-1)..(super.classname ~= ''
						and ' ('..super.classname..')' or '')
					)..':')
			for k,v in glue.sortedpairs(props[super]) do
				print('    '..pad(k..' ('..props_conv[v]..')', 16),
					tostring(super[k]))
			end
			for k in glue.sortedpairs(keys[super]) do
				local oo = oo_state_fields[k] or Object[k] ~= nil
				if show_oo or not oo then
					print('  '..(oo and '* ' or '  ')..pad(k, 16),
						tostring(super[k]))
				end
			end
		end
	end
end

setmetatable(Object, meta)

return setmetatable({
	class = class,
	is = is,
	isinstance = isinstance,
	issubclass = issubclass,
	closest_ancestor = closest_ancestor,
	Object = Object,
}, {
	__index = function(t,k)
		return function(super, ...)
			if type(super) == 'string' then
				super = t[super]
			end
			local cls = class(super, ...)
			cls.classname = k
			t[k] = cls
			return cls
		end
	end
})
