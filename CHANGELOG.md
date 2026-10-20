# Changelog

## v0.2.9 — 2026-10-20 (experimental Linux x86-64 prerelease)

- Added cumulative confirmed instruction-step numbers alongside each of the 16 debugger-local RIP samples. The initial stop is `step=0`, then every successfully verified single-step completion increments and stores its global count before appending the new RIP.
- Added strict `history [N]` / `h [N]` filtering for the latest **1–16** available samples (default all), preserving chronological display and existing unfiltered behavior. Requests larger than the number of recorded entries display only those available.
- Invalid values (zero, 17+, leading zero, signs, trailing whitespace, extra arguments, non-decimal text) report a usage hint without resuming, mutating or delivering pending signals.
- Allocated a separate fixed 128-byte step-index ring synchronized with the original RIP ring; stack frame expands to 1184 bytes with disjoint metadata. No unbounded heap memory, persistent trace, reverse execution or replay.
- Added 12 Python-free Bash/native NASM regression scenarios, bringing the suite to **164/164 passing on both Ubuntu 22.04 and Ubuntu 24.04**. Corrected a pre-existing unknown-command fixture because `history 1` is now valid. The release workflow built and uploaded the native Linux x86-64 archive plus SHA-256 checksum.
- Remains experimental Linux x86-64, single launched tracee, Boost Software License 1.0. No new platform backend or stability claim.


## v0.2.8 — 2026-10-20 (experimental Linux x86-64 prerelease)

- Added native NASM interactive `history` / `h` to show up to **16** recent RIP observations in chronological order. The stored samples are the initial exec-time instruction pointer and every confirmed single-step completion, including individual steps within batches.
- A bounded 128-byte debugger-owned circular buffer overwrites the oldest sample when full, without allocation, filesystem output or target state modification. A fixed local ring index and count preserve chronological presentation across repeated wraparound.
- Genuine signal stops, invalid step requests, read-only `code`/`bytes` inspection and repeated history requests do not generate entries; the command never resumes the tracee.
- Added 10 Python-free native Assembly/Bash regression cases for initial RIP, aliases, repeated history, ring wrap and double wrap, SIGILL stops, rejected stepping, code/byte coexistence, compact display and unknown commands.
- **152/152 native tests passed** on both Ubuntu 22.04 and Ubuntu 24.04 on the release-ready pull request and merged main. The release workflow built and published the Linux x86-64 executable archive and SHA-256 checksum.
- This feature provides only sampled RIP addresses, **not historical CPU/register/memory state, reverse stepping, trace recording, or replay**. License remains Boost Software License 1.0.


## v0.2.7 — 2026-10-20 (experimental Linux x86-64 prerelease)

- Added read-only interactive `bytes [N]` / `b [N]`, displaying **1–8 bytes from current RIP** (default eight) in ascending address order; this is byte inspection, **not disassembly**.
- Reuses `PTRACE_GETREGS` and one `PTRACE_PEEKTEXT`, clearing `errno` to distinguish valid all-ones bytes from failed ptrace requests. Unreadable code returns nonfatally to the session prompt.
- Strict single-digit 1–8 counts reject zero, signs, extra whitespace, multiple arguments, trailing junk and out-of-range values without resuming or delivering pending tracee signals.
- Added 11 Python-free Bash/native NASM regression scenarios for one/eight-byte reads, aliases, known NOP and all-ones bytes, malformed syntax, inspection after stepping and at pending SIGILL, compact mode and EOF. **142/142 tests passed on both Ubuntu 22.04 and 24.04** before publication.
- Retains Boost Software License 1.0, single launched tracee, Linux x86-64 experimental scope and Assembly debugger logic. No breakpoints, trace recording, reverse execution, process attachment or stable release. The v0.2.7 prerelease ships a native Linux x86-64 archive with a SHA-256 checksum.


## v0.2.6 — 2026-10-20 (experimental Linux x86-64 prerelease)

- Added interactive `step N` / `s N` to request **1–16 verified forward instructions** per command. Bare `step` and `s` still execute exactly one instruction.
- Parses one or two strict decimal count digits; rejects zero, leading zeros, counts over 16, signs, extraneous whitespace and trailing text without resuming the stopped process.
- Reuses existing `PTRACE_SINGLESTEP`, register snapshots and deltas on **every** completed instruction; cumulative `status` step counts remain accurate.
- Cancels a pending batch on verified application signal stops and preserves that signal for explicit `step`, `continue` or `quit`. Exec/exit ptrace transitions cancel the batch before automatic continuation.
- Added 14 native Assembly/Bash integration scenarios, bringing the suite to **131 black-box checks**. Final CI: **131 passed, 0 failed** on both Ubuntu 22.04 and 24.04; a native Linux x86-64 archive and SHA-256 checksum were published with the prerelease.
- This remains experimental Linux x86-64, single launched tracee, Boost Software License 1.0, and Python-free. There is no disassembler, recording, replay or actual reverse execution.


## v0.2.5 - 2026-10-20 (experimental Linux x86-64 prerelease)

- Extended interactive `mem 0xHEX [COUNT]` / `m 0xHEX [COUNT]` to read 1–4 adjacent eight-byte words, defaulting to one word for backward compatibility. The count is exactly one decimal digit from 1 to 4; malformed spacing, counts and trailing text are rejected.
- Added 64-bit address-wrap preflight before the first `PTRACE_PEEKDATA`; each read still uses `errno`-safe handling for valid all-ones values. Invalid addresses are nonfatal, and reads do not resume the tracee or deliver pending signals.
- Hardened the 64-byte interactive input buffer: oversized lines are drained and rejected as one command, preventing a fragment such as `continue` from being executed at the next prompt.
- Expanded the Python-free Bash/Assembly regressions for multiple counts, edge syntax, wrapped ranges, oversized lines, EOF and maximum accepted input length. **117/117 checks passed on both Ubuntu 22.04 and 24.04.**
- Remains a **single-tracee, Linux x86-64-only experimental debugger** with no breakpoints, historical recording, reverse execution or deterministic replay. The experimental v0.2.5 prerelease ships a native Linux x86-64 archive and SHA-256 checksums; **no stable release** is claimed.

## v0.2.4 - 2026-10-19 (experimental Linux prerelease)

- Added interactive `mem 0xHEX` / `m 0xHEX`, reading **one eight-byte word** at a specified address in the explicitly launched tracee through `PTRACE_PEEKDATA`. This is read-only; there is no arbitrary process attachment, dump or write support.
- Implemented a strict NASM hex parser allowing a `0x`/`0X` prefix and 1–16 hexadecimal digits; rejects missing digits, extra digits, overflow, signs, trailing whitespace and malformed values without resuming the tracee.
- Uses `errno`-safe ptrace handling for valid all-ones data and returns to the prompt after unmapped-address errors, preserving pending signal delivery.
- Expanded Python-free Bash integration coverage from **99 to 109** black-box cases using `nm`-resolved native Assembly fixture symbols; verifies mapped words, all-ones values, uppercase hex syntax, malformed values, unreadable pointers, repeated reads, compact mode, pending SIGILL, and compatibility with code/stack inspection.
- Retained Boost Software License 1.0, NASM debugger and native fixtures, and Linux x86-64 single-tracee experimental scope. No disassembly, breakpoints, reverse execution, recording or deterministic replay.

## v0.2.3 - 2026-10-19 (experimental Linux prerelease)

- Added interactive `stack` / `k`, a bounded **32-byte read-only stack inspection**: four 64-bit words starting from a freshly obtained RSP, using Linux `PTRACE_PEEKDATA`.
- Handled Linux ptrace's ambiguous `-1` return by clearing and checking `errno` on each word; all-ones data remains valid, and unreadable addresses are reported non-fatally without resuming the tracee.
- Added native NASM fixtures `stack_words.asm` (four known words, including all ones and zero) and `invalid_rsp.asm` (unmapped RSP after a single step; inspect then safely quit).
- Expanded the Python-free Bash integration suite from **92 to 99 tests**, including initial stack, after-step and compact display, pending SIGILL, repeated reads, combined `code`/`stack` and invalid-address recovery.
- Retained experimental Linux x86-64, one launched tracee, and Boost Software License 1.0. No arbitrary-address memory browsing, breakpoints, disassembler, historical recording or reverse execution.

## v0.2.2 - 2026-10-19 (experimental Linux prerelease)

- Added native Assembly interactive `code` / `x` command for a **read-only eight-byte word at the tracee's current RIP**, using a fresh `PTRACE_GETREGS` followed by `PTRACE_PEEKTEXT`.
- Handles the Linux ptrace `-1` ambiguity correctly: clears `errno` before peeking, checks `errno` only on a `-1` return, and keeps the session active on peek failure.
- Added an Assembly executable fixture with a `0xffffffffffffffff` entry word, ensuring successful all-ones reads do not trigger false failures. The tracee is never resumed by this regression.
- Expanded Python-free Bash integration suite from **86 to 92** tests, covering entry-point inspection, after-step RIP changes, compact output, pending SIGILL, coexistence with register display and safe quit.
- Retained Boost Software License 1.0 and Linux x86-64 single-tracee experimental scope. No arbitrary-address memory reading, disassembler, breakpoints, recording or reverse execution.

## v0.2.1 - 2026-10-19 (experimental Linux prerelease)

- Interactive `step` now pauses at verified application signal-delivery stops (including SIGILL, SIGSEGV, and SIGTRAP), preserving the pending signal and allowing register inspection or explicit next action.
- Added interactive `status` / `i` command displaying PID, completed instruction steps and pending signal, without restarting the tracee.
- Interactive `continue` and `step` inject a pending signal exactly once on a successful ptrace resume request; `quit`/EOF cleans up without injecting it.
- Corrected `Signals forwarded: N` to count successful nonzero-signal ptrace resume requests, rather than merely detected signals awaiting a user choice. Ptrace exec/exit events clear stale interactive stepping state.
- Expanded Bash/native Assembly regression coverage to **86 cases**, including pending fatal signals, injected/undelivered signal accounting, `status`, signal-stop CPU inspection and tracee cleanup.
- All executable debugger logic and fixtures remain native NASM x86-64, with no Python dependency; retain Boost Software License 1.0 and experimental Linux x86-64 scope.
- Recording, reverse execution, breakpoints, process attach, and Windows/macOS support remain unimplemented.

## v0.2.0 - 2026-10-19 (experimental Linux prerelease)

- Added an Assembly-implemented `--interactive` debugger mode for one launched Linux x86-64 tracee, with `step`/`s`, `regs`/`r`, `continue`/`c`, `help`, and `quit`/`q` commands.
- Reuses the existing ptrace single-step trap classification, register-delta formatter, exec/exit event observation, signal forwarding, and best-effort child cleanup.
- `--interactive` rejects conflicts with `--steps N` and `--observe-only`, but accepts `--changes-only` and target argument delimiter `--`.
- Explicit `regs` shows the full CPU snapshot even when concise display is enabled. `quit` and stdin EOF attempt to terminate and reap the tracee without resuming it normally.
- New Bash scripted-stdin test harness validates session command sequences, repeated steps, signal/exec/fault lifecycle, cleanup, unusual CLI combinations, and short commands. Native NASM checks expand from 61 to 78 cases.
- The release remains experimental, **Linux x86-64 only**, with no Windows/macOS backend, process attachment, breakpoints, trace recording, deterministic replay or reverse stepping.
- The previously planned Windows v0.2.0 backend is deferred to a future release. Boost Software License 1.0 retained; no Python source or test dependency.

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
