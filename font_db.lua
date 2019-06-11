--[[

	Font database for font selection.
	Written by Cosmin Apreutesei. Public Domain.

	db = fontdb()
	db:free()

	db:add_font(font, name, [weight], [slant])
	db:find_font(name|font, [weight, slant, size, bolder]) -> font,size | nil

]]

local glue = require'glue'

local update = glue.update
local attr = glue.attr
local trim = glue.trim
local index = glue.index
local snap = glue.snap
local clamp = glue.clamp

local font_db = {}
setmetatable(font_db, font_db)

function font_db:__call()
	self = update({}, self)
	self.db = {} --{name -> {slant -> {weight -> font}}}
	self.namecache = {} --{name -> font_name}
	self.searchers = {} --{searcher1, ...}
	return self
end

function font_db:free() end --stub

font_db.weights = {
	thin       = 100,
	ultralight = 200,
	extralight = 200,
	light      = 300,
	regular    = 400,
	normal     = 400,
	medium     = 500,
	semibold   = 600,
	bold       = 700,
	ultrabold  = 800,
	extrabold  = 800,
	heavy      = 900,
}

--TODO: use these
font_db.widths = {
	ultracondensed = 1,
	extracondensed = 2,
	condensed      = 3,
	semicondensed  = 4,
	normal         = 5,
	semiexpanded   = 6,
	expanded       = 7,
	extraexpanded  = 8,
	ultraexpanded  = 9,
}

font_db.slants = {
	italic  = 'italic',
	oblique = 'oblique',
}

local function remove_suffixes(s, validate)
	local removed
	local function remove_suffix(s)
		if validate(s) then
			removed = true
			return ''
		end
	end
	repeat
		removed = false
		s = s:gsub('_([^_]+)$', remove_suffix)
	until not removed
	return s
end

font_db.redundant_suffixes = {regular=1, normal=1}

function font_db:parse_font(name, weight, slant, size, bolder)

	local weight_str, slant_str, size_str
	if type(name) == 'string' then
		name = name:gsub(',([^,]*)$', function(s)
			size_str = tonumber(s)
			return ''
		end)
		name = trim(name):lower():gsub('[%-%s_]+', '_')
		name = name:gsub('_([%d%.]+)', function(s)
			weight_str = tonumber(s)
			return weight_str and ''
		end)
		name = remove_suffixes(name, function(s)
			if self.weights[s] then
				weight_str = self.weights[s]
				return true
			elseif self.slants[s] then
				slant_str = self.slants[s]
				return true
			elseif self.redundant_suffixes[s] then
				return true
			end
		end)
	end

	if weight then
		weight = tonumber(weight) or self.weights[weight:lower()]
	else
		weight = weight_str
	end

	if slant then
		slant = self.slants[slant:lower()]
	else
		slant = slant_str
	end
	size = size or size_str

	name = name or false
	weight = weight or 400
	slant = slant or 'normal'

	if bolder then
		weight = weight + 200
	end

	weight = clamp(snap(weight, 100), 100, 900)

	return name, weight, slant, size
end

function font_db:normalized_font_name(name)
	name = trim(name):lower()
		:gsub('[%-%s_]+', '_') --normalize word separators
		:gsub('_[%d%.]+', '') --remove numbers because they mean `weight'
	name = remove_suffixes(name, function(s)
		if self.redundant_suffixes[s] then return true end
	end)
	return name
end

--NOTE: multiple (name, weight, slant) can be registered with the same font.
--NOTE: `name` doesn't have to be a string, it can be any indexable value.
function font_db:add_font(font, name, weight, slant)
	local name, weight, slant = self:parse_font(name, weight, slant)
	attr(attr(self.db, name), slant)[weight] = font
end

local function closest_weight(t, wanted_weight)
	local best_diff = 1/0
	local best_font
	for weight, font in pairs(t) do
		local diff = math.abs(wanted_weight - weight)
		if diff < best_diff then
			best_diff = diff
			best_font = font
		end
	end
	return best_font
end
function font_db:find_font(name, weight, slant, size, bolder)
	if type(name) ~= 'string' then
		return name --font object: pass-through
	end

	local name_only = not (weight or slant or size)
	local font = name_only and self.namecache[name] --try to skip parsing
	if font then return font end

	local name, weight, slant, size =
		self:parse_font(name, weight, slant, size, bolder)

	--exact search in local db.
	local t = self.db[name]
	local t = t and t[slant]
	local font = t and t[weight]

	--loose search using installed searchers.
	if not font then
		local closest_weight
		for _,searcher in ipairs(self.searchers) do
			local found_font, found_weight = searcher(self, name, weight, slant)
			if not closest_weight
				or math.abs(weight - found_weight)
				 < math.abs(weight - closest_weight)
			then
				font = found_font
				closest_weight = found_weight
			end
		end
	end

	--loose search in local db.
	if not font and t then
		font = closest_weight(t, weight)
	end

	--register the found font for the requested weight.
	--NOTE: register all the searchers before looking up any fonts, otherwise
	--later searchers won't be invoked to find fonts with closer weights.
	if font then
		self:add_font(font, name, weight, slant)
	end

	if font and name_only then
		self.namecache[name] = font
	end

	return font, size
end

function font_db:dump()
	local weight_names = index(self.weights)
	for name,t in glue.sortedpairs(self.db) do
		local dt = {}
		for slant,t in glue.sortedpairs(t) do
			for weight, font in glue.sortedpairs(t) do
				local weight_name = weight_names[weight]
				dt[#dt+1] = weight_name..' ('..weight..')'..' '..(slant or '')
			end
		end
		print(string.format('%-30s %s', tostring(name), table.concat(dt, ', ')))
	end
end

return font_db
