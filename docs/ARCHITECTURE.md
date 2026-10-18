# Architecture and ABI notes

## Current scope

`main` selects exactly three supported CLI operations: `--help`, `--version`, and `run`. `debug_run` accepts a null-terminated `argv` vector and is available only in the Linux/x86-64 build.

All executable debugger implementation in this milestone is Assembly in `src/cli/main.asm`, `platforms/linux/debugger.asm`, and `src/registers/x86_64.asm`. The black-box test runner is Bash orchestration using native Assembly test fixtures; **Python is not required or used**. `Makefile` describes assembly and link steps. The program uses libc as an OS/API wrapper layer; no high-level language source file implements debugging logic.

## Debugger state machine

1. `fork()` once; child requests `PTRACE_TRACEME` and calls `execvp` with the caller-provided argument vector.
2. Parent `waitpid`s for the `exec` stop; requests `PTRACE_O_EXITKILL` before resuming the target.
3. `PTRACE_GETREGS` captures the 216-byte Linux x86-64 `user_regs_struct`. `src/registers/x86_64.asm` prints general-purpose registers (RAX, RBX, RCX, RDX, RSI, RDI, RBP, R8–R15), RFLAGS, FS_BASE and GS_BASE. The Linux backend prints RIP and RSP. This module is architecture-specific, not a generic register layout for other operating systems.
4. `PTRACE_SINGLESTEP` advances up to the user-requested number of instructions, bounded to 1..64, verifying normal single-step traps with `PTRACE_GETSIGINFO` (`si_code == TRAP_TRACE`) and capturing the registers after every completed step. Program-generated SIGTRAP stops are forwarded rather than counted as completed steps.
5. `PTRACE_CONT` resumes the target; the parent reports exit status or termination signal and prints the completed/attempted instruction-step count. Subsequent stops forward signals to the tracee, including application-generated SIGTRAP.
6. Known debugger-error paths attempt to kill and reap the child. A target exiting or being signaled before the expected ptrace stop is reported as a process outcome; other unexpected process states produce a debugger failure.

Currently there is a **single** target process/session, up to 64 sampled steps, and no thread event management, disassembler, breakpoint insertion, `attach`, or memory explorer. Targets that fork children, create threads, or use complex trap/signal behavior are not fully supported. No recording and no replay are present. System security policies are never bypassed.

## Calling convention

- ABI: System V AMD64; caller and callee follow 16-byte alignment at call sites.
- Linux `ptrace` API: `ptrace(request, pid, addr, data)` as exported by libc.
- Linux C library functions used: `fork`, `execvp`, `waitpid`, `ptrace`, `kill`, `printf`, `puts`, `perror`, `_exit`, and `strcmp`.
- Registers in a reserved stack region use the Linux x86-64 kernel's `user_regs_struct` offsets: R15(0), R14(8), R13(16), R12(24), RBP(32), RBX(40), R11(48), R10(56), R9(64), R8(72), RAX(80), RCX(88), RDX(96), RSI(104), RDI(112), RIP(128), RFLAGS(144), RSP(152), FS_BASE(168), GS_BASE(176). These offsets are **not portable** to other architectures or OSes.
- All `main` arguments come from the C runtime; targets run with the caller's inherited environment and permissions.

## Reliability / planned hardening

- The waitpid helper retries on EINTR; more thorough status/signal event classification still needs testing.
- Explicit multi-thread/process follow and stateful interactive sessions are not implemented.
- `PTRACE_O_EXITKILL` reduces orphaned debuggees on debugger crashes but does not replace thorough lifecycle cleanup testing.
- Target exit statuses overlap the debugger's own error codes; machine-readable status separation is future work.
- A future trace format must be versioned, bounds-checked, and tested with corrupt inputs. State snapshots are not equivalent to deterministic replay.
