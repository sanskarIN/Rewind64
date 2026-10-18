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
version() { assert_contains version 'v0.1.1-dev'; }
unsupported() { assert_contains unsupported 'unsupported command'; }
usage() { assert_contains usage 'Error:'; }
zero() {
  assert_contains zero 'Initial stop:' &&
  assert_count zero 'After step:' 1 &&
  assert_contains zero 'Registers:' &&
  assert_contains zero 'Target exited with status 0'
}
seven() { assert_contains seven 'Target exited with status 7'; }
trap_signal() { assert_contains trap_signal 'Target terminated by signal 5'; }
missing_exec() { assert_contains missing_exec 'execvp'; }
triple() {
  assert_count triple 'After step:' 3 &&
  assert_contains triple 'Target exited with status 0'
}
forward_args() { assert_contains forward_args 'Target exited with status 0'; }
usr1() { assert_contains usr1 'Target terminated by signal 10'; }
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
for bad in 0 -1 abc 65 99999999999 1x; do
  check invalid 2 "$BIN" run --steps "$bad" "$ROOT/build/exit0"
done

printf '%d passed; %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
