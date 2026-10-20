; Linux x86-64 deterministic regression fixture: 10 handled SIGUSR1 events.
; Exercises an eight-slot debugger signal-history ring across wrap-around.
; This is a self-signaling test process, no external services or runtime.
default rel
global _start

%define SYS_RT_SIGACTION 13
%define SYS_RT_SIGRETURN 15
%define SYS_GETPID 39
%define SYS_KILL 62
%define SYS_EXIT 60
%define SIGUSR1 10
%define SA_RESTORER 0x04000000
%define BURST_COUNT 10

section .data
    align 8
action:
    dq handle_usr1
    dq SA_RESTORER
    dq signal_restorer
    dq 0
handled_count:
    dd 0

section .text
_start:
    ; Kernel x86-64 rt_sigaction expects a kernel-sized eight-byte set.
    mov eax, SYS_RT_SIGACTION
    mov edi, SIGUSR1
    lea rsi, [rel action]
    xor edx, edx
    mov r10d, 8
    syscall
    test rax, rax
    js .error

    mov r12d, BURST_COUNT        ; survives signal handler and system calls
.send_one:
    mov eax, SYS_GETPID
    syscall
    test rax, rax
    js .error
    mov edi, eax
    mov esi, SIGUSR1
    mov eax, SYS_KILL
    syscall
    test rax, rax
    js .error
    dec r12d
    jnz .send_one

    cmp dword [rel handled_count], BURST_COUNT
    jne .error
    xor edi, edi
    jmp .exit

.error:
    mov edi, 73
.exit:
    mov eax, SYS_EXIT
    syscall

handle_usr1:
    inc dword [rel handled_count]
    ret

signal_restorer:
    mov eax, SYS_RT_SIGRETURN
    syscall
