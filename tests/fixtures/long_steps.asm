; 70 no-ops are enough to test the 64-step upper bound.
global _start
section .text
_start:
    times 70 nop
    xor edi, edi
    mov eax, 60
    syscall
