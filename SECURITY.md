# Security policy

Rewind64 is **experimental, not a security boundary**, and intended solely for programs you own or have explicit permission to debug.

- Debugger targets inherit the caller's environment and permissions; do not execute untrusted programs just to inspect them.
- This CLI currently launches an explicit target. It does not support stealthy attachments, kernel-policy bypasses, or automatic uploads.
- Debug traces, when implemented, may expose secrets from target memory. Keep any debug outputs local and protect them accordingly.
- Operating system ptrace and container restrictions remain in force.
- Do not publish private traces, process memory, or exploit proof-of-concepts in public reports.

To disclose a suspected vulnerability privately, use the GitHub repository's security advisory feature when enabled, or the maintainer's [contact page](https://sanskarin.github.io/contact/). No response-time guarantee is made.
