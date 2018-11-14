# stage1.asm: Boot sector startup program
#
# Copyright 2015 Vincent Damewood
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
# Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVI DED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES# LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

.globl	_start

_pagetabadr = 0x7C00 + 446
_dataadr = 0x500	# Begining of memory where we'll load data: The
                        # directory and file allocation tables.
_loadseg = 0x1000	# Where to load the stage-2 image - 64 kilobytes
_stkbase = 0x7C00	# This is where the stack starts.
_rootsize = 14		# Number of sectors in root directory.

# === FAT DATA ===

.code16

.text

start:
_start:	
	jmp boot
	nop

_fatbiosparm:
.ascii "MSWIN4.1"	# OEM ID
.short 512	# bytes per sector
_cluster:
.byte 1         # sectors per cluster
_resclusters:
.short 1        # Number of reserved clusters
_fatcount:
.byte 2         # Number of file-allocation tables
_entries:
.short 224      # Number of root entries
.short 2880     # Number of sectors
.byte 0xF0      # Media descriptor
_fatsize:
.short 9        # Sectors per file-allocation table
_sectors:
.short 18       # Sectors per track (cylinder)
_heads:
.short 2        # Number of heads/sides
.long 0         # Hidden sectors
.long 0         # Number of sectors (if > 2^16-1)
_fatxbr:	# extended boot record
.byte 0x00	# Drive number
.byte 0x00      # Current Head (Unused)
.byte 0x29	# Signature (0x28 or 0x29)
.long 0         # Volume ID, will be replaced by formatter
.ascii "BOOTDISK   " # Volume label
.ascii "FAT12   "    # System ID# Unreliable.

# === BOOT LOADER ===

boot:
	# Setup segments and stack
	xorw %ax, %ax
	movw %ax, %ds
	movw %ax, %es
	movw %ax, %ss
	movw $_stkbase, %sp
	movw %sp, %bp
	movb %dl, _bootdrive

_getdiskparm:
	# calculate root location.
	# sector = _fatcount * _fatsize + _resclusters)
	
	movb _fatcount, %al
	mulw _fatsize
	addw _resclusters, %ax
	pushw %ax	# sector on disk with FAT

	# data sectors start at rootdir + _rootsize, we subtract 2 because FAT
	# entries 0 and 1 are reserved, so actual data starts at 2. 
	addw $_rootsize - 2, %ax
	pushw %ax

_loadfat:
	pushw $_dataadr         # beginning of FAT
	pushw _resclusters	# source
	pushw _fatsize		# count
	call _load
	addw $4, %sp		# pushed 3 values, but only pop 2.
				# Remaining value _dataadr  will be used later.
	orw %bx, %bx
	jz _errorloadfat
	pushw %bx		# beginning of root dir

_loadroot:			# use previous push as destination
	pushw -2(%bp)		# source
	pushw $_rootsize	# count
	call _load
	addw $4, %sp		# keep the last value again.
	orw %bx, %bx
	jz _errorloaddir

_findstage2:
	movw -8(%bp), %bx
	movw _entries, %cx
_nextfile:
	movw 0x0b(%bx), %ax	# ignore directories and volume label
	andw $0x18, %ax
	jnz _nomatch

	movb (%bx), %al		# if first byte is 0x00, this is end of troot
	or %al, %al		# and we've failed to find the file.
	jz _errornofile	# so, panic and cry about it.

	# inner Loop
	pushw %cx
	movw $_stage2file, %si
	movw %bx, %di
	movw $11, %cx
	repe cmpsb
	popw %cx
	je _loadfile
_nomatch:
	addw $32, %bx		# directory entries are 32 bytes
	loop _nextfile
	jmp _errornofile	# We've exhausted all entries. Quit.

_loadfile:
	# BX - dirent of matching file
	# could save file size word from 28(%bp) (16-bit word)
	movw $_loadseg, %ax	# load segment
	movw %ax, %es

	movw 26(%bx), %cx	# cluster
	xorw %bx, %bx
_loadnext:
	# CX - cluster to load
	# BX - address to load to

	mov -4(%bp), %ax
	addw %cx, %ax

	pushw %bx
	pushw %ax
	movb _cluster, %al
	pushw %ax
	call _load
	addw $6, %sp

	orw %bx, %bx
	jz _errorloadsec

_nextsector:
	# The following bit of magic takes the value of cx, multiplies it by
	# 1.5 and notes if it was odd or even before the process. This gives
	# us the memory offset from the beginning of the FAT for the FAT
	# entry of cluster cx.
	movw %cx, %si
	shrw $1, %si	# si = floor(cx/2)
	sbbw %dx, %dx   # dx = (cx mod 2) == 0 ? 0 : -1
	addw %cx, %si	# si = 1.5*cx
	addw -6(%bp), %si # si = location in fat for cx

	movw (%si), %cx # load cx from new location

	orw %dx, %dx    # At this point cx contains a value with four garbage
	jz _fatalign # bits. So we check if the cluster number was odd/even.
	shrw $4, %cx    # If odd, garbage bits are the low-order bits. Shift.
	jmp _fataligned
_fatalign:
	andw $0xfff, %cx # If even, garbage bits are the high-order bits. Zero.
_fataligned:
	# At this point cx has the next cluster
	cmp $0xff8, %cx	# If the next cluster is not an EOF marker...
	jl _loadnext    # load the next cluster.

_jmpstage2:
	jmp $_loadseg, $0x80 # Else, We're done loading, jmp to the next stage.

_errorloaddir:
_errorloadfat:
_errornofile:
_errorloadsec:
	movw $0x0e21, %ax
_errorprint:
	int $0x10
_errorfreeze:
	hlt
	jmp _errorfreeze

# === FUNCTIONS ===

# 4(%bp): # of sectors
# 6(%bp): 1st sector to load
# 8(%bp): destination address
# returns bx: Memory address that's one past the end of the loaded section
_load:	
# prepare stack
	pushw %bp
	movw %sp, %bp
	pushw %ax
	pushw %cx
	pushw %dx

# #1: convert sector number to CHS
	movb _sectors, %bl
	movb _heads, %al
	mulb %bl
	movb %al, %bl

	movw 6(%bp), %ax
	divb %bl	# AL - cylimder, AH has remainder

	movb %al, %ch	# CH = cylinder
	movb %ah, %al
	movb $0, %ah

	movb _sectors, %bl	# AL - head, AH - sector
	divb %bl

	movb %al, %dh

	incb %ah		# sectors are 1-based
	movb %ah, %cl

# #2: read sectors into memory
	movb 4(%bp), %al	# # of sectors
	movb _bootdrive, %dl	# drive

	movw 8(%bp), %bx	# destination
	movb $0x02, %ah		# AH = 0x02
	int $0x13		# read sectors into memory
	jnc _loadok
	xorw %bx, %bx
	jmp _loadfin
# #3: find and return end of _load
_loadok:
	movw 4(%bp), %bx
	äshlw $9, %bx		# bx := bx * 512
	addw 8(%bp), %bx
_loadfin:
	popw %dx
	popw %cx
	popw %ax
	movw %bp, %sp
	popw %bp
	ret

# === Non-executable Data ===

_stage2file:	.ascii "STAGE2  BIN"
_bootdrive:	.byte 0
.org	446
_pagetab:	.fill 64, 1, 0x00
_bootsig:	.short 0xAA55

