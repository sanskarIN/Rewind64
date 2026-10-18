; Send SIGTERM to the authorized fixture itself.
global _start
section .text
_start:
    mov eax, 39            ; getpid
    syscall
    mov edi, eax
    mov esi, 15            ; SIGTERM
    mov eax, 62            ; kill
    syscall
    mov edi, 77            ; unreachable if signal forwarding works
    mov eax, 60
    syscall
