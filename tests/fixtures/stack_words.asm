; Linux x86-64 native debugger regression: deterministic stack words.
; One step changes RSP to an initialized writable 32-byte region.
global _start
section .data
align 16
words:
    dq 0x1122334455667788
    dq 0xffffffffffffffff
    dq 0
    dq 0x8899aabbccddeeff
section .text
_start:
    lea rsp, [rel words]
    mov eax, 60
    xor edi, edi
    syscall
