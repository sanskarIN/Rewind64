; Trigger an ordinary Linux job-control SIGSTOP in a traced process.
; Rewind64 v0.1.7 must refuse unsupported group-stop, terminate and reap.
; This is an isolated regression fixture, not a debugging utility.
global _start
section .text
_start:
    mov eax, 39                 ; __NR_getpid
    syscall
    mov edi, eax                ; own PID
    mov esi, 19                 ; SIGSTOP
    mov eax, 62                 ; __NR_kill
    syscall
    mov edi, 93                 ; unexpected fallthrough (must not happen)
    mov eax, 60
    syscall
