; Linux x86-64 test target with an actual user-space signal handler.
; Installs SIGUSR1 handler through rt_sigaction and verifies the handler ran.
; No C/Python runtime; direct Linux syscalls and ABI-specific SA_RESTORER.
default rel
global _start

%define SYS_RT_SIGACTION 13
%define SYS_RT_SIGRETURN 15
%define SYS_GETPID 39
%define SYS_KILL 62
%define SYS_EXIT 60
%define SIGUSR1 10
%define SA_RESTORER 0x04000000

section .data
    align 8
action:
    dq handle_usr1                ; handler
    dq SA_RESTORER                ; flags
    dq signal_restorer            ; restorer
    dq 0                          ; kernel rt_sigset_t (8 bytes)
handler_called:
    db 0

section .text
_start:
    mov eax, SYS_RT_SIGACTION
    mov edi, SIGUSR1
    lea rsi, [rel action]
    xor edx, edx
    mov r10d, 8                   ; kernel sigset_t size on x86-64
    syscall
    test rax, rax
    js .error

    mov eax, SYS_GETPID
    syscall
    mov edi, eax
    mov esi, SIGUSR1
    mov eax, SYS_KILL
    syscall
    test rax, rax
    js .error

    ; Repeat a handled signal to exercise multiple ptrace delivery stops.
    mov eax, SYS_GETPID
    syscall
    mov edi, eax
    mov esi, SIGUSR1
    mov eax, SYS_KILL
    syscall
    test rax, rax
    js .error

    cmp byte [rel handler_called], 2
    jne .error
    xor edi, edi
    jmp .exit

.error:
    mov edi, 73
.exit:
    mov eax, SYS_EXIT
    syscall

handle_usr1:
    inc byte [rel handler_called]
    ret

signal_restorer:
    mov eax, SYS_RT_SIGRETURN
    syscall
