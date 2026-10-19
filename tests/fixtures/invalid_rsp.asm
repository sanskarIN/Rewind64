; Linux x86-64 native fixture: after one step RSP becomes unmapped zero.
; Never resume this program in the tests; inspect the unreadable stack
; and request debugger quit/cleanup while the tracee is stopped.
global _start
section .text
_start:
    xor esp, esp
    mov eax, 60
    xor edi, edi
    syscall
