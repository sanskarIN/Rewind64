; Deterministic register-pattern fixture for x86-64 register inspector.
; Run with --steps 4 and verify the four constants appear after each MOV.
global _start
section .text
_start:
    mov rax, 0x1122334455667788
    mov rbx, 0x8877665544332211
    mov r12, 0x1234567890abcdef
    mov r13, 0xfedcba0987654321
    xor edi, edi
    mov eax, 60
    syscall
