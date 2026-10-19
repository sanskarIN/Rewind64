; Self-directed tgkill emits SIGUSR1 with siginfo.si_code = SI_TKILL (-6).
; Only local process signal for integration regression.
global _start
section .text
_start:
    mov eax, 39             ; __NR_getpid
    syscall
    mov r12d, eax
    mov eax, 186            ; __NR_gettid
    syscall
    mov esi, eax            ; tid
    mov edi, r12d           ; tgid
    mov edx, 10             ; SIGUSR1
    mov eax, 234            ; __NR_tgkill
    syscall
    mov edi, 71             ; not expected (default SIGUSR1 terminates)
    mov eax, 60
    syscall
