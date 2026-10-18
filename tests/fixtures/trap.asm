; Regression fixture: an application-generated SIGTRAP must be forwarded.
global _start
section .text
_start:
    mov eax, 60
    int3
    xor edi, edi
    syscall
