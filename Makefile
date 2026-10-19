NASM ?= nasm
CC ?= cc
LD ?= ld
NASMFLAGS ?= -f elf64 -Wall -Werror
CFLAGS ?= -no-pie -Wl,-z,noexecstack

.PHONY: all clean test fixtures
all: build/rewind64

build:
	mkdir -p build

build/main.o: src/cli/main.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/debugger.o: platforms/linux/debugger.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/registers.o: src/registers/x86_64.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/delta.o: src/registers/delta.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/rewind64: build/main.o build/debugger.o build/registers.o build/delta.o
	$(CC) $(CFLAGS) -o $@ $^

build/exit0.o: tests/fixtures/exit0.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/register_fixture.o: tests/fixtures/registers.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/register_fixture: build/register_fixture.o
	$(LD) -o $@ $<

build/argv.o: tests/fixtures/argv.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/argv: build/argv.o
	$(LD) -o $@ $<

build/signal_usr1.o: tests/fixtures/signal_usr1.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/signal_usr1: build/signal_usr1.o
	$(LD) -o $@ $<

build/exit7.o: tests/fixtures/exit7.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/exit0: build/exit0.o
	$(LD) -o $@ $<

build/exit7: build/exit7.o
	$(LD) -o $@ $<

build/trap.o: tests/fixtures/trap.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/trap: build/trap.o
	$(LD) -o $@ $<

build/exit255.o: tests/fixtures/exit255.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/exit255: build/exit255.o
	$(LD) -o $@ $<

build/signal_term.o: tests/fixtures/signal_term.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/signal_term: build/signal_term.o
	$(LD) -o $@ $<

build/segv.o: tests/fixtures/segv.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/segv: build/segv.o
	$(LD) -o $@ $<

build/long_steps.o: tests/fixtures/long_steps.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/long_steps: build/long_steps.o
	$(LD) -o $@ $<

build/illegal.o: tests/fixtures/illegal.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/illegal: build/illegal.o
	$(LD) -o $@ $<

build/divzero.o: tests/fixtures/divzero.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/divzero: build/divzero.o
	$(LD) -o $@ $<

build/exit42.o: tests/fixtures/exit42.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/exit42: build/exit42.o
	$(LD) -o $@ $<

build/handled_signal.o: tests/fixtures/handled_signal.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/handled_signal: build/handled_signal.o
	$(LD) -o $@ $<

build/reexec.o: tests/fixtures/reexec.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/reexec: build/reexec.o
	$(LD) -o $@ $<

build/group_stop.o: tests/fixtures/group_stop.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/group_stop: build/group_stop.o
	$(LD) -o $@ $<

build/thread_signal.o: tests/fixtures/thread_signal.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/thread_signal: build/thread_signal.o
	$(LD) -o $@ $<

build/exit_group.o: tests/fixtures/exit_group.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/exit_group: build/exit_group.o
	$(LD) -o $@ $<

build/all_ones.o: tests/fixtures/all_ones.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/all_ones: build/all_ones.o
	$(LD) -o $@ $<

build/stack_words.o: tests/fixtures/stack_words.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/stack_words: build/stack_words.o
	$(LD) -o $@ $<

build/invalid_rsp.o: tests/fixtures/invalid_rsp.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

build/invalid_rsp: build/invalid_rsp.o
	$(LD) -o $@ $<

fixtures: build/exit0 build/exit7 build/trap build/argv build/signal_usr1 build/register_fixture build/exit255 build/signal_term build/segv build/long_steps build/illegal build/divzero build/exit42 build/handled_signal build/reexec build/group_stop build/thread_signal build/exit_group build/all_ones build/stack_words build/invalid_rsp

test: all fixtures
	bash tests/integration/test_cli.sh

clean:
	rm -rf build
