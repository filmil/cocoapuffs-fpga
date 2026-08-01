.section .init

.option norvc

.type asm_start, @function
.global asm_start
asm_start:
    .cfi_startproc

.option push
.option norelax
    /* Initialize registers to zero */
    li x1, 0
    li x2, 0
    li x3, 0
    li x4, 0
    li x5, 0
    li x6, 0
    li x7, 0
    li x8, 0
    li x9, 0
    li x10, 0
    li x11, 0
    li x12, 0
    li x13, 0
    li x14, 0
    li x15, 0
    li x16, 0
    li x17, 0
    li x18, 0
    li x19, 0
    li x20, 0
    li x21, 0
    li x22, 0
    li x23, 0
    li x24, 0
    li x25, 0
    li x26, 0
    li x27, 0
    li x28, 0
    li x29, 0
    li x30, 0
    li x31, 0

    /* Initialize Global Pointer (GP) relative to PC */
    lla gp, global_pointer
.option pop

    /* Setup stack pointer relative to PC */
    lla sp, stack_top

    /* Clear the BSS section using PC-relative addresses */
    lla t5, bss_start
    lla t6, bss_end
    j 2f
1:
    sw zero, (t5)
    addi t5, t5, 4
2:
    bltu t5, t6, 1b

    /* Jump to _start function using PC-relative addressing */
    lla t0, _start
    jr t0

    .cfi_endproc

.end
