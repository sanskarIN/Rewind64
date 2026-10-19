#!/usr/bin/env bash
# Rewind64 regression suite: Assembly fixtures, shell orchestration.
# No Python is used anywhere in the build or test path.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN="$ROOT/build/rewind64"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT

pass=0
fail=0
output=""
status=0

run_case() {
  local name="$1" expected="$2"
  shift 2
  status=0
  output="$(timeout --signal=TERM --kill-after=1s 10s "$@" 2>&1)" || status=$?
  if [[ "$status" -ne "$expected" ]]; then
    printf 'FAIL %-29s expected exit %s, got %s\n%s\n' "$name" "$expected" "$status" "$output" >&2
    return 1
  fi
  return 0
}

assert_contains() {
  local label="$1" fragment="$2"
  if [[ "$output" != *"$fragment"* ]]; then
    printf 'FAIL %s missing text: %s\noutput: %s\n' "$label" "$fragment" "$output" >&2
    return 1
  fi
}
assert_count() {
  local label="$1" fragment="$2" expected="$3"
  local count=0 tail="$output"
  while [[ "$tail" == *"$fragment"* ]]; do
    tail="${tail#*"$fragment"}"
    ((count+=1))
  done
  if [[ "$count" -ne "$expected" ]]; then
    printf 'FAIL %s: expected %d occurrences of %s, got %d\n%s\n' "$label" "$expected" "$fragment" "$count" "$output" >&2
    return 1
  fi
}
check() {
  local name="$1" expected="$2"
  shift 2
  if run_case "$name" "$expected" "$@" && "$name"; then
    printf 'PASS %s\n' "$name"
    ((pass+=1))
  else
    # run_case already logs a failure; other assertions get counted here.
    # Callers deliberately avoid invoking assertions after run_case failed.
    ((fail+=1))
  fi
}

# Each assertion group is a function so Bash conditionals propagate failure safely.
help() { assert_contains help 'Trace every instruction' && assert_contains help 'run [--steps N]'; }
version() { assert_contains version 'v0.1.6-pre'; }
unsupported() { assert_contains unsupported 'unsupported command'; }
usage() { assert_contains usage 'Error:'; }
zero() {
  assert_contains zero 'Initial stop:' &&
  assert_count zero 'After step:' 1 &&
  assert_count zero '    GPR:' 2 &&
  assert_contains zero 'RFLAGS=0x' &&
  assert_contains zero 'FS_BASE=0x' &&
  assert_contains zero 'Register changes: ' &&
  assert_contains zero '    Changed RIP:' &&
  assert_contains zero 'Steps completed: 1 / 1' &&
  assert_contains zero 'Target exited with status 0' &&
  assert_contains zero 'Signals forwarded: 0' &&
  assert_contains zero 'Ptrace exit event:' &&
  assert_contains zero 'Ptrace events: exec=0 exit=1'
}
seven() { assert_contains seven 'Target exited with status 7'; }
trap_signal() { assert_contains trap_signal 'Target terminated by signal 5'; }
missing_exec() { assert_contains missing_exec 'execvp'; }
triple() {
  assert_count triple 'After step:' 3 &&
  assert_contains triple 'Steps completed: 3 / 3' &&
  assert_contains triple 'Target exited with status 0'
}
forward_args() { assert_contains forward_args 'Target exited with status 0'; }
usr1() { assert_contains usr1 'Target terminated by signal 10' && assert_contains usr1 'Signals forwarded: 1'; }
step_trap() {
  assert_count step_trap 'After step:' 1 &&
  assert_contains step_trap 'Steps completed: 1 / 5' &&
  assert_contains step_trap 'Target terminated by signal 5' &&
  assert_contains step_trap 'Signals forwarded: 1'
}
early_exit() {
  assert_count early_exit 'After step:' 2 &&
  assert_contains early_exit 'Steps completed: 2 / 64' &&
  assert_contains early_exit 'Target exited with status 0'
}
registers() {
  assert_count registers '    GPR:' 5 &&
  assert_count registers '    Bases:' 5 &&
  assert_contains registers 'RAX=0x1122334455667788' &&
  assert_contains registers 'RBX=0x8877665544332211' &&
  assert_contains registers 'R12=0x1234567890abcdef' &&
  assert_contains registers 'R13=0xfedcba0987654321' &&
  assert_contains registers 'RFLAGS=0x' &&
  assert_contains registers 'Steps completed: 4 / 4' &&
  assert_count registers '    Changed RIP:' 4 &&
  assert_contains registers '    Changed RAX:' &&
  assert_contains registers '    Changed RBX:' &&
  assert_contains registers '    Changed R12:' &&
  assert_contains registers '    Changed R13:' &&
  assert_count registers 'Register changes:' 4
}

exit255() {
  assert_contains exit255 'Target exited with status 255' &&
  assert_contains exit255 'Steps completed: 1 / 1'
}
term_signal() {
  assert_contains term_signal 'Target terminated by signal 15' &&
  assert_contains term_signal 'Steps completed: 2 / 2' &&
  assert_contains term_signal 'Signal-delivery stop: signal 15' &&
  assert_contains term_signal 'Signals forwarded: 1'
}
segfault() {
  assert_contains segfault 'Target terminated by signal 11' &&
  assert_contains segfault 'Steps completed: 1 / 5' &&
  assert_count segfault '    Changed RIP:' 1 &&
  assert_contains segfault 'Signals forwarded: 1'
}
max_steps() {
  assert_count max_steps 'After step:' 64 &&
  assert_count max_steps '    Changed RIP:' 64 &&
  assert_contains max_steps 'Steps completed: 64 / 64' &&
  assert_contains max_steps 'Target exited with status 0'
}
invalid() { assert_contains invalid 'steps must be in range'; }
compact() {
  assert_contains compact 'Initial stop:' &&
  assert_count compact 'After step:' 3 &&
  assert_count compact '    GPR:' 0 &&
  assert_count compact '    Bases:' 0 &&
  assert_count compact 'Register changes:' 3 &&
  assert_contains compact '    Changed RIP:' &&
  assert_contains compact 'Steps completed: 3 / 3'
}
compact_reverse() {
  assert_contains compact_reverse 'Initial stop:' &&
  assert_count compact_reverse 'After step:' 2 &&
  assert_count compact_reverse '    GPR:' 0 &&
  assert_count compact_reverse 'Register changes:' 2 &&
  assert_contains compact_reverse 'Target exited with status 0'
}
compact_default() {
  assert_contains compact_default 'Initial stop:' &&
  assert_count compact_default 'After step:' 1 &&
  assert_count compact_default '    GPR:' 0 &&
  assert_contains compact_default 'Register changes:' &&
  assert_contains compact_default 'Steps completed: 1 / 1'
}
duplicate() { assert_contains duplicate 'duplicate option'; }
flag_usage() { assert_contains flag_usage 'Error:'; }
illegal() {
  assert_contains illegal 'Target terminated by signal 4' &&
  assert_contains illegal 'Steps completed: 0 / 4'
}
divide_fault() {
  assert_contains divide_fault 'Target terminated by signal 8' &&
  assert_contains divide_fault 'Steps completed: 3 / 5'
}
exit42() { assert_contains exit42 'Target exited with status 42'; }
dashed_target() { assert_contains dashed_target 'Target exited with status 42'; }
handled_signals() {
  assert_contains handled_signals 'Target exited with status 0' &&
  assert_contains handled_signals 'Steps completed: 2 / 2' &&
  assert_count handled_signals 'Signal-delivery stop: signal 10' 2 &&
  assert_contains handled_signals 'Signals forwarded: 2' &&
  assert_contains handled_signals 'Ptrace events: exec=0 exit=1'
}
handled_compact() {
  assert_contains handled_compact 'Target exited with status 0' &&
  assert_count handled_compact '    GPR:' 0 &&
  assert_count handled_compact 'Signal-delivery stop: signal 10' 2 &&
  assert_contains handled_compact 'Signals forwarded: 2' &&
  assert_contains handled_compact 'Ptrace events: exec=0 exit=1'
}
reexec() {
  assert_contains reexec 'Ptrace exec event:' &&
  assert_contains reexec 'Ptrace exit event:' &&
  assert_contains reexec 'Ptrace events: exec=1 exit=1' &&
  assert_contains reexec 'Signals forwarded: 0' &&
  assert_contains reexec 'Target exited with status 42'
}
reexec_compact() {
  assert_contains reexec_compact 'Ptrace events: exec=1 exit=1' &&
  assert_contains reexec_compact 'Target exited with status 42' &&
  assert_contains reexec_compact 'Signals forwarded: 0' &&
  assert_count reexec_compact '    GPR:' 0
}
early_exit_event() {
  assert_contains early_exit_event 'Target exited with status 0' &&
  assert_contains early_exit_event 'Steps completed: 2 / 64' &&
  assert_contains early_exit_event 'Ptrace events: exec=0 exit=1'
}
exits_zero_signals() {
  assert_contains exits_zero_signals 'Target exited with status 42' &&
  assert_contains exits_zero_signals 'Signals forwarded: 0' &&
  assert_contains exits_zero_signals 'Ptrace events: exec=0 exit=1'
}



# Run tests directly to avoid interpreting executable arguments in a shell.
check help 0 "$BIN" --help
check version 0 "$BIN" --version
check unsupported 2 "$BIN" replay absent.r64
check usage 2 "$BIN" run
check zero 0 "$BIN" run "$ROOT/build/exit0"
check seven 7 "$BIN" run "$ROOT/build/exit7"
check trap_signal 133 "$BIN" run "$ROOT/build/trap"
check missing_exec 127 "$BIN" run /definitely-not-a-real-rewind64-program
check triple 0 "$BIN" run --steps 3 "$ROOT/build/argv" hello
check forward_args 0 "$BIN" run --steps 2 "$ROOT/build/argv" hello
check usr1 138 "$BIN" run "$ROOT/build/signal_usr1"
check handled_signals 0 "$BIN" run --steps 2 "$ROOT/build/handled_signal"
check handled_compact 0 "$BIN" run --changes-only --steps 2 "$ROOT/build/handled_signal"
check step_trap 133 "$BIN" run --steps 5 "$ROOT/build/trap"
check early_exit 0 "$BIN" run --steps 64 "$ROOT/build/exit0"
check registers 0 "$BIN" run --steps 4 "$ROOT/build/register_fixture"
check exit255 255 "$BIN" run "$ROOT/build/exit255"
check term_signal 143 "$BIN" run --steps 2 "$ROOT/build/signal_term"
check segfault 139 "$BIN" run --steps 5 "$ROOT/build/segv"
check max_steps 0 "$BIN" run --steps 64 "$ROOT/build/long_steps"
check compact 0 "$BIN" run --steps 3 --changes-only "$ROOT/build/long_steps"
check compact_reverse 0 "$BIN" run --changes-only --steps 2 "$ROOT/build/argv" hello
check compact_default 0 "$BIN" run --changes-only "$ROOT/build/exit0"
check duplicate 2 "$BIN" run --changes-only --changes-only "$ROOT/build/exit0"
check duplicate 2 "$BIN" run --steps 2 --steps 3 "$ROOT/build/exit0"
check flag_usage 2 "$BIN" run --changes-only
check flag_usage 2 "$BIN" run --
check flag_usage 2 "$BIN" run --steps 3
check illegal 132 "$BIN" run --steps 4 "$ROOT/build/illegal"
check divide_fault 136 "$BIN" run --steps 5 "$ROOT/build/divzero"
check exit42 42 "$BIN" run -- "$ROOT/build/exit42"
check exits_zero_signals 42 "$BIN" run --steps 2 "$ROOT/build/exit42"
check reexec 42 "$BIN" run --steps 1 "$ROOT/build/reexec" "$ROOT/build/exit42"
check reexec_compact 42 "$BIN" run --changes-only --steps 3 "$ROOT/build/reexec" "$ROOT/build/exit42"
check early_exit_event 0 "$BIN" run --steps 64 "$ROOT/build/exit0"
cp -- "$ROOT/build/exit42" "$tmp/--dash-program"
PATH="$tmp:$PATH" check dashed_target 42 "$BIN" run -- --dash-program
for bad in 0 -1 abc 65 99999999999 1x; do
  check invalid 2 "$BIN" run --steps "$bad" "$ROOT/build/exit0"
done

printf '%d passed; %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
