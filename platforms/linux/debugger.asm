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

%define PTRACE_TRACEME     0
%define PTRACE_CONT        7
%define PTRACE_SINGLESTEP  9
%define PTRACE_GETREGS     12
%define PTRACE_SETOPTIONS  0x4200
%define PTRACE_GETSIGINFO  0x4202
%define PTRACE_O_EXITKILL  0x00100000
%define SIGKILL            9
%define SIGTRAP            5
%define TRAP_TRACE         2              ; siginfo_t.si_code for single-step
%define STATUS             (-24)
%define SIGINFO            (-400)         ; 128-byte siginfo_t, non-overlapping
%define REGS               (-256)
%define REG_RIP            (REGS + 128)
%define REG_RSP            (REGS + 152)

section .rodata
    msg_initial:   db 'Initial stop: pid=%ld RIP=0x%016lx RSP=0x%016lx', 10, 0
    msg_step:      db 'After step:   pid=%ld RIP=0x%016lx RSP=0x%016lx', 10, 0
    msg_exit:      db 'Target exited with status %d', 10, 0
    msg_signal:    db 'Target terminated by signal %d', 10, 0
    err_fork:      db 'fork', 0
    err_trace:     db 'ptrace(TRACEME)', 0
    err_exec:      db 'execvp', 0
    err_wait:      db 'waitpid', 0
    err_options:   db 'ptrace(SETOPTIONS)', 0
    err_regs:      db 'ptrace(GETREGS)', 0
    err_siginfo:   db 'ptrace(GETSIGINFO)', 0
    err_step:      db 'ptrace(SINGLESTEP)', 0
    err_cont:      db 'ptrace(CONT)', 0
    err_stop:      db 'Error: child did not enter expected ptrace stop.', 0

section .text
; debug_run(argv, step_limit) => target exit status, 1 on tracing error.
; step_limit is CLI-validated in the inclusive range 1..64.
; Stack frame holds pid, status, and complete 216-byte x86_64 register block.
debug_run:
    push rbp
    mov rbp, rsp
    sub rsp, 416
    mov [rbp-8], rdi              ; argv vector from CLI
    mov dword [rbp-264], esi      ; requested maximum steps
    mov dword [rbp-272], 0        ; completed steps
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

    ; EXITKILL prevents an orphaned traced child if the debugger crashes.
    mov edi, PTRACE_SETOPTIONS
    mov rsi, [rbp-16]
    xor edx, edx
    mov ecx, PTRACE_O_EXITKILL
    xor eax, eax
    call ptrace
    cmp rax, -1
    je .options_failed

    call .get_regs
    test eax, eax
    js .regs_failed
    lea rdi, [rel msg_initial]
    call .print_regs


.step_loop:
    mov edi, PTRACE_SINGLESTEP
    mov rsi, [rbp-16]
    xor edx, edx
    xor ecx, ecx
    xor eax, eax
    call ptrace
    cmp rax, -1
    je .step_failed

    call .wait_child
    test eax, eax
    js .wait_failed
    mov eax, [rbp+STATUS]
    and eax, 0xff
    cmp eax, 0x7f
    jne .not_stopped
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
    jne .interrupted_step

    call .get_regs
    test eax, eax
    js .regs_failed
    lea rdi, [rel msg_step]
    call .print_regs
    inc dword [rbp-272]
    mov eax, [rbp-272]
    cmp eax, [rbp-264]
    jl .step_loop

    mov dword [rbp-36], 0                ; synthetic single-step SIGTRAP must not be delivered
    jmp .resume
.interrupted_step:
    ; Preserve a non-step signal stop rather than losing it or treating it
    ; as a debugger error. Resume the tracee with that signal delivered.
    mov eax, [rbp+STATUS]
    shr eax, 8
    and eax, 0xff
    mov [rbp-36], eax
.resume:
    mov edi, PTRACE_CONT
    mov rsi, [rbp-16]
    xor edx, edx
    mov ecx, [rbp-36]                 ; reinject unrelated signals
    xor eax, eax
    call ptrace
    cmp rax, -1
    je .cont_failed

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
    shr eax, 8
    and eax, 0xff
    mov [rbp-36], eax
    ; After the single-step trap, later signals belong to the target.
    ; In particular, do not swallow application-generated SIGTRAP.
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
.print_regs:
    sub rsp, 8
    mov rsi, [rbp-16]
    mov rdx, [rbp+REG_RIP]
    mov rcx, [rbp+REG_RSP]
    xor eax, eax
    call printf
    lea rdi, [rbp+REGS]        ; complete Linux x86-64 register snapshot
    call print_registers
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
.cleanup_errno:
    call perror
.cleanup:
    mov edi, [rbp-16]
    mov esi, SIGKILL
    call kill
    call .wait_child             ; reap tracee after forced termination
    mov eax, 1
.done:
    leave
    ret
