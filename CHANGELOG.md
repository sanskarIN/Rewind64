# Changelog

## v0.1.0 - 2026-10-18 (experimental prerelease)

- Initial Linux x86-64 native CLI and NASM debugger source.
- Child launch with ptrace, exit-kill option, RIP/RSP and RAX/RBX/RCX/RDX inspection, one instruction step, and process exit diagnostics.
- Improved early exit handling for missing executables and passing native NASM GitHub Actions builds.
- Integration fixtures for exit 0, exit 7, and application-generated SIGTRAP; argument and error checks.
- CI and contributor/security/architecture documentation.

The Linux x86-64 prerelease ships an archive and SHA-256 checksum. No stable release has been declared; lifecycle edge cases and broader validation remain before future stable releases.
