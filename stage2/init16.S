# init16.asm: 16-bit, real-mode initialization
#
# Copyright 2015, 2016 Vincent Damewood
# Copyright 2016 Tuomo Venäläinen
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# multiboot stuff
MBOOT_MAGIC = 0x1badb002
MBOOT_FLAGS = 0x00000003	# page-align, memory info
MBOOT_CHKSUM = (-(MBOOT_MAGIC + MBOOT_FLAGS))
GFX_WIDTH = 1024
GFX_HEIGHT = 768
GFX_DEPTH = 24

.globl Init16
	
PMemTableCount = 0x3300
MemTableCount  = 0x3300
MemTableCountHi = (0x3300 + 4)
PMemTable = (0x3300 + 8)

.data

GdtPointer:
limit: .word 23
base:  .long GdtTable

GdtTable:
null:
	.fill 8, 1, 0x00

sys_code:
.word 0xFFFF # lower 16 bits of limit
.word 0x0000 # Low 16 bits of the base
.byte 0x00   # Next 8 bytes of the base.
.byte 0x9A   # Access flags, ring, etc
.byte 0xCF   # Example code set all to 0xCF
.byte 0x00   # highest 0 bits of base

sys_data:
.word 0xFFFF # lower 16 bits of limit
.word 0x0000 # Low 16 bits of the base
.byte 0x00   # Next 8 bytes of the base.
.byte 0x92   # Access flags, ring, etc
.byte 0xCF   # Example code set all to 0xCF
.byte 0x00   # highest 0 bits of base

usr_code:
.word 0xFFFF # lower 16 bits of limit
.word 0x0000 # Low 16 bits of the base
.byte 0x00   # Next 8 bytes of the base.
.byte 0xFA   # Access flags, ring, etc
.byte 0xCF   # Example code set all to 0xCF
.byte 0x00   # highest 0 bits of base

usr_data:
.word 0xFFFF # lower 16 bits of limit
.word 0x0000 # Low 16 bits of the base
.byte 0x00   # Next 8 bytes of the base.
.byte 0xF2   # Access flags, ring, etc
.byte 0xCF   # Example code set all to 0xCF
.byte 0x00   # highest 0 bits of base

mboothdr:
.long   MBOOT_MAGIC
.long   MBOOT_FLAGS
.long   MBOOT_CHKSUM
.long   0               # header_addr
.long   0               # load_addr
.long   0               # load_end_addr
.long   0               # bss_end_addr
.long   0               # entry_addr
.long   0               # video mode type (linear)
.long   GFX_WIDTH       # video width
.long   GFX_HEIGHT      # video height
.long   GFX_DEPTH       # video depth

.text

.code16

Init16:
	xorl %eax, %eax
	movw %ax, %dx
	movw %ax, %es

LoadMemoryTable:
	# The following blanks a qword for alignment purposes.
	movl %eax, MemTableCount
	movl %eax, MemTableCountHi

	mov $PMemTable, %di
	xor %ebx, %ebx
	movl $0x534D4150, %ebx
_loop:
	movl $0xE820, %eax
	movl $24, %ecx
	int $0x15
	jc _invalid
	incw MemTableCount

	orl %ebx, %ebx
	jz _done
	addw $24, %di
	jmp _loop
_invalid:
	xorw %ax, %ax
	decw %ax
	movw $24, %cx
	rep stosb
_done:

#VBEInit:
#	movw	$24, %cx
#	movw	$768, %dx
#	movw	$1024, %ax
#	call	vbe_init

EnableA20:
	movl $0x2401, %eax
	int $0x15


LoadGdt:
	# GdtPointer will be a 32-bit address, so here
	# we convert it.
	movl $GdtPointer, %ebx

	# Segment to ds
	movl %ebx, %eax
	shrl $4, %eax
	movw %ax, %ds

	# Offset to eax. This is probably always going
	# to be 0, but just in case we calculate here.
	movl %ebx, %eax
	andl $0x0F, %eax

	cli
	lgdt (%eax)


EnterProtectedMode:
	movl %cr0, %eax
	or $1, %al
	movl %eax, %cr0
	ljmpl $0x08, $Init32
#	jmp dword 0x08:Init32

