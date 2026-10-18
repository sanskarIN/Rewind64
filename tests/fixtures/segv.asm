; Trigger a normal Linux user-mode SIGSEGV, no special privileges.
global _start
section .text
_start:
    xor eax, eax
    mov [rax], rax         ; NULL is unmapped on normal Linux systems
    mov edi, 88            ; if reached, SIGSEGV was incorrectly ignored
    mov eax, 60
    syscall
