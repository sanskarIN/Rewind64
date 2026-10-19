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
version() { assert_contains version 'v0.2.1-pre'; }
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

check help 0 "$BIN" --help
check version 0 "$BIN" --version
check session_continue 7 session_exec "$tmp/session-continue" "$BIN" run --interactive "$ROOT/build/exit7"
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
