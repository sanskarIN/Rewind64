; Linux x86-64 ptrace debugger for explicitly launched targets only.
; All offsets below refer to Linux x86-64 struct user_regs_struct.
; This does not implement reverse execution or process attachment.
default rel

global debug_run
extern fork
extern execvp
extern _exit
extern ptrace
extern waitpid
extern kill
extern perror
extern printf
extern puts
extern __errno_location
extern print_registers
extern print_register_changes
extern fgets
extern strcmp
extern fflush
extern stdin
extern stdout

%define PTRACE_TRACEME     0
%define PTRACE_PEEKTEXT    1
%define PTRACE_CONT        7
%define PTRACE_SINGLESTEP  9
%define PTRACE_GETREGS     12
%define PTRACE_SETOPTIONS  0x4200
%define PTRACE_GETSIGINFO  0x4202
%define PTRACE_GETEVENTMSG 0x4201  ; unsigned long ptrace event payload
%define PTRACE_O_EXITKILL  0x00100000
%define PTRACE_O_TRACEEXEC 0x00000010
%define PTRACE_O_TRACEEXIT 0x00000040
%define PTRACE_EVENT_EXEC  4
%define PTRACE_EVENT_EXIT  6
%define EXEC_EVENTS        (-648)        ; outside previous register snapshot
%define EXIT_EVENTS        (-652)
%define CLEANUP_STOPS      (-656)        ; bounded reap loop state
%define EVENT_MESSAGE      (-664)        ; qword event payload; non-overlapping
%define SESSION_MODE       (-680)        ; dword interactive mode from CLI
%define SESSION_RETURN     (-684)        ; dword return after cleanup; 0 for quit
%define SESSION_STEPPING   (-688)        ; dword: pending interactive single-step request
%define INJECTED_SIGNAL    (-692)        ; dword: signal used by last ptrace resume
%define SESSION_BUFFER     (-832)        ; 64-byte input buffer, -832..-769
%define SESSION_BUF_SIZE    64
%define SIGKILL            9
%define SIGTRAP            5
%define TRAP_TRACE         2              ; siginfo_t.si_code for single-step
%define TRAP_BRKPT         1              ; also used for syscall-step on Linux
%define SIGNAL_STOPS       (-28)         ; distinct from child wait status
%define STATUS             (-24)
%define SIGINFO            (-400)         ; 128-byte siginfo_t, non-overlapping
%define PREVREGS           (-640)         ; prior 216-byte snapshot: -640..-425
%define REGS               (-256)
%define REG_RIP            (REGS + 128)
%define REG_RSP            (REGS + 152)

section .rodata
    msg_initial:   db 'Initial stop: pid=%ld RIP=0x%016lx RSP=0x%016lx', 10, 0
    msg_session_intro: db 'Interactive session: step | regs | status | continue | help | quit', 0
    msg_session_status: db 'Session status: pid=%ld steps=%u pending_signal=%u', 10, 0
    msg_pending_signal: db 'Interactive signal stop: signal %u pending; choose step, continue or quit.', 10, 0
    msg_session_prompt: db 'rewind64> ', 0
    msg_session_unknown: db 'Unknown session command. Type help.', 0
    msg_session_quit: db 'Interactive session ended; tracee terminated and reaped.', 0
    msg_session_steps: db 'Interactive steps completed: %u', 10, 0
    cmd_step: db 'step', 10, 0
    cmd_regs: db 'regs', 10, 0
    cmd_status: db 'status', 10, 0
    cmd_continue: db 'continue', 10, 0
    cmd_quit: db 'quit', 10, 0
    cmd_help: db 'help', 10, 0
    cmd_short_step: db 's', 10, 0
    cmd_short_regs: db 'r', 10, 0
    cmd_short_status: db 'i', 10, 0
    cmd_short_continue: db 'c', 10, 0
    cmd_short_quit: db 'q', 10, 0
    msg_step:      db 'After step:   pid=%ld RIP=0x%016lx RSP=0x%016lx', 10, 0
    msg_exit:      db 'Target exited with status %d', 10, 0
    msg_signal:    db 'Target terminated by signal %d', 10, 0
    msg_steps:     db 'Steps completed: %d / %d', 10, 0
    msg_signal_stop: db 'Signal-delivery stop: signal %d si_code=%d', 10, 0
    msg_sender:    db 'Signal sender: pid=%d uid=%u', 10, 0
    msg_stop_total:  db 'Signals forwarded: %d', 10, 0
    msg_exec_event:  db 'Ptrace exec event: pid=%ld', 10, 0
    msg_exit_event:  db 'Ptrace exit event: pid=%ld', 10, 0
    msg_exit_detail: db 'Ptrace exit detail: raw_wait=0x%08lx', 10, 0
    msg_event_total: db 'Ptrace events: exec=%u exit=%u', 10, 0
    err_event:      db 'Error: unsupported ptrace event %u', 10, 0
    msg_other_trap: db 'Unexpected SIGTRAP si_code=%d during step', 10, 0
    err_fork:      db 'fork', 0
    err_trace:     db 'ptrace(TRACEME)', 0
    err_exec:      db 'execvp', 0
    err_wait:      db 'waitpid', 0
    err_options:   db 'ptrace(SETOPTIONS)', 0
    err_regs:      db 'ptrace(GETREGS)', 0
    err_siginfo:   db 'ptrace(GETSIGINFO)', 0
    err_eventmsg:  db 'ptrace(GETEVENTMSG)', 0
    err_step:      db 'ptrace(SINGLESTEP)', 0
    err_cont:      db 'ptrace(CONT)', 0
    err_stop:      db 'Error: child did not enter expected ptrace stop.', 0
    err_group_stop: db 'Error: job-control group stop is unsupported by this tracer.', 0
    err_reap:      db 'Error: cleanup exhausted ptrace stop budget.', 0

section .text
; debug_run(argv, step_limit, changes_only, interactive) => target status;
; interactive=1 uses an Assembly command prompt at the initial exec stop.
; quit/EOF returns 0 after best-effort child shutdown; debugger errors return 1.
; changes_only affects display only; kernel state capture and delta logic unchanged.
; step_limit is CLI-validated in the inclusive range 1..64, or exactly 0
; in --observe-only mode (initial snapshot and ptrace events; no single-step).
; Stack frame holds pid, status, and two disjoint 216-byte register blocks.
; Previous snapshot -640..-425, siginfo -400..-273, new regs -256..-41.
; Event payload at -664..-657 is distinct from cleanup counters and CPU state.
; Prompt control at -692..-677, text input at -832..-769.
debug_run:
    push rbp
    mov rbp, rsp
    sub rsp, 864
    mov [rbp-8], rdi              ; argv vector from CLI
    mov dword [rbp-264], esi      ; requested maximum steps
    mov dword [rbp-40], edx       ; compact register display flag
    mov dword [rbp+SESSION_MODE], ecx
    mov dword [rbp+SESSION_RETURN], 1
    mov dword [rbp+SESSION_STEPPING], 0
    mov dword [rbp-36], 0         ; no pending tracee signal initially
    mov dword [rbp-272], 0        ; completed steps
    mov dword [rbp+SIGNAL_STOPS], 0 ; observed signal-delivery stops
    mov dword [rbp+EXEC_EVENTS], 0
    mov dword [rbp+EXIT_EVENTS], 0
    call fork
    test eax, eax
    js .fork_failed
    jz .child
    mov [rbp-16], rax             ; pid_t

    call .wait_child
    test eax, eax
    js .wait_failed
    mov eax, [rbp+STATUS]
    and eax, 0xff
    cmp eax, 0x7f                 ; WIFSTOPPED(status)
    jne .not_stopped
    ; TRACEME + exec generates an initial SIGTRAP stop. Do not attempt
    ; to single-step an unrelated, unexpected signal-delivery stop.
    mov eax, [rbp+STATUS]
    shr eax, 8
    and eax, 0xff
    cmp eax, SIGTRAP
    jne .wrong_stop

    ; EXITKILL prevents an orphaned traced child if the debugger crashes.
    mov edi, PTRACE_SETOPTIONS
    mov rsi, [rbp-16]
    xor edx, edx
    mov ecx, PTRACE_O_EXITKILL | PTRACE_O_TRACEEXEC | PTRACE_O_TRACEEXIT
    xor eax, eax
    call ptrace
    cmp rax, -1
    je .options_failed

    call .get_regs
    test eax, eax
    js .regs_failed
    lea rdi, [rel msg_initial]
    call .print_regs
    call .save_regs             ; persist previous state before stepping
    cmp dword [rbp+SESSION_MODE], 0
    jne .session_entry
    ; Opt-in observation mode samples initial registers but performs no
    ; PTRACE_SINGLESTEP requests; continue and observe events to termination.
    cmp dword [rbp-264], 0
    jne .step_loop
    mov dword [rbp-36], 0
    jmp .resume

.step_loop:
    ; A user-initiated step from a signal-delivery stop must inject the
    ; signal exactly once. Bounded automatic stepping has no pending signal.
    xor ecx, ecx
    cmp dword [rbp+SESSION_MODE], 0
    je .issue_step
    mov ecx, [rbp-36]
.issue_step:
    mov dword [rbp+INJECTED_SIGNAL], ecx
    mov edi, PTRACE_SINGLESTEP
    mov rsi, [rbp-16]
    xor edx, edx
    xor eax, eax
    call ptrace
    cmp rax, -1
    je .step_failed
    cmp dword [rbp+INJECTED_SIGNAL], 0
    je .step_no_signal
    inc dword [rbp+SIGNAL_STOPS]
.step_no_signal:
    mov dword [rbp-36], 0       ; consumed by a successful resume request

    call .wait_child
    test eax, eax
    js .wait_failed
    mov eax, [rbp+STATUS]
    and eax, 0xff
    cmp eax, 0x7f
    jne .not_stopped
    ; Trace event stops encode their PTRACE_EVENT_* value in the upper
    ; 16 bits of wait status and MUST NOT be forwarded as SIGTRAP.
    mov eax, [rbp+STATUS]
    shr eax, 16
    test eax, eax
    jnz .ptrace_event
    mov eax, [rbp+STATUS]
    shr eax, 8
    and eax, 0xff
    cmp eax, SIGTRAP
    jne .interrupted_step        ; do not kill the tracee for delivered signals
    ; A breakpoint-generated SIGTRAP is not a single-step completion.
    ; Distinguish TRAP_TRACE from TRAP_BRKPT before showing a snapshot.
    call .get_siginfo
    cmp rax, -1
    je .siginfo_failed
    cmp dword [rbp+SIGINFO+8], TRAP_TRACE
    je .step_completed
    cmp dword [rbp+SIGINFO+8], TRAP_BRKPT
    jne .unexpected_trap_code
    ; On some Linux kernels single-stepping the SYSCALL opcode reports
    ; TRAP_BRKPT instead of TRAP_TRACE. Only classify this as a synthetic
    ; step when the *previous* RIP points to the SYSCALL instruction (0f05).
    ; A user INT3 (cc) or generated SIGTRAP must still be delivered.
    mov edi, PTRACE_PEEKTEXT
    mov rsi, [rbp-16]
    mov rdx, [rbp+PREVREGS+128]   ; RIP before PTRACE_SINGLESTEP
    xor ecx, ecx
    xor eax, eax
    call ptrace
    cmp ax, 0x050f              ; little-endian instruction bytes 0f 05
    jne .unexpected_trap_code
.step_completed:
    call .get_regs
    test eax, eax
    js .regs_failed
    lea rdi, [rel msg_step]
    call .print_regs
    lea rdi, [rbp+PREVREGS]
    lea rsi, [rbp+REGS]
    call print_register_changes
    call .save_regs             ; make current state the next baseline
    inc dword [rbp-272]
    cmp dword [rbp+SESSION_MODE], 0
    je .bounded_step_check
    mov dword [rbp+SESSION_STEPPING], 0
    jmp .session_prompt
.bounded_step_check:
    mov eax, [rbp-272]
    cmp eax, [rbp-264]
    jl .step_loop

    mov dword [rbp-36], 0                ; synthetic single-step SIGTRAP must not be delivered
    jmp .resume
.session_entry:
    lea rdi, [rel msg_session_intro]
    call puts
.session_prompt:
    lea rdi, [rel msg_session_prompt]
    xor eax, eax
    call printf
    mov rdi, [rel stdout]
    call fflush
    lea rdi, [rbp+SESSION_BUFFER]
    mov esi, SESSION_BUF_SIZE
    mov rdx, [rel stdin]
    call fgets
    test rax, rax
    jz .session_quit             ; EOF = safe, explicit shutdown
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_step]
    call strcmp
    test eax, eax
    jz .session_step
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_short_step]
    call strcmp
    test eax, eax
    jz .session_step
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_regs]
    call strcmp
    test eax, eax
    jz .session_regs
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_short_regs]
    call strcmp
    test eax, eax
    jz .session_regs
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_status]
    call strcmp
    test eax, eax
    jz .session_status
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_short_status]
    call strcmp
    test eax, eax
    jz .session_status
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_continue]
    call strcmp
    test eax, eax
    jz .session_continue
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_short_continue]
    call strcmp
    test eax, eax
    jz .session_continue
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_quit]
    call strcmp
    test eax, eax
    jz .session_quit
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_short_quit]
    call strcmp
    test eax, eax
    jz .session_quit
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_help]
    call strcmp
    test eax, eax
    jz .session_entry
    lea rdi, [rel msg_session_unknown]
    call puts
    jmp .session_prompt
.session_step:
    mov dword [rbp+SESSION_STEPPING], 1
    jmp .step_loop
.session_status:
    lea rdi, [rel msg_session_status]
    mov rsi, [rbp-16]
    mov edx, [rbp-272]
    mov ecx, [rbp-36]
    xor eax, eax
    call printf
    jmp .session_prompt
.session_regs:
    call .get_regs
    test eax, eax
    js .regs_failed
    lea rdi, [rbp+REGS]
    call print_registers        ; explicit regs always shows complete state
    jmp .session_prompt
.session_continue:
    ; If paused by a genuine signal-delivery stop, continue forwards
    ; the recorded pending signal rather than silently swallowing it.
    mov dword [rbp+SESSION_STEPPING], 0
    jmp .resume
.session_quit:
    lea rdi, [rel msg_session_quit]
    call puts
    call .print_step_count
    mov dword [rbp+SESSION_RETURN], 0
    jmp .cleanup

.unexpected_trap_code:
    lea rdi, [rel msg_other_trap]
    mov esi, [rbp+SIGINFO+8]
    xor eax, eax
    call printf
    jmp .interrupted_step
.interrupted_step:
    ; Preserve a non-step signal stop rather than losing it or treating it
    ; as a debugger error. Resume the tracee with that signal delivered.
    mov eax, [rbp+STATUS]
    shr eax, 8
    and eax, 0xff
    mov [rbp-36], eax
    jmp .classify_signal_stop
; Unlike a signal-delivery stop, Linux job-control group stops do not
; carry a siginfo record: PTRACE_GETSIGINFO fails with EINVAL. Forwarding
; SIGSTOP again on group-stop can loop forever; fail closed and reap.
.classify_signal_stop:
    call .get_siginfo
    cmp rax, -1
    jne .valid_signal_stop
    call __errno_location
    cmp dword [rax], 22             ; EINVAL => group stop
    je .group_stop
    jmp .siginfo_failed
.valid_signal_stop:
    call .report_signal_stop
    cmp dword [rbp+SESSION_MODE], 0
    je .resume
    cmp dword [rbp+SESSION_STEPPING], 0
    je .resume                 ; continue remains noninteractive
    mov dword [rbp+SESSION_STEPPING], 0
    lea rdi, [rel msg_pending_signal]
    mov esi, [rbp-36]
    xor eax, eax
    call printf
    jmp .session_prompt       ; child is stopped, signal not yet injected
.resume:
    mov edi, PTRACE_CONT
    mov rsi, [rbp-16]
    xor edx, edx
    mov ecx, [rbp-36]                 ; reinject unrelated signals
    mov dword [rbp+INJECTED_SIGNAL], ecx
    xor eax, eax
    call ptrace
    cmp rax, -1
    je .cont_failed
    cmp dword [rbp+INJECTED_SIGNAL], 0
    je .resume_no_signal
    inc dword [rbp+SIGNAL_STOPS]
.resume_no_signal:
    mov dword [rbp-36], 0             ; successfully submitted signal

    call .wait_child
    test eax, eax
    js .wait_failed
    mov eax, [rbp+STATUS]
    mov ecx, eax
    and ecx, 0x7f
    cmp ecx, 0
    je .exited
    cmp ecx, 0x7f
    je .stopped_again
.signaled:
    ; WIFSIGNALED: low seven bits are terminating signal.
    mov [rbp-32], ecx
    lea rdi, [rel msg_signal]
    mov esi, ecx
    xor eax, eax
    call printf
    call .print_step_count
    mov eax, [rbp-32]
    add eax, 128
    jmp .done

.not_stopped:
    mov eax, [rbp+STATUS]
    mov ecx, eax
    and ecx, 0x7f
    test ecx, ecx
    jz .exited
    cmp ecx, 0x7f
    jne .signaled
    jmp .wrong_stop

.stopped_again:
    mov edx, eax
    shr edx, 16
    test edx, edx
    jnz .ptrace_event
    shr eax, 8
    and eax, 0xff
    mov [rbp-36], eax
    ; After the single-step trap, ordinary signals belong to the target.
    ; Reject group stops instead of reinjecting SIGSTOP indefinitely.
    jmp .classify_signal_stop

; PTRACE_O_TRACEEXEC / PTRACE_O_TRACEEXIT produce synthetic SIGTRAP
; wait stops, not application signals. Resume with signal zero.
.ptrace_event:
    mov eax, [rbp+STATUS]
    shr eax, 16
    cmp eax, PTRACE_EVENT_EXEC
    je .observed_exec
    cmp eax, PTRACE_EVENT_EXIT
    je .observed_exit
    mov esi, eax
    lea rdi, [rel err_event]
    xor eax, eax
    call printf
    jmp .cleanup
.observed_exec:
    inc dword [rbp+EXEC_EVENTS]
    lea rdi, [rel msg_exec_event]
    jmp .event_print
.observed_exit:
    inc dword [rbp+EXIT_EVENTS]
    call .get_event_message
    cmp rax, -1
    je .eventmsg_failed
    lea rdi, [rel msg_exit_detail]
    mov rsi, [rbp+EVENT_MESSAGE]
    xor eax, eax
    call printf
    lea rdi, [rel msg_exit_event]
.event_print:
    mov rsi, [rbp-16]
    xor eax, eax
    call printf
    mov dword [rbp-36], 0
    mov dword [rbp+SESSION_STEPPING], 0   ; event path resumes automatically
    jmp .resume

.exited:
    mov eax, [rbp+STATUS]
    shr eax, 8
    and eax, 0xff
    mov [rbp-32], eax
    lea rdi, [rel msg_exit]
    mov esi, [rbp-32]
    xor eax, eax
    call printf
    call .print_step_count
    mov eax, [rbp-32]
    jmp .done

.child:
    mov edi, PTRACE_TRACEME
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor eax, eax
    call ptrace
    cmp rax, -1
    je .trace_failed
    mov rax, [rbp-8]
    mov rdi, [rax]
    mov rsi, rax
    call execvp
    lea rdi, [rel err_exec]
    call perror
    mov edi, 127
    call _exit
.trace_failed:
    lea rdi, [rel err_trace]
    call perror
    mov edi, 126
    call _exit

; Reports signal-delivery stops before injecting the signal into the tracee.
; The count is observational, not a per-signal-handling guarantee.
.report_signal_stop:
    sub rsp, 8
    ; Count successful nonzero-signal ptrace resumes instead of stops:
    ; an interactive user may inspect a pending stop and quit without
    ; ever forwarding that signal to the tracee.
    lea rdi, [rel msg_signal_stop]
    mov esi, [rbp-36]
    mov edx, [rbp+SIGINFO+8]      ; signed si_code; e.g. SI_USER=0, SI_TKILL=-6
    xor eax, eax
    call printf
    ; The kill(2) siginfo union exposes sender PID and UID at offsets
    ; 16 and 20 only for user-originated SI_USER / SI_TKILL deliveries.
    ; Never interpret these fields for kernel-generated CPU fault signals.
    mov eax, [rbp+SIGINFO+8]
    cmp eax, 0                   ; SI_USER
    je .user_sender
    cmp eax, -6                  ; SI_TKILL
    jne .sender_done
.user_sender:
    lea rdi, [rel msg_sender]
    mov esi, [rbp+SIGINFO+16]
    mov edx, [rbp+SIGINFO+20]
    xor eax, eax
    call printf
.sender_done:
    add rsp, 8
    ret

; Reports completed steps and signals forwarded when a tracee exits.
.print_step_count:
    sub rsp, 8
    cmp dword [rbp+SESSION_MODE], 0
    je .bounded_summary
    lea rdi, [rel msg_session_steps]
    mov esi, [rbp-272]
    xor eax, eax
    call printf
    jmp .other_summary
.bounded_summary:
    lea rdi, [rel msg_steps]
    mov esi, [rbp-272]
    mov edx, [rbp-264]
    xor eax, eax
    call printf
.other_summary:
    lea rdi, [rel msg_stop_total]
    mov esi, [rbp+SIGNAL_STOPS]
    xor eax, eax
    call printf
    lea rdi, [rel msg_event_total]
    mov esi, [rbp+EXEC_EVENTS]
    mov edx, [rbp+EXIT_EVENTS]
    xor eax, eax
    call printf
    add rsp, 8
    ret

; A full 216-byte user_regs_struct is 27 qwords. This helper copies only
; debugger-owned state, without allocating or relying on Python/C helpers.
.save_regs:
    lea rsi, [rbp+REGS]
    lea rdi, [rbp+PREVREGS]
    mov ecx, 27
    cld
    rep movsq
    ret

; Internal subroutines preserve the debug_run frame.
.wait_child:
    sub rsp, 8                     ; helper calls maintain ABI alignment
    mov edi, [rbp-16]
    lea rsi, [rbp+STATUS]
    xor edx, edx
.wait_again:
    call waitpid
    cmp rax, -1
    jne .wait_done
    call __errno_location
    cmp dword [rax], 4           ; EINTR
    jne .wait_failed_errno
    mov edi, [rbp-16]
    lea rsi, [rbp+STATUS]
    xor edx, edx
    jmp .wait_again
.wait_failed_errno:
    mov rax, -1
.wait_done:
    add rsp, 8
    ret
.get_regs:
    sub rsp, 8
    mov edi, PTRACE_GETREGS
    mov rsi, [rbp-16]
    xor edx, edx
    lea rcx, [rbp+REGS]
    xor eax, eax
    call ptrace
    add rsp, 8
    ret
; Linux siginfo_t has si_signo, si_errno, si_code at offsets 0,4,8.
.get_siginfo:
    sub rsp, 8
    mov edi, PTRACE_GETSIGINFO
    mov rsi, [rbp-16]
    xor edx, edx
    lea rcx, [rbp+SIGINFO]
    xor eax, eax
    call ptrace
    add rsp, 8
    ret
; Linux PTRACE_GETEVENTMSG places a machine word at the supplied address;
; for TRACEEXIT it is the kernel's pending raw wait status.
.get_event_message:
    sub rsp, 8
    mov edi, PTRACE_GETEVENTMSG
    mov rsi, [rbp-16]
    xor edx, edx
    lea rcx, [rbp+EVENT_MESSAGE]
    xor eax, eax
    call ptrace
    add rsp, 8
    ret
.print_regs:
    sub rsp, 8
    mov rsi, [rbp-16]
    mov rdx, [rbp+REG_RIP]
    mov rcx, [rbp+REG_RSP]
    xor eax, eax
    call printf
    cmp dword [rbp-40], 0         ; opt-in concise display
    jne .skip_full_table
    lea rdi, [rbp+REGS]           ; complete Linux x86-64 register snapshot
    call print_registers
.skip_full_table:
    add rsp, 8
    ret

.fork_failed:
    lea rdi, [rel err_fork]
    call perror
    mov eax, 1
    jmp .done
.wait_failed:
    lea rdi, [rel err_wait]
    jmp .cleanup_errno
.options_failed:
    lea rdi, [rel err_options]
    jmp .cleanup_errno
.regs_failed:
    lea rdi, [rel err_regs]
    jmp .cleanup_errno
.siginfo_failed:
    lea rdi, [rel err_siginfo]
    jmp .cleanup_errno
.eventmsg_failed:
    lea rdi, [rel err_eventmsg]
    jmp .cleanup_errno
.step_failed:
    lea rdi, [rel err_step]
    jmp .cleanup_errno
.cont_failed:
    lea rdi, [rel err_cont]
    jmp .cleanup_errno
.wrong_stop:
    lea rdi, [rel err_stop]
    call puts
    jmp .cleanup
.group_stop:
    lea rdi, [rel err_group_stop]
    call puts
    jmp .cleanup
.cleanup_errno:
    call perror
.cleanup:
    ; A SIGKILL is not necessarily followed by a terminal waitpid result:
    ; PTRACE_O_TRACEEXIT can first report a synthetic EXIT stop. Drain
    ; stopped states with PTRACE_CONT(signal=0), then wait until the child
    ; has been reaped. Limit the stop loop to avoid infinite cleanup cycles.
    mov edi, [rbp-16]
    mov esi, SIGKILL
    call kill
    mov dword [rbp+CLEANUP_STOPS], 0
.cleanup_wait:
    call .wait_child
    cmp rax, -1
    je .cleanup_done            ; already reaped/ECHILD or wait error
    mov eax, [rbp+STATUS]
    mov ecx, eax
    and ecx, 0x7f
    je .cleanup_done            ; WIFEXITED
    cmp ecx, 0x7f
    jne .cleanup_done           ; WIFSIGNALED
    inc dword [rbp+CLEANUP_STOPS]
    cmp dword [rbp+CLEANUP_STOPS], 32
    jae .cleanup_exhausted
    mov edi, PTRACE_CONT
    mov rsi, [rbp-16]
    xor edx, edx
    xor ecx, ecx
    xor eax, eax
    call ptrace
    cmp rax, -1
    je .cleanup_wait            ; possibly died between stop and continue
    jmp .cleanup_wait
.cleanup_exhausted:
    lea rdi, [rel err_reap]
    call puts
    mov edi, [rbp-16]
    mov esi, SIGKILL
    call kill                   ; bounded best-effort fallback
.cleanup_done:
    mov eax, [rbp+SESSION_RETURN]
.done:
    leave
    ret
