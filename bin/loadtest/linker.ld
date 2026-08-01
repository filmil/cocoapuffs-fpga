ENTRY(asm_start);

. = 0x0;

SECTIONS {
    /* Include entry point at start of binary */
    .text : ALIGN(4K) {
        *(.text);
    }
}

