; Check that the tracee receives a normal argv vector and the argument "hello".
global _start
section .text
_start:
    cmp qword [rsp], 2                 ; argc
    jne .bad
    mov rax, [rsp+16]                 ; argv[1]
    test rax, rax
    jz .bad
    cmp byte [rax], 'h'
    jne .bad
    cmp byte [rax+1], 'e'
    jne .bad
    cmp byte [rax+2], 'l'
    jne .bad
    cmp byte [rax+3], 'l'
    jne .bad
    cmp byte [rax+4], 'o'
    jne .bad
    cmp byte [rax+5], 0
    jne .bad
    xor edi, edi
    jmp .exit
.bad:
    mov edi, 42
.exit:
    mov eax, 60
    syscall
