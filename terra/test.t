setfenv(1, require'terra/low')
require_h'harfbuzz_h'

terra hb_feature_t:__eq(other: &hb_feature_t)
	return true
end

hb_feature_arr_t = arr(hb_feature_t)

terra f()
	--var a = hb_feature_arr_t(nil)
	--var b = hb_feature_arr_t(nil)
	var a = arr(hb_feature_t)
	var b = arr(hb_feature_t)
	--var a: arr(hb_feature_t); a:init()
	--var b: arr(hb_feature_t); b:init()
	a:add()
	b:add()
	print(a == b)
end

f()
