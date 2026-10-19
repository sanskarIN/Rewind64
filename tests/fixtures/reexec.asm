; Re-exec a second authorized Assembly program using Linux execve.
; This changes the tracee image and exercises PTRACE_EVENT_EXEC.
; Usage: rewind64 run [--steps N] ./build/reexec ./build/exit42
global _start
section .text
_start:
    cmp qword [rsp], 2
    jne .bad
    mov rdi, [rsp+16]           ; path in argv[1]
    test rdi, rdi
    jz .bad
    lea rsi, [rsp+16]           ; argv for new executable
    xor edx, edx                ; empty environment
    mov eax, 59                 ; __NR_execve
    syscall
.bad:
    mov edi, 76                 ; execve unexpectedly returned
    mov eax, 60                 ; __NR_exit
    syscall
