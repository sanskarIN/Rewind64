; Send SIGUSR1 to this authorized test program; debugger must forward it.
global _start
section .text
_start:
    mov eax, 39            ; getpid
    syscall
    mov edi, eax
    mov esi, 10            ; SIGUSR1
    mov eax, 62            ; kill
    syscall
    mov edi, 77            ; unexpected if SIGUSR1 is delivered correctly
    mov eax, 60
    syscall
