# Contributing to Rewind64

Rewind64 is an experimental Assembly-first systems project. Contributions are welcome for legitimate debugging, testing, documentation, and performance analysis.

1. Read the [architecture and limitations](docs/ARCHITECTURE.md) before editing.
2. Work on a descriptive feature branch and make focused commits.
3. Keep executable debugger logic in x86-64 Assembly; test/build scripts may use other languages.
4. Verify `make test` on a Linux x86-64 environment with NASM, and explain OS permission constraints if tracing is blocked.
5. Add negative, lifecycle, and regression tests for bug fixes. Do not claim unsupported platforms or replay semantics.
6. Document behavior and update `CHANGELOG.md` and `what_changed.md` when appropriate.
7. Respect all relevant software licenses; do not copy external sources into this repository without permission and attribution.

For security-sensitive issues follow [SECURITY.md](SECURITY.md), not the public issue tracker.
