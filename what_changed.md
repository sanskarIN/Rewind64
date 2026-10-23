# Rewind64 development progress

## v0.2.17 bounded non-invasive RIP watch — 2026-10-23 (experimental prerelease published)

- **Published:** [v0.2.17](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.17) through merged [PR #30](https://github.com/sanskarIN/Rewind64/pull/30), with all 13 development commits authored/committed as `sanskarin@outlook.in`.
- Native NASM `until-rip 0xHEX` checks the current RIP, then single-steps at most 64 confirmed instructions to an exact address. No executable code is patched; it is **not** a persistent breakpoint engine.
- Strict hexadecimal parsing, explicit exhaustion, pending-signal preservation, real INT3 handling and re-exec cancellation are covered by 17 new native Bash/NASM test scenarios.
- **276/276 Python-free tests passed** on Ubuntu 22.04 and 24.04 in [final PR CI](https://github.com/sanskarIN/Rewind64/actions/runs/39928433952); [release workflow](https://github.com/sanskarIN/Rewind64/actions/runs/39928572687) passed both Ubuntu verification jobs plus packaging. Linux archive and SHA-256 checksum assets published.
- A true INT3 breakpoint slot registry and re-arm/restore lifecycle remain future work in [Issue #25](https://github.com/sanskarIN/Rewind64/issues/25).

## v0.2.16 opt-in exec-event pause — 2026-10-23 (experimental prerelease published)

- **Published:** [v0.2.16](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.16) from merged [PR #28](https://github.com/sanskarIN/Rewind64/pull/28), after 21 feature/verification commits using author and committer `sanskarin@outlook.in`.
- Native NASM `until-exec` / `v` pauses at the next genuine ptrace exec event, refreshes registers, and resets RIP history to the new image without recording or restoring earlier state. Intermediate application signals are forwarded normally.
- Linux can report an extra no-progress SIGTRAP on the first post-exec single-step. The debugger retries at most once when the previous opcode is not INT3, INT 3 or ICEBP. The test suite verifies genuine INT3 remains an application signal and never becomes a completed step.
- **259/259 Python-free native integration tests passed** on Ubuntu 22.04 and 24.04 in [final PR CI](https://github.com/sanskarIN/Rewind64/actions/runs/39921511509). The [release workflow](https://github.com/sanskarIN/Rewind64/actions/runs/39921645322) passed both supported Ubuntu native suites before final packaging, publishing the Linux x86-64 archive and SHA-256 checksums.
- Experimental single-launched-tracee Linux x86-64 only. No stable release, breakpoint engine, process attachment, persistent trace, replay or reverse execution.

## v0.2.15 EOF-safe interactive command input — 2026-10-23 (experimental prerelease published)

- **Published:** [v0.2.15](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.15) through merged [PR #27](https://github.com/sanskarIN/Rewind64/pull/27). All 243 native tests passed on Ubuntu 22.04 and 24.04 at [PR head](https://github.com/sanskarIN/Rewind64/actions/runs/39917140384), and the [guarded release workflow](https://github.com/sanskarIN/Rewind64/actions/runs/39919770031) succeeded with both Ubuntu verification jobs plus the packaging job.
- Short exact input commands without final LF now dispatch normally, with safe EOF cleanup and strict 62-byte input boundary. Release assets include the Linux x86-64 archive and SHA-256 checksum.
- Still forward-only, single launched tracee, with no stable release, attach, trace recording or replay.

## v0.2.14 machine-readable capabilities — 2026-10-23 (experimental prerelease published)

- **Published:** [v0.2.14](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.14) from merged [PR #24](https://github.com/sanskarIN/Rewind64/pull/24), after ten development commits with author/committer `sanskarin@outlook.in`.
- NASM `--capabilities` prints target-free schema-v1 JSON describing supported Linux ptrace run modes, bounded inspection and unavailable functionality; no traced target is launched.
- **222/222 Python-free integration tests passed** on Ubuntu 22.04 and 24.04 at [PR head](https://github.com/sanskarIN/Rewind64/actions/runs/39910592007) and on [merged main](https://github.com/sanskarIN/Rewind64/actions/runs/39915509701). The [publishing workflow](https://github.com/sanskarIN/Rewind64/actions/runs/39915509678) succeeded and released the Linux archive and SHA-256 checksums.
- Remains experimental Linux x86-64, single launched tracee, forward-only; no true reverse debugging, trace recording, process attachment, Windows/macOS backend or stable release.

## v0.2.13 bounded signal history views — 2026-10-23 (experimental prerelease published)

- **Published:** [v0.2.13](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.13) through merged [PR #23](https://github.com/sanskarIN/Rewind64/pull/23).
- Added NASM `signals [N]` / `g [N]` filtering for the last 1–8 retained validated signal-delivery stops, preserving true indices across wraparound without resuming or forwarding pending signals.
- Added 13 native Bash/NASM integration tests, making **217/217 pass** on both [Ubuntu 22.04 and 24.04](https://github.com/sanskarIN/Rewind64/actions/runs/39909255822). [Merged-main CI](https://github.com/sanskarIN/Rewind64/actions/runs/39910666722) and [prerelease workflow](https://github.com/sanskarIN/Rewind64/actions/runs/39910666671) also passed. Native executable and checksum assets published.
- No Python, execution recording, replay or historical state restoration was introduced.

## v0.2.12 repeatable stop-on-signal — 2026-10-20 (experimental prerelease published)

- **Published:** [v0.2.12 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.12), merged through [PR #22](https://github.com/sanskarIN/Rewind64/pull/22) after 12 focused development commits using `sanskarin@outlook.in`.
- Added NASM interactive `until-signal` / `u` to resume toward the **next verified application signal-delivery stop**, return to the prompt with the new signal pending and allow inspection of the accumulated `signals` / `events` state. A previously pending signal is forwarded once only on successful resume.
- Added native assembly `signal_burst` fixture that repeatedly sends and handles **ten** SIGUSR1 events, verifying exactly ten stops, eight retained history entries and correct observed-vs-forwarded counts. Tests also exercise two handled signals, fault stops, lifecycle event transitions, EOF, malformed commands and compact mode.
- **204/204 native NASM/Bash tests passed** on Ubuntu 22.04 and Ubuntu 24.04 at final PR head and merged `main`: https://github.com/sanskarIN/Rewind64/actions/runs/39389585338 . The [guarded release workflow](https://github.com/sanskarIN/Rewind64/actions/runs/39389585348) passed and published the Linux x86-64 executable archive and SHA-256 checksum.
- No Python is used; release remains experimental single-process Linux x86-64, forward-only, with no replay or historic CPU/memory state reconstruction.


## v0.2.11 classified signal-stop history — 2026-10-20 (experimental prerelease published)

- **Published:** [v0.2.11 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.11). The implementation merged through [PR #21](https://github.com/sanskarIN/Rewind64/pull/21) with 11 focused development commits using `sanskarin@outlook.in`.
- Native NASM `signals` / `g` displays up to eight genuine validated signal-delivery stop records (signal number, signed `si_code`, global confirmed step count), oldest first.
- New eight-slot ring uses 128 debugger-local bytes, with distinct stack metadata and preserved alignment, and does not change the tracee or inject pending signals. Synthetic steps and unrelated ptrace events do not become signal history entries.
- Thirteen black-box Bash/native Assembly cases cover initial empty history, aliases, repeated inspection, SIGILL/SIGSEGV/SIGTRAP, pending batch interruption, status/inspection coexistence, compact mode, no-newline EOF, malformed commands and explicit signal forwarding.
- The initial CI run found a Bash test-file insertion syntax issue. Restoring the pre-existing `session_code` test and ELF symbol setup fixed it. The corrected suite passed **190/190 on Ubuntu 22.04 and Ubuntu 24.04**.
- **190/190 tests passed** on Ubuntu 22.04 and 24.04 on the final PR head and merged `main`: https://github.com/sanskarIN/Rewind64/actions/runs/39387729287 . The [gated release workflow](https://github.com/sanskarIN/Rewind64/actions/runs/39387729244) passed and published the experimental Linux x86-64 executable archive and SHA-256 checksum. Remains Linux x86-64, Python-free, forward-only and single-tracee.


## v0.2.10 interactive lifecycle diagnostics — 2026-10-20 (experimental prerelease published)

- **Published:** [v0.2.10 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.10). Changes merged via [PR #20](https://github.com/sanskarIN/Rewind64/pull/20) after 12 focused commits using `sanskarin@outlook.in`.
- Implemented native NASM read-only `events` / `e` to report the stopped tracee's PID, successful instruction step count, **validated application signal-delivery stops**, **signal-forwarding requests accepted by ptrace**, pending signal and ptrace exec/exit event totals.
- Validated signal stops update a dedicated observed counter and last signal number/signed `si_code`. Synthetic trace traps and ptrace events do not count as signal-delivery stops. A successful resume with a nonzero signal increments the existing forwarded counter; these values need not be equal.
- Added 13 native Bash/Assembly regression scenarios covering initial and stepped state, read-only coexistence, aliases, malformed commands, stopped SIGILL/SIGSEGV/SIGTRAP, interrupting step batches, compact mode, repeated inspections and EOF without a final newline.
- First CI run surfaced missing newline-free exact-command support; fixed the parser and added an explicit alias EOF regression. **177/177 tests passed on Ubuntu 22.04 and 24.04** at the final PR head. [Merged-main CI](https://github.com/sanskarIN/Rewind64/actions/runs/39377202811) and the [pre-release workflow](https://github.com/sanskarIN/Rewind64/actions/runs/39377202875) completed successfully and shipped the Linux archive and SHA-256 checksum.
- Existing experimental Linux-only, single-tracee, forward-only constraints and Boost Software License 1.0 remain unchanged. No Python used.


## v0.2.9 step-numbered RIP history — 2026-10-20 (experimental prerelease published)

- **Published:** [v0.2.9 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.9), merged via [PR #19](https://github.com/sanskarIN/Rewind64/pull/19). All 12 feature/maintenance commits used `sanskarin@outlook.in`.
- NASM debugger adds fixed-size per-sample verified step labels to RIP history: initial post-exec stop `step=0`; successful `PTRACE_SINGLESTEP` completion `step=1` onward.
- Adds `history [N]` and `h [N]` for the last 1–16 recorded entries, defaulting to all available; prints oldest-to-newest, with strict count validation, no tracing/recording, and no resumed tracee on reads.
- New 128-byte step-number ring uses disjoint stack slots, with the prior 128-byte RIP ring and bounded display metadata; wrapping preserves the correct step/address association.
- Added 12 Bash/native Assembly integration cases for step labels, range clamping, alias, validation, ring wraps, read-only inspection, stopped signals, repeated filtering and EOF. A prior unknown-command regression had to change because `history 1` is now recognized.
- **164/164 black-box tests passed** on both Ubuntu 22.04 and 24.04, on the final PR head and merged `main` in [GitHub CI](https://github.com/sanskarIN/Rewind64/actions/runs/39371053359). [Pre-release workflow](https://github.com/sanskarIN/Rewind64/actions/runs/39371053377) built and published the Linux x86-64 archive and SHA-256 checksum.
- Rewind64 remains an experimental forward-only Linux x86-64 single-tracee debugger. No Python; no reverse stepping, past memory reconstruction, replay, or disk trace format.


## v0.2.8 bounded instruction-pointer history — 2026-10-20 (experimental prerelease published)

- **Published:** [v0.2.8 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.8), merged via [PR #18](https://github.com/sanskarIN/Rewind64/pull/18) with 10 focused development commits using `sanskarin@outlook.in`.
- Implemented read-only `history` / `h` in NASM, tracking up to 16 recent observed RIP values in a 128-byte circular buffer, presented oldest to newest. The first sample comes from the post-exec stop; each subsequent successful verified instruction step adds a sample.
- Ring and metadata occupy non-overlapping debugger stack slots. Old entries are overwritten at capacity; no tracing file is written, no process state is restored, and inspection does not resume or modify the tracee.
- Added ten Bash/native Assembly regression scenarios for initial, steps, alias, repeated inspection, 16-entry wrap/double-wrap, aborted signal stepping, invalid input, code/byte coexistence and compact mode.
- **152/152 tests passed** on both Ubuntu 22.04 and Ubuntu 24.04 on the final PR and merged `main`: https://github.com/sanskarIN/Rewind64/actions/runs/39365723534 . The [experimental release workflow](https://github.com/sanskarIN/Rewind64/actions/runs/39365723551) also succeeded and published a native Linux x86-64 archive and SHA-256 checksum.
- Scope: experimental Linux x86-64, single launched tracee, no Python source/dependency, and no disassembly, process attachment, recording, deterministic replay or true reverse execution.


## v0.2.7 bounded RIP byte inspection — 2026-10-20 (experimental prerelease published)

- **Published:** [v0.2.7 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.7). Changes merged via [PR #17](https://github.com/sanskarIN/Rewind64/pull/17) with ten focused development commits using `sanskarin@outlook.in`.
- Added native NASM interactive `bytes [N]` / `b [N]` for 1–8 read-only instruction bytes at freshly sampled RIP. Byte order follows rising addresses. The command does not decode instruction boundaries or modify tracee state.
- Added strict count parsing with a one-byte decimal range, and `errno`-safe `PTRACE_PEEKTEXT` so valid `0xffffffffffffffff` values produce eight `ff` bytes.
- Added eleven Bash/native Assembly regression scenarios checking NOP data, all-ones, aliases, 1/4/8 counts, signal-stop inspection, compact mode, after-step inspection, EOF and malformed counts.
- **142/142 tests passed** on Ubuntu 22.04 and 24.04 on the final PR and merged `main`. GitHub Actions built and published the native Linux x86-64 archive and SHA-256 checksum through the gated prerelease workflow. No stable release, disassembler, trace recording or reverse execution is claimed.


## v0.2.6 interactive bounded step batches — 2026-10-20 (experimental prerelease published)

- **Published:** [v0.2.6 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.6). The implementation was merged through [PR #16](https://github.com/sanskarIN/Rewind64/pull/16), with 11 focused development commits using `sanskarin@outlook.in`.
- Native NASM interactive debugger accepts `step N` and `s N` (1–16 decimal), while bare `step` / `s` retain one-step behavior. Malformed counts are rejected while the tracee stays stopped.
- A new local `SESSION_REMAINING` slot counts verified synthetic step completions. CPU state is inspected and delta-printed after **each** completion, not only at the end of a batch. Cumulative diagnostic counts remain unchanged.
- Batch requests return to the prompt when the count reaches zero. Real signal-delivery stops immediately cancel the remainder and preserve pending signal decisions; synthetic exec/exit ptrace events cancel the batch before automatic continuation.
- Added 14 Bash integration cases using native NASM fixtures for exact/aliased/mixed count requests, malformed input, pending SIGILL/SIGSEGV/SIGTRAP, forwarding, concise CPU deltas, code inspection, early program exit and EOF.
- **131/131 checks passed** on both Ubuntu 22.04 and Ubuntu 24.04, on the final PR head and merged main: https://github.com/sanskarIN/Rewind64/actions/runs/39363424631 . The gated [pre-release workflow](https://github.com/sanskarIN/Rewind64/actions/runs/39363424542) succeeded and uploaded the Linux x86-64 executable archive plus SHA-256 checksum.
- Remains Linux x86-64 only, Python-free and single-tracee. No process attachment, source-level debugger, trace recording, replay or reverse stepping is implemented.


## v0.2.5 bounded memory inspection and interactive hardening — 2026-10-20 (experimental prerelease published)

- **Published:** [v0.2.5 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.5). The work was merged through [PR #15](https://github.com/sanskarIN/Rewind64/pull/15), with 12 authored commits using `sanskarin@outlook.in`.
- Added `mem 0xHEX [1..4]` / `m 0xHEX [1..4]` with a strict decimal count, a one-word default, a maximum of four consecutive eight-byte reads, range-overflow preflight, and per-word `errno`-safe ptrace handling.
- Rejected invalid counts, extraneous spaces and address arithmetic wrap without running the tracee or forwarding pending signals.
- Hardened the input loop so a command longer than the 63-byte `fgets` payload is drained to newline/EOF and discarded, preventing its suffix from being dispatched independently.
- Added native Bash regression cases for four words, two words, an explicit single word, malformed counts, 64-bit range wrap, long input with a `continue` suffix, long input at EOF, and the maximum accepted line length.
- **117/117 native integration tests passed on both Ubuntu 22.04 and 24.04** on the final PR head: https://github.com/sanskarIN/Rewind64/actions/runs/39361937180 . The release workflow rebuilt, tested, packaged and published the Linux binary and SHA-256 checksums: https://github.com/sanskarIN/Rewind64/actions/runs/39362052585 . This work does not implement recording, reverse stepping, replay, attach, or a Windows backend. Python remains absent from the build and tests.

## v0.2.4 strict single-word memory inspection — 2026-10-19

- **Published:** [v0.2.4 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.4), not stable. Fresh native NASM build, 109 integration tests, Linux archive packaging and SHA-256 checksum publication succeeded: https://github.com/sanskarIN/Rewind64/actions/runs/39277396958 .
- Added `mem 0xHEX` / `m 0xHEX` in `platforms/linux/debugger.asm`. The NASM address parser accepts a `0x` / `0X` prefix and 1–16 hex digits, rejects signs, malformed/trailing input and overflow without resuming the tracee, and performs exactly one `PTRACE_PEEKDATA` read per valid command.
- Clears `errno` before each ptrace read and distinguishes a legitimate `0xffffffffffffffff` word from a failed `-1` return. Errors (including unmapped/invalid addresses) are nonfatal to the interactive command loop; pending signals remain pending.
- Expanded Python-free Bash test coverage from 99 to **109 tests** using `nm` to resolve `words` and `_start` in native Assembly ELF fixtures, testing known values, all-ones, uppercase hexadecimal input, malformed/overflow values, unmapped and high addresses, repeated reads, concise mode, and inspection during pending SIGILL.
- All executable debugging behavior remains written in NASM Assembly. No Python files or dependencies; existing Boost Software License 1.0, Linux x86-64 scope, and author email `sanskarin@outlook.in` are retained.
- **109/109 native integration checks passed** on Ubuntu 22.04 and 24.04 on the final pull request and merged main: https://github.com/sanskarIN/Rewind64/actions/runs/39277396999 .
- This is not memory writing, a memory dump service, a disassembler, a breakpoint manager, trace recording, reverse stepping, multi-process following, Windows/macOS support, or stable release.

## v0.2.3 bounded stack inspection — 2026-10-19

- **Published:** [v0.2.3 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.3), not stable. Native NASM build/tests, Linux archive packaging and SHA-256 checksum upload passed: https://github.com/sanskarIN/Rewind64/actions/runs/39271480022 .
- Added `stack` / `k` interactive command. It calls `PTRACE_GETREGS` to refresh RSP and prints four 64-bit words at `RSP`, `RSP+8`, `RSP+16`, and `RSP+24` using `PTRACE_PEEKDATA`, for a strict maximum of 32 bytes per command. No tracee state is changed.
- Before each peek, resets `errno`; a return of `-1` is only a failure if `errno` is nonzero, allowing valid `0xffffffffffffffff` words. Invalid or unreadable RSP addresses produce a nonfatal error, do not inject signals, and leave the tracee stopped.
- Added pure NASM `tests/fixtures/stack_words.asm` for predictable RSP contents (including all-ones and zero words) and `tests/fixtures/invalid_rsp.asm` for unmapped-stack recovery. The invalid-RSP fixture is inspected then quit while stopped, not resumed.
- Expanded Python-free Bash suite from 92 to **99 tests** covering initial, post-step, compact, pending SIGILL, alias/repeat, combined code/stack, and invalid RSP behaviors. **99/99 native tests passed on Ubuntu 22.04 and 24.04** on the final PR head and merged main: https://github.com/sanskarIN/Rewind64/actions/runs/39271304135 .
- Retained Linux x86-64 only, one tracee, Boost Software License 1.0 and commit email `sanskarin@outlook.in`. No arbitrary memory address parser, disassembler, breakpoint management, recording, reverse stepping, replay or Windows/macOS support.

## v0.2.2 code-word inspection — 2026-10-19

- **Published:** [v0.2.2 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.2), not stable. Native NASM build, 92 integration checks, release archive and SHA-256 checksums passed and were publicly published: https://github.com/sanskarIN/Rewind64/actions/runs/39265396779 .
- Added `code` / `x` to the native NASM interactive command loop. The command refreshes the register snapshot and reads one eight-byte word at the current stopped RIP via `PTRACE_PEEKTEXT`; it prints the address and word without modifying registers, memory or pending signals.
- Correctly disambiguated a valid all-ones `ptrace` word (return `-1`) from a failure by resetting `errno` before the read and checking it after `-1`. Genuine peek errors are reported without terminating the interactive debugger.
- Added `tests/fixtures/all_ones.asm`, whose first eight code bytes are exactly `0xffffffffffffffff`; tests inspect but **never resume the invalid instruction stream**.
- Expanded Python-free Bash tests from 86 to **92**: code inspection at initial RIP, after a step, in compact mode, with explicit register inspection, at a pending SIGILL stop, and with an all-ones ptrace word.
- Native NASM/ELF CI passed **92/92** tests on Ubuntu 22.04 and 24.04 in the final pull request: https://github.com/sanskarIN/Rewind64/actions/runs/39265167602 .
- Scope remains Linux x86-64 single-tracee experimental. No arbitrary-address memory browsing, disassembly, breakpoint management, recording, reverse stepping, deterministic replay or Windows/macOS backend. Boost Software License 1.0 and author email `sanskarin@outlook.in` retained.

## v0.2.1 interactive signal hardening — 2026-10-19

- **Published:** [v0.2.1 experimental Linux x86-64 prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.1), not stable. Clean native NASM build and Bash tests, SHA-256 archive packaging and release publishing passed: https://github.com/sanskarIN/Rewind64/actions/runs/39235173579 .
- Fixed a behavior that automatically continued when `PTRACE_SINGLESTEP` encountered a genuine application signal. Interactive mode now reports the stop, preserves the pending signal and returns to the prompt, allowing `regs`, `status`, `step`, `continue` or `quit`.
- Implemented `status` (alias `i`) with PID, successfully completed interactive instruction steps, and pending signal number; improved printed interactive command help accordingly.
- Pending signals are forwarded **once** via successful `PTRACE_SINGLESTEP` or `PTRACE_CONT` requests; `quit` or EOF clean up without forwarding. The `Signals forwarded: N` counter is now incremented only after a successful nonzero-signal ptrace resume request, fixing earlier over-counting of inspected-but-undelivered signals.
- Reset interactive step state when transitioning through kernel exec/exit events, retaining automatic event continuation where appropriate.
- Expanded the Python-free integration suite from 78 to **86 tests**. Native NASM/ELF builds and **86/86 Bash tests passed** on Ubuntu 22.04 and 24.04 in PR and merged main: https://github.com/sanskarIN/Rewind64/actions/runs/39235173746 .
- Retained Boost Software License 1.0, author email `sanskarin@outlook.in`, one launched Linux x86-64 tracee, and no recording/reverse execution, attach, breakpoints or comprehensive job-control tracing.

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
