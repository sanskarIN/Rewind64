# Rewind64 development progress

## v0.2.0 interactive Linux development — 2026-10-19

- **Published:** [v0.2.0 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.0); not stable. Native NASM build, integration tests, archive, SHA-256 checksums and public prerelease publishing passed: https://github.com/sanskarIN/Rewind64/actions/runs/39231018860 . The Windows x86-64 backend was deferred to a future milestone.
- Implemented `run --interactive PROGRAM [ARGS...]` in native NASM Assembly: initial stop CPU register snapshot, flushed `rewind64> ` prompt, newline-terminated `step`/`s`, `regs`/`r`, `continue`/`c`, `help`, and `quit`/`q` commands.
- `step` returns to the prompt on recognized single-step traps using the existing register snapshots and deltas; `regs` prints full CPU state from `PTRACE_GETREGS` even under `--changes-only`. `continue` resumes normal ptrace wait/exec/exit/signal processing; `quit` and stdin EOF request SIGKILL followed by bounded ptrace-stop cleanup/reaping.
- `--interactive` is incompatible with `--steps N` / `--observe-only` and works with `--changes-only`. Command parsing and debugging remain Assembly-only; integration tests remain Bash + native Assembly fixtures, with no Python.
- The first new CI attempt found a test harness bug (Bash helper passed to `timeout` as an executable returned 127); corrected it to apply the command script through stdin to the real timed debugger executable.
- **78/78 Python-free integration checks passed** on both Ubuntu 22.04 and 24.04 in PR and merged main: https://github.com/sanskarIN/Rewind64/actions/runs/39231018821 .
- Interactive mode is deliberately limited to one tracee and the initial stop or recognized step completions; it is not full terminal/job-control support. Breakpoints, memory browsing, multithread following, reverse stepping, recording, deterministic replay, Windows/macOS and stable release remain unimplemented.
- Retained Boost Software License 1.0 and commit author email `sanskarin@outlook.in`.

## v0.1.9 development — 2026-10-19

- **Published:** [v0.1.9 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.1.9), not stable. Clean NASM release build/tests, SHA-256 packaging and publishing succeeded: https://github.com/sanskarIN/Rewind64/actions/runs/39227105042 .
- Added `run --observe-only PROGRAM [ARGS...]` in the NASM command parser, mutually exclusive with `--steps N`. The Linux debugger samples registers at the initial exec stop then issues zero single-step requests, continuing directly to observe signal and process lifecycle events through normal exit/termination.
- Opt-in observation mode works with `--changes-only` and `--` and emits `Steps completed: 0 / 0`. Default forward stepping 1..64 remains unchanged.
- For user-originated `siginfo_t.si_code=SI_USER` and `SI_TKILL`, report sender PID/UID from the correct Linux siginfo union offsets; kernel fault signals are not misinterpreted as sender metadata.
- Added 12 Python-free Bash integration checks (49 to 61), including normal and nonzero exits, exec replacement, handled and fatal signals, unsupported group stops, flag exclusivity and argument forwarding. **61/61 native NASM/Bash checks passed on Ubuntu 22.04 and 24.04** on PR and merged main: https://github.com/sanskarIN/Rewind64/actions/runs/39226991290 .
- No Python code, multi-process tracing, recording, reverse execution or deterministic replay added; Boost Software License 1.0 retained.

## v0.1.8 development — 2026-10-19

- **Published:** [v0.1.8 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.1.8), not stable. Clean NASM build, integration tests, SHA-256 packaging and release publication passed: https://github.com/sanskarIN/Rewind64/actions/runs/39225141849 .
- Implemented `PTRACE_GETEVENTMSG` decoding at Linux `PTRACE_EVENT_EXIT` stops in NASM and displayed the event-time `raw_wait` word, distinct from final reaped `waitpid` status.
- Reported signed `siginfo_t.si_code` for validated signal-delivery stops. The diagnostic can distinguish `SI_USER=0` from thread-directed `SI_TKILL=-6`.
- Added `tests/fixtures/thread_signal.asm` (native `tgkill`) and `tests/fixtures/exit_group.asm` (native `exit_group`) plus Bash integration checks for raw wait-status values, signal codes, regular/compact display, and in-process re-exec.
- Retained Python-free native NASM binaries, Bash/Make test orchestration, single-process Linux x86-64 experimental scope, and Boost Software License 1.0. No interactive debugger or reverse-execution claim.
- **49/49 Python-free Bash integration tests passed** on Ubuntu 22.04 and 24.04 on the final pull request and merged `main`: https://github.com/sanskarIN/Rewind64/actions/runs/39225141815 .

## v0.1.7 development — 2026-10-19

- **Published:** [v0.1.7 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.1.7), not stable. Native NASM build and 45 Bash tests passed, and release archive/checksums were published: https://github.com/sanskarIN/Rewind64/actions/runs/39219765675 .
- Extended NASM Linux debugger to classify ordinary signal-delivery stops with `PTRACE_GETSIGINFO` and detect unsupported job-control group stops when the query returns `EINVAL`. Group stops now terminate with an explicit diagnostic rather than potentially looping after reinjecting `SIGSTOP`.
- Reworked error cleanup to send SIGKILL and **drain intermediate ptrace wait stops**, including synthetic exit events. Each nonterminal stopped state is resumed with `PTRACE_CONT` signal zero. The bounded loop is defensive, not a guarantee of universal cleanup.
- Added `tests/fixtures/group_stop.asm` (pure NASM) and Bash assertions for standard, `--changes-only`, and mid-step group stops, plus checks that the tracee PID has been reaped.
- Native NASM/ELF build and **45/45 Python-free Bash tests passed** on Ubuntu 22.04 and 24.04: https://github.com/sanskarIN/Rewind64/actions/runs/39219331206 .
- Retained the existing Boost Software License 1.0 and Linux x86-64 single-tracee scope. Correct continuation through group stops, full thread/process tracing, reverse execution, and deterministic replay remain unsupported.

## v0.1.6 development — 2026-10-19

- **Published:** [v0.1.6 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.1.6), not stable. Native build/tests, SHA-256 packaging and release publication succeeded: https://github.com/sanskarIN/Rewind64/actions/runs/39216521066 .
- Enabled `PTRACE_O_TRACEEXEC` and `PTRACE_O_TRACEEXIT` alongside `PTRACE_O_EXITKILL` in the Assembly backend. Ptrace event stops are decoded from bits 16..31 of wait status and resumed with signal zero instead of accidentally forwarding a kernel-generated SIGTRAP.
- Added `Ptrace exec event` and `Ptrace exit event` diagnostics plus `Ptrace events: exec=N exit=N` counts, separate from `Signals forwarded: N`.
- Added `tests/fixtures/reexec.asm` (NASM Linux execve fixture) to exercise image replacement and target exit. Extended Bash integration checks for normal mode, compact display, and early exit event accounting.
- **42/42 Python-free integration tests passed** on Ubuntu 22.04 and Ubuntu 24.04 during PR validation: https://github.com/sanskarIN/Rewind64/actions/runs/39216202778 .
- No Python files or Python dependency were added. Rewind64 still supports one launched tracee on Linux x86-64 only; this is not a history recorder or full event/thread/fork manager.

## v0.1.5 development — 2026-10-19

- **Published v0.1.5 experimental Linux x86-64 prerelease:** https://github.com/sanskarIN/Rewind64/releases/tag/v0.1.5 . The clean NASM prerelease build, archive checksum and artifact publication succeeded: https://github.com/sanskarIN/Rewind64/actions/runs/39201835241 .
- Added NASM-only signal-delivery stop diagnostics and per-process `Signals forwarded: N` accounting for bounded stepping and later continuation, without adding a high-level debugger implementation.
- Added `tests/fixtures/handled_signal.asm` with a direct Linux `rt_sigaction` handler for SIGUSR1, two signal sends, `rt_sigreturn`, and a successful exit only if both handler calls occurred.
- Expanded Bash integration suite from 36 to **39 cases**, including repeated signal delivery, compact-mode output, and signal-stop counters for SIGTERM/SIGTRAP/SIGSEGV and normal exits. **39/39 tests passed** on Ubuntu 22.04 and 24.04: https://github.com/sanskarIN/Rewind64/actions/runs/39201756511 .
- Observed and fixed a test-only version mismatch (the first CI execution reported 38 passed, one version failure). The code identified itself as v0.1.5 after correction.
- Python is excluded from the source and test runtime. The project remains single-tracee Linux x86-64 without replay, reverse stepping, recording, or multi-process support.

## v0.1.4 development — 2026-10-18

- **Published:** [v0.1.4 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.1.4), not stable. Artifact packaging, checksum and native NASM release tests passed: https://github.com/sanskarIN/Rewind64/actions/runs/39111072939 .
- Implemented `run [--steps N] [--changes-only] [--] PROGRAM [ARGS...]` entirely in NASM Assembly, supporting flags in either order. `--` terminates option parsing, and duplicate flags return an explicit CLI error.
- `--changes-only` retains RIP/stack-pointer stop headers, per-instruction register deltas and step counts, but suppresses large, repetitive CPU register tables. Full register collection and delta calculation continue unchanged.
- Linux ptrace parent now verifies an initial exec-stop `SIGTRAP` before setting trace options and stepping.
- Added three new NASM test fixtures: `illegal.asm` (SIGILL), `divzero.asm` (SIGFPE) and `exit42.asm` (status 42). Bash tests also exercise compact modes, flag ordering, duplicate flags, missing targets, and the `--` delimiter including a dash-prefixed executable name.
- **36 native Assembly-fixture integration checks passed** on Ubuntu 22.04 and Ubuntu 24.04, including the merged main release build: https://github.com/sanskarIN/Rewind64/actions/runs/39111072934 .
- No `.py` files or Python dependency in build and tests.
- Limitations: Linux x86-64 only, one launched tracee, no memory explorer, attach, breakpoints, interactive stepping, trace recording, reverse execution, deterministic replay, or fully audited signal/thread/process lifecycle.

## v0.1.3 development — 2026-10-18

- **Published:** [v0.1.3 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.1.3), not stable. Release build, test, archive and checksum publication succeeded: https://github.com/sanskarIN/Rewind64/actions/runs/39100091815 .
- Added `src/registers/delta.asm`, a NASM-only CPU register delta engine. Compares 20 displayed 64-bit fields between adjacent successful steps and shows names, previous/current values, and totals.
- Maintains a previous 216-byte Linux x86-64 register snapshot in a separate non-overlapping Assembly stack buffer; **no execution trace, recording, or reverse execution**.
- Added native Assembly fixtures `exit255.asm`, `signal_term.asm`, `segv.asm` and `long_steps.asm`. Expanded Bash integration regression suite to **24 cases**.
- Diagnosed a Linux `PTRACE_SINGLESTEP` syscall edge case where a synthetic syscall stop reports `TRAP_BRKPT`. The debugger confirms the prior RIP contains the x86-64 `syscall` instruction through `PTRACE_PEEKTEXT` before treating it as a completed step. Program `INT3` signals remain forwarded.
- Adjusted a test to accommodate legitimate differences in initial RFLAGS across Ubuntu versions rather than assuming all instructions produce exactly two register changes.
- Native NASM and all **24 Python-free Bash integration tests passed on Ubuntu 22.04 and Ubuntu 24.04**: https://github.com/sanskarIN/Rewind64/actions/runs/39099963374 .
- All executable debugging and register comparison logic remains Assembly. Python is not used or required.
- Remaining: single-tracee scope, incomplete signal/thread lifecycle coverage, no replay, attach, breakpoints, or other OS binaries.

## v0.1.2 development — 2026-10-18

- **Published:** [v0.1.2 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.1.2), not stable. Release workflow succeeded: https://github.com/sanskarIN/Rewind64/actions/runs/39097091563 .
- Added `src/registers/x86_64.asm` with an Assembly-only display of all 16 x86-64 general-purpose registers, RIP, RFLAGS and FS/GS base addresses from Linux `user_regs_struct`.
- Updated `platforms/linux/debugger.asm` to call the register display module and report `Steps completed: actual / requested` on target exit/termination.
- Added `tests/fixtures/registers.asm` with known RAX, RBX, R12 and R13 values; expanded Bash integration suite from 19 to **20 cases**.
- `Makefile` now assembles the new register formatter and fixture.
- Linux CI matrix now tests Ubuntu 22.04 and 24.04; both succeeded during PR validation: https://github.com/sanskarIN/Rewind64/actions/runs/39096876383 .
- The merged `main` CI passed on both Ubuntu runners: https://github.com/sanskarIN/Rewind64/actions/runs/39097091550 .
- Released artifact: `rewind64-v0.1.2-linux-x86_64.tar.gz` plus `SHA256SUMS.txt`. No Windows/macOS artifact was published.
- Python remains excluded from the source, build and test execution path.
- The project still lacks interactive sessions, breakpoints, attach, execution recording, reverse stepping, deterministic replay and other OS backends. No claim of full signal/thread lifecycle correctness is made.

## v0.1.1 development — 2026-10-18

- **Published v0.1.1 experimental Linux x86-64 prerelease:** https://github.com/sanskarIN/Rewind64/releases/tag/v0.1.1 .
- Added `run --steps N` for 1..64 forward instruction steps with repeated register output.
- Fixed delivery of synthetic single-step SIGTRAP to the tracee; added siginfo trap-code classification for program-generated SIGTRAP during stepping; retained application-signal forwarding.
- Added retry on EINTR for `waitpid`.
- Removed `tests/integration/test_cli.py`; no Python source or runtime is used by this branch.
- Added native Assembly fixtures `argv.asm` and `signal_usr1.asm`; Bash drives black-box integration checks.
- Updated Make, CI, documentation, and release pipeline.
- CI initially caught a real SIGTRAP regression, which was fixed. Native NASM build and **19 Bash integration checks passed** after new SIGTRAP/early-exit regressions: https://github.com/sanskarIN/Rewind64/actions/runs/39095671110 .
- Release packaging, SHA-256 digest creation, artifact upload, and public prerelease publication passed: https://github.com/sanskarIN/Rewind64/actions/runs/39095913314 .
- Release remains experimental; no deterministic replay, reverse stepping, memory editing, attach, or verified cross-platform support.
- Next: more ptrace fault-injection tests, multithread/process-lifecycle research, and structured exit diagnostics.

## Scope

Phase 1, Linux x86-64. **Experimental v0.1.0 prerelease published:** https://github.com/sanskarIN/Rewind64/releases/tag/v0.1.0

## New source and tooling

- `src/cli/main.asm`: NASM CLI parser, version/help, `run` command.
- `platforms/linux/debugger.asm`: process launch, ptrace register snapshots, single-step, signal forwarding, exit reporting, error cleanup.
- `tests/fixtures/*.asm`: exit 0, exit 7, application SIGTRAP test programs.
- Initial v0.1.0 used `tests/integration/test_cli.py` (eight tests); **this historical Python file was removed in v0.1.1** and is not present in the current project.
- Expanded Linux register snapshots include RAX, RBX, RCX, RDX, RIP, and RSP. Early child exits are reported without attempting to kill an already-reaped process.
- `Makefile`, `.gitignore`, Linux GitHub Actions CI, documentation and policies.

## Verification

- Local Linux x86-64 environment: 8/8 integration tests passed using a **temporary GNU assembler translation of NASM syntax**, because NASM was not installed in the local container. This is **not** evidence of a native NASM compilation.
- **Native NASM CI passed on GitHub Actions** with successful assemble/link, integration testing, artifact checksum, and upload steps: https://github.com/sanskarIN/Rewind64/actions/runs/39094217690
- Latest local GNU assembler adaptation: 8/8 tests passed; GitHub CI is authoritative for canonical NASM.
- Windows/macOS and ARM64: not implemented, not tested.
- A native Linux x86-64 archive and SHA256SUMS.txt were published after the NASM prerelease workflow passed: https://github.com/sanskarIN/Rewind64/actions/runs/39094420276
- No cross-platform binaries or unsupported benchmarks have been published.

## Limitations / next steps

1. Keep native NASM CI green; extend fault injection, cleanup, and register inspection tests.
2. Review ABI assumptions, stack alignment, signal handling, and child cleanup under more fault conditions.
3. Add full register reporting and opt-in repeated stepping; define reliable program exit/error distinctions.
4. Study Windows/macOS designs only after the initial Linux foundation is healthy.
5. Treat v0.1.0 as an **experimental prerelease**, not stable; complete lifecycle hardening and broader platform validation before any stable designation.
