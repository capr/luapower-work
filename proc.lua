
--Process & IPC API for Windows & POSIX.
--Written by Cosmin Apreutesei. Public Domain.

local ffi = require'ffi'
local glue = require'glue'
local M = {}

if ffi.abi'win' then ---------------------------------------------------------

local winapi = require'winapi'
require'winapi.process'

local proc = {}

function M.env(k)
	if k then
		return winapi.GetEnvironmentVariable(k)
	end
	local t = {}
	for i,s in ipairs(winapi.GetEnvironmentStrings()) do
		local k,v = s:match'^([^=]*)=(.*)'
		if k ~= '' then
			t[k:upper()] = v
		end
	end
	return t
end

--NOTE: os.getenv() doesn't reflect the changes made with setenv() !!!
function M.setenv(k, v)
	winapi.SetEnvironmentVariable(k, v)
end

function M.spawn(cmd, args, env, cur_dir)
	if args then
		local t = {'"'..cmd..'"'}
		for i,s in ipairs(args) do
			t[i+1] = '"'..s..'"'
		end
		cmd = table.concat(t, ' ')
	end
	local proc_info, err, code = winapi.CreateProcess(cmd, env, cur_dir)
	if not proc_info then return nil, err, code end
	local proc = glue.inherit({}, proc)
	proc.h = proc_info.hProcess
	proc.main_thread_h = proc_info.hThread
	proc.id = proc_info.dwProcessId
	proc.main_thread_id = proc_info.dwThreadId
	return proc
end

function proc:forget()
	assert(winapi.CloseHandle(self.h))
	self.h = false
	assert(winapi.CloseHandle(self.main_thread_h))
	self.main_thread_h = false
end

function proc:kill()
	return winapi.TerminateProcess(self.h)
end

function proc:exit_code()
	return winapi.GetExitCodeProcess(self.h)
end

elseif ffi.os == 'Linux' or ffi.os == 'OSX' then -----------------------------

ffi.cdef[[
extern char **environ;
int setenv(const char *name, const char *value, int overwrite);
int unsetenv(const char *name);
int execvpe(const char *file, char *const argv[], char *const envp[]);
]]

function M.env(k)
	if k then
		return os.getenv(k)
	end
	local e = ffi.C.environ
	local t = {}
	local i = 0
	while e[i] ~= nil do
		local s = ffi.string(e[i])
		local k,v = s:match'^([^=]*)=(.*)'
		if k and k ~= '' then
			t[k] = v
		end
		i = i + 1
	end
	return t
end

function M.setenv(k, v)
	assert(k)
	if v then
		assert(ffi.C.setenv(k, v, 1) == 0)
	else
		assert(ffi.C.unsetenv(k) == 0)
	end
end

function M.spawn(cmd, args, env, cur_dir)
	local arg_buf, arg_ptrs
	if args then
		local n = 0
		for i,s in ipairs(args) do
			n = n + #s + 1
		end
		arg_buf = ffi.new('char[?]', n)
		arg_ptr = ffi.new('char*[?]', #args + 1)
		local n = 0
		for i, s in ipairs(args) do
			ffi.copy(arg_buf + n, s, #s + 1)
			arg_ptr[i-1] = arg_buf + n
			n = n + #s + 1
		end
		arg_ptr[#args] = 0
	end
	local env_buf, env_ptrs
	if env then
		local n = 0
		local m = 0
		for k, v in pairs(env) do
			n = n + #k + 1 + #v + 1
			m = m + 1
		end
		env_buf = ffi.new('char[?]', n)
		env_ptr = ffi.new('char*[?]', m + 1)
		local i = 0
		local n = 0
		for k, v in pairs(env) do
			env_ptr[i] = env_buf + n
			ffi.copy(env_buf + n, k, #k)
			n = n + #k
			env_buf[n] = string.byte('=')
			n = n + 1
			ffi.copy(env_buf + n, v, #v + 1)
			n = n + #v + 1
		end
		env_ptr[m] = 0
	end
	local ret = ffi.C.execvpe(cmd, arg_ptr, env_ptr)
end

else
	error('unsupported OS '..ffi.os)
end

--self-test ------------------------------------------------------------------

if not ... then

local proc = M
local time = require'time'
local pp = require'pp'

proc.setenv('zz', '123')
proc.setenv('zZ', '567')
if ffi.abi'win' then
	assert(proc.env('zz') == '567')
	assert(proc.env('zZ') == '567')
else
	assert(proc.env('zz') == '123')
	assert(proc.env('zZ') == '567')
end
proc.setenv('zz')
proc.setenv('zZ')
assert(not proc.env'zz')
assert(not proc.env'zZ')
proc.setenv('Zz', '321')
local t = proc.env()
pp(t)
if ffi.abi'win' then
	assert(t.ZZ == '321')
else
	assert(t.Zz == '321')
end

local luajit =
	ffi.abi'win' and 'bin/mingw64/luajit.exe'
	or ffi.os == 'Linux' and 'bin/linux64/luajit'
	or ffi.os == 'OSX' and 'bin/osx64/luajit'

local p = proc.spawn(
	luajit, {'-e', "print(os.getenv'XX', require'fs'.cd()); os.exit(123)"},
	{XX = 55},
	'bin'
)
assert(p)
time.sleep(.5)
assert(not p:kill())
time.sleep(.5)
assert(not p:kill())
assert(p:exit_code() == 123)
p:forget()

end
