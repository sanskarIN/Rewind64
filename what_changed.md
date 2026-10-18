# Rewind64 development progress

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
