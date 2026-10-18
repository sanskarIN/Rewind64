; Rewind64 x86-64 Linux user_regs_struct presentation.
; Assembly-only register formatter; System V AMD64 ABI.
; The caller supplies a pointer to the 216-byte x86-64 register snapshot.
; Register offsets are Linux-specific, NOT Windows CONTEXT offsets.
default rel

global print_registers
extern printf

%define R15       0
%define R14       8
%define R13      16
%define R12      24
%define RBP_REG  32
%define RBX_REG  40
%define R11      48
%define R10      56
%define R9       64
%define R8_REG   72
%define RAX_REG  80
%define RCX_REG  88
%define RDX_REG  96
%define RSI_REG 104
%define RDI_REG 112
%define RFLAGS  144
%define FS_BASE 168
%define GS_BASE 176

section .rodata
    row1: db '    GPR: RAX=0x%016lx RBX=0x%016lx RCX=0x%016lx RDX=0x%016lx', 10, 0
    row2: db '         RSI=0x%016lx RDI=0x%016lx RBP=0x%016lx R8=0x%016lx', 10, 0
    row3: db '         R9=0x%016lx R10=0x%016lx R11=0x%016lx R12=0x%016lx', 10, 0
    row4: db '         R13=0x%016lx R14=0x%016lx R15=0x%016lx RFLAGS=0x%016lx', 10, 0
    row5: db '    Bases: FS_BASE=0x%016lx GS_BASE=0x%016lx', 10, 0

section .text
; void print_registers(const struct user_regs_struct *regs)
; Saves RBX, does not allocate, and maintains 16-byte alignment for printf.
print_registers:
    push rbp
    mov rbp, rsp
    push rbx
    sub rsp, 8
    mov rbx, rdi

    lea rdi, [rel row1]
    mov rsi, [rbx+RAX_REG]
    mov rdx, [rbx+RBX_REG]
    mov rcx, [rbx+RCX_REG]
    mov r8,  [rbx+RDX_REG]
    xor eax, eax
    call printf

    lea rdi, [rel row2]
    mov rsi, [rbx+RSI_REG]
    mov rdx, [rbx+RDI_REG]
    mov rcx, [rbx+RBP_REG]
    mov r8,  [rbx+R8_REG]
    xor eax, eax
    call printf

    lea rdi, [rel row3]
    mov rsi, [rbx+R9]
    mov rdx, [rbx+R10]
    mov rcx, [rbx+R11]
    mov r8,  [rbx+R12]
    xor eax, eax
    call printf

    lea rdi, [rel row4]
    mov rsi, [rbx+R13]
    mov rdx, [rbx+R14]
    mov rcx, [rbx+R15]
    mov r8,  [rbx+RFLAGS]
    xor eax, eax
    call printf

    lea rdi, [rel row5]
    mov rsi, [rbx+FS_BASE]
    mov rdx, [rbx+GS_BASE]
    xor eax, eax
    call printf

    add rsp, 8
    pop rbx
    leave
    ret
