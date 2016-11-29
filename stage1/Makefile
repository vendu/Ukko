all: stage1.bin

clean:
	rm -rf stage1.bin

distclean: clean

stage1.bin: stage1.S
	as --32 -o stage1.o stage1.S
	ld -melf_i386 -N -T stage1.lds -static -o stage1.elf stage1.o
	objcopy -O binary stage1.elf stage1.bin

.PHONY: all clean distclean
