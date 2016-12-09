CC=gcc
CFLAGS=-g -m32 -O -ffreestanding -fno-builtin -nostdlib \
	-march=i386 -c
LD=ld
LDFLAGS=-g -melf_i386 -N -static
ASM=nasm
ASMFLAGS=-f elf
AS=as
ASFLAGS=-g --32
OBJECTS= \
	util16.o \
	init16.o \
	init32.o \
	init32c.o \
	acpi.o \
	command.o \
	cpuid.o \
	fat12.o \
	floppy.o \
	keyboard.o \
	memory.o \
	screen.o \
	shell.o \
	timer.o \
	uio.o \
	util.o \


all: stage2.bin

stage2.bin: stage2.ld $(OBJECTS)
	$(LD) $(LDFLAGS) -g -T stage2.ld -o stage2.bin $(OBJECTS)
#	objcopy --only-keep-debug stage2.elf stage2.db
#	objcopy --add-gnu-debuglink stage2.db stage2.elf
#	objcopy -O binary stage2.elf stage2.bin

init16.o: init16.S
	$(AS) $(ASFLAGS) -o $@ $<

util16.o: util16.S
	$(AS) $(ASFLAGS) -o $@ $<

#init32.o: init32.S
#	$(AS) $(ASFLAGS) -o $@ $<

init32.o: init32.asm
	$(ASM) $(ASMFLAGS) -o $@ $<

init32c.o: init32c.c screen.h shell.h timer.h
	$(CC) $(CFLAGS) -o $@ $<

acpi.o: acpi.c acpi.h screen.h util.h
	$(CC) $(CFLAGS) -o acpi.o acpi.c

command.o: command.c acpi.h command.h cpuid.h driver.h floppy.h memory.h screen.h timer.h uio.h util.h
	$(CC) $(CFLAGS) -o command.o command.c

cpuid.o: cpuid.c cpuid.h screen.h
	$(CC) $(CFLAGS) -o cpuid.o cpuid.c

fat12.o: fat12.c driver.h fat12.h
	$(CC) $(CFLAGS) -o fat12.o fat12.c

floppy.o: floppy.c driver.h floppy.h timer.h x86asm.h
	$(CC) $(CFLAGS) -o floppy.o floppy.c

keyboard.o: keyboard.c keyboard.h x86asm.h
	$(CC) $(CFLAGS) -o keyboard.o keyboard.c

memory.o: memory.c memory.h screen.h
	$(CC) $(CFLAGS) -o memory.o memory.c

screen.o: screen.c screen.h x86asm.h
	$(CC) $(CFLAGS) -o screen.o screen.c

shell.o: shell.c command.h screen.h shell.h uio.h
	$(CC) $(CFLAGS) -o shell.o shell.c

timer.o: timer.c timer.h x86asm.h
	$(CC) $(CFLAGS) -o timer.o timer.c

uio.o: uio.c keyboard.h screen.h uio.h
	$(CC) $(CFLAGS) -o uio.o uio.c

util.o: util.c util.h
	$(CC) $(CFLAGS) -o util.o util.c

distclean: clean

clean:
	rm -rf stage2.bin *.o stage2.elf stage2.db

.PHONY: all clean distclean
