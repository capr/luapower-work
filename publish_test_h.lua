local ffi = require'ffi'
local C = ffi.load'publish_test'
ffi.cdef[[
typedef struct ANON ANON;
typedef struct S S;
typedef struct double2_bool double2_bool;
typedef struct int2 int2;
typedef struct bool2 bool2;
typedef struct int82_bool2 int82_bool2;
typedef struct bool2_int_S bool2_int_S;
typedef bool2_int_S (*bool_int_to_bool2_int_S) (bool, int32_t);
struct ANON {
	const char * c;
	float d;
};
struct S {
	int32_t x;
	union {
		S*** a;
		union {
			void* b;
			ANON s1;
			ANON s2;
		};
	};
	double y;
};
double2_bool S_f(S*, int2, int82_bool2);
S S_g(S*, bool_int_to_bool2_int_S);
S f(ANON);
void g(void*, const char *, bool);
]]
pcall(ffi.cdef, 'struct double2_bool { double _0; double _1; bool _2; };')
pcall(ffi.cdef, 'struct int2 { int32_t _0; int32_t _1; };')
pcall(ffi.cdef, 'struct bool2 { bool _0; bool _1; };')
pcall(ffi.cdef, 'struct int82_bool2 { int8_t _0; int8_t _1; bool2 _2; };')
pcall(ffi.cdef, 'struct bool2_int_S { bool2 _0; int32_t _1; S _2; };')
ffi.metatype('ANON', {__index = {
}})
ffi.metatype('S', {__index = {
	f = C.S_f,
	g = C.S_g,
}})
return C
