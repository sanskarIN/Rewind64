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
version() { assert_contains version 'v0.1.3-pre'; }
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
  assert_contains zero 'Target exited with status 0'
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
usr1() { assert_contains usr1 'Target terminated by signal 10'; }
step_trap() {
  assert_count step_trap 'After step:' 1 &&
  assert_contains step_trap 'Steps completed: 1 / 5' &&
  assert_contains step_trap 'Target terminated by signal 5'
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
  assert_count registers 'Register changes: 2' 4
}

exit255() {
  assert_contains exit255 'Target exited with status 255' &&
  assert_contains exit255 'Steps completed: 1 / 1'
}
term_signal() {
  assert_contains term_signal 'Target terminated by signal 15' &&
  assert_contains term_signal 'Steps completed: 2 / 2'
}
segfault() {
  assert_contains segfault 'Target terminated by signal 11' &&
  assert_contains segfault 'Steps completed: 1 / 5' &&
  assert_count segfault '    Changed RIP:' 1
}
max_steps() {
  assert_count max_steps 'After step:' 64 &&
  assert_count max_steps '    Changed RIP:' 64 &&
  assert_contains max_steps 'Steps completed: 64 / 64' &&
  assert_contains max_steps 'Target exited with status 0'
}
invalid() { assert_contains invalid 'steps must be in range'; }

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
check step_trap 133 "$BIN" run --steps 5 "$ROOT/build/trap"
check early_exit 0 "$BIN" run --steps 64 "$ROOT/build/exit0"
check registers 0 "$BIN" run --steps 4 "$ROOT/build/register_fixture"
check exit255 255 "$BIN" run "$ROOT/build/exit255"
check term_signal 143 "$BIN" run --steps 2 "$ROOT/build/signal_term"
check segfault 139 "$BIN" run --steps 5 "$ROOT/build/segv"
check max_steps 0 "$BIN" run --steps 64 "$ROOT/build/long_steps"
for bad in 0 -1 abc 65 99999999999 1x; do
  check invalid 2 "$BIN" run --steps "$bad" "$ROOT/build/exit0"
done

printf '%d passed; %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
