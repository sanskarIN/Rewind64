; Authorized test executable for expected status 42.
global _start
section .text
_start:
    mov edi, 42
    mov eax, 60
    syscall
