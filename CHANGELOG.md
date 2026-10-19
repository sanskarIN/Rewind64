# Changelog

## v0.1.9 - 2026-10-19 (experimental prerelease)

- Implemented a true zero-single-step observation option: `run --observe-only PROGRAM`. It captures initial registers and then follows ptrace exec/exit events and signal-delivery stops to termination.
- Rejects incompatible `--observe-only` and `--steps N` flags in either order; `--changes-only` and the `--` option delimiter remain supported.
- Reports signal sender PID and UID from the Linux `siginfo_t` union only for SI_USER (0) and SI_TKILL (-6), not for kernel fault signals.
- Expanded pure Bash regression suite to 61 cases, including observation of normal exits, exec replacement, repeated handlers, fatal signals, job-control stops and malformed options.
- Assembly-only debugger and fixtures, Python-free tests, Linux x86-64 only. No recording, interactive control or reverse execution.

## v0.1.8 - 2026-10-19 (experimental prerelease)

- Read `PTRACE_GETEVENTMSG` at `PTRACE_EVENT_EXIT` stops and display the kernel's raw wait-status payload before final process termination.
- Report signed `siginfo_t.si_code` for valid signal-delivery stops, distinguishing user-sent and thread-directed signals.
- Added pure NASM fixtures for self-directed `tgkill` (`SI_TKILL=-6`) and `exit_group(23)`; extended Bash tests for raw exit status, re-exec, signed signal codes, and concise output.
- No Python code or runtime dependency; native Linux x86-64 NASM tests run on Ubuntu 22.04 and 24.04.
- Remains single-tracee experimental software without recording, interactive control, or reverse execution.

## v0.1.7 - 2026-10-19 (experimental prerelease)

- Classified Linux job-control group stops using `PTRACE_GETSIGINFO` / `EINVAL` to prevent repeatedly reinjecting `SIGSTOP` into a stopped tracee. Unsupported group stops now return a tracing error and trigger cleanup.
- Fixed cleanup to drain ptrace wait stops, including synthetic `PTRACE_EVENT_EXIT`, after `SIGKILL`, before treating the child as reaped.
- Bounded abnormal-stop processing with a stop budget to avoid endless ptrace cleanup cycles; pathological scenarios remain best-effort.
- Added a pure NASM `SIGSTOP` regression fixture plus Python-free Bash tests verifying ordinary, compact and mid-step group-stop handling and that the child PID no longer runs.
- Verified 45 Bash integration checks on Ubuntu 22.04 and Ubuntu 24.04 with native NASM/ELF builds.
- Retained Boost Software License 1.0 and experimental, single-tracee Linux x86-64 scope.

## v0.1.6 - 2026-10-19 (experimental prerelease)

- Enabled Linux `PTRACE_O_TRACEEXEC` / `PTRACE_O_TRACEEXIT` with the existing `PTRACE_O_EXITKILL` option.
- Distinguished kernel ptrace event stops using `waitpid` event bits and resumed them without forwarding a synthetic SIGTRAP to the target.
- Added exec/exit event logging and diagnostic event counts distinct from ordinary forwarded-signal counts.
- Added a NASM re-exec fixture exercising in-process image replacement and expanded Bash tests for event accounting and early exits.
- Native Linux x86-64 NASM build and 42 Python-free Bash integration checks passed on Ubuntu 22.04 and 24.04.
- Remains a single-tracee experimental debugger without replay or process/thread following.

## v0.1.5 - 2026-10-19 (experimental prerelease)

- Log and count observed ptrace signal-delivery stops, including stops during initial bounded stepping and later process continuation.
- Report `Signals forwarded: N` with completed instruction steps and target exit/signal diagnostics.
- Added an Assembly fixture that installs an `rt_sigaction` SIGUSR1 handler, exercises two signal deliveries and exits successfully only after both handlers ran.
- Expanded Python-free Bash tests to cover signal counters on handled signals, SIGTERM, SIGTRAP, SIGSEGV, and normal exits.
- Retained Linux x86-64, glibc, NASM and Boost Software License 1.0. No recording or reverse execution.

## v0.1.4 - 2026-10-18 (experimental prerelease)

- Added `run [--steps N] [--changes-only] [--] PROGRAM [ARGS...]` with flags accepted in either order before the target and an explicit `--` delimiter.
- Opt-in concise register output hides the repeated full CPU tables but retains initial/step headers, register changes and final step counts; full display remains the default.
- Rejected duplicate command options and tightened error reporting for missing flags and target arguments.
- Checked the initial traced exec-stop signal before attempting register inspection or single-stepping.
- Added pure Assembly SIGILL, SIGFPE and exit-42 test fixtures. Expanded Bash regression checks to 36 tests on Ubuntu 22.04 and 24.04.
- No Python source, Python build dependency, recording or reverse execution was added.

## v0.1.3 - 2026-10-18 (experimental prerelease)

- Added a NASM register-delta engine comparing 20 displayed fields between adjacent successful instruction steps, printing previous and current 64-bit values.
- Reserved a second complete 216-byte Linux register buffer within the debugger's stack frame; no trace storage or reverse execution is implemented.
- Extended black-box Bash tests and native Assembly fixtures for SIGTERM, SIGSEGV during stepping, exit status 255, and the 64-step upper bound.
- Distinguished syscall single-step traps from application INT3 on Linux where syscall stepping reports `TRAP_BRKPT`.
- Retained Python-free NASM builds and integration checks on Ubuntu 22.04 and 24.04.

## v0.1.2 - 2026-10-18 (experimental prerelease)

- Added a dedicated NASM register-inspector module exposing the 16 x86-64 GPRs, RFLAGS, FS/GS bases, RIP and RSP across snapshots.
- Reported actual completed steps versus the requested maximum on normal exit and signal termination.
- Added a native Assembly fixture with known values for RAX, RBX, R12 and R13.
- Expanded Bash integration checks to validate register values and step accounting.
- Verified clean native NASM builds and Python-free tests on Ubuntu 22.04 and 24.04.

## v0.1.1 - 2026-10-18 (experimental prerelease)

- Implemented bounded forward single-stepping (`run --steps N`, range 1..64) and repeated register snapshots.
- Fixed synthetic SIGTRAP forwarding after stepping, distinguished debugger traps from application traps using siginfo, and added waitpid EINTR retry.
- Added Assembly fixtures testing argv forwarding and SIGUSR1 propagation.
- Replaced and removed Python integration tests with Bash-driven checks of native Assembly targets.
- Hardened clean-build CI and added pre-release documentation.

## v0.1.0 - 2026-10-18 (experimental prerelease)

- Initial Linux x86-64 native CLI and NASM debugger source.
- Child launch with ptrace, exit-kill option, RIP/RSP and RAX/RBX/RCX/RDX inspection, one instruction step, and process exit diagnostics.
- Improved early exit handling for missing executables and passing native NASM GitHub Actions builds.
- Integration fixtures for exit 0, exit 7, and application-generated SIGTRAP; argument and error checks.
- CI and contributor/security/architecture documentation.

The Linux x86-64 prerelease ships an archive and SHA-256 checksum. No stable release has been declared; lifecycle edge cases and broader validation remain before future stable releases.
