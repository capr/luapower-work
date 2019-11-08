local ffi        = require "ffi"
local ffi_new    = ffi.new
local ffi_gc = ffi.gc
local ffi_typeof = ffi.typeof
local ffi_cdef   = ffi.cdef
local ffi_load   = ffi.load
local ffi_str    = ffi.string
local C          = ffi.C
local tonumber   = tonumber
local setmetatable = setmetatable
local error = error


local _M = { _VERSION = '0.01' }

local mt = { __index = _M }

ffi_cdef [[
unsigned long ERR_get_error(void);
const char * ERR_reason_error_string(unsigned long e);
typedef struct PKCS11_key_st {
	char *label;
	unsigned char *id;
	size_t id_len;
	unsigned char isPrivate;	/**< private key present? */
	unsigned char needLogin;	/**< login to read private key? */
	EVP_PKEY *evp_key;		/**< initially NULL, need to call PKCS11_load_key */
	void *_private;
} PKCS11_KEY;
typedef struct PKCS11_cert_st {
	char *label;
	unsigned char *id;
	size_t id_len;
	X509 *x509;
	void *_private;
} PKCS11_CERT;
typedef struct PKCS11_token_st {
	char *label;
	char *manufacturer;
	char *model;
	char *serialnr;
	unsigned char initialized;
	unsigned char loginRequired;
	unsigned char secureLogin;
	unsigned char userPinSet;
	unsigned char readOnly;
	unsigned char hasRng;
	unsigned char userPinCountLow;
	unsigned char userPinFinalTry;
	unsigned char userPinLocked;
	unsigned char userPinToBeChanged;
	unsigned char soPinCountLow;
	unsigned char soPinFinalTry;
	unsigned char soPinLocked;
	unsigned char soPinToBeChanged;
	void *_private;
} PKCS11_TOKEN;
typedef struct PKCS11_slot_st {
	char *manufacturer;
	char *description;
	unsigned char removable;
	PKCS11_TOKEN *token;	/**< NULL if no token present */
	void *_private;
} PKCS11_SLOT;
typedef struct PKCS11_ctx_st {
	char *manufacturer;
	char *description;
	void *_private;
} PKCS11_CTX;
extern PKCS11_CTX* PKCS11_CTX_new(void);
extern void PKCS11_CTX_free(PKCS11_CTX * ctx);
extern int PKCS11_CTX_load(PKCS11_CTX * ctx, const char * ident);
extern int PKCS11_CTX_reload(PKCS11_CTX * ctx);
extern int PKCS11_open_session(PKCS11_SLOT * slot, int rw);
extern int PKCS11_enumerate_slots(PKCS11_CTX * ctx, PKCS11_SLOT **slotsp, unsigned int *nslotsp);
extern unsigned long PKCS11_get_slotid_from_slot(PKCS11_SLOT *slotp);
extern void PKCS11_release_all_slots(PKCS11_CTX * ctx, PKCS11_SLOT *slots, unsigned int nslots);
extern int PKCS11_enumerate_slots(PKCS11_CTX * ctx, PKCS11_SLOT **slotsp, unsigned int *nslotsp);
PKCS11_SLOT *PKCS11_find_token(PKCS11_CTX * ctx, PKCS11_SLOT *slots, unsigned int nslots);
extern int PKCS11_login(PKCS11_SLOT * slot, int so, const char *pin);
]]

local lib = ffi_load ("/opt/capione/lualib/p11.so")
local char_t = ffi_typeof "char[?]"
local size_t = ffi_typeof "size_t[1]"
local uint_ptr = ffi.typeof"unsigned int[1]"
local ctx_ptr_type = ffi.typeof("PKCS11_CTX[1]")
local pkcs_slot_ptr_type = ffi.typeof("PKCS11_SLOT[1]");

local function _err()
    local code = _C.ERR_get_error()
    if code == 0 then
        return code, "Zero error code (null arguments?)"
    end
    return code, ffi.string(_C.ERR_reason_error_string(code))
end


function _M.new(self, pkcsmodule)
    
    local ctx = lib.PKCS11_CTX_new()

    local r = lib.PKCS11_CTX_load(ctx, pkcsmodule)
    
    if r ~= 0 then
      ffi_gc(ctx, lib.PKCS11_CTX_free)
      return nil, _err()
     end
    ffi_gc(ctx, lib.PKCS11_CTX_free)
    return setmetatable({ _ctx = ctx }, mt)
end

function _M.enumerate_slots(self)
  local nslots = uint_ptr()
  local slots = ffi.new("PKCS11_SLOT *[1]")
  local rc = lib.PKCS11_enumerate_slots(self._ctx, slots, nslots)
  if rc < 0 then
     return nil, _err()
  end
  print(nslots[0] .. ":")
  

  local slot = lib.PKCS11_find_token(self._ctx, slots[0], nslots[0])
   
  if not slot[0] then
    print("slot not found")
    lib.PKCS11_release_all_slots(self._ctx, slots[0], nslots[0])
    return nil, 0,  "no token available"
  end
   print("slot found")
  if not slot[0].token then
    print("slot token not found")
    lib.PKCS11_release_all_slots(self._ctx, slots[0], nslots[0])
    return nil, 0,  "no token available"
  end
  
 
  print("Slot manufacturer......: %s\n", ffi.string(slot.manufacturer))
	print("Slot description.......: %s\n", ffi.string(slot.description))
	print("Slot token label.......: %s\n", ffi.string(slot.token.label))
	print("Slot token manufacturer: %s\n", ffi.string(slot.token.manufacturer))
	print("Slot token model.......: %s\n", ffi.string(slot.token.model))
	print("Slot token serialnr....: %s\n", ffi.string(slot.token.serialnr))
  
  if slot.token.loginRequired == 1 then
    print("login required...")
   local rc = lib.PKCS11_login(slot, 0, "1234")
   if rc ~= 0 then
     print("Login failed")
     return nil, 0, "login failed"
   end
   print("Login success")
  end
  lib.PKCS11_release_all_slots(self._ctx, slots[0], nslots[0]);

end

--[[usage
local softhsm = "/usr/local/lib/softhsm/libsofthsm.so"
  local p11 = pkcs11:new(softhsm)
  if not p11 then
    log_msg(log.ERROR,  "Failed to load :" , softhsm)
    return
  end
  
  local ok, code, msg = p11:enumerate_slots()
]]

return _M