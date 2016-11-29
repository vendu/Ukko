# stage1.asm: Boot sector startup program
#
# Copyright 2015, Vincent Damewood
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
# THIS SOFTWARE IS PROVI DED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES# LOSS OF USE,
# DATA, OR PROFITS (OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

.org	0x7c00

.code16

data_start = 0x500	# Begining of memory where we'll load data: The
                        # directory and file allocation tables.
stg2_segment = 0x1000	# Where to load the stage-2 image.
stack_base = 0x7C00     # This is where the stack starts.
rootsize = 14		# Number of sectors in root directory.

			# === FAT DATA ===

_beginfile:

	jmp start
	nop
fat_bios_parameter_block:
	.ascii "MSWIN4.1" # OEM ID
	.short 512        # bytes per sector
cluster:
	.byte 1          # sectors per cluster
reserved:
	.short 1          # Number of reserved clusters
fatcount:
	.byte 2          # Number of file-allocation tables
entries:
	.short 224        # Number of root entires
	.short 2880       # Number of sectors
	.byte 0xF0       # Media descriptor
fatsize:
	.short 9          # Sectors per file-allocation table
sectors:
	.short 18         # Sectors per track (cylinder)
heads:
	.short 2          # Number of heads/sides
	.long 0          # Hidden sectors
	.long 0          # Number of sectors (if > 2^16-1)
fat_extended_boot_record:
	.byte 0x00	# Drive number
	.byte 0x00      # Current Head (Unused)
	.byte 0x29	# Signature (0x28 or 0x29)
	.long 0x00000000 # Volume ID, will be replaced by formatter
	.ascii "BOOTDISK   " # Volume label
	.ascii "FAT12   "    # System ID# Unreliable.

# === BOOT LOADER ===
_start:	
start:
	# Setup segments and stack
	xorw %ax, %ax
	movw %ax, %ds
	movw %ax, %es
	movw %ax, %ss
	movw $stack_base, %sp
	movw %sp, %bp
	movb %dl, bootdrive

fat_sector = -2
data_sector = -4
fat_memory = -6
root_memory = -8

find_disk_values:
	# Calculate Where root Directory is.
	# (Sector # = fatcount * fatsize + reserved)
	movb fatcount, %al
	mulw fatsize
	addw reserved, %ax
	pushw %ax # fat_sector, sector on disk that has FAT

	# The data sectors start at (rootdir + rootsize), we subtract 2 because FAT
	# enties 0 and 1 are reserved, so actual data starts at 2. 
	addw $rootsize - 2, %ax
	pushw %ax # data_sector

load_fat:
	pushw $data_start       # fat_memory, beginning of FAT
	pushw reserved		# Source
	pushw fatsize		# Count
	call load
	addw $4, %sp		# We pushed 3 values to stack, but only pop 2.
				# Remaining value (the beginning of the FAT in
				# memory) will be used later.
	orw %bx, %bx
	jz error_loadfat
	pushw %bx  # root_memory, beginning of root dir

load_root_dir:		# Use previous push as destination
	pushw -2(%bp)	# Source
	pushw $rootsize		# Count
	call load
	addw $4, %sp		# We're going to keep the last value again.
	orw %bx, %bx
	jz error_loaddir

find_stage_2:
	movw -8(%bp), %bx
	movw entries, %cx
file_next:
	movw 0x0b(%bx), %ax	# Ignore directories and the volume label
	andw $0x18, %ax
	jnz file_nomatch

	movb (%bx), %al	# If the first byte is 0x00, this is the end of the root
	or %al, %al		# directory and we've failed to find the file.
	jz error_notfound	# So, panic and cry about it.

	pushw %cx # Inner Loop
	mov st2_file, %si
	mov %bx, %di
	mov $11, %cx
	repe cmpsb
	popw %cx
	je load_file
file_nomatch:
	addw $32, %bx		# directory entries are 32 bytes
	loop file_next
	jmp error_notfound	# We've exhausted all entries. Quit.

load_file:
	# bx now has directory entry of matching file
	# If I ever decide to keep track of file size,
	# this would be the place to save it. It's at
	# .short 28(%bx)

	movw $stg2_segment, %ax
	movw %ax, %es

	movw 26(%bx), %cx
	xorw %bx, %bx
load_next:
	# CX has cluster to load
	# BX has memory address to load to

	mov -4(%bp), %ax
	addw %cx, %ax

	pushw %bx
	pushw %ax
	movb cluster, %al
	pushw %ax
	call load
	addw $6, %sp

	orw %bx, %bx
	jz error_loads2sec

.find_next_sector:
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
	jz fat_align_even # bits. So we check if the cluster number was odd/even.
	shrw $4, %cx    # If odd, garbage bits are the low-order bits. Shift.
	jmp fat_align_end
fat_align_even:
	andw $0xffff, %cx # If even, garbage bits are the high-order bits. Zero.
fat_align_end:
	# At this point cx has the next cluster
	cmp $0xff8, %cx	# If the next cluster is not an EOF marker...
	jl load_next    # load the next cluster.

jump_to_stage_2:
	jmp $stg2_segment, $0x80 # Else, We're done loading, jmp to the next stage.

/*
%undef fat_sector
%undef data_sector
%undef fat_memory
%undef root_memory
*/

error_loaddir:
error_loadfat:
error_notfound:
error_loads2sec:
	movw $0x0e21, %ax
error_print:
	int $0x10
error_freeze:
	hlt
	jmp error_freeze

# === FUNCTIONS ===

#4(%bp): Number of sectors to load
#6(%bp): First sector to load
#8(%bp): Destination starting memory address
# returns bx: Memory address that's one past
#        the end of the loaded section
load:	
load_fpreamb:
	pushw %bp
	movw %sp, %bp
	pushw %ax
	pushw %cx
	pushw %dx
load_fbody:

# Step 1: Convert sector number to CHS
	movb sectors, %bl
	movb heads, %al
	mulb %bl
	movb %al, %bl

	movw 6(%bp), %ax
	divb %bl # AL has cyl, AH has remainder

	movb %al, %ch	# Set CH = Cylinder
	movb %ah, %al
	movb $0, %ah

	movb sectors, %bl	# AL has head, AH has sector
	divb %bl

	movb %al, %dh

	incb %ah # Sectors are 1-based
	movb %ah, %cl

# Step 2: Make the actual copy to memory
	movb 4(%bp), %al	# Number of sectors
	movb bootdrive, %dl	# drive

	movw 8(%bp), %bx	# destination
	movb $2, %ah
	int $0x13 # due to ah = 0x02, Read sectors into memory
	jnc load_success
	xorw %bx, %bx
	jmp load_freturn
# Step 3: Find and return the end of the load
load_success:
	movw 4(%bp), %bx
	shlw $9, %bx # bx := bx * 512
	addw 8(%bp), %bx
load_freturn:
	popw %dx
	popw %cx
	popw %ax
	movw %bp, %sp
	popw %bp
	ret

# === Non-executable Data ===
st2_file:	.ascii "STAGE2  BIN"
bootdrive:	.byte 0
pad:		.fill 446 - ($pad - $_beginfile), 1, 0x00
# pad:        times 446-($-$$) db 0
ptable:		.fill 64, 1, 0x00
bootsig:	.short 0xAA55

