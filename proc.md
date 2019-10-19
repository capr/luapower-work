---
tagline: processes and IPC
---

## `local proc = require'proc'`

A library for creating, controlling and communicating with child processes.
Works on Windows, Linux and OSX.

## API

---------------------------------------------- -------------------------------
`proc.spawn(cmd,[args],[env],[cur_dir]) -> p`  spawn a child process
`p:kill()`                                     kill process
`p:exit_code() -> n`                           get process exit code
`p:forget()`                                   close process handle
`proc.env(k) -> v`                             get env. var
`proc.setenv(k, v) -> v`                       set env. var
`proc.setenv(k) -> v`                          delete env. var
`proc.env() -> env`                            get all env. vars
---------------------------------------------- -------------------------------

__NOTE:__ Env. vars are case-sensitive on Linux and OSX, not so on Windows.

### `proc.spawn(cmd,[args],[env],[cur_dir]) -> p`

Spawn a child process and return a process object to query and control the
process.

  * `cmd` is the filepath of the executable to run.
  * `args` is an array of strings representing command-line arguments.
  * `env` is a table of environment variables (if not given, the current
  environment is inherited).
  * `cur_dir` is the directory to start the process in.

