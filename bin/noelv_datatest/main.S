.section .text
.global _start

# Standalone test: does the SERV ihex loader correctly load a .data section at
# 0x80000?  OpenSBI's RW data (incl. the console_early_fifo struct @0x803b8) lives
# at 0x80000 -- a DIFFERENT ihex extended-segment region (segment 0x8000) than the
# .text at 0x40000 (segment 0x4000).  noelv_memtest only proved the CORE can
# write+read 0x80000; it overwrote whatever SERV loaded.  This instead links a
# KNOWN pattern into .data AT 0x80000, lets SERV upload it, and the core reads it
# back -- verifying the SERV->DDR3->core path for that segment.
#
# .text at 0x40000, .data at 0x80000 (both uploaded).  No stack.  Prints
# "DATA OK" or "DATA BAD <addr> <got>" on the APBUART (drained method).

#define UART_SCALER 42
#define N 1024                       /* words of pattern */

_start:
    nop
    li   t0, 0xff9
    slli t0, t0, 20
    li   t1, UART_SCALER
    sw   t1, 12(t0)
    li   t1, 0x3
    sw   t1, 8(t0)
    mv   s0, t0

    # verify .data at 0x80000: word[i] must equal 0x5a7a0000 + i
    li   t0, 0x80000                 # .data base (linked there)
    li   t1, N
    li   t2, 0x5a7a0000              # expected (bit31 clear -> no lw sign issue)
    li   t3, 0
1:  lw   t5, 0(t0)
    bne  t5, t2, fail
    addi t0, t0, 4
    addi t2, t2, 1
    addi t3, t3, 1
    bltu t3, t1, 1b

    li   a0, 'D'; jal ra, putc
    li   a0, 'A'; jal ra, putc
    li   a0, 'T'; jal ra, putc
    li   a0, 'A'; jal ra, putc
    li   a0, ' '; jal ra, putc
    li   a0, 'O'; jal ra, putc
    li   a0, 'K'; jal ra, putc
    li   a0, 13;  jal ra, putc
    li   a0, 10;  jal ra, putc
2:  j    2b

fail:
    mv   s2, t0                      # save (puthex32 clobbers t2/t6) -- addr
    mv   s3, t5                      # got
    mv   s4, t2                      # expected
    li   a0, 'D'; jal ra, putc
    li   a0, 'A'; jal ra, putc
    li   a0, 'T'; jal ra, putc
    li   a0, 'A'; jal ra, putc
    li   a0, ' '; jal ra, putc
    li   a0, 'B'; jal ra, putc
    li   a0, 'A'; jal ra, putc
    li   a0, 'D'; jal ra, putc
    li   a0, ' '; jal ra, putc
    mv   a1, s2;  jal ra, puthex32   # failing address
    li   a0, ' '; jal ra, putc
    mv   a1, s3;  jal ra, puthex32   # value read
    li   a0, ' '; jal ra, putc
    mv   a1, s4;  jal ra, puthex32   # value expected
    li   a0, 13;  jal ra, putc
    li   a0, 10;  jal ra, putc
3:  j    3b

putc:
    lw   t1, 4(s0)
    andi t1, t1, 0x2
    beqz t1, putc
    sw   a0, 0(s0)
    ret

puthex32:
    mv   s1, ra
    li   t2, 8
ph_loop:
    srli a0, a1, 28
    andi a0, a0, 0xf
    li   t6, 10
    blt  a0, t6, ph_dig
    addi a0, a0, 'a' - 10
    j    ph_emit
ph_dig:
    addi a0, a0, '0'
ph_emit:
    jal  ra, putc
    slli a1, a1, 4
    addi t2, t2, -1
    bnez t2, ph_loop
    mv   ra, s1
    ret

# Known pattern placed in .data, which the linker puts at 0x80000.
.section .data
.align 3
pattern:
.set i, 0
.rept N
    .long 0x5a7a0000 + i
    .set i, i + 1
.endr
