# Rewind64 development progress

## Scope

Phase 1, `v0.1.0-dev`, Linux x86-64 only. No public release created.

## New source and tooling

- `src/cli/main.asm`: NASM CLI parser, version/help, `run` command.
- `platforms/linux/debugger.asm`: process launch, ptrace register snapshots, single-step, signal forwarding, exit reporting, error cleanup.
- `tests/fixtures/*.asm`: exit 0, exit 7, application SIGTRAP test programs.
- `tests/integration/test_cli.py`: eight black-box integration tests, including normal exits, a failed exec, and signal forwarding.
- Expanded Linux register snapshots include RAX, RBX, RCX, RDX, RIP, and RSP. Early child exits are reported without attempting to kill an already-reaped process.
- `Makefile`, `.gitignore`, Linux GitHub Actions CI, documentation and policies.

## Verification

- Local Linux x86-64 environment: 8/8 integration tests passed using a **temporary GNU assembler translation of NASM syntax**, because NASM was not installed in the local container. This is **not** evidence of a native NASM compilation.
- **Native NASM CI passed on GitHub Actions** with successful assemble/link, integration testing, artifact checksum, and upload steps: https://github.com/sanskarIN/Rewind64/actions/runs/39094217690
- Latest local GNU assembler adaptation: 8/8 tests passed; GitHub CI is authoritative for canonical NASM.
- Windows/macOS and ARM64: not implemented, not tested.
- No benchmark claims or binary artifacts published.

## Limitations / next steps

1. Keep native NASM CI green; extend fault injection, cleanup, and register inspection tests.
2. Review ABI assumptions, stack alignment, signal handling, and child cleanup under more fault conditions.
3. Add full register reporting and opt-in repeated stepping; define reliable program exit/error distinctions.
4. Study Windows/macOS designs only after the initial Linux foundation is healthy.
5. Consider an **experimental** v0.1.0 prerelease only when release acceptance checks pass; do not label this stable.
