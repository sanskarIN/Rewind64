# Machine-readable capability discovery

Rewind64 development v0.2.14 adds a static `--capabilities` command for IDE integrations, automated tooling, and end users who need to distinguish implemented features from roadmap ideas.

```sh
./build/rewind64 --capabilities
```

The command prints **one JSON document to stdout**, adds no framing text, and exits **0**. It does not fork, launch a program, call ptrace, inspect files, contact a server or require tracing privileges. Supplying an argument (`--capabilities anything`) prints a diagnostic and exits **2**; arguments are not silently ignored.

## Example schema (v1)

```json
{
  "schema": 1,
  "name": "Rewind64",
  "version": "0.2.14-pre",
  "platform": "linux-x86_64",
  "debug_backend": "ptrace",
  "execution": {
    "modes": ["bounded-step", "observe-only", "interactive"],
    "max_cli_steps": 64,
    "max_interactive_step_batch": 16
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

The Python-free Bash/native integration suite checks the exact command, JSON fields, limitation flags, help discovery, repeatability and rejection of unexpected arguments. When `jq` is already installed, the suite additionally parses the document and checks JSON field types/values without making `jq` a hard build prerequisite. The current suite targets **222 tests** (204 through v0.2.12, 13 for v0.2.13, and 5 for v0.2.14), pending GitHub CI on Ubuntu 22.04 and 24.04.

This document describes the **v0.2.14 development branch**, not a published release.
