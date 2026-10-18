; Rewind64 Linux x86-64 CLI. Production implementation: NASM Assembly.
default rel
global main
extern strcmp
extern puts
extern debug_run

%define MAX_STEPS 64

section .rodata
    flag_help:      db '--help', 0
    flag_version:   db '--version', 0
    flag_steps:     db '--steps', 0
    cmd_run:        db 'run', 0
    help_text:      db 'Rewind64 - Explore execution. Trace every instruction. Understand the past.', 10
                    db 'Usage:', 10
                    db '  rewind64 --help', 10
                    db '  rewind64 --version', 10
                    db '  rewind64 run [--steps N] PROGRAM [ARGS...]', 10
                    db '  N must be 1..64; default N=1.', 10
                    db 'Only Linux x86-64 run is implemented.', 0
    version_text:   db 'Rewind64 v0.1.1-dev (Linux x86-64)', 0
    usage_error:    db 'Error: expected rewind64 run [--steps N] PROGRAM [ARGS...].', 0
    steps_error:    db 'Error: steps must be in range 1..64 (decimal digits only).', 0
    unknown_error:  db 'Error: unsupported command. See rewind64 --help.', 0

section .text
main:
    push rbp
    mov rbp, rsp
    sub rsp, 16
    mov [rbp-8], rdi                  ; argc
    mov [rbp-16], rsi                 ; argv
    cmp rdi, 2
    jl .usage

    mov rax, [rbp-16]
    mov rdi, [rax+8]                  ; argv[1]
    lea rsi, [rel flag_help]
    call strcmp
    test eax, eax
    jz .help

    mov rax, [rbp-16]
    mov rdi, [rax+8]
    lea rsi, [rel flag_version]
    call strcmp
    test eax, eax
    jz .version

    mov rax, [rbp-16]
    mov rdi, [rax+8]
    lea rsi, [rel cmd_run]
    call strcmp
    test eax, eax
    jnz .unknown
    cmp qword [rbp-8], 3
    jl .usage

    mov rax, [rbp-16]
    mov rdi, [rax+16]                 ; argv[2]
    lea rsi, [rel flag_steps]
    call strcmp
    test eax, eax
    jz .parse_steps

    mov rdi, [rbp-16]
    add rdi, 16                       ; &argv[2] (target and arguments)
    mov esi, 1                        ; default one instruction
    call debug_run
    jmp .done

.parse_steps:
    cmp qword [rbp-8], 5             ; must include count AND executable
    jl .steps_invalid
    mov rax, [rbp-16]
    mov r10, [rax+24]                 ; argv[3] numeric string
    xor r8d, r8d
.parse_loop:
    movzx edx, byte [r10]
    test edx, edx
    jz .parsed
    cmp edx, '0'
    jb .steps_invalid
    cmp edx, '9'
    ja .steps_invalid
    sub edx, '0'
    imul r8d, r8d, 10
    add r8d, edx
    cmp r8d, MAX_STEPS               ; bound each iteration (no overflow)
    ja .steps_invalid
    inc r10
    jmp .parse_loop
.parsed:
    test r8d, r8d
    jz .steps_invalid
    mov rdi, [rbp-16]
    add rdi, 32                       ; &argv[4]
    mov esi, r8d
    call debug_run
    jmp .done

.help:
    lea rdi, [rel help_text]
    call puts
    xor eax, eax
    jmp .done
.version:
    lea rdi, [rel version_text]
    call puts
    xor eax, eax
    jmp .done
.usage:
    lea rdi, [rel usage_error]
    call puts
    mov eax, 2
    jmp .done
.steps_invalid:
    lea rdi, [rel steps_error]
    call puts
    mov eax, 2
    jmp .done
.unknown:
    lea rdi, [rel unknown_error]
    call puts
    mov eax, 2
.done:
    leave
    ret
