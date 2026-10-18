; Ensure the tracer preserves the full unsigned 8-bit exit status.
global _start
section .text
_start:
    mov edi, 255
    mov eax, 60
    syscall
