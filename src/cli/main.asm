; Rewind64 Linux x86-64 CLI. Executable implementation is NASM Assembly.
; Flags may appear in either order BEFORE the target, and '--' ends parsing.
default rel
global main
extern strcmp
extern puts
extern debug_run

%define MAX_STEPS 64
%define ARG_INDEX    -24
%define STEP_LIMIT   -32
%define CHANGES_ONLY -36
%define SEEN_STEPS   -40
%define SEEN_CHANGES -44
%define SEEN_OBSERVE -48
%define SEEN_SESSION -52

section .rodata
    flag_help:      db '--help', 0
    flag_version:   db '--version', 0
    flag_steps:     db '--steps', 0
    flag_changes:   db '--changes-only', 0
    flag_observe:   db '--observe-only', 0
    flag_session:   db '--interactive', 0
    flag_terminator: db '--', 0
    cmd_run:        db 'run', 0
    help_text:      db 'Rewind64 - Explore execution. Trace every instruction. Understand the past.', 10
                    db 'Usage:', 10
                    db '  rewind64 --help', 10
                    db '  rewind64 --version', 10
                    db '  rewind64 run [--steps N | --observe-only | --interactive] [--changes-only] [--] PROGRAM [ARGS...]', 10
                    db '  N must be 1..64; default N=1.', 10
                    db '  --observe-only captures initial state and follows events without stepping.', 10
                    db '  --steps, --observe-only and --interactive are mutually exclusive.', 10
                    db '  --interactive supports step [1..16], regs, status, code, bytes [1..8], stack, mem 0xHEX [1..4], continue, help, quit.', 10
                    db '  --changes-only hides repeated full register tables, not CPU deltas.', 10
                    db '  -- ends option parsing (use for programs beginning with --).', 10
                    db 'Only Linux x86-64 run is implemented.', 0
    version_text:   db 'Rewind64 v0.2.7-pre (Linux x86-64)', 0
    usage_error:    db 'Error: expected rewind64 run [--steps N | --observe-only | --interactive] [--changes-only] [--] PROGRAM [ARGS...].', 0
    steps_error:    db 'Error: steps must be in range 1..64 (decimal digits only).', 0
    options_error:  db 'Error: duplicate option; each run flag may be specified once.', 0
    conflict_error: db 'Error: --steps, --observe-only and --interactive are mutually exclusive.', 0
    unknown_error:  db 'Error: unsupported command. See rewind64 --help.', 0

section .text
main:
    push rbp
    mov rbp, rsp
    sub rsp, 64
    mov [rbp-8], rdi                  ; argc
    mov [rbp-16], rsi                 ; argv
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

    mov qword [rbp+ARG_INDEX], 2
    mov dword [rbp+STEP_LIMIT], 1
    mov dword [rbp+CHANGES_ONLY], 0
    mov dword [rbp+SEEN_STEPS], 0
    mov dword [rbp+SEEN_CHANGES], 0
    mov dword [rbp+SEEN_OBSERVE], 0
    mov dword [rbp+SEEN_SESSION], 0
.option_loop:
    mov rcx, [rbp+ARG_INDEX]
    cmp rcx, [rbp-8]
    jae .usage
    mov rax, [rbp-16]
    mov rdi, [rax+rcx*8]
    lea rsi, [rel flag_terminator]
    call strcmp
    test eax, eax
    jz .terminator

    mov rcx, [rbp+ARG_INDEX]
    mov rax, [rbp-16]
    mov rdi, [rax+rcx*8]
    lea rsi, [rel flag_steps]
    call strcmp
    test eax, eax
    jz .parse_steps

    mov rcx, [rbp+ARG_INDEX]
    mov rax, [rbp-16]
    mov rdi, [rax+rcx*8]
    lea rsi, [rel flag_changes]
    call strcmp
    test eax, eax
    jz .set_changes

    mov rcx, [rbp+ARG_INDEX]
    mov rax, [rbp-16]
    mov rdi, [rax+rcx*8]
    lea rsi, [rel flag_observe]
    call strcmp
    test eax, eax
    jz .set_observe

    mov rcx, [rbp+ARG_INDEX]
    mov rax, [rbp-16]
    mov rdi, [rax+rcx*8]
    lea rsi, [rel flag_session]
    call strcmp
    test eax, eax
    jz .set_session

    jmp .run_target                  ; ordinary target path, no shell

.terminator:
    inc qword [rbp+ARG_INDEX]
    mov rcx, [rbp+ARG_INDEX]
    cmp rcx, [rbp-8]
    jae .usage
    jmp .run_target

.set_session:
    cmp dword [rbp+SEEN_SESSION], 0
    jne .duplicate
    cmp dword [rbp+SEEN_STEPS], 0
    jne .conflict
    cmp dword [rbp+SEEN_OBSERVE], 0
    jne .conflict
    mov dword [rbp+SEEN_SESSION], 1
    mov dword [rbp+STEP_LIMIT], 0
    inc qword [rbp+ARG_INDEX]
    jmp .option_loop

.set_observe:
    cmp dword [rbp+SEEN_OBSERVE], 0
    jne .duplicate
    cmp dword [rbp+SEEN_STEPS], 0
    jne .conflict
    cmp dword [rbp+SEEN_SESSION], 0
    jne .conflict
    mov dword [rbp+SEEN_OBSERVE], 1
    mov dword [rbp+STEP_LIMIT], 0
    inc qword [rbp+ARG_INDEX]
    jmp .option_loop

.set_changes:
    cmp dword [rbp+SEEN_CHANGES], 0
    jne .duplicate
    mov dword [rbp+SEEN_CHANGES], 1
    mov dword [rbp+CHANGES_ONLY], 1
    inc qword [rbp+ARG_INDEX]
    jmp .option_loop

.parse_steps:
    cmp dword [rbp+SEEN_OBSERVE], 0
    jne .conflict
    cmp dword [rbp+SEEN_SESSION], 0
    jne .conflict
    cmp dword [rbp+SEEN_STEPS], 0
    jne .duplicate
    mov dword [rbp+SEEN_STEPS], 1
    mov rcx, [rbp+ARG_INDEX]
    inc rcx
    cmp rcx, [rbp-8]
    jae .steps_invalid
    mov rax, [rbp-16]
    mov r10, [rax+rcx*8]             ; decimal argument
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
    cmp r8d, MAX_STEPS               ; reject before integer overflow
    ja .steps_invalid
    inc r10
    jmp .parse_loop
.parsed:
    test r8d, r8d
    jz .steps_invalid
    mov [rbp+STEP_LIMIT], r8d
    add qword [rbp+ARG_INDEX], 2
    jmp .option_loop

.run_target:
    mov rdi, [rbp-16]
    mov rcx, [rbp+ARG_INDEX]
    lea rdi, [rdi+rcx*8]            ; null-terminated &argv[target]
    mov esi, [rbp+STEP_LIMIT]
    mov edx, [rbp+CHANGES_ONLY]
    mov ecx, [rbp+SEEN_SESSION]
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
.duplicate:
    lea rdi, [rel options_error]
    call puts
    mov eax, 2
    jmp .done
.conflict:
    lea rdi, [rel conflict_error]
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
