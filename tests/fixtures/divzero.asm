; Authorized fixture: CPU integer division by zero should raise SIGFPE.
global _start
section .text
_start:
    xor edx, edx
    mov eax, 1
    xor ebx, ebx
    div rbx
    mov edi, 77
    mov eax, 60
    syscall
