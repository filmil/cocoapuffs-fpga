ENTRY(asm_start);

STACK_SIZE = DEFINED(STACK_SIZE) ? STACK_SIZE : 4096;

. = DEFINED(RAM_START) ? RAM_START : 0x0;

SECTIONS {
    /* Include entry point at start of binary */
    .text : ALIGN(4K) {
        *(.init);
        *(.text);
        *(.text.*);
    }
    .bss : ALIGN(4K) {
        PROVIDE(bss_start = .);
        *(.bss);
        *(.bss.*);
        *(COMMON);
        . = ALIGN(16);
        . += STACK_SIZE;
        PROVIDE(stack_top = .);
        . += 4096;
        PROVIDE(global_pointer = .);
        PROVIDE(bss_end = .);
    }
    .rodata : ALIGN(4K) {
        *(.rodata);
        *(.rodata.*);
        *(.srodata);
        *(.srodata.*);

        . = ALIGN(4);
        PROVIDE(__init_array_start = .);
        KEEP(*(SORT(.init_array.*)))
        KEEP(*(.init_array))
        PROVIDE(__init_array_end = .);

        . = ALIGN(4);
        PROVIDE(__fini_array_start = .);
        KEEP(*(SORT(.fini_array.*)))
        KEEP(*(.fini_array))
        PROVIDE(__fini_array_end = .);
    }
    .data : ALIGN(4K) {
        *(.data);
        *(.data.*);
        *(.sdata);
        *(.sdata.*);
    }

    PROVIDE(_end = .);
}

