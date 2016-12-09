ENTRY(Init16)

SECTIONS
{
    /* ELF-headers are loaded at 0x10000..0x1007f */
    .text.real16 (0x10080) : {
        init16.o(.text)
        util16.o(.text)
    }
    .data.real16 : {
        init16.o(.data)
        util16.o(.data)
    }
    .text : { *(.text) }
    .data : { *(.data) }
    .bss  : { *(.bss) }
}
