; stage1.asm: Boot sector startup program
;
; Copyright 2015, Vincent Damewood
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without
; modification, are permitted provided that the following conditions
; are met:
;
; 1. Redistributions of source code must retain the above copyright
; notice, this list of conditions and the following disclaimer.
;
; 2. Redistributions in binary form must reproduce the above copyright
; notice, this list of conditions and the following disclaimer in the
; documentation and/or other materials provided with the distribution.
;
; THIS SOFTWARE IS PROVI DED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
; A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
; HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
; LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
; DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
; (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
; OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

[BITS 16]
[ORG 0x7C00]

memory_start   equ  0x0500 ; Beginning of free memory. 256 bytes
                           ; are reserved (by me) for variables
                           ; and state. But I'm only using 2 bytes.
data_start     equ  0x0600 ; Begining of memory where we'll load
                           ; data: the root directory and
                           ; file allocation tables.
stage1_start   equ  0x7C00 ; The beginning of where the boot sector
                           ; is loaded. This is used to setup the
stage2_start   equ  0x8000 ; Where to load the second-stage image.
stack_base     equ  stage1_start

; === FAT DATA ===

	jmp start
	nop
fat_bios_parameter_block:
	db 'MSWIN4.1' ; OEM ID
	dw 512        ; bytes per sector
cluster:
	db 1          ; sectors per cluster
reserved:
%ifdef DEBUG
	dw 2          ; Number of reserved clusters
%else ; not DEBUG
	dw 1          ; Number of reserved clusters
%endif
fatcount:
	db 2          ; Number of file-allocation tables
entries:
	dw 224        ; Number of root entires
	dw 2880       ; Number of sectors
	db 0xF0       ; Media descriptor
fatsize:
	dw 9          ; Sectors per file-allocation table
	dw 18         ; Sectors per track (cylinder)
	dw 2          ; Number of heads/sides
	dd 0          ; Hidden sectors
	dd 0          ; Number of sectors (if > 2^16-1)
fat_extended_boot_record:
	db 0x00          ; Drive number
	db 0x00          ; Current Head (Unused)
	db 0x28          ; Signature (0x28 or 0x29)
	dd 0xBAADBEEF    ; Volume ID
	db 'BOOTDISK   ' ; Volume label
	db 'FAT12   '    ; System ID; Unreliable.

; === BOOT LOADER ===
start:
	; Setup segments and stack
	mov ax, 0
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, stack_base
	mov bp, stack_base

%ifdef DEBUG
	push ax
	; Load debugging/development code
	push 0x7E00
	push 1
	push 1
	call load
	add sp, 6

	; Display start-up message
	push msg_start
	call print
	add sp, 2
	pop ax
%endif ; DEBUG

.load_dir:
	; Calculate Where root Directory is.
	; (Sector # = fatcount * fatsize + reserved)
	mov al, [fatcount]
	imul ax, [fatsize]
	add ax, [reserved]

	push data_start ; Destination
	push ax ; Source
	push 14 ; Count
	call load
	add sp, 6

.load_fat:
	push ax ; ax holds the location to which the FAT will be loaded.
	push word[reserved] ; Source
	push word[fatsize] ; Count
	call load
	add sp, 4 ; We pushed 3 values to stack, but only pop 2.
	          ; The remaining value (the beginning of the FAT in
	          ; memory) will be used later.
	push ax   ; We'll also save the end of the FAT.

	mov bx, data_start
	mov cx, [entries]

.nextfile:
	mov ax, [bx+0x0B] ; Ignore directories and the volume label
	and ax, 0x18
	jnz .file_nomatch

	push cx ; Inner Loop
	mov si, st2_file
	mov di, bx
	mov cx, 11
	repe cmpsb
	pop cx
	jne .file_nomatch
	jmp .file_found

.file_nomatch:
	add bx, 32 ; Directory entries are 32 bytes
	loop .nextfile
	jmp .error ; We've exhausted all entries. Quit.

.file_found:
	; bx now has directory entry of matching file
	; If I ever decide to keep track of file size,
	; this would be the place to save it. It's at
	; dword[bx+28].

	mov cx, word[bx+26]
	mov bx, stage2_start
.loadnext:
	; CX has cluster to load
	; BX has memory address to load to

	; The location of cluster n is sector
	; (reserved + fat_size * fat_count + 12) + n
	; Where the 12 represents the size of the root
	; directory (14) minus 2 because FAT clusters
	; start at 2.
	mov dx, [fatsize]
	mov ah, 0
	mov al, [fatcount]
	mul dx
	add ax, [reserved]
	add ax, 12
	add ax, cx

	push bx
	push ax
	mov al, [cluster]
	push ax
	call load
	add sp, 4
	or ax, ax
	jz .error

	; [bp-2] Beginning of FAT
	; [bp-4] End of FAT

	; The following bit of magic takes the value of cx, multiplies it by
	; 1.5 and notes if it was odd or even before the process.
	mov ax, cx
	shr ax, 1       ; ax = floor(cx/2)
	sbb dx, dx      ; dx = (cx mod 2) ? -1 : 0
	add cx, ax      ; cx = 1.5*cx
	add cx, [bp-2]

	mov di, cx
	mov cx, [di]

	or dx, dx           ; At this point cx contains a value with four garbage
	jz .fat_align_even  ; bits. So we check if the cluster number was odd/even.
	shr cx, 4           ; If odd, garbage bits are the low-order bits. Shift.
	jmp .fat_align_end
.fat_align_even:
	and cx, 0x0FFF      ; If even, garbage bits are the high-order bits. Zero.
.fat_align_end:
	; At this point cx has the next cluster
	cmp cx, 0xFF8    ; If the next cluster is an EOF marker...
	jge stage2_start ; We're done loading, jmp to the next stage.

	; Otherwise, setup to load the next cluster.
	add bx, 512
	jmp .loadnext
.error:
	mov ax, 0x0E13
	int 0x10
.freeze:
	hlt
	jmp .freeze

; === FUNCTIONS ===

load:
;[bp+4]: Number of sectors to load
;[bp+6]: First sector to load
;[bp+8]: Destination starting memory address
; returns ax: Memory address that's one past
;        the end of the loaded section
.fpreamb:
	push bp
	mov bp, sp
	push cx
	push dx
	push bx
.fbody:

; Step 1: Convert sector number to CHS
	mov ax, [bp+6]
	mov bl, 36
	div bl ; AL has cyl, AH has remainder

	mov ch, al ; Set CH = Cylinder
	mov al, ah
	mov ah, 0

	mov bl, 18 ; AL has head, AH has sector
	div bl

	mov dh, al

	inc ah ; Sectors are 1-based
	mov cl, ah

; Step 2: Make the actual copy to memory
	mov al, [bp+4] ; Number of sectors
	mov dl, 0 ; drive

	mov bx, [bp+8] ; destination
	mov ah, 2
	int 0x13 ; due to ah = 0x02, Read sectors into memory
	; FIXME: Carry flag set on failure. Do something.

; Step 3: Find and return the end of the load
	mov ax, 512
	mov bx, [bp+6]
	mul bx
	add ax, [bp+8]
.freturn:
	pop bx
	pop dx
	pop cx
	mov sp, bp
	pop bp
	ret

; === Non-executable Data ===
st2_file:  db 'STAGE2  BIN'
pad:        times 444-($-$$) db 0
marker:     dw 0xFFFE ; This is so that I can see how much space
                      ; is available in the binary.
ptable:     times 64 db 0
bootsig:    dw 0xAA55

; === End of first sector ===
; All code below this point is for debugging and should be
; removed after the bootsector is complete.

%ifdef DEBUG
; Print a string
print:
.fpreamb:
	push bp
	mov bp, sp
	push ax
	push si
.fbody:
	mov si, [bp+4]
	mov ah, 0x0E ; Causes the BIOS interrupt to print a character
.loop:
	lodsb        ; Fetch next byte in string, ...
	or al, al    ; ... test if it's 0x00, ...
	jz .freturn  ; ... and, if so, were'd done
	int 0x10     ; Due to ah = 0x0E, prints character
	jmp .loop
.freturn:
	pop si
	pop ax
	mov sp, bp
	pop bp
	ret

print_byte:
.fpreamb:
	push bp
	mov bp, sp
	push ax
.fbody:
	mov ah, 0x0E
	mov al, [bp+4]
	shr al, 4
	add al, 0x30
	cmp al, 0x39
	jle .skip1
	add al, 7
.skip1:
	int 0x10

	mov al, [bp+4]
	and al, 0x0F
	add al, 0x30
	cmp al, 0x39
	jle .skip2
	add al, 7
.skip2:
	int 0x10
.freturn:
	pop ax
	mov sp, bp
	pop bp
	ret

debug_word:
.fpreamb:
	push bp
	mov bp, sp
	push ax
.fbody:
	push msg_debug_word
	call print

	mov ax, [bp+4]
	shr ax, 8
	push ax
	call print_byte

	mov ax, [bp+4]
	push ax
	call print_byte

	push msg_debug_end
	call print
	add sp, 8
.freturn:
	pop ax
	mov sp, bp
	pop bp
	ret

debug_byte:
.fpreamb:
	push bp
	mov bp, sp
	push ax
.fbody:
	push msg_debug_byte
	call print

	mov ax, [bp+4]
	push ax
	call print_byte

	push msg_debug_end
	call print
	add sp, 6
.freturn:
	pop ax
	mov sp, bp
	pop bp
	ret

msg_start:      db 'Boot sector loaded.', 0x0D, 0x0A, 0
msg_debug_byte: db 'BYTE(', 0
msg_debug_word: db 'WORD(', 0
msg_debug_end:  db ')'

pad2:        times 1024-($-$$) db 0
%endif
