
--Process & IPC API for Windows & POSIX.
--Written by Cosmin Apreutesei. Public Domain.

local ffi = require'ffi'
local bit = require'bit'
local glue = require'glue'
local M = {}

if ffi.os == 'Windows' then --------------------------------------------------

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

function M.exec(cmd, args, env, cur_dir)
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
	if not self.h then return end
	assert(winapi.CloseHandle(self.h))
	assert(winapi.CloseHandle(self.main_thread_h))
	self.h = false
	self.id = false
	self.main_thread_h = false
	self.main_thread_id = false
end

--compound the STILL_ACTIVE hack with another hack to signal killed status.
local EXIT_CODE_KILLED = winapi.STILL_ACTIVE + 1

function proc:kill()
	if not self.h then
		return nil, 'invalid handle'
	end
	local ok, err, errcode = winapi.TerminateProcess(self.h, EXIT_CODE_KILLED)
	if not ok then
		return nil, err, errcode
	end
	return true
end

function proc:exit_code()
	if self._exit_code then
		return self._exit_code
	elseif self._killed then
		return nil, 'killed'
	end
	if not self.h then
		return nil, 'invalid handle'
	end
	local exitcode = winapi.GetExitCodeProcess(self.h)
	if not exitcode then
		return nil, 'active'
	end
	if exitcode == EXIT_CODE_KILLED then
		self._killed = true
	else
		self._exit_code = exitcode
	end
	self:forget()
	return self:exit_code()
end

elseif ffi.os == 'Linux' or ffi.os == 'OSX' then -----------------------------

ffi.cdef[[
extern char **environ;
int setenv(const char *name, const char *value, int overwrite);
int unsetenv(const char *name);
int execve(const char *file, char *const argv[], char *const envp[]);
typedef int32_t pid_t;
pid_t fork(void);
int kill(pid_t pid, int sig);
typedef int32_t idtype_t;
typedef int32_t id_t;
pid_t waitpid(pid_t pid, int *status, int options);
void _exit(int status);
int pipe(int[2]);
int fcntl(int fd, int cmd, ...);
int close(int fd);
ssize_t write(int fd, const void *buf, size_t count);
ssize_t read(int fd, void *buf, size_t count);
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

local proc = {}

local F_GETFD = 1
local F_SETFD = 2
local FD_CLOEXEC = 1
local EAGAIN = 11
local EINTR  = 4

local char     = ffi.typeof'char[?]'
local char_ptr = ffi.typeof'char*[?]'
local int      = ffi.typeof'int[?]'

function M.exec(cmd, args, env, cur_dir)

	--copy the args list to a char*[] buffer.
	local arg_buf, arg_ptrs
	if args then
		local n = #cmd + 1
		local m = #args + 1
		for i,s in ipairs(args) do
			n = n + #s + 1
		end
		arg_buf = char(n)
		arg_ptr = char_ptr(m + 1)
		local n = 0
		ffi.copy(arg_buf, cmd, #cmd + 1)
		arg_ptr[0] = arg_buf
		n = n + #cmd + 1
		for i,s in ipairs(args) do
			ffi.copy(arg_buf + n, s, #s + 1)
			arg_ptr[i] = arg_buf + n
			n = n + #s + 1
		end
		arg_ptr[m] = nil
	end

	--copy the env. table to a char*[] buffer.
	local env_buf, env_ptrs
	if env then
		local n = 0
		local m = 0
		for k,v in pairs(env) do
			v = tostring(v)
			n = n + #k + 1 + #v + 1
			m = m + 1
		end
		env_buf = char(n)
		env_ptr = char_ptr(m + 1)
		local i = 0
		local n = 0
		for k,v in pairs(env) do
			v = tostring(v)
			env_ptr[i] = env_buf + n
			ffi.copy(env_buf + n, k, #k)
			n = n + #k
			env_buf[n] = string.byte('=')
			n = n + 1
			ffi.copy(env_buf + n, v, #v + 1)
			n = n + #v + 1
		end
		env_ptr[m] = nil
	end

	--see https://stackoverflow.com/questions/1584956/how-to-handle-execvp-errors-after-fork
	local pipefds = int(2)
	if ffi.C.pipe(pipefds) ~= 0 then
		return nil, 'pipe() failed', ffi.errno()
	end
	local flags = ffi.C.fcntl(pipefds[1], F_GETFD)
	local flags = bit.bor(flags, FD_CLOEXEC)
	if ffi.C.fcntl(pipefds[1], F_SETFD, ffi.cast('int', flags)) ~= 0 then
		return nil, 'fcntl() failed', ffi.errno()
 	end

	local pid = ffi.C.fork()

	if pid == -1 then --in parent process

		return nil, 'fork() failed', ffi.errno()

	elseif pid == 0 then --in child process

		ffi.C.close(pipefds[0])
		ffi.C.execve(cmd, arg_ptr, env_ptr)

		--exec failed: put the errno on the pipe.
		local err = int(1, ffi.errno())
		ffi.C.write(pipefds[1], err, ffi.sizeof(err))
		ffi.C._exit(0)

	else --in parent process

		--check if exec failed by reading from the errno pipe.
		ffi.C.close(pipefds[1])
		local err = int(1)
		local n
		repeat
			n = ffi.C.read(pipefds[0], err, ffi.sizeof(err))
		until not (n == -1 and (ffi.errno() == EAGAIN or ffi.errno() == EINTR))
		ffi.C.close(pipefds[0])
		if n > 0 then
			return nil, 'exec() failed', err[0]
		end

		return glue.inherit({id = pid}, proc)

	end
end

function proc:forget()
	self.id = false
end

local SIGKILL = 9
local WNOHANG = 1

function proc:kill()
	if not self.id then
		return nil, 'invalid pid'
	end
	if ffi.C.kill(self.id, SIGKILL) ~= 0 then
		return nil, 'kill() failed', ffi.errno()
	end
	return true
end

function proc:exit_code()
	if self._exit_code then
		return self._exit_code
	elseif self._killed then
		return nil, 'killed'
	end
	if not self.id then
		return nil, 'invalid pid'
	end
	local status = int(1)
	local pid = ffi.C.waitpid(self.id, status, WNOHANG)
	if pid < 0 then
		return nil, 'waitpid() failed', ffi.errno()
	end
	if pid == 0 then
		return nil, 'active'
	end
	if bit.band(status[0], 0x7f) == 0 then --exited with exit code
		self._exit_code = bit.rshift(bit.band(status[0], 0xff00), 8)
	else
		self._killed = true
	end
	self:forget()
	return self:exit_code()
end

else
	error('unsupported OS '..ffi.os)
end

--self-test ------------------------------------------------------------------

if not ... then

local proc = M
local time = require'time'
local pp = require'pp'
io.stdout:setvbuf'no'
io.stderr:setvbuf'no'

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
--pp(t)
if ffi.abi'win' then
	assert(t.ZZ == '321')
else
	assert(t.Zz == '321')
end

local luajit =
	   ffi.os == 'Windows' and 'bin/mingw64/luajit.exe'
	or ffi.os == 'Linux'   and 'bin/linux64/luajit'
	or ffi.os == 'OSX'     and 'bin/osx64/luajit'

local p, err, errno = proc.exec(
	luajit,
	{'-e', 'local n=.12; for i=1,1000000000 do n=n*0.5321 end; print(n); os.exit(123)'},
	--{'-e', 'print(os.getenv\'XX\', require\'fs\'.cd()); os.exit(123)'},
	{XX = 55},
	'bin'
)
if not p then print(err, errno) end
assert(p)
print('pid:', p.id)
print'sleeping'
time.sleep(.5)
print'killing'
assert(p:kill())
assert(p:kill())
time.sleep(.5)
print('exit code', p:exit_code())
print('exit code', p:exit_code())
--assert(p:exit_code() == 123)
p:forget()

end
