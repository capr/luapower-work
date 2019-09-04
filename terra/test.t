setfenv(1, require'terra/low')

local terra subpixel_resolution(v: num)
	return 1.0 / nextpow2(int(1.0 / clamp(v, 1.0/64, 1.0)))
end

print(subpixel_resolution(1))

