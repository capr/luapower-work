setfenv(1, require'terra/low')

print(ffi.typeof('int8_t*') == ffi.typeof('char*'))

print(rawstring == &int8)
