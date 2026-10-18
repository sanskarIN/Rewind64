# Changelog

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
