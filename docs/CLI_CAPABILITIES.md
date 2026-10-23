# Machine-readable capability discovery

Rewind64 v0.2.14 introduced a static `--capabilities` command for IDE integrations, automated tooling, and end users who need to distinguish implemented features from roadmap ideas.

```sh
./build/rewind64 --capabilities
```

The command prints **one JSON document to stdout**, adds no framing text, and exits **0**. It does not fork, launch a program, call ptrace, inspect files, contact a server or require tracing privileges. Supplying an argument (`--capabilities anything`) prints a diagnostic and exits **2**; arguments are not silently ignored.

## Example schema (v1)

```json
{
  "schema": 1,
  "name": "Rewind64",
  "version": "0.2.17-pre",
  "platform": "linux-x86_64",
  "debug_backend": "ptrace",
  "execution": {
    "modes": ["bounded-step", "observe-only", "interactive"],
    "max_cli_steps": 64,
    "max_interactive_step_batch": 16,
    "stop_on_exec": true,\n    "rip_watch": true,\n    "rip_watch_max_steps": 64
  },
  "inspection": {
    "registers": true,
    "memory_words_max": 4,
    "stack_words_max": 4,
    "rip_bytes_max": 8,
    "rip_history_max": 16,
    "signal_history_max": 8,
    "signal_history_tail": true
  },
  "limitations": {
    "single_launched_tracee": true,
    "forward_only": true,
    "recording": false,
    "reverse_execution": false,
    "replay": false,
    "breakpoints": false,
    "attach": false
  }
}
```

Numbers are maxima for documented user-facing commands, not available kernel resources. `memory_words_max=4` means four 8-byte words; `signal_history_max=8` means *eight most recently retained validated stops*, not the total number of observed stops. `single_launched_tracee` means debugging one target started by Rewind64, not attaching to arbitrary processes. `forward_only` means execution never runs backwards. The `version` matches the CLI `--version` development build.

### Consumers

- Read `schema` first. Schema 1 defines the keys above. Ignore unfamiliar keys within a recognized schema, but fail safely on unsupported schema versions.
- Show unsupported features as unavailable rather than inventing commands for them. Do **not** interpret the presence of `signals` or RIP history as a recording/replay engine.
- Do not infer real runtime ptrace permission from the static output. Host kernel policy may block debugging even when the feature is compiled in.
- `--capabilities` reports compile-time support only and never auto-discovers installed/available Windows or macOS backend features.
- Do not share process contents from a debugging session without authorization.

## Quality gates

The Python-free Bash/native integration suite checks the exact command, JSON fields, limitation flags, help discovery, repeatability and rejection of unexpected arguments. When `jq` is already installed, the suite additionally parses the document and checks JSON field types/values without making `jq` a hard build prerequisite. The published v0.2.15 suite passed **243 tests** on Ubuntu 22.04 and 24.04. The published v0.2.16 release adds 16 exec-stop tests, with **259/259 passing** on Ubuntu 22.04 and 24.04. The v0.2.17 development branch adds 17 finite RIP-watch tests, targeting **276**, pending CI.

This schema was introduced in published v0.2.14. The example above shows the **v0.2.17 development version's** compiled feature contract. Its `execution.stop_on_exec` property is true only for builds implementing the interactive `until-exec` command and denotes compiled support, not host ptrace permission. Consumers must treat the version field as build-dependent and may use the [published v0.2.16 release](https://github.com/sanskarIN/Rewind64/releases/tag/v0.2.16) for a released executable.

The `execution.rip_watch` field describes a **bounded 64-step, non-patching** address watch. It does not mean software breakpoints have been implemented. `limitations.breakpoints` intentionally remains `false` pending the separate breakpoint implementation and regression coverage.
