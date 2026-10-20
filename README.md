# Rewind64

**Explore execution. Trace every instruction. Understand the past.**

Rewind64 is an experimental, local-first, open-source native program inspection and debugger project. Its executable debugger logic is written in **x86-64 Assembly**. The first implementation targets **Linux x86-64 only**. Windows, macOS, recording, historical state navigation, and deterministic replay are roadmap items, **not implemented features**.

> **Current published release:** [v0.2.4 experimental prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.4), Linux x86-64 only. This version adds strictly validated read-only `mem 0xHEX` inspection, nonfatal ptrace errors, and Python-free CI on Ubuntu 22.04/24.04. No stable release or reversible execution is claimed. Debug only programs you own or have permission to debug. Recorded process state, once recording is implemented, may contain sensitive data.

> **In development (unreleased v0.2.5):** Optional `mem 0xHEX COUNT` reads 1–4 contiguous 64-bit words (8–32 bytes), with address wrap checks. Oversized session input is drained before command dispatch, avoiding accidental execution of a queued fragment.

## Implemented

- CLI `--help`, `--version`, and `run [--steps N | --observe-only | --interactive] [--changes-only] [--] PROGRAM [ARGS...]` commands. `N` is 1–64, default 1. Options can be given in either order; `--` ends option parsing.
- Launch targets using `fork`, `PTRACE_TRACEME`, and `execvp` (arguments are passed directly, without a shell).
- Observe the post-`exec` stop; inspect all 16 x86-64 general-purpose registers, RIP, RFLAGS, and FS/GS base addresses via `PTRACE_GETREGS`; and perform **up to 64** `PTRACE_SINGLESTEP` operations requested by the CLI.
- `--observe-only` prints the initial CPU register snapshot and follows process signals/exec/exit events to termination **without making any `PTRACE_SINGLESTEP` requests**. It is exclusive with `--steps N` and `--interactive`, and ends with `Steps completed: 0 / 0`.
- `--interactive` pauses at the initial executable stop and accepts Assembly-implemented `step` (`s`), `regs` (`r`), `status` (`i`), `code` (`x`), `stack` (`k`), `mem 0xHEX` (`m 0xHEX`), `continue` (`c`), `help`, and `quit` (`q`) commands on stdin. Recognized single-step completions **and verified signal-delivery stops during interactive stepping** return to the prompt; the user may inspect the stopped state, check pending signals, step again, continue or quit. `quit` and EOF terminate/reap the launched tracee. `status` prints PID, completed instruction steps and pending signal. `code`/`x` reads and displays one eight-byte word at the current RIP using Linux ptrace; the all-ones `-1` case is validated using `errno`. It is read-only and not a disassembler or arbitrary-address memory browser. `stack`/`k` similarly refreshes RSP and inspects at most four eight-byte words (32 bytes) beginning at the current stack pointer. All-ones words are valid, unreadable addresses produce a nonfatal diagnostic, and the command never follows pointers or changes tracee memory. `mem 0xHEX [COUNT]` / `m 0xHEX [COUNT]` reads **one to four contiguous eight-byte words** (default COUNT=1; max=4) at an explicitly supplied 1–16-digit hex address in the launched tracee using `PTRACE_PEEKDATA`. The strict NASM parser rejects signs, excess digits, invalid counts, excess whitespace and trailing characters; address-range arithmetic rejects 64-bit wrap before reading; unreadable addresses report a nonfatal error and preserve the stopped process. An overlong session line is discarded in full rather than treating its suffix as another command. Reads may expose sensitive data; don't share trace output casually. A pending signal is delivered only after a successful `step`/`continue` ptrace resume; `quit`/EOF cleans up without forwarding it. The session is **forward-only**, single-tracee, and does not include breakpoint or source-level debugging.
- Compare the 20 displayed register fields before/after each successful instruction step, show changed 64-bit values and a change count; snapshots remain in debugger-local memory (no trace recording). **`--changes-only` suppresses verbose full register tables** without suppressing the state changes.
- Verify the expected initial exec-time `SIGTRAP` before tracing. Continue and wait for target exit; report normal exit status or terminating signal, actual completed step count, and the **observed signal-delivery stop count**; forward subsequent application signals.
- Use `PTRACE_O_TRACEEXEC` and `PTRACE_O_TRACEEXIT` to observe in-process image replacement and process exit. Classify synthetic ptrace event stops by event number rather than forwarding them as application SIGTRAP, report separate exec/exit event counters, and print the kernel-supplied raw exit-event wait-status payload through `PTRACE_GETEVENTMSG`.
- Report signed `siginfo_t.si_code` values for valid signal-delivery stops (for example, `SI_USER=0` versus `SI_TKILL=-6` on Linux), and sender PID/UID for those two user-originated codes only; avoid interpreting kernel fault siginfo union data as a signal sender.
- Detect unsupported Linux job-control group stops via `PTRACE_GETSIGINFO` / `EINVAL`, report them explicitly, then terminate the stopped tracee instead of repeatedly forwarding `SIGSTOP`.
- Request `PTRACE_O_EXITKILL` and use a bounded kill/ptrace-continue/wait loop after debugger errors to drain intermediate ptrace exit stops before reaping the child.
- Linux NASM source, **Assembly-native fixtures**, Bash integration checks, and GitHub Actions CI on Ubuntu 22.04 and 24.04; **Python is not used**.

## Compatibility

| Platform | State |
| --- | --- |
| Linux x86-64, glibc, NASM ELF64 | Experimental; CI on Ubuntu 22.04 and 24.04 |
| Windows x86-64 | Planned, not implemented |
| macOS x86-64 | Planned, not implemented |
| ARM64 / FreeBSD | Future investigation |

Requires Linux permission for self-child tracing. Container seccomp and host security policies may deny tracing; Rewind64 does not bypass those restrictions. Linux ABI offsets are specifically for x86-64 `struct user_regs_struct`. The prototype uses libc for process-management wrapper calls, `printf`, and `execvp`; its debugger logic remains Assembly.

## Build

Requirements: Linux x86-64, `nasm`, `cc` (with glibc toolchain), `ld`, `make`, `bash`, coreutils `timeout`; **no Python**.

```sh
make
make fixtures
make test
```

Built executable: `build/rewind64`. A checksum-verified native Linux archive is available on the [v0.2.4 release page](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.4). Build output is untracked. CI assembles canonical source with NASM, tests the result, and uploads a short-retention experimental binary on the [Actions page](https://github.com/sanskarIN/Rewind64/actions). Do not infer binary compatibility across OSes.

## Usage

```sh
./build/rewind64 --help
./build/rewind64 --version
./build/rewind64 run ./build/exit0
./build/rewind64 run --steps 4 ./build/register_fixture
./build/rewind64 run --interactive ./build/stack_words  # at prompt: mem 0xADDRESS 4
./build/rewind64 run --interactive ./build/all_ones
./build/rewind64 run --interactive ./build/illegal
./build/rewind64 run --interactive ./build/long_steps
./build/rewind64 run --interactive --changes-only ./build/register_fixture
./build/rewind64 run --observe-only ./build/exit0
./build/rewind64 run --observe-only --changes-only ./build/handled_signal
./build/rewind64 run --steps 4 --changes-only ./build/register_fixture
./build/rewind64 run --changes-only --steps 3 ./build/long_steps
./build/rewind64 run --steps 2 ./build/argv hello
./build/rewind64 run /path/to/your/authorized/program arg1 arg2
```

The `run` command waits for an `exec` stop, prints initial general-purpose register values, RIP, RSP, RFLAGS and FS/GS base addresses, executes up to the requested number of instructions (default one), and prints a register snapshot **and register-value deltas** after each completed step. With `--changes-only`, it omits the repeated full register tables but retains stop headers and register deltas. With `--observe-only`, it captures only the initial register state, issues no single-step instructions, and continues to report signals and exec/exit events. With `--interactive`, it exposes `rewind64> ` at the initial stop and after recognized step completions or signal stops during stepping, supporting repeatable `step`, `regs`, `status`, `code`, `stack`, `mem`, `continue`, `help`, and `quit` commands; `regs` prints the full current CPU state even in concise display mode. It then continues execution, reporting actual completed steps, `Signals forwarded: N` (successful nonzero-signal ptrace resume requests, not merely observed stops), and `Ptrace events: exec=N exit=N` at termination. These counters are diagnostics, not process history. **Memory access is limited to bounded read-only word ranges of at most 32 bytes via `mem`; there is no memory-writing command, dump facility, process attachment, breakpoint management, source-level debugging, disassembly, reverse execution or trace recording.** Commands such as `attach`, `trace`, and `replay` report unsupported-command errors.

The debugger exits with the target's normal status (0–255) when possible, or `128 + signal` on signal termination. A debugger error returns 1; a CLI argument error returns 2. These can overlap a target's chosen exit status; structured result codes are planned. A target failing to execute prints a diagnostic and exits with status 127; the pre-exec child failure is not reported as a successful trace.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for ABI notes and current module boundaries. At a glance: `src/cli/main.asm` handles commands; `src/registers/x86_64.asm` formats extended CPU state; `src/registers/delta.asm` compares successive CPU snapshots; `platforms/linux/debugger.asm` implements the Linux ptrace execution path; `tests/fixtures/` contains target executables; `tests/integration/` verifies CLI and process behavior. No other architecture or platform code exists yet.

## Roadmap

1. **v0.1.0:** First experimental Linux process inspection prerelease; **v0.1.1:** bounded stepping and Python-free tests; **v0.1.2:** full register presentation, step accounting, and expanded Linux CI; **v0.1.3:** forward-only register deltas and lifecycle regression tests; **v0.1.4:** opt-in concise CPU deltas, CLI flag ordering, initial-stop checks, and extended fault regressions; **v0.1.5:** signal-delivery diagnostics and repeated handled-signal tests; **v0.1.6:** ptrace exec/exit event classification and re-exec regression tests; **v0.1.7:** group-stop detection and bounded ptrace cleanup/reaping tests; **v0.1.8:** raw exit-event status and signed signal source diagnostics; **v0.1.9:** no-step observation mode and sender PID/UID for user-originated signals; **v0.2.0:** initial experimental interactive Assembly command loop with step, regs, continue and quit; **v0.2.1:** pending-signal handling during interactive stepping, status inspection, and signal-forwarding accounting; **v0.2.2:** read-only RIP code-word inspection and correct handling of valid all-ones ptrace values; **v0.2.3:** bounded four-word RSP stack inspection, invalid-address recovery, and new native Assembly fixtures; **v0.2.4:** strictly validated single-word address reads with `mem` / `m`; **v0.2.5 (in development):** optional 1–4-word reads, address-wrap guards and long-input draining.
2. **Future v0.3.x+:** Investigate and implement a verified Windows x86-64 backend (previously proposed for v0.2.0; deferred so interactive Linux sessions could be tested first).
3. **Future milestone:** Investigate macOS Intel debugging APIs and entitlements.
4. **Future milestone:** Platform abstraction, memory inspection, breakpoint management, and richer interactive stepping.
5. **v0.5.0:** Versioned execution trace format with bounded readers/writers.
6. **v0.6.0:** Historical trace inspection (distinct from true reverse execution).
7. **v0.7.0+:** Investigate restricted deterministic replay with verified nondeterminism capture.

Dates and versions are planning targets and not promises. A stable release requires a native NASM build, integration tests on the target OS, and a reviewed security and lifecycle audit.

## Open source and contributions

- License: [Boost Software License 1.0](LICENSE), already selected in this repository and retained here.
- Contributor guide: [CONTRIBUTING.md](CONTRIBUTING.md).
- Security guidance: [SECURITY.md](SECURITY.md).
- Project progress: [what_changed.md](what_changed.md).

Maintainer: [sanskarIN on GitHub](https://github.com/sanskarIN). Updates: [developer website](https://sanskarin.github.io), [contact](https://sanskarin.github.io/contact/), [X](https://x.com/SanskarCodes), [LinkedIn](https://linkedin.com/in/SanskarCodes).

## Support Rewind64

Development support is voluntary; no donation is required to use or contribute to Rewind64.

- [Buy Me a Coffee](https://buymeacoffee.com/SanskarCodes)
- [Razorpay](https://razorpay.me/@SanskarCodes)
- [PayPal.me](https://paypal.me/SanskarCodes)
