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

build/rewind64: build/main.o build/debugger.o
	$(CC) $(CFLAGS) -o $@ $^

build/exit0.o: tests/fixtures/exit0.asm | build
	$(NASM) $(NASMFLAGS) -o $@ $<

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

fixtures: build/exit0 build/exit7 build/trap

test: all fixtures
	python3 -m unittest discover -s tests/integration -v

clean:
	rm -rf build
