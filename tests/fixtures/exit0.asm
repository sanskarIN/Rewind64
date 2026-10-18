; Test fixture: a single-process x86_64 Linux program that exits normally.
global _start
section .text
_start:
    xor edi, edi
    mov eax, 60
    syscall
