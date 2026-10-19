# Rewind64

**Explore execution. Trace every instruction. Understand the past.**

Rewind64 is an experimental, local-first, open-source native program inspection and debugger project. Its executable debugger logic is written in **x86-64 Assembly**. The first implementation targets **Linux x86-64 only**. Windows, macOS, recording, historical state navigation, and deterministic replay are roadmap items, **not implemented features**.

> **Current published release:** [v0.1.8 experimental prerelease](https://github.com/sanskarIN/Rewind64/releases/tag/v0.1.8), Linux x86-64 only. This version adds raw ptrace exit-event status, signed signal source diagnostics, and Python-free CI on Ubuntu 22.04/24.04. No stable release or reversible execution is claimed. Debug only programs you own or have permission to debug. Recorded process state, once recording is implemented, may contain sensitive data.

## Implemented

- CLI `--help`, `--version`, and `run [--steps N | --observe-only] [--changes-only] [--] PROGRAM [ARGS...]` commands. `N` is 1–64, default 1. Options can be given in either order; `--` ends option parsing.
- Launch targets using `fork`, `PTRACE_TRACEME`, and `execvp` (arguments are passed directly, without a shell).
- Observe the post-`exec` stop; inspect all 16 x86-64 general-purpose registers, RIP, RFLAGS, and FS/GS base addresses via `PTRACE_GETREGS`; and perform **up to 64** `PTRACE_SINGLESTEP` operations requested by the CLI.
- `--observe-only` prints the initial CPU register snapshot and follows process signals/exec/exit events to termination **without making any `PTRACE_SINGLESTEP` requests**. It is exclusive with `--steps N` and ends with `Steps completed: 0 / 0`.
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

Built executable: `build/rewind64`. A checksum-verified native Linux archive is available on the [v0.1.8 release page](https://github.com/sanskarIN/Rewind64/releases/tag/v0.1.8). Build output is untracked. CI assembles canonical source with NASM, tests the result, and uploads a short-retention experimental binary on the [Actions page](https://github.com/sanskarIN/Rewind64/actions). Do not infer binary compatibility across OSes.

## Usage

```sh
./build/rewind64 --help
./build/rewind64 --version
./build/rewind64 run ./build/exit0
./build/rewind64 run --steps 4 ./build/register_fixture
./build/rewind64 run --observe-only ./build/exit0
./build/rewind64 run --observe-only --changes-only ./build/handled_signal
./build/rewind64 run --steps 4 --changes-only ./build/register_fixture
./build/rewind64 run --changes-only --steps 3 ./build/long_steps
./build/rewind64 run --steps 2 ./build/argv hello
./build/rewind64 run /path/to/your/authorized/program arg1 arg2
```

The `run` command waits for an `exec` stop, prints initial general-purpose register values, RIP, RSP, RFLAGS and FS/GS base addresses, executes up to the requested number of instructions (default one), and prints a register snapshot **and register-value deltas** after each completed step. With `--changes-only`, it omits the repeated full register tables but retains stop headers and register deltas. With `--observe-only`, it captures only the initial register state, issues no single-step instructions, and continues to report signals and exec/exit events. It then continues execution, reporting actual completed steps, `Signals forwarded: N` (observed ptrace signal stops), and `Ptrace events: exec=N exit=N` at termination. These counters are diagnostics, not process history. **It does not offer interactive stepping, breakpoints, memory reading, reverse execution, or trace recording.** Commands such as `attach`, `trace`, and `replay` report unsupported-command errors.

The debugger exits with the target's normal status (0–255) when possible, or `128 + signal` on signal termination. A debugger error returns 1; a CLI argument error returns 2. These can overlap a target's chosen exit status; structured result codes are planned. A target failing to execute prints a diagnostic and exits with status 127; the pre-exec child failure is not reported as a successful trace.

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for ABI notes and current module boundaries. At a glance: `src/cli/main.asm` handles commands; `src/registers/x86_64.asm` formats extended CPU state; `src/registers/delta.asm` compares successive CPU snapshots; `platforms/linux/debugger.asm` implements the Linux ptrace execution path; `tests/fixtures/` contains target executables; `tests/integration/` verifies CLI and process behavior. No other architecture or platform code exists yet.

## Roadmap

1. **v0.1.0:** First experimental Linux process inspection prerelease; **v0.1.1:** bounded stepping and Python-free tests; **v0.1.2:** full register presentation, step accounting, and expanded Linux CI; **v0.1.3:** forward-only register deltas and lifecycle regression tests; **v0.1.4:** opt-in concise CPU deltas, CLI flag ordering, initial-stop checks, and extended fault regressions; **v0.1.5:** signal-delivery diagnostics and repeated handled-signal tests; **v0.1.6:** ptrace exec/exit event classification and re-exec regression tests; **v0.1.7:** group-stop detection and bounded ptrace cleanup/reaping tests; **v0.1.8:** raw exit-event status and signed signal source diagnostics; **v0.1.9:** no-step observation mode and sender PID/UID for user-originated signals.
2. **v0.2.0:** Investigate and implement a verified Windows x86-64 backend.
3. **v0.3.0:** Investigate macOS Intel debugging APIs and entitlements.
4. **v0.4.0:** Platform abstraction, memory inspection, breakpoint management, and interactive stepping.
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
