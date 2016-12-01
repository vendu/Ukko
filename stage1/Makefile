all: stage1.bin

clean:
	rm -rf stage1.bin stage1.o stage1.elf stage1.db

distclean: clean

stage1.bin: stage1.S
	as -g --32 -o stage1.o stage1.S
#	ld -melf_i386 -N -T stage1.lds -static -o stage1.elf stage1.o
	ld -g -m elf_i386 -nostdlib -nodefaultlibs -Ttext 0x7c00 -N -static -o stage1.elf stage1.o
#	nm stage1.elf > stage1.sym
	objcopy --only-keep-debug stage1.elf stage1.db
	objcopy --add-gnu-debuglink stage1.db stage1.elf
	strip --strip-debug --strip-unneeded stage1.elf
	objcopy -O binary stage1.elf stage1.bin

.PHONY: all clean distclean
