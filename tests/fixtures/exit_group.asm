; Native Linux x86-64 exit_group(23) to test TRACEEXIT event payload.
global _start
section .text
_start:
    mov edi, 23
    mov eax, 231            ; __NR_exit_group
    syscall
