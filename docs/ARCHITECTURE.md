# Architecture and ABI notes

## Current scope

`main` selects exactly three supported CLI operations: `--help`, `--version`, and `run`. `debug_run` accepts a null-terminated `argv` vector and is available only in the Linux/x86-64 build.

All executable debugger implementation in this milestone is Assembly in `src/cli/main.asm` and `platforms/linux/debugger.asm`. The black-box test runner is Python orchestration only. `Makefile` describes assembly and link steps. The program uses libc as an OS/API wrapper layer; no C or Python file implements debugging logic.

## Debugger state machine

1. `fork()` once; child requests `PTRACE_TRACEME` and calls `execvp` with the caller-provided argument vector.
2. Parent `waitpid`s for the `exec` stop; requests `PTRACE_O_EXITKILL` before resuming the target.
3. `PTRACE_GETREGS` captures the 216-byte Linux x86-64 `user_regs_struct`, reading RIP at offset 128 and RSP at offset 152.
4. `PTRACE_SINGLESTEP` advances one instruction, then the parent verifies a SIGTRAP stop and captures a second register snapshot.
5. `PTRACE_CONT` resumes the target; the parent reports exit status or termination signal. Subsequent stops forward signals to the tracee, including application-generated SIGTRAP.
6. Known debugger-error paths attempt to kill and reap the child. Unexpected process states terminate the debugger with a nonzero exit status.

Currently there is a **single** target process/session, a **single** sampled step, and no thread event management, disassembler, breakpoint insertion, `attach`, or memory explorer. Targets that fork children, create threads, or use complex trap/signal behavior are not fully supported. No recording and no replay are present. System security policies are never bypassed.

## Calling convention

- ABI: System V AMD64; caller and callee follow 16-byte alignment at call sites.
- Linux `ptrace` API: `ptrace(request, pid, addr, data)` as exported by libc.
- Linux C library functions used: `fork`, `execvp`, `waitpid`, `ptrace`, `kill`, `printf`, `puts`, `perror`, `_exit`, and `strcmp`.
- Registers in a reserved stack region are represented using the Linux x86-64 kernel's `user_regs_struct` layout. These offsets are **not portable** to other architectures or OSes.
- All `main` arguments come from the C runtime; targets run with the caller's inherited environment and permissions.

## Reliability / planned hardening

- EINTR retry and `waitpid` status normalization need further work.
- Explicit multi-thread/process follow and stateful interactive sessions are not implemented.
- `PTRACE_O_EXITKILL` reduces orphaned debuggees on debugger crashes but does not replace thorough lifecycle cleanup testing.
- Target exit statuses overlap the debugger's own error codes; machine-readable status separation is future work.
- A future trace format must be versioned, bounds-checked, and tested with corrupt inputs. State snapshots are not equivalent to deterministic replay.
