; Forward-only comparison of two Linux x86-64 user_regs_struct snapshots.
; This DOES NOT record history or implement reverse execution.
; All executable comparison logic and field descriptors are NASM Assembly.
default rel
global print_register_changes
extern printf

section .rodata
    delta_line: db '    Changed %s: 0x%016lx -> 0x%016lx', 10, 0
    delta_summary: db 'Register changes: %u', 10, 0
    name_rax: db 'RAX', 0
    name_rbx: db 'RBX', 0
    name_rcx: db 'RCX', 0
    name_rdx: db 'RDX', 0
    name_rsi: db 'RSI', 0
    name_rdi: db 'RDI', 0
    name_rbp: db 'RBP', 0
    name_rsp: db 'RSP', 0
    name_r8: db 'R8', 0
    name_r9: db 'R9', 0
    name_r10: db 'R10', 0
    name_r11: db 'R11', 0
    name_r12: db 'R12', 0
    name_r13: db 'R13', 0
    name_r14: db 'R14', 0
    name_r15: db 'R15', 0
    name_rip: db 'RIP', 0
    name_rflags: db 'RFLAGS', 0
    name_fs: db 'FS_BASE', 0
    name_gs: db 'GS_BASE', 0

    align 8
    ; Linux x86-64 kernel user_regs_struct: (offset, NUL label pointer).
    ; The descriptor list deliberately excludes segment selectors and
    ; orig_rax, which are not general-purpose registers.
fields:
    dq 80, name_rax
    dq 40, name_rbx
    dq 88, name_rcx
    dq 96, name_rdx
    dq 104, name_rsi
    dq 112, name_rdi
    dq 32, name_rbp
    dq 152, name_rsp
    dq 72, name_r8
    dq 64, name_r9
    dq 56, name_r10
    dq 48, name_r11
    dq 24, name_r12
    dq 16, name_r13
    dq 8, name_r14
    dq 0, name_r15
    dq 128, name_rip
    dq 144, name_rflags
    dq 168, name_fs
    dq 176, name_gs
fields_end:
%define FIELD_COUNT ((fields_end - fields) / 16)

section .text
; void print_register_changes(const void *before, const void *after)
; Only compares 20 displayed 64-bit fields. Both pointers must reference
; valid 216-byte Linux x86-64 register buffers.
print_register_changes:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8                   ; 16-byte stack alignment for libc calls
    mov r12, rdi
    mov r13, rsi
    lea r14, [rel fields]
    mov ebx, FIELD_COUNT
    xor r15d, r15d

.scan:
    mov rax, [r14]              ; byte offset into kernel register structure
    mov rdx, [r12+rax]          ; before
    mov rcx, [r13+rax]          ; after
    cmp rdx, rcx
    je .next
    inc r15d
    lea rdi, [rel delta_line]
    mov rsi, [r14+8]            ; field name
    xor eax, eax               ; SysV variadic printf: no vector arguments
    call printf
.next:
    add r14, 16
    dec ebx
    jnz .scan

    lea rdi, [rel delta_summary]
    mov esi, r15d
    xor eax, eax
    call printf
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    leave
    ret
