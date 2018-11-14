# init16.asm: 16-bit, real-mode initialization
#
# Copyright 2015, 2016 Vincent Damewood
# Copyright 2016-2018 Tuomo Venäläinen
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
MBOOT_GFX_WIDTH = 1024
MBOOT_GFX_HEIGHT = 768
MBOOT_GFX_DEPTH = 24

.globl init16
	
pmemtabcnt = 0x3300
memtabcnt  = 0x3300
memtabcnthi = (0x3300 + 4)
pmemtab = (0x3300 + 8)

.macro _gdtdesc lbl:req, adr:req, lim:req, perm:req, flg:req
lbl():
.word	\lim & 0xffff
.word	\adr & 0xffff
.byte	(\adr >> 16) & 0xff
.byte	\perm
.byte	\flg
.byte	(\adr >> 24) & 0xff
.endm

.data

_gdt:
_gdtdesc _null, 0, 0, 0, 0
_gdtdesc _syscode, 0, 0xffff, 0x9a, 0xcf
_gdtdesc _sysdata, 0, 0xffff, 0x92, 0xcf
_gdtdesc _usrcode, 0, 9xffff, 0xfa, 0xcf
_gdtdesc _usrdata, 0, 0xffff, 0xf2, 0xcf

_mboothdr:
.long   MBOOT_MAGIC
.long   MBOOT_FLAGS
.long   MBOOT_CHKSUM
.long   0               # header_addr
.long   0               # load_addr
.long   0               # load_end_addr
.long   0               # bss_end_addr
.long   0               # entry_addr
.long   0               # video mode type (linear)
.long   MBOOT_GFX_WIDTH	# video width
.long   MBOOT_GFX_HEIGHT	# video height
.long   MBOOT_GFX_DEPTH		# video depth

.text

.code16

init16:
	xorl	%eax, %eax
	movw	%ax, %dx
	movw	%ax, %es

_loadmemtab:
	# blank qword for alignment
	movl	%eax, memtabcnt
	movl	%eax, memtabcnthi

	mov	$pmemtab, %di
#	xor	%ebx, %ebx
	movl	$0x534D4150, %ebx
_loop:
	movl	$0xE820, %eax
	movl	$24, %ecx
	int	$0x15
	jc	_failure
	incw	memtabcnt

	orl	%ebx, %ebx
	jz	_done
	addw	$24, %di
	jmp	_loop
_failure:
	xorw	%ax, %ax
	decw	%ax
	movw	$24, %cx
	rep	stosb
_done:

#VBEInit:
#	movw	$24, %cx
#	movw	$768, %dx
#	movw	$1024, %ax
#	call	vbe_init

EnableA20:
_a20fast:
	# try "fast" method for enabling A20
	inb	$0x92, %al	# check for method
	testb	$0x02, %al	# available?
	jnz	_a20bios	# nope
	orb	$0x02, %al	# set flag
	andb	$0xfe, %al	# mask reset flag
	outb	%al, $0x92	# enable
	outb	%al, $0x80	# delay
	jmp	_resetfd	# done
_a20bios:
	# try BIOS int 0x15 to enable A20
	movl	$0x2401, %eax	# enable
	int	$0x15		# interrupt
_a20bioschk:
        movw    $0x2402, %ax    # check status
        int     $0x15           # interrupt
        cmp     $0x01, %al      # enabled?
        je      ResetFD         # yes
_a20kbd1:
        inb     $0x64, %al      # get status
        testb   $0x02, %al      # busy?
        jnz     _a20kbd1        # yes
        movb    $0xd1, %al      # write
        outb    %al, $0x64      # output
        outb    %al, $0x80      # delay
_a20kbd2:
        inb     $0x64, %al      # get status
        testb   $0x02, %al      # busy?
        jnz     _a20kbd2        # yes
        movb    $0xdf, %al      # enable
        outb    %al, $0x60      # A20
        outb    %al, $0x80      # delay
_a20kbd3:
        inb     $0x64, %al      # get status
        testb   $0x02, %al      # busy?
        jnz     _a20kbd3	# yes
	
_resetfd:
	movb	$0x00, %ah
	movb	$0x00, %dl
	int	$0x13

_loadgdt:
	# gdtfptr will be a 32-bit address, so here
	# we convert it.
	movl	$gdtfptr, %ebx

	# Segment to ds
	movl	%ebx, %eax
	shrl	$4, %eax
	movw	%ax, %ds

	# Offset to eax. This is probably always going
	# to be 0, but just in case we calculate here.
	movl	%ebx, %eax
	andl	$0x0F, %eax

	cli
	lgdt	(%eax)


_protmode:
	movl	%cr0, %eax
	or	$0x01, %al
	movl	%eax, %cr0
	ljmpl	$0x08, $init32


.rodata

gdtfptr:
limit: .word 23
base:  .long _gdt

