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
  if [[ "${1:-}" == session_exec ]]; then
    # Bash helpers cannot be execve'd by timeout; the helper times out the
    # real debugger subprocess after applying stdin redirection.
    output="$(session_exec "${@:2}" 2>&1)" || status=$?
  else
    output="$(timeout --signal=TERM --kill-after=1s 10s "$@" 2>&1)" || status=$?
  fi
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
help() { assert_contains help 'Trace every instruction' && assert_contains help 'run [--steps N | --observe-only | --interactive]' && assert_contains help 'without stepping'; }
version() { assert_contains version 'v0.2.12-pre'; }
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
  assert_contains zero 'Ptrace events: exec=0 exit=1' &&
  assert_contains zero 'Ptrace exit detail: raw_wait=0x00000000'
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
usr1() { assert_contains usr1 'Target terminated by signal 10' && assert_contains usr1 'Signals forwarded: 1' && assert_contains usr1 'Signal-delivery stop: signal 10 si_code=0' && assert_contains usr1 'Signal sender: pid=' && assert_contains usr1 'uid='; }
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
  assert_contains handled_signals 'Ptrace events: exec=0 exit=1' &&
  assert_count handled_signals 'Signal-delivery stop: signal 10 si_code=0' 2 &&
  assert_count handled_signals 'Signal sender: pid=' 2
}
handled_compact() {
  assert_contains handled_compact 'Target exited with status 0' &&
  assert_count handled_compact '    GPR:' 0 &&
  assert_count handled_compact 'Signal-delivery stop: signal 10' 2 &&
  assert_contains handled_compact 'Signals forwarded: 2' &&
  assert_contains handled_compact 'Ptrace events: exec=0 exit=1'
}
reexec() {
  assert_contains reexec 'Ptrace exit detail: raw_wait=0x00002a00' &&
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
group_stop() {
  assert_contains group_stop 'Signal-delivery stop: signal 19' &&
  assert_contains group_stop 'Error: job-control group stop is unsupported' &&
  assert_not_running group_stop
}
group_stop_compact() {
  assert_contains group_stop_compact 'Error: job-control group stop is unsupported' &&
  assert_count group_stop_compact '    GPR:' 0 &&
  assert_not_running group_stop_compact
}
group_stop_midstep() {
  assert_contains group_stop_midstep 'Error: job-control group stop is unsupported' &&
  assert_not_running group_stop_midstep
}
assert_not_running() {
  local label="$1" pid
  if [[ "$output" =~ Initial[[:space:]]stop:[[:space:]]pid=([0-9]+) ]]; then
    pid="${BASH_REMATCH[1]}"
  else
    printf 'FAIL %s: missing target pid in trace output\n' "$label" >&2
    return 1
  fi
  if kill -0 "$pid" 2>/dev/null; then
    printf 'FAIL %s: traced child %s survived failed debugger cleanup\n' "$label" "$pid" >&2
    return 1
  fi
}
early_exit_event() {
  assert_contains early_exit_event 'Target exited with status 0' &&
  assert_contains early_exit_event 'Steps completed: 2 / 64' &&
  assert_contains early_exit_event 'Ptrace events: exec=0 exit=1'
}
thread_signal() {
  assert_contains thread_signal 'Signal-delivery stop: signal 10 si_code=-6' &&
  assert_contains thread_signal 'Signals forwarded: 1' &&
  assert_contains thread_signal 'Target terminated by signal 10' &&
  assert_contains thread_signal 'Signal sender: pid=' &&
  assert_contains thread_signal 'uid='
}
thread_signal_compact() {
  assert_contains thread_signal_compact 'Signal-delivery stop: signal 10 si_code=-6' &&
  assert_count thread_signal_compact '    GPR:' 0 &&
  assert_contains thread_signal_compact 'Target terminated by signal 10'
}
exit_group() {
  assert_contains exit_group 'Target exited with status 23' &&
  assert_contains exit_group 'Ptrace exit detail: raw_wait=0x00001700' &&
  assert_contains exit_group 'Ptrace events: exec=0 exit=1' &&
  assert_contains exit_group 'Signals forwarded: 0'
}
exit_group_compact() {
  assert_contains exit_group_compact 'Target exited with status 23' &&
  assert_contains exit_group_compact 'Ptrace exit detail: raw_wait=0x00001700' &&
  assert_count exit_group_compact '    GPR:' 0
}
# Observation mode skips single-stepping but continues through ptrace events.
observe_exit0() {
  assert_count observe_exit0 'Initial stop:' 1 &&
  assert_count observe_exit0 'After step:' 0 &&
  assert_count observe_exit0 'Register changes:' 0 &&
  assert_contains observe_exit0 'Steps completed: 0 / 0' &&
  assert_contains observe_exit0 'Ptrace events: exec=0 exit=1' &&
  assert_contains observe_exit0 'Target exited with status 0'
}
observe_exit42() {
  assert_count observe_exit42 'After step:' 0 &&
  assert_contains observe_exit42 'Steps completed: 0 / 0' &&
  assert_contains observe_exit42 'Target exited with status 42'
}
observe_compact() {
  assert_count observe_compact '    GPR:' 0 &&
  assert_count observe_compact 'After step:' 0 &&
  assert_contains observe_compact 'Steps completed: 0 / 0' &&
  assert_contains observe_compact 'Ptrace exit detail: raw_wait=0x00001700' &&
  assert_contains observe_compact 'Target exited with status 23'
}
observe_reexec() {
  assert_count observe_reexec 'After step:' 0 &&
  assert_contains observe_reexec 'Steps completed: 0 / 0' &&
  assert_contains observe_reexec 'Ptrace events: exec=1 exit=1' &&
  assert_contains observe_reexec 'Target exited with status 42'
}
observe_handled() {
  assert_count observe_handled 'After step:' 0 &&
  assert_contains observe_handled 'Steps completed: 0 / 0' &&
  assert_count observe_handled 'Signal-delivery stop: signal 10 si_code=0' 2 &&
  assert_count observe_handled 'Signal sender: pid=' 2 &&
  assert_contains observe_handled 'Signals forwarded: 2' &&
  assert_contains observe_handled 'Target exited with status 0'
}
observe_user_signal() {
  assert_count observe_user_signal 'After step:' 0 &&
  assert_contains observe_user_signal 'Signal-delivery stop: signal 10 si_code=-6' &&
  assert_contains observe_user_signal 'Signal sender: pid=' &&
  assert_contains observe_user_signal 'Steps completed: 0 / 0' &&
  assert_contains observe_user_signal 'Target terminated by signal 10'
}
observe_group_stop() {
  assert_count observe_group_stop 'After step:' 0 &&
  assert_contains observe_group_stop 'Error: job-control group stop is unsupported' &&
  assert_not_running observe_group_stop
}
observe_args() {
  assert_contains observe_args 'Steps completed: 0 / 0' &&
  assert_contains observe_args 'Target exited with status 0'
}
conflict() { assert_contains conflict 'mutually exclusive'; }

# Pipe only fixed fixture command files into a real stdin-backed session.
# No shell evaluation of target arguments or Python test harness.
session_exec() {
  local commands="$1"
  shift
  timeout --signal=TERM --kill-after=1s 10s "$@" < "$commands"
}
session_continue() {
  assert_contains session_continue 'Interactive session:' &&
  assert_contains session_continue 'Interactive steps completed: 0' &&
  assert_contains session_continue 'Target exited with status 7' &&
  assert_count session_continue 'After step:' 0 &&
  assert_contains session_continue 'Ptrace events: exec=0 exit=1'
}
session_steps() {
  assert_contains session_steps 'Interactive steps completed: 2' &&
  assert_count session_steps 'After step:' 2 &&
  assert_count session_steps 'Register changes:' 2 &&
  assert_contains session_steps 'Target exited with status 0' &&
  assert_contains session_steps 'Ptrace events: exec=0 exit=1'
}
session_regs() {
  assert_contains session_regs 'Interactive steps completed: 1' &&
  assert_count session_regs '    GPR:' 1 &&
  assert_count session_regs 'After step:' 1 &&
  assert_contains session_regs 'Target exited with status 0'
}
session_quit() {
  assert_contains session_quit 'Interactive session ended; tracee terminated and reaped.' &&
  assert_contains session_quit 'Interactive steps completed: 0' &&
  assert_not_running session_quit
}
session_eof() {
  assert_contains session_eof 'Interactive session ended; tracee terminated and reaped.' &&
  assert_not_running session_eof
}
session_help() {
  assert_count session_help 'Interactive session:' 2 &&
  assert_contains session_help 'Unknown session command. Type help.' &&
  assert_contains session_help 'Interactive steps completed: 0' &&
  assert_not_running session_help
}
session_quit_after_steps() {
  assert_count session_quit_after_steps 'After step:' 3 &&
  assert_contains session_quit_after_steps 'Interactive steps completed: 3' &&
  assert_not_running session_quit_after_steps
}
session_signal() {
  assert_contains session_signal 'Interactive steps completed: 0' &&
  assert_contains session_signal 'Signal-delivery stop: signal 10 si_code=0' &&
  assert_contains session_signal 'Target terminated by signal 10'
}
session_reexec() {
  assert_contains session_reexec 'Ptrace events: exec=1 exit=1' &&
  assert_contains session_reexec 'Interactive steps completed: 0' &&
  assert_contains session_reexec 'Target exited with status 42'
}
session_group_stop() {
  assert_contains session_group_stop 'Error: job-control group stop is unsupported' &&
  assert_not_running session_group_stop
}
session_missing_exec() { assert_contains session_missing_exec 'execvp'; }
session_status_start() {
  assert_contains session_status_start 'Session status: pid=' &&
  assert_contains session_status_start 'steps=0 pending_signal=0' &&
  assert_contains session_status_start 'Interactive session ended;' &&
  assert_not_running session_status_start
}
session_status_steps() {
  assert_contains session_status_steps 'steps=2 pending_signal=0' &&
  assert_contains session_status_steps 'Interactive steps completed: 2' &&
  assert_count session_status_steps 'After step:' 2 &&
  assert_not_running session_status_steps
}
session_signal_ill() {
  assert_contains session_signal_ill 'Interactive signal stop: signal 4 pending' &&
  assert_contains session_signal_ill 'steps=0 pending_signal=4' &&
  assert_contains session_signal_ill 'Signal-delivery stop: signal 4' &&
  assert_contains session_signal_ill 'Signals forwarded: 1' &&
  assert_contains session_signal_ill 'Target terminated by signal 4' &&
  assert_count session_signal_ill 'After step:' 0
}
session_signal_segv() {
  assert_contains session_signal_segv 'Interactive signal stop: signal 11 pending' &&
  assert_contains session_signal_segv 'steps=1 pending_signal=11' &&
  assert_contains session_signal_segv 'Target terminated by signal 11' &&
  assert_contains session_signal_segv 'Signals forwarded: 1' &&
  assert_count session_signal_segv 'After step:' 1
}
session_signal_trap() {
  assert_contains session_signal_trap 'Interactive signal stop: signal 5 pending' &&
  assert_contains session_signal_trap 'steps=1 pending_signal=5' &&
  assert_contains session_signal_trap 'Target terminated by signal 5' &&
  assert_contains session_signal_trap 'Signals forwarded: 1'
}
session_signal_quit() {
  assert_contains session_signal_quit 'Interactive signal stop: signal 4 pending' &&
  assert_contains session_signal_quit 'steps=0 pending_signal=4' &&
  assert_contains session_signal_quit 'Interactive session ended; tracee terminated and reaped.' &&
  assert_contains session_signal_quit 'Signals forwarded: 0' &&
  assert_not_running session_signal_quit
}
session_signal_step() {
  assert_contains session_signal_step 'Interactive signal stop: signal 4 pending' &&
  assert_contains session_signal_step 'steps=0 pending_signal=4' &&
  assert_contains session_signal_step 'Signals forwarded: 1' &&
  assert_contains session_signal_step 'Target terminated by signal 4'
}
# v0.2.6: strict interactive batch stepping, interruption and state checks.
batch_step_four() {
  assert_count batch_step_four 'After step:' 4 &&
  assert_count batch_step_four 'Register changes:' 4 &&
  assert_contains batch_step_four 'steps=4 pending_signal=0' &&
  assert_contains batch_step_four 'Interactive steps completed: 4' &&
  assert_not_running batch_step_four
}
batch_step_sixteen() {
  assert_count batch_step_sixteen 'After step:' 16 &&
  assert_contains batch_step_sixteen 'steps=16 pending_signal=0' &&
  assert_contains batch_step_sixteen 'Interactive steps completed: 16' &&
  assert_not_running batch_step_sixteen
}
batch_step_mixed() {
  assert_count batch_step_mixed 'After step:' 5 &&
  assert_contains batch_step_mixed 'steps=5 pending_signal=0' &&
  assert_not_running batch_step_mixed
}
batch_step_explicit_one() {
  assert_count batch_step_explicit_one 'After step:' 2 &&
  assert_contains batch_step_explicit_one 'steps=2 pending_signal=0' &&
  assert_not_running batch_step_explicit_one
}
batch_step_invalid() {
  assert_count batch_step_invalid 'Usage: step [1..16]' 15 &&
  assert_count batch_step_invalid 'After step:' 0 &&
  assert_contains batch_step_invalid 'steps=0 pending_signal=0' &&
  assert_count batch_step_invalid 'Signals forwarded: 0' 1 &&
  assert_not_running batch_step_invalid
}
batch_step_ill() {
  assert_contains batch_step_ill 'Interactive signal stop: signal 4 pending' &&
  assert_count batch_step_ill 'After step:' 0 &&
  assert_contains batch_step_ill 'steps=0 pending_signal=4' &&
  assert_contains batch_step_ill 'Signals forwarded: 0' &&
  assert_not_running batch_step_ill
}
batch_step_ill_forward() {
  assert_contains batch_step_ill_forward 'Interactive signal stop: signal 4 pending' &&
  assert_contains batch_step_ill_forward 'steps=0 pending_signal=4' &&
  assert_contains batch_step_ill_forward 'Signals forwarded: 1' &&
  assert_contains batch_step_ill_forward 'Target terminated by signal 4'
}
batch_step_segv() {
  assert_count batch_step_segv 'After step:' 1 &&
  assert_contains batch_step_segv 'Interactive signal stop: signal 11 pending' &&
  assert_contains batch_step_segv 'steps=1 pending_signal=11' &&
  assert_contains batch_step_segv 'Signals forwarded: 0' &&
  assert_not_running batch_step_segv
}
batch_step_trap() {
  assert_count batch_step_trap 'After step:' 1 &&
  assert_contains batch_step_trap 'Interactive signal stop: signal 5 pending' &&
  assert_contains batch_step_trap 'steps=1 pending_signal=5' &&
  assert_contains batch_step_trap 'Signals forwarded: 0' &&
  assert_not_running batch_step_trap
}
batch_step_compact() {
  assert_count batch_step_compact 'After step:' 6 &&
  assert_count batch_step_compact 'Register changes:' 6 &&
  assert_count batch_step_compact '    GPR:' 0 &&
  assert_contains batch_step_compact 'steps=6 pending_signal=0' &&
  assert_not_running batch_step_compact
}
batch_step_inspect() {
  assert_count batch_step_inspect 'After step:' 2 &&
  assert_count batch_step_inspect 'Code word at RIP=' 1 &&
  assert_contains batch_step_inspect 'steps=2 pending_signal=0' &&
  assert_not_running batch_step_inspect
}
batch_step_early_exit() {
  assert_contains batch_step_early_exit 'Target exited with status 0' &&
  assert_contains batch_step_early_exit 'Ptrace events: exec=0 exit=1' &&
  assert_count batch_step_early_exit 'After step:' 2 &&
  assert_contains batch_step_early_exit 'Interactive steps completed: 2'
}
batch_step_invalid_signal() {
  assert_count batch_step_invalid_signal 'Usage: step [1..16]' 1 &&
  assert_contains batch_step_invalid_signal 'steps=0 pending_signal=4' &&
  assert_contains batch_step_invalid_signal 'Signals forwarded: 0' &&
  assert_not_running batch_step_invalid_signal
}
batch_step_no_newline() {
  assert_count batch_step_no_newline 'After step:' 3 &&
  assert_contains batch_step_no_newline 'Interactive steps completed: 3' &&
  assert_not_running batch_step_no_newline
}
memory_word() {
  assert_contains memory_word 'Memory word at 0x' &&
  assert_contains memory_word ': 0x1122334455667788' &&
  assert_contains memory_word 'Interactive session ended;' &&
  assert_count memory_word 'Memory word at 0x' 1 &&
  assert_not_running memory_word
}
memory_all_ones() {
  assert_contains memory_all_ones 'Memory word at 0x' &&
  assert_contains memory_all_ones ': 0xffffffffffffffff' &&
  assert_count memory_all_ones 'Memory word at 0x' 1 &&
  assert_not_running memory_all_ones
}
memory_uppercase() {
  assert_contains memory_uppercase 'Memory word at 0x' &&
  assert_contains memory_uppercase ': 0x1122334455667788' &&
  assert_not_running memory_uppercase
}
memory_repeated() {
  assert_count memory_repeated 'Memory word at 0x' 2 &&
  assert_contains memory_repeated ': 0x1122334455667788' &&
  assert_contains memory_repeated ': 0xffffffffffffffff' &&
  assert_contains memory_repeated 'Interactive steps completed: 1' &&
  assert_not_running memory_repeated
}
memory_unmapped() {
  assert_contains memory_unmapped 'ptrace(PEEKDATA at address)' &&
  assert_contains memory_unmapped 'steps=0 pending_signal=0' &&
  assert_count memory_unmapped 'Memory word at 0x' 0 &&
  assert_not_running memory_unmapped
}
memory_high_unmapped() {
  assert_contains memory_high_unmapped 'ptrace(PEEKDATA at address)' &&
  assert_count memory_high_unmapped 'Memory word at 0x' 0 &&
  assert_not_running memory_high_unmapped
}
memory_invalid() {
  assert_count memory_invalid 'Usage: mem 0xHEX' 8 &&
  assert_count memory_invalid 'Memory word at 0x' 0 &&
  assert_contains memory_invalid 'Interactive session ended;' &&
  assert_not_running memory_invalid
}
memory_signal() {
  assert_contains memory_signal 'Interactive signal stop: signal 4 pending' &&
  assert_contains memory_signal 'Memory word at 0x' &&
  assert_contains memory_signal 'steps=0 pending_signal=4' &&
  assert_contains memory_signal 'Signals forwarded: 0' &&
  assert_not_running memory_signal
}
memory_compact() {
  assert_count memory_compact 'Memory word at 0x' 1 &&
  assert_count memory_compact '    GPR:' 0 &&
  assert_contains memory_compact 'Target exited with status 0'
}
memory_combo() {
  assert_count memory_combo 'Memory word at 0x' 1 &&
  assert_count memory_combo 'Code word at RIP=' 1 &&
  assert_count memory_combo 'Stack word [' 4 &&
  assert_not_running memory_combo
}
memory_range_four() {
  assert_count memory_range_four 'Memory word at 0x' 4 &&
  assert_contains memory_range_four ': 0x1122334455667788' &&
  assert_contains memory_range_four ': 0xffffffffffffffff' &&
  assert_contains memory_range_four ': 0x0000000000000000' &&
  assert_contains memory_range_four ': 0x8899aabbccddeeff' &&
  assert_contains memory_range_four 'Interactive steps completed: 0' &&
  assert_not_running memory_range_four
}
memory_range_two() {
  assert_count memory_range_two 'Memory word at 0x' 2 &&
  assert_contains memory_range_two ': 0xffffffffffffffff' &&
  assert_contains memory_range_two ': 0x0000000000000000' &&
  assert_not_running memory_range_two
}
memory_range_one() {
  assert_count memory_range_one 'Memory word at 0x' 1 &&
  assert_contains memory_range_one ': 0x1122334455667788' &&
  assert_not_running memory_range_one
}
memory_range_invalid_count() {
  assert_count memory_range_invalid_count 'Usage: mem 0xHEX' 9 &&
  assert_count memory_range_invalid_count 'Memory word at 0x' 0 &&
  assert_contains memory_range_invalid_count 'steps=0 pending_signal=0' &&
  assert_not_running memory_range_invalid_count
}
memory_range_wrap() {
  assert_contains memory_range_wrap 'Error: memory range wraps the 64-bit address space.' &&
  assert_count memory_range_wrap 'Memory word at 0x' 0 &&
  assert_count memory_range_wrap 'ptrace(PEEKDATA at address)' 0 &&
  assert_not_running memory_range_wrap
}
session_overlong() {
  assert_count session_overlong 'Error: session command too long' 1 &&
  assert_count session_overlong 'Target exited with status' 0 &&
  assert_contains session_overlong 'steps=0 pending_signal=0' &&
  assert_contains session_overlong 'Interactive session ended;' &&
  assert_not_running session_overlong
}
session_overlong_eof() {
  assert_count session_overlong_eof 'Error: session command too long' 1 &&
  assert_contains session_overlong_eof 'Interactive session ended;' &&
  assert_not_running session_overlong_eof
}
session_max_line() {
  assert_count session_max_line 'Error: session command too long' 0 &&
  assert_count session_max_line 'Unknown session command. Type help.' 1 &&
  assert_not_running session_max_line
}
session_stack_initial() {
  assert_count session_stack_initial 'Stack word [' 4 &&
  assert_contains session_stack_initial 'Stack word [0] at ' &&
  assert_contains session_stack_initial ': 0x0000000000000001' &&
  assert_contains session_stack_initial 'Target exited with status 42'
}
session_stack_fixture() {
  assert_count session_stack_fixture 'Stack word [' 4 &&
  assert_contains session_stack_fixture ': 0x1122334455667788' &&
  assert_contains session_stack_fixture ': 0xffffffffffffffff' &&
  assert_contains session_stack_fixture ': 0x0000000000000000' &&
  assert_contains session_stack_fixture ': 0x8899aabbccddeeff' &&
  assert_contains session_stack_fixture 'Interactive steps completed: 1' &&
  assert_not_running session_stack_fixture
}
session_stack_compact() {
  assert_count session_stack_compact 'Stack word [' 4 &&
  assert_count session_stack_compact '    GPR:' 0 &&
  assert_contains session_stack_compact ': 0xffffffffffffffff' &&
  assert_not_running session_stack_compact
}
session_stack_invalid() {
  assert_contains session_stack_invalid 'ptrace(PEEKDATA at RSP)' &&
  assert_count session_stack_invalid 'Stack word [' 0 &&
  assert_contains session_stack_invalid 'steps=1 pending_signal=0' &&
  assert_not_running session_stack_invalid
}
session_stack_signal() {
  assert_contains session_stack_signal 'Interactive signal stop: signal 4 pending' &&
  assert_count session_stack_signal 'Stack word [' 4 &&
  assert_contains session_stack_signal 'steps=0 pending_signal=4' &&
  assert_contains session_stack_signal 'Signals forwarded: 0' &&
  assert_not_running session_stack_signal
}
session_stack_repeat() {
  assert_count session_stack_repeat 'Stack word [' 8 &&
  assert_contains session_stack_repeat 'Interactive steps completed: 0' &&
  assert_not_running session_stack_repeat
}
session_stack_with_code() {
  assert_count session_stack_with_code 'Code word at RIP=' 1 &&
  assert_count session_stack_with_code 'Stack word [' 4 &&
  assert_contains session_stack_with_code 'Interactive steps completed: 1' &&
  assert_not_running session_stack_with_code
}
# v0.2.7: bounded read-only RIP bytes in ascending address order.
instruction_bytes_default() {
  assert_count instruction_bytes_default 'Instruction byte [' 8 &&
  assert_count instruction_bytes_default ': 0x90' 8 &&
  assert_count instruction_bytes_default 'Code word at RIP=' 0 &&
  assert_contains instruction_bytes_default 'steps=0 pending_signal=0' &&
  assert_not_running instruction_bytes_default
}
instruction_bytes_alias() {
  assert_count instruction_bytes_alias 'Instruction byte [' 8 &&
  assert_count instruction_bytes_alias ': 0x90' 8 &&
  assert_not_running instruction_bytes_alias
}
instruction_bytes_one() {
  assert_count instruction_bytes_one 'Instruction byte [' 1 &&
  assert_contains instruction_bytes_one 'Instruction byte [+0]' &&
  assert_count instruction_bytes_one ': 0x90' 1 &&
  assert_not_running instruction_bytes_one
}
instruction_bytes_four() {
  assert_count instruction_bytes_four 'Instruction byte [' 4 &&
  assert_count instruction_bytes_four ': 0x90' 4 &&
  assert_not_running instruction_bytes_four
}
instruction_bytes_mixed() {
  assert_count instruction_bytes_mixed 'Instruction byte [' 10 &&
  assert_count instruction_bytes_mixed 'Code word at RIP=' 1 &&
  assert_contains instruction_bytes_mixed 'steps=2 pending_signal=0' &&
  assert_not_running instruction_bytes_mixed
}
instruction_bytes_allones() {
  assert_count instruction_bytes_allones 'Instruction byte [' 8 &&
  assert_count instruction_bytes_allones ': 0xff' 8 &&
  assert_not_running instruction_bytes_allones
}
instruction_bytes_invalid() {
  assert_count instruction_bytes_invalid 'Usage: bytes [1..8]' 13 &&
  assert_count instruction_bytes_invalid 'Instruction byte [' 0 &&
  assert_contains instruction_bytes_invalid 'steps=0 pending_signal=0' &&
  assert_not_running instruction_bytes_invalid
}
instruction_bytes_signal() {
  assert_contains instruction_bytes_signal 'Interactive signal stop: signal 4 pending' &&
  assert_count instruction_bytes_signal 'Instruction byte [' 2 &&
  assert_contains instruction_bytes_signal ': 0x0f' &&
  assert_contains instruction_bytes_signal ': 0x0b' &&
  assert_contains instruction_bytes_signal 'steps=0 pending_signal=4' &&
  assert_contains instruction_bytes_signal 'Signals forwarded: 0' &&
  assert_not_running instruction_bytes_signal
}
instruction_bytes_compact() {
  assert_count instruction_bytes_compact 'Instruction byte [' 8 &&
  assert_count instruction_bytes_compact '    GPR:' 0 &&
  assert_contains instruction_bytes_compact 'steps=1 pending_signal=0' &&
  assert_not_running instruction_bytes_compact
}
instruction_bytes_eof() {
  assert_count instruction_bytes_eof 'Instruction byte [' 2 &&
  assert_contains instruction_bytes_eof 'Interactive session ended;' &&
  assert_not_running instruction_bytes_eof
}
instruction_bytes_unknown() {
  assert_contains instruction_bytes_unknown 'Unknown session command. Type help.' &&
  assert_count instruction_bytes_unknown 'Instruction byte [' 0 &&
  assert_not_running instruction_bytes_unknown
}
# v0.2.8: only initial and confirmed instruction step RIPs enter history.
history_initial() {
  assert_count history_initial 'RIP history [' 1 &&
  assert_contains history_initial "RIP history [0]: 0x${history_entry}" &&
  assert_contains history_initial 'steps=0 pending_signal=0' &&
  assert_not_running history_initial
}
history_alias() {
  assert_count history_alias 'RIP history [' 3 &&
  assert_contains history_alias "RIP history [0]: 0x${history_entry}" &&
  assert_contains history_alias "RIP history [2]: 0x${history_two}" &&
  assert_contains history_alias 'steps=2 pending_signal=0' &&
  assert_not_running history_alias
}
history_repeat() {
  assert_count history_repeat 'RIP history [' 6 &&
  assert_count history_repeat "RIP history [0]: 0x${history_entry}" 2 &&
  assert_count history_repeat "RIP history [2]: 0x${history_two}" 2 &&
  assert_not_running history_repeat
}
history_full_ring() {
  assert_count history_full_ring 'RIP history [' 16 &&
  assert_contains history_full_ring "RIP history [0]: 0x${history_five}" &&
  assert_contains history_full_ring "RIP history [15]: 0x${history_twenty}" &&
  assert_contains history_full_ring 'steps=20 pending_signal=0' &&
  assert_not_running history_full_ring
}
history_wrap_twice() {
  assert_count history_wrap_twice 'RIP history [' 16 &&
  assert_contains history_wrap_twice "RIP history [0]: 0x${history_eighteen}" &&
  assert_contains history_wrap_twice "RIP history [15]: 0x${history_thirtythree}" &&
  assert_contains history_wrap_twice 'steps=33 pending_signal=0' &&
  assert_not_running history_wrap_twice
}
history_signal() {
  assert_count history_signal 'RIP history [' 1 &&
  assert_contains history_signal 'Interactive signal stop: signal 4 pending' &&
  assert_contains history_signal 'steps=0 pending_signal=4' &&
  assert_contains history_signal 'Signals forwarded: 0' &&
  assert_not_running history_signal
}
history_invalid_step() {
  assert_count history_invalid_step 'RIP history [' 1 &&
  assert_contains history_invalid_step 'Usage: step [1..16]' &&
  assert_contains history_invalid_step 'steps=0 pending_signal=0' &&
  assert_not_running history_invalid_step
}
history_inspection() {
  assert_count history_inspection 'RIP history [' 1 &&
  assert_count history_inspection 'Instruction byte [' 4 &&
  assert_contains history_inspection 'Code word at RIP=' &&
  assert_contains history_inspection 'steps=0 pending_signal=0' &&
  assert_not_running history_inspection
}
history_compact() {
  assert_count history_compact 'RIP history [' 5 &&
  assert_count history_compact '    GPR:' 0 &&
  assert_contains history_compact 'steps=4 pending_signal=0' &&
  assert_not_running history_compact
}
history_unknown() {
  assert_count history_unknown 'RIP history [' 0 &&
  assert_count history_unknown 'Unknown session command. Type help.' 2 &&
  assert_not_running history_unknown
}
# v0.2.9: retain cumulative step numbers and select a bounded history tail.
history_step_initial() {
  assert_count history_step_initial 'RIP history [' 1 &&
  assert_contains history_step_initial 'step=0' &&
  assert_contains history_step_initial 'steps=0 pending_signal=0' &&
  assert_not_running history_step_initial
}
history_step_three() {
  assert_count history_step_three 'RIP history [' 4 &&
  assert_contains history_step_three 'RIP history [0]:' &&
  assert_contains history_step_three 'step=0' &&
  assert_contains history_step_three 'step=1' &&
  assert_contains history_step_three 'step=2' &&
  assert_contains history_step_three 'step=3' &&
  assert_contains history_step_three 'steps=3 pending_signal=0' &&
  assert_not_running history_step_three
}
history_tail_one() {
  assert_count history_tail_one 'RIP history [' 1 &&
  assert_contains history_tail_one "RIP history [0]: 0x${history_twenty} step=20" &&
  assert_contains history_tail_one 'steps=20 pending_signal=0' &&
  assert_not_running history_tail_one
}
history_tail_three() {
  assert_count history_tail_three 'RIP history [' 3 &&
  assert_contains history_tail_three "RIP history [0]: 0x${history_eighteen} step=18" &&
  assert_contains history_tail_three "RIP history [2]: 0x${history_twenty} step=20" &&
  assert_not_running history_tail_three
}
history_tail_alias() {
  assert_count history_tail_alias 'RIP history [' 2 &&
  assert_contains history_tail_alias 'step=3' &&
  assert_contains history_tail_alias 'step=4' &&
  assert_count history_tail_alias 'step=0' 0 &&
  assert_not_running history_tail_alias
}
history_tail_clamp() {
  assert_count history_tail_clamp 'RIP history [' 3 &&
  assert_contains history_tail_clamp 'step=0' &&
  assert_contains history_tail_clamp 'step=2' &&
  assert_not_running history_tail_clamp
}
history_tail_invalid() {
  assert_count history_tail_invalid 'Usage: history [1..16]' 16 &&
  assert_count history_tail_invalid 'RIP history [' 0 &&
  assert_contains history_tail_invalid 'steps=0 pending_signal=0' &&
  assert_not_running history_tail_invalid
}
history_tail_signal() {
  assert_count history_tail_signal 'RIP history [' 1 &&
  assert_contains history_tail_signal 'step=0' &&
  assert_contains history_tail_signal 'Interactive signal stop: signal 4 pending' &&
  assert_contains history_tail_signal 'steps=0 pending_signal=4' &&
  assert_contains history_tail_signal 'Signals forwarded: 0' &&
  assert_not_running history_tail_signal
}
history_tail_inspection() {
  assert_count history_tail_inspection 'RIP history [' 1 &&
  assert_contains history_tail_inspection 'step=1' &&
  assert_contains history_tail_inspection 'Code word at RIP=' &&
  assert_count history_tail_inspection 'Instruction byte [' 2 &&
  assert_not_running history_tail_inspection
}
history_tail_repeat() {
  assert_count history_tail_repeat 'RIP history [' 4 &&
  assert_count history_tail_repeat 'step=4' 2 &&
  assert_count history_tail_repeat 'step=5' 2 &&
  assert_not_running history_tail_repeat
}
history_tail_eof() {
  assert_count history_tail_eof 'RIP history [' 1 &&
  assert_contains history_tail_eof 'step=2' &&
  assert_contains history_tail_eof 'Interactive session ended;' &&
  assert_not_running history_tail_eof
}
history_tail_wrap() {
  assert_count history_tail_wrap 'RIP history [' 16 &&
  assert_contains history_tail_wrap "RIP history [0]: 0x${history_eighteen} step=18" &&
  assert_contains history_tail_wrap "RIP history [15]: 0x${history_thirtythree} step=33" &&
  assert_not_running history_tail_wrap
}
# v0.2.10: distinguish observed signal-delivery stops from forwarded ones.
events_initial() {
  assert_count events_initial 'Lifecycle: pid=' 1 &&
  assert_contains events_initial 'steps=0 observed_signals=0 forwarded_signals=0 pending_signal=0 exec_events=0 exit_events=0' &&
  assert_count events_initial 'Last signal stop:' 0 &&
  assert_not_running events_initial
}
events_alias() {
  assert_count events_alias 'Lifecycle: pid=' 1 &&
  assert_contains events_alias 'steps=0 observed_signals=0 forwarded_signals=0 pending_signal=0 exec_events=0 exit_events=0' &&
  assert_not_running events_alias
}
events_repeat() {
  assert_count events_repeat 'Lifecycle: pid=' 3 &&
  assert_count events_repeat 'steps=0 observed_signals=0 forwarded_signals=0 pending_signal=0 exec_events=0 exit_events=0' 3 &&
  assert_count events_repeat 'Last signal stop:' 0 &&
  assert_not_running events_repeat
}
events_steps() {
  assert_contains events_steps 'steps=3 observed_signals=0 forwarded_signals=0 pending_signal=0 exec_events=0 exit_events=0' &&
  assert_count events_steps 'After step:' 3 &&
  assert_not_running events_steps
}
events_inspection() {
  assert_contains events_inspection 'steps=0 observed_signals=0 forwarded_signals=0 pending_signal=0 exec_events=0 exit_events=0' &&
  assert_count events_inspection 'Code word at RIP=' 1 &&
  assert_count events_inspection 'Instruction byte [' 2 &&
  assert_count events_inspection 'RIP history [' 1 &&
  assert_not_running events_inspection
}
events_invalid() {
  assert_count events_invalid 'Unknown session command. Type help.' 4 &&
  assert_count events_invalid 'Lifecycle: pid=' 0 &&
  assert_contains events_invalid 'steps=0 pending_signal=0' &&
  assert_not_running events_invalid
}
events_sigill() {
  assert_contains events_sigill 'Interactive signal stop: signal 4 pending' &&
  assert_contains events_sigill 'steps=0 observed_signals=1 forwarded_signals=0 pending_signal=4 exec_events=0 exit_events=0' &&
  assert_contains events_sigill 'Last signal stop: signal=4 si_code=' &&
  assert_contains events_sigill 'Signals forwarded: 0' &&
  assert_not_running events_sigill
}
events_sigsegv() {
  assert_contains events_sigsegv 'Interactive signal stop: signal 11 pending' &&
  assert_contains events_sigsegv 'steps=1 observed_signals=1 forwarded_signals=0 pending_signal=11 exec_events=0 exit_events=0' &&
  assert_contains events_sigsegv 'Last signal stop: signal=11 si_code=' &&
  assert_not_running events_sigsegv
}
events_sigtrap() {
  assert_contains events_sigtrap 'Interactive signal stop: signal 5 pending' &&
  assert_contains events_sigtrap 'steps=1 observed_signals=1 forwarded_signals=0 pending_signal=5 exec_events=0 exit_events=0' &&
  assert_contains events_sigtrap 'Last signal stop: signal=5 si_code=' &&
  assert_not_running events_sigtrap
}
events_batch_signal() {
  assert_contains events_batch_signal 'steps=0 observed_signals=1 forwarded_signals=0 pending_signal=4 exec_events=0 exit_events=0' &&
  assert_count events_batch_signal 'Last signal stop:' 1 &&
  assert_contains events_batch_signal 'Signals forwarded: 0' &&
  assert_not_running events_batch_signal
}
events_compact() {
  assert_count events_compact 'Lifecycle: pid=' 1 &&
  assert_contains events_compact 'steps=4 observed_signals=0 forwarded_signals=0 pending_signal=0 exec_events=0 exit_events=0' &&
  assert_count events_compact '    GPR:' 0 &&
  assert_not_running events_compact
}
events_alias_eof() {
  assert_contains events_alias_eof 'steps=0 observed_signals=0 forwarded_signals=0 pending_signal=0 exec_events=0 exit_events=0' &&
  assert_contains events_alias_eof 'Interactive session ended;' &&
  assert_not_running events_alias_eof
}
events_eof() {
  assert_contains events_eof 'steps=0 observed_signals=0 forwarded_signals=0 pending_signal=0 exec_events=0 exit_events=0' &&
  assert_contains events_eof 'Interactive session ended;' &&
  assert_not_running events_eof
}
# v0.2.11: classified signal-delivery stops only; bounded, read-only history.
signal_history_empty() {
  assert_count signal_history_empty 'Signal history: no validated signal-delivery stops yet.' 1 &&
  assert_count signal_history_empty 'Signal history [' 0 &&
  assert_contains signal_history_empty 'steps=0 pending_signal=0' &&
  assert_not_running signal_history_empty
}
signal_history_alias() {
  assert_count signal_history_alias 'Signal history: no validated signal-delivery stops yet.' 1 &&
  assert_not_running signal_history_alias
}
signal_history_repeated_empty() {
  assert_count signal_history_repeated_empty 'Signal history: no validated signal-delivery stops yet.' 3 &&
  assert_count signal_history_repeated_empty 'Signal history [' 0 &&
  assert_not_running signal_history_repeated_empty
}
signal_history_ill() {
  assert_contains signal_history_ill 'Interactive signal stop: signal 4 pending' &&
  assert_count signal_history_ill 'Signal history [' 1 &&
  assert_contains signal_history_ill 'Signal history [0]: signal=4 si_code=' &&
  assert_contains signal_history_ill ' step=0' &&
  assert_contains signal_history_ill 'steps=0 observed_signals=1 forwarded_signals=0 pending_signal=4' &&
  assert_not_running signal_history_ill
}
signal_history_segv() {
  assert_contains signal_history_segv 'Interactive signal stop: signal 11 pending' &&
  assert_count signal_history_segv 'Signal history [' 1 &&
  assert_contains signal_history_segv 'Signal history [0]: signal=11 si_code=' &&
  assert_contains signal_history_segv ' step=1' &&
  assert_not_running signal_history_segv
}
signal_history_trap() {
  assert_contains signal_history_trap 'Interactive signal stop: signal 5 pending' &&
  assert_count signal_history_trap 'Signal history [' 1 &&
  assert_contains signal_history_trap 'Signal history [0]: signal=5 si_code=' &&
  assert_contains signal_history_trap ' step=1' &&
  assert_not_running signal_history_trap
}
signal_history_batch() {
  assert_contains signal_history_batch 'Interactive signal stop: signal 4 pending' &&
  assert_count signal_history_batch 'Signal history [' 1 &&
  assert_contains signal_history_batch 'Signal history [0]: signal=4 si_code=' &&
  assert_contains signal_history_batch ' step=0' &&
  assert_not_running signal_history_batch
}
signal_history_inspection() {
  assert_count signal_history_inspection 'Signal history: no validated signal-delivery stops yet.' 1 &&
  assert_contains signal_history_inspection 'Code word at RIP=' &&
  assert_count signal_history_inspection 'Instruction byte [' 2 &&
  assert_count signal_history_inspection 'RIP history [' 1 &&
  assert_not_running signal_history_inspection
}
signal_history_compact() {
  assert_count signal_history_compact 'Signal history [' 1 &&
  assert_count signal_history_compact '    GPR:' 0 &&
  assert_contains signal_history_compact 'steps=0 observed_signals=1 forwarded_signals=0 pending_signal=4' &&
  assert_not_running signal_history_compact
}
signal_history_unknown() {
  assert_count signal_history_unknown 'Unknown session command. Type help.' 4 &&
  assert_count signal_history_unknown 'Signal history [' 0 &&
  assert_not_running signal_history_unknown
}
signal_history_eof() {
  assert_contains signal_history_eof 'Signal history: no validated signal-delivery stops yet.' &&
  assert_contains signal_history_eof 'Interactive session ended;' &&
  assert_not_running signal_history_eof
}
signal_history_alias_eof() {
  assert_contains signal_history_alias_eof 'Signal history: no validated signal-delivery stops yet.' &&
  assert_contains signal_history_alias_eof 'Interactive session ended;' &&
  assert_not_running signal_history_alias_eof
}
signal_history_forward() {
  assert_count signal_history_forward 'Signal history [' 1 &&
  assert_contains signal_history_forward 'Signal history [0]: signal=4 si_code=' &&
  assert_contains signal_history_forward 'Signals forwarded: 1' &&
  assert_contains signal_history_forward 'Target terminated by signal 4'
}
# v0.2.12: resume to the next genuine signal without consuming it.
until_handled_twice() {
  assert_contains until_handled_twice 'Target exited with status 0' &&
  assert_count until_handled_twice 'Interactive signal stop: signal 10 pending' 2 &&
  assert_count until_handled_twice 'Signal history [' 3 &&
  assert_contains until_handled_twice 'Signal history [1]: signal=10 si_code=0 step=0' &&
  assert_contains until_handled_twice 'observed_signals=1 forwarded_signals=0 pending_signal=10' &&
  assert_contains until_handled_twice 'observed_signals=2 forwarded_signals=1 pending_signal=10' &&
  assert_contains until_handled_twice 'Signals forwarded: 2'
}
until_burst_ring() {
  assert_contains until_burst_ring 'Target exited with status 0' &&
  assert_count until_burst_ring 'Interactive signal stop: signal 10 pending' 10 &&
  assert_count until_burst_ring 'Signal history [' 8 &&
  assert_contains until_burst_ring 'Signal history [0]: signal=10 si_code=0 step=0' &&
  assert_contains until_burst_ring 'Signal history [7]: signal=10 si_code=0 step=0' &&
  assert_contains until_burst_ring 'observed_signals=10 forwarded_signals=9 pending_signal=10' &&
  assert_contains until_burst_ring 'Signals forwarded: 10'
}
until_burst_repeat_read() {
  assert_contains until_burst_repeat_read 'Target exited with status 0' &&
  assert_count until_burst_repeat_read 'Signal history [' 16 &&
  assert_count until_burst_repeat_read 'Signal history [0]: signal=10 si_code=0 step=0' 2 &&
  assert_count until_burst_repeat_read 'Signal history [7]: signal=10 si_code=0 step=0' 2 &&
  assert_contains until_burst_repeat_read 'Signals forwarded: 10'
}
until_fault_pending() {
  assert_contains until_fault_pending 'Interactive signal stop: signal 4 pending' &&
  assert_contains until_fault_pending 'steps=0 pending_signal=4' &&
  assert_contains until_fault_pending 'Signal history [0]: signal=4 si_code=' &&
  assert_contains until_fault_pending 'Signals forwarded: 0' &&
  assert_not_running until_fault_pending
}
until_fault_forward() {
  assert_contains until_fault_forward 'Interactive signal stop: signal 4 pending' &&
  assert_contains until_fault_forward 'Target terminated by signal 4' &&
  assert_contains until_fault_forward 'Signals forwarded: 1'
}
until_terminates() {
  assert_contains until_terminates 'Target exited with status 7' &&
  assert_count until_terminates 'Interactive signal stop:' 0 &&
  assert_contains until_terminates 'Signals forwarded: 0'
}
until_reexec() {
  assert_contains until_reexec 'Ptrace exec event:' &&
  assert_contains until_reexec 'Target exited with status 42' &&
  assert_contains until_reexec 'Ptrace events: exec=1 exit=1' &&
  assert_count until_reexec 'Interactive signal stop:' 0
}
until_invalid() {
  assert_count until_invalid 'Unknown session command. Type help.' 5 &&
  assert_contains until_invalid 'steps=0 pending_signal=0' &&
  assert_count until_invalid 'Interactive signal stop:' 0 &&
  assert_not_running until_invalid
}
until_eof() {
  assert_contains until_eof 'Target exited with status 7' &&
  assert_contains until_eof 'Signals forwarded: 0'
}
until_alias_eof() {
  assert_contains until_alias_eof 'Target exited with status 7' &&
  assert_contains until_alias_eof 'Signals forwarded: 0'
}
until_compact() {
  assert_count until_compact '    GPR:' 0 &&
  assert_contains until_compact 'observed_signals=1 forwarded_signals=0 pending_signal=4' &&
  assert_contains until_compact 'Signal history [0]: signal=4 si_code=' &&
  assert_not_running until_compact
}
until_inspect_pending() {
  assert_contains until_inspect_pending 'Interactive signal stop: signal 4 pending' &&
  assert_contains until_inspect_pending 'observed_signals=1 forwarded_signals=0 pending_signal=4' &&
  assert_count until_inspect_pending 'Signal history [' 1 &&
  assert_count until_inspect_pending 'RIP history [' 1 &&
  assert_contains until_inspect_pending 'steps=0 pending_signal=4' &&
  assert_not_running until_inspect_pending
}
until_step_pending() {
  assert_contains until_step_pending 'Interactive signal stop: signal 4 pending' &&
  assert_contains until_step_pending 'Signals forwarded: 1' &&
  assert_contains until_step_pending 'Target terminated by signal 4'
}
until_continue_pending() {
  assert_contains until_continue_pending 'Interactive signal stop: signal 4 pending' &&
  assert_contains until_continue_pending 'Signals forwarded: 1' &&
  assert_contains until_continue_pending 'Target terminated by signal 4'
}

# v0.2.13: bounded last-N views over the existing validated signal ring.
signal_tail_empty() {
  assert_count signal_tail_empty 'Signal history: no validated signal-delivery stops yet.' 1 &&
  assert_count signal_tail_empty 'Signal history [' 0 &&
  assert_contains signal_tail_empty 'steps=0 pending_signal=0' &&
  assert_not_running signal_tail_empty
}
signal_tail_alias_empty() {
  assert_count signal_tail_alias_empty 'Signal history: no validated signal-delivery stops yet.' 1 &&
  assert_not_running signal_tail_alias_empty
}
signal_tail_pending() {
  assert_count signal_tail_pending 'Signal history [' 1 &&
  assert_contains signal_tail_pending 'Signal history [0]: signal=4 si_code=' &&
  assert_contains signal_tail_pending 'observed_signals=1 forwarded_signals=0 pending_signal=4' &&
  assert_not_running signal_tail_pending
}
signal_tail_clamp() {
  assert_count signal_tail_clamp 'Signal history [' 1 &&
  assert_contains signal_tail_clamp 'Signal history [0]: signal=4 si_code=' &&
  assert_not_running signal_tail_clamp
}
signal_tail_full() {
  assert_count signal_tail_full 'Signal history [' 8 &&
  assert_contains signal_tail_full 'Signal history [0]: signal=10 si_code=0 step=0' &&
  assert_contains signal_tail_full 'Signal history [7]: signal=10 si_code=0 step=0' &&
  assert_contains signal_tail_full 'observed_signals=10 forwarded_signals=9 pending_signal=10' &&
  assert_not_running signal_tail_full
}
signal_tail_wrap_three() {
  assert_count signal_tail_wrap_three 'Signal history [' 3 &&
  assert_contains signal_tail_wrap_three 'Signal history [5]: signal=10 si_code=0 step=0' &&
  assert_contains signal_tail_wrap_three 'Signal history [6]: signal=10 si_code=0 step=0' &&
  assert_contains signal_tail_wrap_three 'Signal history [7]: signal=10 si_code=0 step=0' &&
  assert_count signal_tail_wrap_three 'Signal history [0]:' 0 &&
  assert_contains signal_tail_wrap_three 'observed_signals=10 forwarded_signals=9 pending_signal=10' &&
  assert_not_running signal_tail_wrap_three
}
signal_tail_wrap_alias() {
  assert_count signal_tail_wrap_alias 'Signal history [' 2 &&
  assert_contains signal_tail_wrap_alias 'Signal history [6]: signal=10 si_code=0 step=0' &&
  assert_contains signal_tail_wrap_alias 'Signal history [7]: signal=10 si_code=0 step=0' &&
  assert_count signal_tail_wrap_alias 'Signal history [0]:' 0 &&
  assert_not_running signal_tail_wrap_alias
}
signal_tail_invalid() {
  assert_count signal_tail_invalid 'Usage: signals [1..8] or g [1..8]' 12 &&
  assert_count signal_tail_invalid 'Unknown session command. Type help.' 1 &&
  assert_count signal_tail_invalid 'Signal history [' 0 &&
  assert_contains signal_tail_invalid 'steps=0 pending_signal=0' &&
  assert_not_running signal_tail_invalid
}
signal_tail_invalid_pending() {
  assert_count signal_tail_invalid_pending 'Usage: signals [1..8] or g [1..8]' 3 &&
  assert_count signal_tail_invalid_pending 'Signal history [' 1 &&
  assert_contains signal_tail_invalid_pending 'observed_signals=1 forwarded_signals=0 pending_signal=4' &&
  assert_not_running signal_tail_invalid_pending
}
signal_tail_nonmutating() {
  assert_contains signal_tail_nonmutating 'Target exited with status 0' &&
  assert_count signal_tail_nonmutating 'Signal history [' 4 &&
  assert_count signal_tail_nonmutating 'Signal history [1]: signal=10 si_code=0 step=0' 3 &&
  assert_contains signal_tail_nonmutating 'observed_signals=2 forwarded_signals=1 pending_signal=10' &&
  assert_contains signal_tail_nonmutating 'Signals forwarded: 2'
}
signal_tail_eof() {
  assert_contains signal_tail_eof 'Signal history: no validated signal-delivery stops yet.' &&
  assert_contains signal_tail_eof 'Interactive session ended;' &&
  assert_not_running signal_tail_eof
}
signal_tail_alias_eof() {
  assert_contains signal_tail_alias_eof 'Signal history: no validated signal-delivery stops yet.' &&
  assert_contains signal_tail_alias_eof 'Interactive session ended;' &&
  assert_not_running signal_tail_alias_eof
}
signal_tail_compact() {
  assert_count signal_tail_compact '    GPR:' 0 &&
  assert_count signal_tail_compact 'Signal history [' 1 &&
  assert_contains signal_tail_compact 'observed_signals=1 forwarded_signals=0 pending_signal=4' &&
  assert_not_running signal_tail_compact
}

session_code() {
  assert_contains session_code 'Code word at RIP=0x' &&
  assert_contains session_code 'Target exited with status 42' &&
  assert_contains session_code 'Interactive steps completed: 0'
}
session_code_alias() {
  assert_count session_code_alias 'Code word at RIP=0x' 2 &&
  assert_contains session_code_alias 'Interactive steps completed: 1' &&
  assert_count session_code_alias 'After step:' 1 &&
  assert_contains session_code_alias 'Target exited with status 0'
}
session_code_all_ones() {
  assert_contains session_code_all_ones ': 0xffffffffffffffff' &&
  assert_contains session_code_all_ones 'Interactive session ended; tracee terminated and reaped.' &&
  assert_not_running session_code_all_ones
}
session_code_signal() {
  assert_contains session_code_signal 'Interactive signal stop: signal 4 pending' &&
  assert_contains session_code_signal 'Code word at RIP=0x' &&
  assert_contains session_code_signal 'steps=0 pending_signal=4' &&
  assert_contains session_code_signal 'Signals forwarded: 0' &&
  assert_not_running session_code_signal
}
session_code_compact() {
  assert_count session_code_compact 'Code word at RIP=0x' 2 &&
  assert_count session_code_compact '    GPR:' 0 &&
  assert_contains session_code_compact 'Target exited with status 23'
}
session_code_regs() {
  assert_count session_code_regs 'Code word at RIP=0x' 1 &&
  assert_count session_code_regs '    GPR:' 1 &&
  assert_contains session_code_regs 'Target exited with status 0'
}
session_signal_regs() {
  assert_contains session_signal_regs 'Interactive signal stop: signal 4 pending' &&
  assert_contains session_signal_regs 'steps=0 pending_signal=4' &&
  assert_count session_signal_regs '    GPR:' 1 &&
  assert_contains session_signal_regs 'Signals forwarded: 0' &&
  assert_not_running session_signal_regs
}

exits_zero_signals() {
  assert_contains exits_zero_signals 'Target exited with status 42' &&
  assert_contains exits_zero_signals 'Signals forwarded: 0' &&
  assert_contains exits_zero_signals 'Ptrace events: exec=0 exit=1' &&
  assert_contains exits_zero_signals 'Ptrace exit detail: raw_wait=0x00002a00'
}



# Run tests directly to avoid interpreting executable arguments in a shell.
# Command scripts exercise the same stdin API as a terminal user.
printf 'continue\n' > "$tmp/session-continue"
printf 'step\nstep\ncontinue\n' > "$tmp/session-steps"
printf 'regs\nstep\ncontinue\n' > "$tmp/session-regs"
printf 'quit\n' > "$tmp/session-quit"
: > "$tmp/session-eof"
printf 'help\ninvalid\nq\n' > "$tmp/session-help"
printf 's\ns\ns\nq\n' > "$tmp/session-quit-steps"
printf 'status\nq\n' > "$tmp/session-status-start"
printf 's\ns\ni\nq\n' > "$tmp/session-status-steps"
printf 'step\nstatus\ncontinue\n' > "$tmp/session-signal-ill"
printf 'step\nstep\nstatus\ncontinue\n' > "$tmp/session-signal-segv"
printf 'step\nstep\nstatus\ncontinue\n' > "$tmp/session-signal-trap"
printf 'step\nstatus\nquit\n' > "$tmp/session-signal-quit"
printf 'step\nregs\nstatus\nq\n' > "$tmp/session-signal-regs"
printf 'step\nstatus\nstep\n' > "$tmp/session-signal-step"
printf 'code\ncontinue\n' > "$tmp/session-code"
printf 'code\ns\nx\ncontinue\n' > "$tmp/session-code-alias"
printf 'code\nquit\n' > "$tmp/session-code-all-ones"
printf 'step\nx\nstatus\nquit\n' > "$tmp/session-code-signal"
printf 'x\ncode\nc\n' > "$tmp/session-code-compact"
printf 'code\nregs\ncontinue\n' > "$tmp/session-code-regs"
printf 'stack\ncontinue\n' > "$tmp/session-stack-initial"
printf 's\nk\nquit\n' > "$tmp/session-stack-fixture"
printf 's\nstack\nquit\n' > "$tmp/session-stack-compact"
printf 's\nstack\nstatus\nquit\n' > "$tmp/session-stack-invalid"
printf 'step\nstack\nstatus\nquit\n' > "$tmp/session-stack-signal"
printf 'stack\nk\nquit\n' > "$tmp/session-stack-repeat"
printf 'code\ns\nstack\nq\n' > "$tmp/session-stack-with-code"

printf 'step 4\nstatus\nquit\n' > "$tmp/batch-step-four"
printf 's 16\nstatus\nq\n' > "$tmp/batch-step-sixteen"
printf 's 3\nstep 2\nstatus\nq\n' > "$tmp/batch-step-mixed"
printf 'step 1\ns 1\nstatus\nquit\n' > "$tmp/batch-step-explicit-one"
printf 'step 0\ns 17\nstep 01\nstep -1\nstep 1x\nstep 1 \ns 1 2\ns 100\nstep +3\ns \nstep 00\nstep 2\t\nstep 9999\ns 016\ns 1\r\nstatus\nquit\n' > "$tmp/batch-step-invalid"
printf 'step 5\nstatus\nregs\nquit\n' > "$tmp/batch-step-ill"
printf 'step 16\nstatus\ncontinue\n' > "$tmp/batch-step-ill-forward"
printf 'step 16\nstatus\nquit\n' > "$tmp/batch-step-segv"
printf 's 16\nstatus\nquit\n' > "$tmp/batch-step-trap"
printf 's 6\nstatus\nq\n' > "$tmp/batch-step-compact"
printf 'step 2\ncode\nstatus\nq\n' > "$tmp/batch-step-inspect"
printf 'step 16\n' > "$tmp/batch-step-early-exit"
printf 'step\ns 0\nstatus\nquit\n' > "$tmp/batch-step-invalid-signal"
printf 'step 3' > "$tmp/batch-step-no-newline"

# v0.2.7: instruction bytes are displayed in ascending address order,
# unlike a 64-bit machine word printed as a hexadecimal integer.
printf 'bytes\nstatus\nquit\n' > "$tmp/instruction-bytes-default"
printf 'b\nquit\n' > "$tmp/instruction-bytes-alias"
printf 'bytes 1\nquit\n' > "$tmp/instruction-bytes-one"
printf 'b 4\nquit\n' > "$tmp/instruction-bytes-four"
printf 'bytes 8\nstep 2\nb 2\ncode\nstatus\nquit\n' > "$tmp/instruction-bytes-mixed"
printf 'bytes\nquit\n' > "$tmp/instruction-bytes-allones"
printf 'bytes 0\nbytes 9\nbytes 10\nbytes 01\nbytes -1\nbytes 1 \nbytes 1x\nb \nb 0\nb 8 \nb 4x\nbytes 1 2\nb +1\nstatus\nquit\n' > "$tmp/instruction-bytes-invalid"
printf 'step\nbytes 2\nstatus\nquit\n' > "$tmp/instruction-bytes-signal"
printf 'step\nb 8\nstatus\nquit\n' > "$tmp/instruction-bytes-compact"
printf 'bytes 2' > "$tmp/instruction-bytes-eof"
printf 'byte\nquit\n' > "$tmp/instruction-bytes-unknown"

printf 'history\nstatus\nquit\n' > "$tmp/history-initial"
printf 's 2\nh\nstatus\nq\n' > "$tmp/history-alias"
printf 'step 2\nhistory\nh\nq\n' > "$tmp/history-repeat"
printf 'step 16\nstep 4\nhistory\nstatus\nquit\n' > "$tmp/history-full-ring"
printf 'step 16\nstep 16\ns 1\nh\nstatus\nq\n' > "$tmp/history-wrap-twice"
printf 'step 4\nhistory\nstatus\nq\n' > "$tmp/history-signal"
printf 's 0\nhistory\nstatus\nquit\n' > "$tmp/history-invalid-step"
printf 'code\nbytes 4\nhistory\nstatus\nquit\n' > "$tmp/history-inspection"
printf 'step 4\nh\nstatus\nq\n' > "$tmp/history-compact"
printf 'historyx 1\nHISTORY\nquit\n' > "$tmp/history-unknown"

# v0.2.9: history N keeps only the last N confirmed RIP observations.
printf 'history\nstatus\nquit\n' > "$tmp/history-step-initial"
printf 'step 3\nh\nstatus\nquit\n' > "$tmp/history-step-three"
printf 'step 16\nstep 4\nhistory 1\nstatus\nquit\n' > "$tmp/history-tail-one"
printf 'step 16\nstep 4\nhistory 3\nq\n' > "$tmp/history-tail-three"
printf 'step 4\nh 2\nquit\n' > "$tmp/history-tail-alias"
printf 's 2\nhistory 16\nquit\n' > "$tmp/history-tail-clamp"
printf 'history 0\nhistory 17\nhistory 99\nhistory 01\nhistory -1\nhistory +1\nhistory 1x\nhistory 1 \nhistory 1 2\nh 016\nh x\nh \nh 1 \nh  2\nhistory 2\t\nhistory 1\r\nstatus\nquit\n' > "$tmp/history-tail-invalid"
printf 'step 4\nhistory 1\nstatus\nquit\n' > "$tmp/history-tail-signal"
printf 'step\ncode\nbytes 2\nhistory 1\nq\n' > "$tmp/history-tail-inspection"
printf 'step 5\nhistory 2\nh 2\nquit\n' > "$tmp/history-tail-repeat"
printf 's 2\nhistory 1' > "$tmp/history-tail-eof"
printf 'step 16\nstep 16\ns 1\nhistory 16\nq\n' > "$tmp/history-tail-wrap"

# v0.2.10 read-only lifecycle counters at interactive stops.
printf 'events\nstatus\nquit\n' > "$tmp/events-initial"
printf 'e\nquit\n' > "$tmp/events-alias"
printf 'events\ne\nevents\nq\n' > "$tmp/events-repeat"
printf 'step 3\ne\nq\n' > "$tmp/events-steps"
printf 'code\nbytes 2\nhistory 1\nevents\nquit\n' > "$tmp/events-inspection"
printf 'events 1\ne 1\nEVENTS\neventsx\nstatus\nq\n' > "$tmp/events-invalid"
printf 'step\nevents\nstatus\nquit\n' > "$tmp/events-sigill"
printf 'step\nstep\ne\nq\n' > "$tmp/events-sigsegv"
printf 'step\nstep\nevents\nquit\n' > "$tmp/events-sigtrap"
printf 'step 16\nevents\nquit\n' > "$tmp/events-batch-signal"
printf 'step 4\ne\nquit\n' > "$tmp/events-compact"
printf 'events' > "$tmp/events-eof"

printf 'e' > "$tmp/events-alias-eof"
# v0.2.11 signal-stop history scripts.
printf 'signals\nstatus\nq\n' > "$tmp/signal-history-empty"
printf 'g\nquit\n' > "$tmp/signal-history-alias"
printf 'signals\ng\nsignals\nquit\n' > "$tmp/signal-history-repeated-empty"
printf 'step\nsignals\nevents\nquit\n' > "$tmp/signal-history-ill"
printf 'step\nstep\ng\nq\n' > "$tmp/signal-history-segv"
printf 'step\nstep\nsignals\nquit\n' > "$tmp/signal-history-trap"
printf 'step 16\nsignals\nquit\n' > "$tmp/signal-history-batch"
printf 'code\nbytes 2\nhistory 1\nsignals\nquit\n' > "$tmp/signal-history-inspection"
printf 'step\nsignals\nevents\nquit\n' > "$tmp/signal-history-compact"
printf 'signalsx\ng1\nSIGNALS\nsignalz\nquit\n' > "$tmp/signal-history-unknown"
printf 'signals' > "$tmp/signal-history-eof"
printf 'g' > "$tmp/signal-history-alias-eof"
printf 'step\nsignals\ncontinue\n' > "$tmp/signal-history-forward"


# assuming fixed link addresses; no Python or hardcoded ASLR assumptions.
# v0.2.12 native repeat-signal and session transition command scripts.
printf 'until-signal\nsignals\nevents\nu\nsignals\nevents\nu\n' > "$tmp/until-handled-twice"
: > "$tmp/until-burst-ring"
for ((n=0;n<10;n++)); do printf 'u\n' >> "$tmp/until-burst-ring"; done
printf 'signals\nevents\nu\n' >> "$tmp/until-burst-ring"
: > "$tmp/until-burst-repeat"
for ((n=0;n<10;n++)); do printf 'until-signal\n' >> "$tmp/until-burst-repeat"; done
printf 'signals\ng\nu\n' >> "$tmp/until-burst-repeat"
printf 'until-signal\nsignals\nstatus\nquit\n' > "$tmp/until-fault-pending"
printf 'u\nu\n' > "$tmp/until-fault-forward"
printf 'u\n' > "$tmp/until-terminates"
printf 'until-signal\n' > "$tmp/until-reexec"
printf 'until-signal 1\nu 1\nUNTIL-SIGNAL\nU\nuntil-signal?\nstatus\nquit\n' > "$tmp/until-invalid"
printf 'until-signal' > "$tmp/until-eof"
printf 'u' > "$tmp/until-alias-eof"
printf 'u\nsignals\nevents\nquit\n' > "$tmp/until-compact"
printf 'u\nevents\nsignals\nhistory 1\nstatus\nquit\n' > "$tmp/until-inspect-pending"
printf 'u\nstep\n' > "$tmp/until-step-pending"
printf 'u\ncontinue\n' > "$tmp/until-continue-pending"

# v0.2.13 filtered signal-stop view scripts.
printf 'signals 4\nstatus\nquit\n' > "$tmp/signal-tail-empty"
printf 'g 3\nquit\n' > "$tmp/signal-tail-alias-empty"
printf 'step\nsignals 1\nevents\nquit\n' > "$tmp/signal-tail-pending"
printf 'step\ng 8\nquit\n' > "$tmp/signal-tail-clamp"
: > "$tmp/signal-tail-full"
: > "$tmp/signal-tail-wrap-three"
: > "$tmp/signal-tail-wrap-alias"
for ((n=0;n<10;n++)); do
  printf 'u\n' >> "$tmp/signal-tail-full"
  printf 'u\n' >> "$tmp/signal-tail-wrap-three"
  printf 'u\n' >> "$tmp/signal-tail-wrap-alias"
done
printf 'signals 8\nevents\nquit\n' >> "$tmp/signal-tail-full"
printf 'signals 3\nevents\nquit\n' >> "$tmp/signal-tail-wrap-three"
printf 'g 2\nquit\n' >> "$tmp/signal-tail-wrap-alias"
printf 'signals 0\nsignals 9\nsignals 10\nsignals 01\nsignals -1\nsignals 1x\nsignals 1 \nsignals \ng 0\ng 9\ng +1\ng 00\ng1\nstatus\nquit\n' > "$tmp/signal-tail-invalid"
printf 'step\nsignals 0\ng 9\nsignals 10\nsignals 1\nevents\nquit\n' > "$tmp/signal-tail-invalid-pending"
printf 'u\nu\nsignals 1\nsignals 2\ng 1\nevents\nu\n' > "$tmp/signal-tail-nonmutating"
printf 'signals 2' > "$tmp/signal-tail-eof"
printf 'g 1' > "$tmp/signal-tail-alias-eof"
printf 'u\ng 1\nevents\nquit\n' > "$tmp/signal-tail-compact"

# Resolve addresses from symbols in the native ELF fixtures.
memory_base="$(nm -n "$ROOT/build/stack_words" | awk '$3 == "words" {print $1; exit}')"
illegal_entry="$(nm -n "$ROOT/build/illegal" | awk '$3 == "_start" {print $1; exit}')"
if [[ ! "$memory_base" =~ ^[[:xdigit:]]{1,16}$ || ! "$illegal_entry" =~ ^[[:xdigit:]]{1,16}$ ]]; then
  printf 'Missing valid NASM fixture symbols for memory tests\n' >&2
  exit 1
fi
history_entry="$(nm -n "$ROOT/build/long_steps" | awk '$3 == "_start" {print $1; exit}')"
if [[ ! "$history_entry" =~ ^[[:xdigit:]]{1,16}$ ]]; then
  printf 'Missing valid long_steps _start symbol for history tests\n' >&2
  exit 1
fi
printf -v history_two '%016x' "$((16#$history_entry + 2))"
printf -v history_five '%016x' "$((16#$history_entry + 5))"
printf -v history_twenty '%016x' "$((16#$history_entry + 20))"
printf -v history_eighteen '%016x' "$((16#$history_entry + 18))"
printf -v history_thirtythree '%016x' "$((16#$history_entry + 33))"
printf -v memory_second '%016x' "$((16#$memory_base + 8))"
memory_upper="$(printf '%s' "$memory_base" | tr 'abcdef' 'ABCDEF')"
printf 'mem 0x%s\nquit\n' "$memory_base" > "$tmp/memory-word"
printf 'm 0x%s\nquit\n' "$memory_second" > "$tmp/memory-all-ones"
printf 'mem 0X%s\nquit\n' "$memory_upper" > "$tmp/memory-uppercase"
printf 'step\nmem 0x%s\nm 0x%s\nquit\n' "$memory_base" "$memory_second" > "$tmp/memory-repeated"
printf 'mem 0x0\nstatus\nquit\n' > "$tmp/memory-unmapped"
printf 'mem 0xffffffffffffffff\nquit\n' > "$tmp/memory-high-unmapped"
printf 'mem 0x\nmem 0xG\nmem 0x1234567890abcdef0\nmem -1\nm 0x1z\nmem 0x1  \nmem 1234\nm 0x\nquit\n' > "$tmp/memory-invalid"
printf 'step\nmem 0x%s\nstatus\nquit\n' "$illegal_entry" > "$tmp/memory-signal"
printf 'mem 0x%s\ncontinue\n' "$memory_base" > "$tmp/memory-compact"
printf 'code\nmem 0x%s\nstack\nquit\n' "$memory_base" > "$tmp/memory-combo"

# v0.2.5: bounded read-only word ranges and strict count syntax.
printf 'mem 0x%s 4\nquit\n' "$memory_base" > "$tmp/memory-range-four"
printf 'm 0x%s 2\nquit\n' "$memory_second" > "$tmp/memory-range-two"
printf 'mem 0x%s 1\nquit\n' "$memory_base" > "$tmp/memory-range-one"
printf 'mem 0x%s 0\nmem 0x%s 5\nmem 0x%s 10\nmem 0x%s -1\nmem 0x%s a\nmem 0x%s 1 \nmem 0x%s  2\nmem 0x%s 2x\nm 0x%s 4 \nstatus\nquit\n' \
  "$memory_base" "$memory_base" "$memory_base" "$memory_base" "$memory_base" \
  "$memory_base" "$memory_base" "$memory_base" "$memory_base" > "$tmp/memory-range-invalid-count"
printf 'mem 0xfffffffffffffff8 2\nquit\n' > "$tmp/memory-range-wrap"
# A long line ending in 'continue' must not resume the traced program.
# 62 bytes plus newline is exactly the longest accepted fgets line.
printf '%063dcontinue\nstatus\nquit\n' 0 > "$tmp/session-overlong"
printf '%064d' 0 > "$tmp/session-overlong-eof"
printf '%062d\nquit\n' 0 > "$tmp/session-max-line"

check help 0 "$BIN" --help
check version 0 "$BIN" --version
check session_continue 7 session_exec "$tmp/session-continue" "$BIN" run --interactive "$ROOT/build/exit7"
check batch_step_four 0 session_exec "$tmp/batch-step-four" "$BIN" run --interactive "$ROOT/build/long_steps"
check batch_step_sixteen 0 session_exec "$tmp/batch-step-sixteen" "$BIN" run --interactive "$ROOT/build/long_steps"
check batch_step_mixed 0 session_exec "$tmp/batch-step-mixed" "$BIN" run --interactive "$ROOT/build/long_steps"
check batch_step_explicit_one 0 session_exec "$tmp/batch-step-explicit-one" "$BIN" run --interactive "$ROOT/build/long_steps"
check batch_step_invalid 0 session_exec "$tmp/batch-step-invalid" "$BIN" run --interactive "$ROOT/build/long_steps"
check batch_step_ill 0 session_exec "$tmp/batch-step-ill" "$BIN" run --interactive "$ROOT/build/illegal"
check batch_step_ill_forward 132 session_exec "$tmp/batch-step-ill-forward" "$BIN" run --interactive "$ROOT/build/illegal"
check batch_step_segv 0 session_exec "$tmp/batch-step-segv" "$BIN" run --interactive "$ROOT/build/segv"
check batch_step_trap 0 session_exec "$tmp/batch-step-trap" "$BIN" run --interactive "$ROOT/build/trap"
check batch_step_compact 0 session_exec "$tmp/batch-step-compact" "$BIN" run --interactive --changes-only "$ROOT/build/long_steps"
check batch_step_inspect 0 session_exec "$tmp/batch-step-inspect" "$BIN" run --interactive "$ROOT/build/long_steps"
check batch_step_early_exit 0 session_exec "$tmp/batch-step-early-exit" "$BIN" run --interactive "$ROOT/build/exit0"
check batch_step_invalid_signal 0 session_exec "$tmp/batch-step-invalid-signal" "$BIN" run --interactive "$ROOT/build/illegal"
check batch_step_no_newline 0 session_exec "$tmp/batch-step-no-newline" "$BIN" run --interactive "$ROOT/build/long_steps"
check memory_word 0 session_exec "$tmp/memory-word" "$BIN" run --interactive "$ROOT/build/stack_words"
check memory_all_ones 0 session_exec "$tmp/memory-all-ones" "$BIN" run --interactive "$ROOT/build/stack_words"
check memory_uppercase 0 session_exec "$tmp/memory-uppercase" "$BIN" run --interactive "$ROOT/build/stack_words"
check memory_repeated 0 session_exec "$tmp/memory-repeated" "$BIN" run --interactive "$ROOT/build/stack_words"
check memory_unmapped 0 session_exec "$tmp/memory-unmapped" "$BIN" run --interactive "$ROOT/build/exit0"
check memory_high_unmapped 0 session_exec "$tmp/memory-high-unmapped" "$BIN" run --interactive "$ROOT/build/exit0"
check memory_invalid 0 session_exec "$tmp/memory-invalid" "$BIN" run --interactive "$ROOT/build/exit0"
check memory_signal 0 session_exec "$tmp/memory-signal" "$BIN" run --interactive "$ROOT/build/illegal"
check memory_compact 0 session_exec "$tmp/memory-compact" "$BIN" run --interactive --changes-only "$ROOT/build/stack_words"
check memory_combo 0 session_exec "$tmp/memory-combo" "$BIN" run --interactive "$ROOT/build/stack_words"
check memory_range_four 0 session_exec "$tmp/memory-range-four" "$BIN" run --interactive "$ROOT/build/stack_words"
check memory_range_two 0 session_exec "$tmp/memory-range-two" "$BIN" run --interactive "$ROOT/build/stack_words"
check memory_range_one 0 session_exec "$tmp/memory-range-one" "$BIN" run --interactive "$ROOT/build/stack_words"
check memory_range_invalid_count 0 session_exec "$tmp/memory-range-invalid-count" "$BIN" run --interactive "$ROOT/build/stack_words"
check memory_range_wrap 0 session_exec "$tmp/memory-range-wrap" "$BIN" run --interactive "$ROOT/build/stack_words"
check session_overlong 0 session_exec "$tmp/session-overlong" "$BIN" run --interactive "$ROOT/build/exit7"
check session_overlong_eof 0 session_exec "$tmp/session-overlong-eof" "$BIN" run --interactive "$ROOT/build/exit7"
check session_max_line 0 session_exec "$tmp/session-max-line" "$BIN" run --interactive "$ROOT/build/exit7"
check session_stack_initial 42 session_exec "$tmp/session-stack-initial" "$BIN" run --interactive "$ROOT/build/exit42"
check session_stack_fixture 0 session_exec "$tmp/session-stack-fixture" "$BIN" run --interactive "$ROOT/build/stack_words"
check session_stack_compact 0 session_exec "$tmp/session-stack-compact" "$BIN" run --interactive --changes-only "$ROOT/build/stack_words"
check session_stack_invalid 0 session_exec "$tmp/session-stack-invalid" "$BIN" run --interactive "$ROOT/build/invalid_rsp"
check session_stack_signal 0 session_exec "$tmp/session-stack-signal" "$BIN" run --interactive "$ROOT/build/illegal"
check session_stack_repeat 0 session_exec "$tmp/session-stack-repeat" "$BIN" run --interactive "$ROOT/build/exit0"
check session_stack_with_code 0 session_exec "$tmp/session-stack-with-code" "$BIN" run --interactive "$ROOT/build/stack_words"
check instruction_bytes_default 0 session_exec "$tmp/instruction-bytes-default" "$BIN" run --interactive "$ROOT/build/long_steps"
check instruction_bytes_alias 0 session_exec "$tmp/instruction-bytes-alias" "$BIN" run --interactive "$ROOT/build/long_steps"
check instruction_bytes_one 0 session_exec "$tmp/instruction-bytes-one" "$BIN" run --interactive "$ROOT/build/long_steps"
check instruction_bytes_four 0 session_exec "$tmp/instruction-bytes-four" "$BIN" run --interactive "$ROOT/build/long_steps"
check instruction_bytes_mixed 0 session_exec "$tmp/instruction-bytes-mixed" "$BIN" run --interactive "$ROOT/build/long_steps"
check instruction_bytes_allones 0 session_exec "$tmp/instruction-bytes-allones" "$BIN" run --interactive "$ROOT/build/all_ones"
check instruction_bytes_invalid 0 session_exec "$tmp/instruction-bytes-invalid" "$BIN" run --interactive "$ROOT/build/long_steps"
check instruction_bytes_signal 0 session_exec "$tmp/instruction-bytes-signal" "$BIN" run --interactive "$ROOT/build/illegal"
check instruction_bytes_compact 0 session_exec "$tmp/instruction-bytes-compact" "$BIN" run --interactive --changes-only "$ROOT/build/long_steps"
check instruction_bytes_eof 0 session_exec "$tmp/instruction-bytes-eof" "$BIN" run --interactive "$ROOT/build/long_steps"
check instruction_bytes_unknown 0 session_exec "$tmp/instruction-bytes-unknown" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_initial 0 session_exec "$tmp/history-initial" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_alias 0 session_exec "$tmp/history-alias" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_repeat 0 session_exec "$tmp/history-repeat" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_full_ring 0 session_exec "$tmp/history-full-ring" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_wrap_twice 0 session_exec "$tmp/history-wrap-twice" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_signal 0 session_exec "$tmp/history-signal" "$BIN" run --interactive "$ROOT/build/illegal"
check history_invalid_step 0 session_exec "$tmp/history-invalid-step" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_inspection 0 session_exec "$tmp/history-inspection" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_compact 0 session_exec "$tmp/history-compact" "$BIN" run --interactive --changes-only "$ROOT/build/long_steps"
check history_unknown 0 session_exec "$tmp/history-unknown" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_step_initial 0 session_exec "$tmp/history-step-initial" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_step_three 0 session_exec "$tmp/history-step-three" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_tail_one 0 session_exec "$tmp/history-tail-one" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_tail_three 0 session_exec "$tmp/history-tail-three" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_tail_alias 0 session_exec "$tmp/history-tail-alias" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_tail_clamp 0 session_exec "$tmp/history-tail-clamp" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_tail_invalid 0 session_exec "$tmp/history-tail-invalid" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_tail_signal 0 session_exec "$tmp/history-tail-signal" "$BIN" run --interactive "$ROOT/build/illegal"
check history_tail_inspection 0 session_exec "$tmp/history-tail-inspection" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_tail_repeat 0 session_exec "$tmp/history-tail-repeat" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_tail_eof 0 session_exec "$tmp/history-tail-eof" "$BIN" run --interactive "$ROOT/build/long_steps"
check history_tail_wrap 0 session_exec "$tmp/history-tail-wrap" "$BIN" run --interactive "$ROOT/build/long_steps"
check events_initial 0 session_exec "$tmp/events-initial" "$BIN" run --interactive "$ROOT/build/long_steps"
check events_alias 0 session_exec "$tmp/events-alias" "$BIN" run --interactive "$ROOT/build/long_steps"
check events_repeat 0 session_exec "$tmp/events-repeat" "$BIN" run --interactive "$ROOT/build/long_steps"
check events_steps 0 session_exec "$tmp/events-steps" "$BIN" run --interactive "$ROOT/build/long_steps"
check events_inspection 0 session_exec "$tmp/events-inspection" "$BIN" run --interactive "$ROOT/build/long_steps"
check events_invalid 0 session_exec "$tmp/events-invalid" "$BIN" run --interactive "$ROOT/build/long_steps"
check events_sigill 0 session_exec "$tmp/events-sigill" "$BIN" run --interactive "$ROOT/build/illegal"
check events_sigsegv 0 session_exec "$tmp/events-sigsegv" "$BIN" run --interactive "$ROOT/build/segv"
check events_sigtrap 0 session_exec "$tmp/events-sigtrap" "$BIN" run --interactive "$ROOT/build/trap"
check events_batch_signal 0 session_exec "$tmp/events-batch-signal" "$BIN" run --interactive "$ROOT/build/illegal"
check events_compact 0 session_exec "$tmp/events-compact" "$BIN" run --interactive --changes-only "$ROOT/build/long_steps"
check events_eof 0 session_exec "$tmp/events-eof" "$BIN" run --interactive "$ROOT/build/long_steps"
check events_alias_eof 0 session_exec "$tmp/events-alias-eof" "$BIN" run --interactive "$ROOT/build/long_steps"
check signal_history_empty 0 session_exec "$tmp/signal-history-empty" "$BIN" run --interactive "$ROOT/build/long_steps"
check signal_history_alias 0 session_exec "$tmp/signal-history-alias" "$BIN" run --interactive "$ROOT/build/long_steps"
check signal_history_repeated_empty 0 session_exec "$tmp/signal-history-repeated-empty" "$BIN" run --interactive "$ROOT/build/long_steps"
check signal_history_ill 0 session_exec "$tmp/signal-history-ill" "$BIN" run --interactive "$ROOT/build/illegal"
check signal_history_segv 0 session_exec "$tmp/signal-history-segv" "$BIN" run --interactive "$ROOT/build/segv"
check signal_history_trap 0 session_exec "$tmp/signal-history-trap" "$BIN" run --interactive "$ROOT/build/trap"
check signal_history_batch 0 session_exec "$tmp/signal-history-batch" "$BIN" run --interactive "$ROOT/build/illegal"
check signal_history_inspection 0 session_exec "$tmp/signal-history-inspection" "$BIN" run --interactive "$ROOT/build/long_steps"
check signal_history_compact 0 session_exec "$tmp/signal-history-compact" "$BIN" run --interactive --changes-only "$ROOT/build/illegal"
check signal_history_unknown 0 session_exec "$tmp/signal-history-unknown" "$BIN" run --interactive "$ROOT/build/long_steps"
check signal_history_eof 0 session_exec "$tmp/signal-history-eof" "$BIN" run --interactive "$ROOT/build/long_steps"
check signal_history_alias_eof 0 session_exec "$tmp/signal-history-alias-eof" "$BIN" run --interactive "$ROOT/build/long_steps"
check signal_history_forward 132 session_exec "$tmp/signal-history-forward" "$BIN" run --interactive "$ROOT/build/illegal"
check until_handled_twice 0 session_exec "$tmp/until-handled-twice" "$BIN" run --interactive "$ROOT/build/handled_signal"
check until_burst_ring 0 session_exec "$tmp/until-burst-ring" "$BIN" run --interactive "$ROOT/build/signal_burst"
check until_burst_repeat_read 0 session_exec "$tmp/until-burst-repeat" "$BIN" run --interactive "$ROOT/build/signal_burst"
check until_fault_pending 0 session_exec "$tmp/until-fault-pending" "$BIN" run --interactive "$ROOT/build/illegal"
check until_fault_forward 132 session_exec "$tmp/until-fault-forward" "$BIN" run --interactive "$ROOT/build/illegal"
check until_terminates 7 session_exec "$tmp/until-terminates" "$BIN" run --interactive "$ROOT/build/exit7"
check until_reexec 42 session_exec "$tmp/until-reexec" "$BIN" run --interactive "$ROOT/build/reexec" "$ROOT/build/exit42"
check until_invalid 0 session_exec "$tmp/until-invalid" "$BIN" run --interactive "$ROOT/build/long_steps"
check until_eof 7 session_exec "$tmp/until-eof" "$BIN" run --interactive "$ROOT/build/exit7"
check until_alias_eof 7 session_exec "$tmp/until-alias-eof" "$BIN" run --interactive "$ROOT/build/exit7"
check until_compact 0 session_exec "$tmp/until-compact" "$BIN" run --interactive --changes-only "$ROOT/build/illegal"
check until_inspect_pending 0 session_exec "$tmp/until-inspect-pending" "$BIN" run --interactive "$ROOT/build/illegal"
check until_step_pending 132 session_exec "$tmp/until-step-pending" "$BIN" run --interactive "$ROOT/build/illegal"
check until_continue_pending 132 session_exec "$tmp/until-continue-pending" "$BIN" run --interactive "$ROOT/build/illegal"
check signal_tail_empty 0 session_exec "$tmp/signal-tail-empty" "$BIN" run --interactive "$ROOT/build/long_steps"
check signal_tail_alias_empty 0 session_exec "$tmp/signal-tail-alias-empty" "$BIN" run --interactive "$ROOT/build/long_steps"
check signal_tail_pending 0 session_exec "$tmp/signal-tail-pending" "$BIN" run --interactive "$ROOT/build/illegal"
check signal_tail_clamp 0 session_exec "$tmp/signal-tail-clamp" "$BIN" run --interactive "$ROOT/build/illegal"
check signal_tail_full 0 session_exec "$tmp/signal-tail-full" "$BIN" run --interactive "$ROOT/build/signal_burst"
check signal_tail_wrap_three 0 session_exec "$tmp/signal-tail-wrap-three" "$BIN" run --interactive "$ROOT/build/signal_burst"
check signal_tail_wrap_alias 0 session_exec "$tmp/signal-tail-wrap-alias" "$BIN" run --interactive "$ROOT/build/signal_burst"
check signal_tail_invalid 0 session_exec "$tmp/signal-tail-invalid" "$BIN" run --interactive "$ROOT/build/long_steps"
check signal_tail_invalid_pending 0 session_exec "$tmp/signal-tail-invalid-pending" "$BIN" run --interactive "$ROOT/build/illegal"
check signal_tail_nonmutating 0 session_exec "$tmp/signal-tail-nonmutating" "$BIN" run --interactive "$ROOT/build/handled_signal"
check signal_tail_eof 0 session_exec "$tmp/signal-tail-eof" "$BIN" run --interactive "$ROOT/build/long_steps"
check signal_tail_alias_eof 0 session_exec "$tmp/signal-tail-alias-eof" "$BIN" run --interactive "$ROOT/build/long_steps"
check signal_tail_compact 0 session_exec "$tmp/signal-tail-compact" "$BIN" run --interactive --changes-only "$ROOT/build/illegal"
check session_code 42 session_exec "$tmp/session-code" "$BIN" run --interactive "$ROOT/build/exit42"
check session_code_alias 0 session_exec "$tmp/session-code-alias" "$BIN" run --interactive "$ROOT/build/long_steps"
check session_code_all_ones 0 session_exec "$tmp/session-code-all-ones" "$BIN" run --interactive "$ROOT/build/all_ones"
check session_code_signal 0 session_exec "$tmp/session-code-signal" "$BIN" run --interactive "$ROOT/build/illegal"
check session_code_compact 23 session_exec "$tmp/session-code-compact" "$BIN" run --interactive --changes-only "$ROOT/build/exit_group"
check session_code_regs 0 session_exec "$tmp/session-code-regs" "$BIN" run --interactive --changes-only "$ROOT/build/long_steps"
check session_status_start 0 session_exec "$tmp/session-status-start" "$BIN" run --interactive "$ROOT/build/long_steps"
check session_status_steps 0 session_exec "$tmp/session-status-steps" "$BIN" run --interactive --changes-only "$ROOT/build/long_steps"
check session_signal_ill 132 session_exec "$tmp/session-signal-ill" "$BIN" run --interactive "$ROOT/build/illegal"
check session_signal_segv 139 session_exec "$tmp/session-signal-segv" "$BIN" run --interactive "$ROOT/build/segv"
check session_signal_trap 133 session_exec "$tmp/session-signal-trap" "$BIN" run --interactive "$ROOT/build/trap"
check session_signal_quit 0 session_exec "$tmp/session-signal-quit" "$BIN" run --interactive "$ROOT/build/illegal"
check session_signal_regs 0 session_exec "$tmp/session-signal-regs" "$BIN" run --interactive --changes-only "$ROOT/build/illegal"
check session_signal_step 132 session_exec "$tmp/session-signal-step" "$BIN" run --interactive "$ROOT/build/illegal"
check session_steps 0 session_exec "$tmp/session-steps" "$BIN" run --interactive "$ROOT/build/long_steps"
check session_regs 0 session_exec "$tmp/session-regs" "$BIN" run --interactive --changes-only "$ROOT/build/long_steps"
check session_quit 0 session_exec "$tmp/session-quit" "$BIN" run --interactive "$ROOT/build/long_steps"
check session_eof 0 session_exec "$tmp/session-eof" "$BIN" run --interactive "$ROOT/build/exit0"
check session_help 0 session_exec "$tmp/session-help" "$BIN" run --interactive "$ROOT/build/exit0"
check session_quit_after_steps 0 session_exec "$tmp/session-quit-steps" "$BIN" run --interactive "$ROOT/build/long_steps"
check session_signal 138 session_exec "$tmp/session-continue" "$BIN" run --interactive "$ROOT/build/signal_usr1"
check session_reexec 42 session_exec "$tmp/session-continue" "$BIN" run --interactive "$ROOT/build/reexec" "$ROOT/build/exit42"
check session_group_stop 1 session_exec "$tmp/session-continue" "$BIN" run --interactive "$ROOT/build/group_stop"
check session_missing_exec 127 session_exec "$tmp/session-quit" "$BIN" run --interactive /definitely-not-a-real-rewind64-program
check conflict 2 "$BIN" run --interactive --steps 2 "$ROOT/build/exit0"
check conflict 2 "$BIN" run --steps 2 --interactive "$ROOT/build/exit0"
check conflict 2 "$BIN" run --interactive --observe-only "$ROOT/build/exit0"
check conflict 2 "$BIN" run --observe-only --interactive "$ROOT/build/exit0"
check duplicate 2 "$BIN" run --interactive --interactive "$ROOT/build/exit0"
check flag_usage 2 "$BIN" run --interactive
check unsupported 2 "$BIN" replay absent.r64
check usage 2 "$BIN" run
check zero 0 "$BIN" run "$ROOT/build/exit0"
check seven 7 "$BIN" run "$ROOT/build/exit7"
check trap_signal 133 "$BIN" run "$ROOT/build/trap"
check missing_exec 127 "$BIN" run /definitely-not-a-real-rewind64-program
check triple 0 "$BIN" run --steps 3 "$ROOT/build/argv" hello
check forward_args 0 "$BIN" run --steps 2 "$ROOT/build/argv" hello
check usr1 138 "$BIN" run "$ROOT/build/signal_usr1"
check thread_signal 138 "$BIN" run "$ROOT/build/thread_signal"
check thread_signal_compact 138 "$BIN" run --changes-only "$ROOT/build/thread_signal"
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
check observe_exit0 0 "$BIN" run --observe-only "$ROOT/build/exit0"
check observe_exit42 42 "$BIN" run --observe-only "$ROOT/build/exit42"
check observe_compact 23 "$BIN" run --changes-only --observe-only "$ROOT/build/exit_group"
check observe_reexec 42 "$BIN" run --observe-only "$ROOT/build/reexec" "$ROOT/build/exit42"
check observe_handled 0 "$BIN" run --observe-only "$ROOT/build/handled_signal"
check observe_user_signal 138 "$BIN" run --observe-only "$ROOT/build/thread_signal"
check observe_group_stop 1 "$BIN" run --observe-only "$ROOT/build/group_stop"
check observe_args 0 "$BIN" run --observe-only -- "$ROOT/build/argv" hello
check conflict 2 "$BIN" run --observe-only --steps 2 "$ROOT/build/exit0"
check conflict 2 "$BIN" run --steps 2 --observe-only "$ROOT/build/exit0"
check duplicate 2 "$BIN" run --observe-only --observe-only "$ROOT/build/exit0"
check flag_usage 2 "$BIN" run --observe-only
check exit_group 23 "$BIN" run --steps 1 "$ROOT/build/exit_group"
check exit_group_compact 23 "$BIN" run --changes-only "$ROOT/build/exit_group"
check exits_zero_signals 42 "$BIN" run --steps 2 "$ROOT/build/exit42"
check reexec 42 "$BIN" run --steps 1 "$ROOT/build/reexec" "$ROOT/build/exit42"
check reexec_compact 42 "$BIN" run --changes-only --steps 3 "$ROOT/build/reexec" "$ROOT/build/exit42"
check early_exit_event 0 "$BIN" run --steps 64 "$ROOT/build/exit0"
check group_stop 1 "$BIN" run "$ROOT/build/group_stop"
check group_stop_compact 1 "$BIN" run --changes-only "$ROOT/build/group_stop"
check group_stop_midstep 1 "$BIN" run --steps 64 "$ROOT/build/group_stop"
cp -- "$ROOT/build/exit42" "$tmp/--dash-program"
PATH="$tmp:$PATH" check dashed_target 42 "$BIN" run -- --dash-program
for bad in 0 -1 abc 65 99999999999 1x; do
  check invalid 2 "$BIN" run --steps "$bad" "$ROOT/build/exit0"
done

printf '%d passed; %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
