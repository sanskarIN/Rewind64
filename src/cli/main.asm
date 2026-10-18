; Rewind64 CLI entry point (Linux System V AMD64 ABI).
default rel

global main
extern strcmp
extern puts
extern debug_run

section .rodata
    flag_help:       db '--help', 0
    flag_version:    db '--version', 0
    cmd_run:         db 'run', 0
    help_text:       db 'Rewind64 - Explore execution. Trace every instruction. Understand the past.', 10
                     db 'Usage:', 10
                     db '  rewind64 --help', 10
                     db '  rewind64 --version', 10
                     db '  rewind64 run PROGRAM [ARGS...]', 10
                     db 'Only Linux x86-64 run is implemented. Other commands are unavailable.', 0
    version_text:    db 'Rewind64 v0.1.0-dev (Linux x86-64)', 0
    usage_error:     db 'Error: expected rewind64 run PROGRAM [ARGS...].', 0
    unknown_error:   db 'Error: unsupported command. See rewind64 --help.', 0

section .text
main:
    push rbp
    mov rbp, rsp
    sub rsp, 16                    ; preserve 16-byte call alignment
    mov [rbp-8], rdi              ; argc
    mov [rbp-16], rsi             ; argv
    cmp rdi, 2
    jl .usage

    mov rax, [rbp-16]
    mov rdi, [rax+8]
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
    mov rdi, [rbp-16]
    add rdi, 16                    ; &argv[2], null-terminated by C runtime
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
.unknown:
    lea rdi, [rel unknown_error]
    call puts
    mov eax, 2
.done:
    leave
    ret
