; PTRACE_PEEKTEXT returns a signed machine word. Eight 0xff bytes result
; in rax=-1, which MUST be treated as valid if errno remains zero.
; This authorized test target is never resumed by the regression: the
; debugger inspects its initial entry point and quits while it is stopped.
global _start
section .text
_start:
    times 8 db 0xff
    mov edi, 97
    mov eax, 60
    syscall
