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
extern strlen
extern getchar
extern strcmp
extern fflush
extern stdin
extern stdout

%define PTRACE_TRACEME     0
%define PTRACE_PEEKTEXT    1
%define PTRACE_PEEKDATA    2
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
%define CODE_WORD          (-704)        ; qword: PTRACE_PEEKTEXT result at current RIP
%define STACK_WORD         (-712)        ; read-only PTRACE_PEEKDATA result
%define STACK_BASE         (-720)        ; saved RSP from fresh registers
%define STACK_INDEX        (-724)        ; bounded word index, 0..3
%define STACK_WORD_LIMIT   4
%define MEMORY_ADDRESS     (-736)        ; one address read from strict hex
%define MEMORY_DIGITS      (-740)        ; parsed digit count, max 16
%define MEMORY_WORD        (-752)        ; qword from PTRACE_PEEKDATA
%define MEMORY_LIMIT       (-756)        ; bounded requested words, 1..4
%define MEMORY_INDEX       (-760)        ; zero-based current word index
%define MEMORY_CURRENT     (-768)        ; computed address checked for wrap
%define SESSION_BUFFER     (-832)        ; 64-byte input buffer, -832..-769
%define SESSION_BUF_SIZE    64
%define SESSION_REMAINING  (-840)       ; dword batch steps left, outside input buffer
%define SESSION_MAX_STEPS  16         ; bounded operator-requested batch
%define BYTE_LIMIT         (-844)     ; instruction-byte count 1..8
%define BYTE_INDEX         (-848)     ; byte offset within inspected word
%define HISTORY_BUFFER     (-1024)    ; 16 x 8-byte RIP snapshots, -1024..-897
%define HISTORY_START      (-892)     ; oldest ring slot when full (dword)
%define HISTORY_PRINT_INDEX (-888)    ; bounded iteration index (dword)
%define HISTORY_NEXT       (-884)     ; next slot to overwrite (dword)
%define HISTORY_COUNT      (-880)     ; stored snapshots, 0..16 (dword)
%define HISTORY_CAPACITY   16
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
    msg_session_intro: db 'Interactive session: step [1..16] | history | regs | status | code | bytes [1..8] | stack | mem 0xHEX [1..4] | continue | help | quit', 0
    msg_history_entry: db 'RIP history [%u]: 0x%016lx', 10, 0
    msg_step_usage: db 'Usage: step [1..16] or s [1..16] (strict decimal count; default 1)', 0
    msg_byte_usage: db 'Usage: bytes [1..8] or b [1..8] (read-only RIP bytes; default 8)', 0
    msg_instruction_byte: db 'Instruction byte [+%u] at 0x%016lx: 0x%02x', 10, 0
    msg_memory_word: db 'Memory word at 0x%016lx: 0x%016lx', 10, 0
    msg_memory_usage: db 'Usage: mem 0xHEX [1..4] or m 0xHEX [1..4] (1..16 hex digits; 8 bytes per word)', 0
    err_memory_wrap: db 'Error: memory range wraps the 64-bit address space.', 0
    msg_stack_word: db 'Stack word [%u] at 0x%016lx: 0x%016lx', 10, 0
    msg_code_word: db 'Code word at RIP=0x%016lx: 0x%016lx', 10, 0
    msg_session_status: db 'Session status: pid=%ld steps=%u pending_signal=%u', 10, 0
    msg_pending_signal: db 'Interactive signal stop: signal %u pending; choose step, continue or quit.', 10, 0
    msg_session_prompt: db 'rewind64> ', 0
    msg_session_unknown: db 'Unknown session command. Type help.', 0
    msg_session_overlong: db 'Error: session command too long (maximum 62 bytes); line discarded.', 0
    msg_session_quit: db 'Interactive session ended; tracee terminated and reaped.', 0
    msg_session_steps: db 'Interactive steps completed: %u', 10, 0
    cmd_step: db 'step', 10, 0
    cmd_regs: db 'regs', 10, 0
    cmd_status: db 'status', 10, 0
    cmd_code: db 'code', 10, 0
    cmd_bytes: db 'bytes', 10, 0
    cmd_stack: db 'stack', 10, 0
    cmd_continue: db 'continue', 10, 0
    cmd_quit: db 'quit', 10, 0
    cmd_help: db 'help', 10, 0
    cmd_history: db 'history', 10, 0
    cmd_short_history: db 'h', 10, 0
    cmd_short_step: db 's', 10, 0
    cmd_short_regs: db 'r', 10, 0
    cmd_short_status: db 'i', 10, 0
    cmd_short_code: db 'x', 10, 0
    cmd_short_bytes: db 'b', 10, 0
    cmd_short_stack: db 'k', 10, 0
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
    err_code_read: db 'ptrace(PEEKTEXT at RIP)', 0
    err_byte_read: db 'ptrace(PEEKTEXT bytes at RIP)', 0
    err_stack_read: db 'ptrace(PEEKDATA at RSP)', 0
    err_memory_read: db 'ptrace(PEEKDATA at address)', 0
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
; Prompt control and memory words at -752..-677, text input at -832..-769.
; RIP history ring at -1024..-897 and metadata at -892..-880 never
; overlap the tracee register snapshots, input, or other local state.
debug_run:
    push rbp
    mov rbp, rsp
    sub rsp, 1056
    mov [rbp-8], rdi              ; argv vector from CLI
    mov dword [rbp-264], esi      ; requested maximum steps
    mov dword [rbp-40], edx       ; compact register display flag
    mov dword [rbp+SESSION_MODE], ecx
    mov dword [rbp+SESSION_RETURN], 1
    mov dword [rbp+SESSION_STEPPING], 0
    mov dword [rbp+SESSION_REMAINING], 0
    mov dword [rbp+HISTORY_NEXT], 0
    mov dword [rbp+HISTORY_COUNT], 0
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
    call .record_rip            ; initial post-exec RIP, before any stepping
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
    call .record_rip            ; a confirmed step, not a signal/event stop
    inc dword [rbp-272]
    cmp dword [rbp+SESSION_MODE], 0
    je .bounded_step_check
    ; A counted interactive step request is completed only after a real
    ; synthetic step trap. Keep sampling/deltas on every instruction.
    dec dword [rbp+SESSION_REMAINING]
    jg .step_loop
    mov dword [rbp+SESSION_STEPPING], 0
    mov dword [rbp+SESSION_REMAINING], 0
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
    ; A line longer than the 63-byte fgets payload must be discarded
    ; as a WHOLE, otherwise a trailing fragment could become a command.
    ; Permit a final newline as byte 63 (62 command bytes).
    lea rdi, [rbp+SESSION_BUFFER]
    call strlen
    cmp rax, SESSION_BUF_SIZE - 1
    jne .session_dispatch
    cmp byte [rbp+SESSION_BUFFER+SESSION_BUF_SIZE-2], 10
    je .session_dispatch
.session_drain:
    call getchar
    cmp eax, -1                ; EOF: no partial command is executed
    je .session_overlong
    cmp eax, 10
    jne .session_drain
.session_overlong:
    lea rdi, [rel msg_session_overlong]
    call puts
    jmp .session_prompt
.session_dispatch:
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
    ; Distinguish 'step N' and 's N' from the exact single-step forms,
    ; with no prefix confusion for 'stack', 'status' or other commands.
    lea rsi, [rbp+SESSION_BUFFER]
    cmp byte [rsi], 's'
    jne .session_not_counted_step
    cmp byte [rsi+1], ' '
    je .session_short_count
    cmp byte [rsi+1], 't'
    jne .session_not_counted_step
    cmp byte [rsi+2], 'e'
    jne .session_not_counted_step
    cmp byte [rsi+3], 'p'
    jne .session_not_counted_step
    cmp byte [rsi+4], ' '
    jne .session_not_counted_step
    add rsi, 5
    jmp .session_parse_count
.session_short_count:
    add rsi, 2
.session_parse_count:
    ; 1..16 without signs, leading zeros, whitespace or extra arguments.
    ; Accept final newline or EOF after exactly one/two decimal digits.
    movzx edx, byte [rsi]
    cmp dl, '1'
    jb .session_step_usage
    cmp dl, '9'
    ja .session_step_usage
    sub edx, '0'
    mov ecx, edx
    inc rsi
    movzx edx, byte [rsi]
    cmp dl, 10
    je .session_count_valid
    test dl, dl
    jz .session_count_valid
    cmp dl, '0'
    jb .session_step_usage
    cmp dl, '9'
    ja .session_step_usage
    imul ecx, ecx, 10
    sub edx, '0'
    add ecx, edx
    inc rsi
    cmp byte [rsi], 10
    je .session_count_valid
    cmp byte [rsi], 0
    jne .session_step_usage
.session_count_valid:
    cmp ecx, SESSION_MAX_STEPS
    ja .session_step_usage
    mov dword [rbp+SESSION_REMAINING], ecx
    mov dword [rbp+SESSION_STEPPING], 1
    jmp .step_loop
.session_step_usage:
    lea rdi, [rel msg_step_usage]
    call puts
    jmp .session_prompt
.session_not_counted_step:
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
    lea rsi, [rel cmd_code]
    call strcmp
    test eax, eax
    jz .session_code
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_short_code]
    call strcmp
    test eax, eax
    jz .session_code
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_bytes]
    call strcmp
    test eax, eax
    jz .session_bytes_default
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_short_bytes]
    call strcmp
    test eax, eax
    jz .session_bytes_default
    ; Recognize exactly "bytes N" or "b N"; reject malformed numeric
    ; suffixes without calling ptrace or resuming the launched tracee.
    lea rsi, [rbp+SESSION_BUFFER]
    cmp byte [rsi], 'b'
    jne .session_not_bytes
    cmp byte [rsi+1], ' '
    je .session_short_bytes_count
    cmp byte [rsi+1], 'y'
    jne .session_not_bytes
    cmp byte [rsi+2], 't'
    jne .session_not_bytes
    cmp byte [rsi+3], 'e'
    jne .session_not_bytes
    cmp byte [rsi+4], 's'
    jne .session_not_bytes
    cmp byte [rsi+5], ' '
    jne .session_not_bytes
    add rsi, 6
    jmp .session_bytes_count
.session_short_bytes_count:
    add rsi, 2
.session_bytes_count:
    movzx eax, byte [rsi]
    cmp al, '1'
    jb .session_bytes_usage
    cmp al, '8'
    ja .session_bytes_usage
    sub eax, '0'
    mov dword [rbp+BYTE_LIMIT], eax
    inc rsi
    cmp byte [rsi], 10
    je .session_bytes
    cmp byte [rsi], 0
    je .session_bytes
    jmp .session_bytes_usage
.session_bytes_default:
    mov dword [rbp+BYTE_LIMIT], 8
    jmp .session_bytes
.session_bytes_usage:
    lea rdi, [rel msg_byte_usage]
    call puts
    jmp .session_prompt
.session_not_bytes:
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_stack]
    call strcmp
    test eax, eax
    jz .session_stack
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_short_stack]
    call strcmp
    test eax, eax
    jz .session_stack
    ; Only accept 'mem 0x...' or 'm 0x...'. The address parser below
    ; validates every hexadecimal digit and optional bounded word count.
    lea rsi, [rbp+SESSION_BUFFER]
    cmp byte [rsi], 'm'
    jne .session_not_memory
    cmp byte [rsi+1], 'e'
    jne .session_short_memory
    cmp byte [rsi+2], 'm'
    jne .session_not_memory
    cmp byte [rsi+3], ' '
    jne .session_memory_usage
    add rsi, 4
    jmp .session_memory_parse
.session_short_memory:
    cmp byte [rsi+1], ' '
    jne .session_not_memory
    add rsi, 2
    jmp .session_memory_parse
.session_not_memory:
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_history]
    call strcmp
    test eax, eax
    jz .session_history
    lea rdi, [rbp+SESSION_BUFFER]
    lea rsi, [rel cmd_short_history]
    call strcmp
    test eax, eax
    jz .session_history
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
.session_history:
    ; Show only debugger-observed RIP snapshots; the first is the
    ; initial exec stop, later samples are confirmed single steps.
    ; Chronological presentation begins at zero until the ring fills;
    ; once full, the next overwrite slot is the oldest saved sample.
    mov dword [rbp+HISTORY_PRINT_INDEX], 0
    mov dword [rbp+HISTORY_START], 0
    cmp dword [rbp+HISTORY_COUNT], HISTORY_CAPACITY
    jne .history_next
    mov eax, [rbp+HISTORY_NEXT]
    mov dword [rbp+HISTORY_START], eax
.history_next:
    mov eax, [rbp+HISTORY_PRINT_INDEX]
    cmp eax, [rbp+HISTORY_COUNT]
    jae .session_prompt
    add eax, [rbp+HISTORY_START]
    and eax, HISTORY_CAPACITY - 1
    mov rdx, [rbp+HISTORY_BUFFER+rax*8]
    lea rdi, [rel msg_history_entry]
    mov esi, [rbp+HISTORY_PRINT_INDEX]
    xor eax, eax
    call printf
    inc dword [rbp+HISTORY_PRINT_INDEX]
    jmp .history_next
.session_step:
    mov dword [rbp+SESSION_REMAINING], 1
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
.session_code:
    ; Pure read-only instruction inspection for the current stopped tracee.
    ; A PEEKTEXT return of -1 is valid when all eight bytes are 0xff.
    ; errno MUST be cleared before ptrace and inspected only when rax=-1.
    call .get_regs
    cmp rax, -1
    je .regs_failed
    call __errno_location
    mov dword [rax], 0
    mov edi, PTRACE_PEEKTEXT
    mov rsi, [rbp-16]
    mov rdx, [rbp+REG_RIP]
    xor ecx, ecx
    xor eax, eax
    call ptrace
    mov [rbp+CODE_WORD], rax
    cmp rax, -1
    jne .session_code_print
    call __errno_location
    cmp dword [rax], 0
    jne .session_code_failed
.session_code_print:
    lea rdi, [rel msg_code_word]
    mov rsi, [rbp+REG_RIP]
    mov rdx, [rbp+CODE_WORD]
    xor eax, eax
    call printf
    jmp .session_prompt
.session_code_failed:
    lea rdi, [rel err_code_read]
    call perror
    jmp .session_prompt
.session_bytes:
    ; A read-only view of 1..8 bytes at the stopped RIP, in execution
    ; address order (little-endian x86-64). This is NOT disassembly.
    ; One PEEKTEXT word is enough for the bounded eight-byte window.
    call .get_regs
    cmp rax, -1
    je .regs_failed
    call __errno_location
    mov dword [rax], 0
    mov edi, PTRACE_PEEKTEXT
    mov rsi, [rbp-16]
    mov rdx, [rbp+REG_RIP]
    xor ecx, ecx
    xor eax, eax
    call ptrace
    mov [rbp+CODE_WORD], rax
    cmp rax, -1
    jne .session_bytes_ready
    call __errno_location
    cmp dword [rax], 0
    jne .session_bytes_failed
.session_bytes_ready:
    mov dword [rbp+BYTE_INDEX], 0
.session_bytes_next:
    ; Rip + offset is a freshly observed tracee address; no target
    ; memory is modified, and no instruction is executed by this command.
    lea rdi, [rel msg_instruction_byte]
    mov esi, [rbp+BYTE_INDEX]
    mov rdx, [rbp+REG_RIP]
    add rdx, rsi
    mov rax, [rbp+CODE_WORD]
    mov ecx, [rbp+BYTE_INDEX]
    shl ecx, 3
    shr rax, cl
    and eax, 0xff
    mov ecx, eax
    xor eax, eax
    call printf
    inc dword [rbp+BYTE_INDEX]
    mov eax, [rbp+BYTE_INDEX]
    cmp eax, [rbp+BYTE_LIMIT]
    jl .session_bytes_next
    jmp .session_prompt
.session_bytes_failed:
    lea rdi, [rel err_byte_read]
    call perror
    jmp .session_prompt
.session_stack:
    ; Read only four machine words starting at the current RSP. Bounds
    ; are fixed here: no user-supplied memory addresses or write requests.
    call .get_regs
    cmp rax, -1
    je .regs_failed
    mov rax, [rbp+REG_RSP]
    mov [rbp+STACK_BASE], rax
    mov dword [rbp+STACK_INDEX], 0
.stack_next:
    call __errno_location
    mov dword [rax], 0
    mov edi, PTRACE_PEEKDATA
    mov rsi, [rbp-16]
    movsxd rax, dword [rbp+STACK_INDEX]
    mov rdx, [rbp+STACK_BASE]
    lea rdx, [rdx+rax*8]
    xor ecx, ecx
    xor eax, eax
    call ptrace
    mov [rbp+STACK_WORD], rax
    cmp rax, -1
    jne .stack_print
    call __errno_location
    cmp dword [rax], 0
    jne .stack_failed
.stack_print:
    lea rdi, [rel msg_stack_word]
    mov esi, [rbp+STACK_INDEX]
    movsxd rax, dword [rbp+STACK_INDEX]
    mov rdx, [rbp+STACK_BASE]
    lea rdx, [rdx+rax*8]
    mov rcx, [rbp+STACK_WORD]
    xor eax, eax
    call printf
    inc dword [rbp+STACK_INDEX]
    cmp dword [rbp+STACK_INDEX], STACK_WORD_LIMIT
    jl .stack_next
    jmp .session_prompt
.stack_failed:
    ; A non-readable RSP reports one error, without resuming the tracee.
    lea rdi, [rel err_stack_read]
    call perror
    jmp .session_prompt
.session_memory_parse:
    ; Strict 0x-prefixed hex, 1..16 digits. Do not use strtoull:
    ; signs, whitespace, trailing junk and silent overflow are rejected.
    cmp byte [rsi], '0'
    jne .session_memory_usage
    cmp byte [rsi+1], 'x'
    je .memory_prefix_ok
    cmp byte [rsi+1], 'X'
    jne .session_memory_usage
.memory_prefix_ok:
    add rsi, 2
    mov dword [rbp+MEMORY_LIMIT], 1 ; single-word behavior remains default
    xor rdx, rdx                ; 64-bit address accumulator
    xor ecx, ecx                ; number of valid hex digits
.memory_digit:
    movzx r8d, byte [rsi]
    test r8b, r8b
    jz .memory_end
    cmp r8b, 10
    je .memory_end
    cmp r8b, ' '
    je .memory_optional_count
    cmp r8b, '0'
    jb .session_memory_usage
    cmp r8b, '9'
    jbe .memory_numeric
    cmp r8b, 'A'
    jb .session_memory_usage
    cmp r8b, 'F'
    jbe .memory_uppercase
    cmp r8b, 'a'
    jb .session_memory_usage
    cmp r8b, 'f'
    ja .session_memory_usage
    sub r8d, 'a'-10
    jmp .memory_valid_digit
.memory_uppercase:
    sub r8d, 'A'-10
    jmp .memory_valid_digit
.memory_numeric:
    sub r8d, '0'
.memory_valid_digit:
    cmp ecx, 16
    jae .session_memory_usage  ; reject overflow and excess digits
    shl rdx, 4
    or rdx, r8
    inc ecx
    inc rsi
    jmp .memory_digit
.memory_optional_count:
    ; Exactly one separating space, then one decimal digit 1..4.
    ; No trailing spaces or extra arguments are permitted.
    test ecx, ecx
    jz .session_memory_usage
    inc rsi
    movzx eax, byte [rsi]
    cmp al, '1'
    jb .session_memory_usage
    cmp al, '4'
    ja .session_memory_usage
    sub eax, '0'
    mov [rbp+MEMORY_LIMIT], eax
    inc rsi
    cmp byte [rsi], 10
    je .memory_end
    cmp byte [rsi], 0
    jne .session_memory_usage
.memory_end:
    test ecx, ecx
    jz .session_memory_usage
    mov [rbp+MEMORY_ADDRESS], rdx
    ; Reject a crossing range BEFORE any ptrace reads are attempted.
    mov eax, [rbp+MEMORY_LIMIT]
    dec eax
    lea r8, [rax*8]
    add rdx, r8
    jc .memory_wrap
    mov dword [rbp+MEMORY_INDEX], 0
.memory_next:
    ; An overflowing address must never wrap to low tracee memory.
    mov eax, [rbp+MEMORY_INDEX]
    lea r8, [rax*8]
    mov rdx, [rbp+MEMORY_ADDRESS]
    add rdx, r8
    jc .memory_wrap
    mov [rbp+MEMORY_CURRENT], rdx
    call __errno_location
    mov dword [rax], 0
    mov edi, PTRACE_PEEKDATA
    mov rsi, [rbp-16]
    mov rdx, [rbp+MEMORY_CURRENT]
    xor ecx, ecx
    xor eax, eax
    call ptrace
    mov [rbp+MEMORY_WORD], rax
    cmp rax, -1
    jne .memory_print
    call __errno_location
    cmp dword [rax], 0
    jne .memory_read_failed
.memory_print:
    lea rdi, [rel msg_memory_word]
    mov rsi, [rbp+MEMORY_CURRENT]
    mov rdx, [rbp+MEMORY_WORD]
    xor eax, eax
    call printf
    inc dword [rbp+MEMORY_INDEX]
    mov eax, [rbp+MEMORY_INDEX]
    cmp eax, [rbp+MEMORY_LIMIT]
    jl .memory_next
    jmp .session_prompt
.memory_wrap:
    lea rdi, [rel err_memory_wrap]
    call puts
    jmp .session_prompt
.memory_read_failed:
    lea rdi, [rel err_memory_read]
    call perror
    jmp .session_prompt
.session_memory_usage:
    lea rdi, [rel msg_memory_usage]
    call puts
    jmp .session_prompt
.session_continue:
    ; If paused by a genuine signal-delivery stop, continue forwards
    ; the recorded pending signal rather than silently swallowing it.
    mov dword [rbp+SESSION_STEPPING], 0
    mov dword [rbp+SESSION_REMAINING], 0
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
    mov dword [rbp+SESSION_REMAINING], 0
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
    mov dword [rbp+SESSION_REMAINING], 0  ; cancel remainder at ptrace event
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

; One initial RIP and up to 15 newer step-completion RIPs are retained
; in a 16-slot circular buffer. The next index is masked instead of
; dividing; the ring's size must remain a power of two.
.record_rip:
    mov eax, [rbp+HISTORY_NEXT]
    mov rdx, [rbp+REG_RIP]
    mov [rbp+HISTORY_BUFFER+rax*8], rdx
    inc eax
    and eax, HISTORY_CAPACITY - 1
    mov [rbp+HISTORY_NEXT], eax
    cmp dword [rbp+HISTORY_COUNT], HISTORY_CAPACITY
    jae .record_rip_done
    inc dword [rbp+HISTORY_COUNT]
.record_rip_done:
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
