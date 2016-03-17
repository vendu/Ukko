; acpi.asm: ACPI interface code
;
; Copyright 2016 Vincent Damewood
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

%include "functions.inc"

extern Compare
extern ScreenPrintHexDWord
extern ScreenPrintHexByte
extern ScreenPrintChar
extern ScreenPrintSpace
extern ScreenBreakLine
extern ScreenPrintLine

%define HeaderLen 36

section .data

PointerSignature:  db "RSD PTR "
PointerHeader:     db "Addr     Sig      Ch Vendor Rv RSDTAddr", 0
TableHeader:       db "Addr     Sig  Length   Rv Ch OEM    OEM Tbl  OEMRev   Crtr CrtrRev", 0
PointerError:      db "Error: RSDP not found", 0
PointerLocation:   dd 0

section .text

GetPointer:
	fprolog 0
	mov eax, [PointerLocation]
	or eax, eax
	jnz .done
	call FindPointer
	mov [PointerLocation], eax
.done:
	freturn

FindPointer:
	fprolog 0, ecx

	mov ecx, 0x000E0000
	push 8
	push PointerSignature
.loop:
	push ecx
	call Compare
	add esp, 4
	or eax, eax
	jz .found
	add ecx, 0x10
	cmp ecx, 0x00100000
	jne .loop
.notfound:
	xor eax, eax
	jmp .done
.found:
	mov eax, ecx
.done:
	add esp, 8
	freturn ecx

global AcpiShowRsdp
AcpiShowRsdp:
	fprolog 0, eax, ecx, esi

	call GetPointer
	or eax, eax
	jnz .exists
	push PointerError
	call ScreenPrintLine
	add esp, 4
	jmp .done

.exists:
	mov esi, eax
	xor eax, eax

	push PointerHeader
	call ScreenPrintLine
	add esp, 4


	push esi
	call ScreenPrintHexDWord
	add esp, 4
	call ScreenPrintSpace

	mov ecx, 8
.signature:
	lodsb
	push eax
	call ScreenPrintChar
	add esp, 4
	loop .signature
	call ScreenPrintSpace

.checksum:
	lodsb
	push eax
	call ScreenPrintHexByte
	add esp, 4
	call ScreenPrintSpace

	mov ecx, 6
.vendor:
	lodsb
	push eax
	call ScreenPrintChar
	add esp, 4
	loop .vendor
	call ScreenPrintSpace

	lodsb
	push eax
	call ScreenPrintHexByte
	add esp, 4
	call ScreenPrintSpace

	lodsd
	push eax
	call ScreenPrintHexDWord
	add esp, 4

	call ScreenBreakLine
.done:
	freturn eax, ecx, esi

showSdtHeader:
	fprolog 0, eax, esi

	;push TableHeader
	;call ScreenPrintLine
	;add esp, 4

	mov esi, [ebp+8]
	push esi
	call ScreenPrintHexDWord
	add esp, 4
	call ScreenPrintSpace

	mov ecx, 4
.signature:
	lodsb
	push eax
	call ScreenPrintChar
	add esp, 4
	loop .signature
	call ScreenPrintSpace

.length:
	lodsd
	push eax
	call ScreenPrintHexDWord
	add esp, 4
	call ScreenPrintSpace

.revision:
	lodsb
	push eax
	call ScreenPrintHexByte
	add esp, 4
	call ScreenPrintSpace

.checksum:
	lodsb
	push eax
	call ScreenPrintHexByte
	add esp, 4
	call ScreenPrintSpace

	mov ecx, 6
.oem:
	lodsb
	push eax
	call ScreenPrintChar
	add esp, 4
	loop .oem
	call ScreenPrintSpace

	mov ecx, 8
.oemId:
	lodsb
	push eax
	call ScreenPrintChar
	add esp, 4
	loop .oemId
	call ScreenPrintSpace

.oemRevision:
	lodsd
	push eax
	call ScreenPrintHexDWord
	add esp, 4
	call ScreenPrintSpace

	mov ecx, 4
.creatorId:
	lodsb
	push eax
	call ScreenPrintChar
	add esp, 4
	loop .creatorId
	call ScreenPrintSpace

.creatorRev:
	lodsd
	push eax
	call ScreenPrintHexDWord
	add esp, 4
	call ScreenBreakLine
.done:
	freturn eax, esi

global AcpiShowTables
AcpiShowTables:
	fprolog 0, eax
	call GetPointer
	or eax, eax
	jnz .exists
	push PointerError
	call ScreenPrintLine
	add esp, 4
	jmp .done

.exists:
	push TableHeader
	call ScreenPrintLine
	add esp, 4

	push dword[eax+16]
	call showSdtHeader
	add esp, 4

.done:
	freturn eax, ebx