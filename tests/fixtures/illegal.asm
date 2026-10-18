; Authorized fixture: deliberately invalid x86-64 opcode should raise SIGILL.
global _start
section .text
_start:
    ud2
    mov edi, 77
    mov eax, 60
    syscall
