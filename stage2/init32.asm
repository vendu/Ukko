; init32.asm: 32-bit, protected-mode initialization
;
; Copyright 2015, 2016 Vincent Damewood
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
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
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

extern Init32c
extern KeyboardHandleInterrupt
extern fdHandleInterrupt
extern tmrHandleInterrupt

%macro  fprolog 1-*
	push ebp
	mov ebp, esp
	%if %1
		sub esp, (%1*4)
	%endif
	%if %0 > 2
		%rotate 1
		%rep  %0-1
			push    %1
			%rotate 1
		%endrep
	%endif
%endmacro

%macro  freturn 0-*
	%rep %0
		%rotate -1
		pop %1
	%endrep
	mov esp, ebp
	pop ebp
	ret
%endmacro

%macro  intrfreturn 0-*
	%rep %0
		%rotate -1
		pop %1
	%endrep
	mov esp, ebp
	pop ebp
	sti
	ret
%endmacro

%define IdtCount 48
%define IdtSize  (IdtCount<<3)
%define IdtLimit (IdtSize-1)
%define HexTable '0123456789ABCDEF'

SECTION .data

BssSignature: db '.bss', 0

IntrTableReference:
	.Limit: dw IdtLimit
	.Base:  dd IntrTable

; This makes a table of references to the ISRs so
; that it can be looped through to create the real IDT.
IntrSimpleTable:
%assign i 0
%rep IdtCount
	%substr IsrDigit1 HexTable ((i / 16 + 1))
	%substr IsrDigit2 HexTable ((i % 16 + 1))
	%strcat IsrHexString '0x' IsrDigit1 IsrDigit2
	%deftok IsrHexToken IsrHexString
	dd IntrIsr%[IsrHexToken]
	%assign i i+1
%endrep

%undef IsrHexToken
%undef IsrHexString
%undef IsrDigit2
%undef IsrDigit1
%undef IntrHexTable

SECTION .text

global Init32
Init32:
	mov eax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	mov esp, 0x90000
	mov ebp, esp
LoadBss:
	mov esi, [0x10020] ; Section Table Offset
	add esi, 0x10000 ; Convert offset to memory

	; Entry = SectionTable + EntrySize * StringIndex
	xor eax, eax
	xor edx, edx
	mov ax, word[0x1002E] ; Size of Entry in section table
	mov dx, word[0x10032] ; Index of .shstrtab section, in section table
	mul dx
	shl edx, 16
	or eax, edx
	add eax, esi ; We now have the offset within the table, add offset to base

	mov ebx, eax
	add ebx, 0x10      ; Byte 0x10 of a table entry the section's offset
	mov ebx, [ebx]
	add ebx, 0x10000   ; ebx now has the memory address of .shstrtab

	xor ecx, ecx
	xor edx, edx
	mov dx, word[0x1002E] ; Load Entry size... again
	mov cx, word[0x10030] ; Count

	; eax
	; ecx -- Number of Sectons
	; edx -- Size of a Section Entry
	; ebx -- Address of .shstrtab
	; esi -- Current Table Entry
	; edi

.BssScanLoop:
	push esi
	push ecx

	mov edi, [esi] ; Read first word in entry (offset in .shstrtab)
	add edi, ebx   ; Add offset to base
	mov esi, BssSignature
	mov ecx, 5
	repe cmpsb

	pop ecx
	pop esi
	jz .BssFound

	add esi, edx
	loop .BssScanLoop
	jmp .BssDone
.BssFound:
	mov eax, [esi]
	add eax, ebx

	xor eax, eax
	mov edi, [esi+0x0C] ; Address of .bss
	mov ecx, [esi+0x14] ; Size of .bss
	rep stosb
.BssDone:

	call IntrSetupInterrupts
JumpToC:
	jmp Init32c


section .bss
IntrTable: resb IdtSize

section .text

IntrIsrCommon:
%define Interrupt dword[ebp+4]
%define Code     dword[ebp+8]
	push ebp
	mov ebp, esp
	pusha

	mov eax, Interrupt
.try_timer:
	cmp eax, 0x20
	jne .not_timer
.yes_timer:
	call tmrHandleInterrupt
	jmp .cleanup
.not_timer:

.try_keyboard:
	cmp eax, 0x21
	jne .not_keyboard
.yes_keyboard:
	call KeyboardHandleInterrupt
	jmp .cleanup
.not_keyboard:

.try_floppy:
	cmp eax, 0x26
	jne .not_floppy
.yes_floppy:
	call fdHandleInterrupt
	jmp .cleanup
.not_floppy:

.cleanup:
	mov ecx, Interrupt
	cmp ecx, 0x20
	jl .done
	cmp ecx, 0x2F
	jg .done
	mov al, 0x20
	out 0x20, al
	cmp ecx, 0x28
	jl .done
	out 0xA0, al
.done:
	popa
	mov esp, ebp
	pop ebp
	add esp, 8
	sti
	iret
%undef Interrupt
%undef Code


; The following code creates ISRs for each interrupt.
%assign i 0
%rep IdtCount
	%substr IsrDigit1 HexTable ((i / 16 + 1))
	%substr IsrDigit2 HexTable ((i % 16 + 1))
	%strcat IsrHexString '0x' IsrDigit1 IsrDigit2
	%deftok IsrHexToken IsrHexString
IntrIsr%[IsrHexToken]:
		cli
		%if (i = 8 || (i >= 10 && i <= 14) ||  i = 17 | i = 30)
		%else
			push 0
		%endif
		push i
		jmp IntrIsrCommon
	%assign i i+1
%endrep


IntrSetupInterrupts:
	fprolog 0, eax, edx, ebx
	mov eax, 0
	mov ebx, IntrSimpleTable
	push 0x8E ; Flags
	push 0x08 ; Segment
.loop:
	push dword[ebx]
	push eax
	call IntrAddInterrupt
	add esp, 8
	add ebx, 4 ; next entry
	inc eax
	cmp eax, IdtCount
	jne .loop

	mov edx, IntrTableReference
	lidt [edx]

	;read 0x21
	;read 0xA1
	in al, 0x21
	shl ax, 8
	in al, 0xA1
	mov bx, ax

	;0x20 <-- 0x11
	;0xA0 <-- 0x11
	mov al, 0x11
	out 0x20, al
	out 0xA0, al

	;0x21 <-- 0x20
	;0xA1 <-- 0x28
	mov al, 0x20
	out 0x21, al
	mov al, 0x28
	out 0xA1, al

	;0x21 <-- 0x04
	;0xA1 <-- 0x02
	mov al, 0x04
	out 0x21, al
	mov al, 0x02
	out 0xA1, al

	;0x21 <-- 0x01
	;0xA1 <-- 0x01
	mov al, 0x01
	out 0x21, al
	out 0xA1, al

	;replace 0xA1
	;replace 0x21
	mov ax, bx
	out 0xA1, al
	shr ax, 8
	out 0x21, al

	mov al,20h
	out 20h,al

	intrfreturn eax, edx, ebx

IntrAddInterrupt:
	fprolog 0, eax, ebx
%define SrcNumber  byte  [ebp+ 8]
%define SrcAddr    dword [ebp+12]
%define SrcSegment word  [ebp+16]
%define SrcFlags   byte  [ebp+20]
%define DstAddrLo  word  [ebx+0]
%define DstSegment word  [ebx+2]
%define DstZero    byte  [ebx+4]
%define DstFlags   byte  [ebx+5]
%define DstAddrHi  word  [ebx+6]
.EndDebug:
	xor eax, eax
	xor ebx, ebx

	; Establish Entry Address
	mov bl, SrcNumber
	shl ebx, 3
	add ebx, IntrTable

	; Set the Always-Zero Field to Zero
	mov DstZero, al

	; Mangle and save the ISR address
	mov eax, SrcAddr
	mov DstAddrLo, ax
	shr eax, 16
	mov DstAddrHi, ax

	; Simple copies
	mov ax, SrcSegment
	mov DstSegment, ax
	mov al, SrcFlags
	mov DstFlags, al
%undef SrcNumber
%undef SrcAddr
%undef SrcSegment
%undef SrcFlags
%undef DstAddrHi
%undef DstSegment
%undef DstZero
%undef DstFlags
%undef DstAddrLo
	freturn eax, ebx

%undef IdtCount
%undef IdtSize
%undef IdtLimit
