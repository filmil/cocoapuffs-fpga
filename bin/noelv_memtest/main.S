.section .text
.global _start

# Standalone RV64 memory test for OpenSBI's RW/heap region on the NOEL-V board.
#
# OpenSBI runs its code from 0x40000 (works -- it executes), but DIES at
# sbi_domain_init, which lives entirely in the 0x80000+ region: .data
# (_fw_rw_start=0x80000, incl. console_early_fifo @0x803b8), .bss (0x83000..),
# and the heap (~0x88000).  In pure simulation (clean BRAM) domain_init SUCCEEDS;
# on hardware it fails -- the one thing that differs is that 0x80000+ is real
# DDR3.  This test isolates that: it writes a unique value (the address itself)
# to every word in [0x80000, 0x92000), reads them all back, and reports the FIRST
# mismatch -- catching stuck bits, write-doesn't-stick, refresh decay, and
# address aliasing that a single-word test misses.
#
# Linked at 0x40000 so the SERV ihex loader + boot stub run it directly (no
# OpenSBI).  Uses NO stack (all register-based) so the result does not depend on
# any DDR3 location being good.  Prints "MEM OK" or "BAD <addr> <got>" on the
# APBUART @0xFF900000 (scaler 42 = 115200 @ 40 MHz; poll status bit1 = TX empty).

#define UART_SCALER 42
#define MEM_START   0x80000
#define MEM_END     0x92000          /* covers .data, .bss, heap, stack */

_start:
    nop
    li   t0, 0xff9
    slli t0, t0, 20                  # APBUART base 0xFF900000
    li   t1, UART_SCALER
    sw   t1, 12(t0)                  # scaler
    li   t1, 0x3
    sw   t1, 8(t0)                   # control: RE | TE
    mv   s0, t0                      # s0 = UART base (kept for putc)

    # ---- write phase: each word holds its own address ----
    li   t3, MEM_START
    li   t4, MEM_END
1:  sw   t3, 0(t3)
    addi t3, t3, 4
    bltu t3, t4, 1b

    # ---- read/verify phase ----
    li   t3, MEM_START
2:  lw   t5, 0(t3)
    bne  t5, t3, fail
    addi t3, t3, 4
    bltu t3, t4, 2b

    # ---- all words verified: "MEM OK\r\n" ----
    li   a0, 'M'; jal ra, putc
    li   a0, 'E'; jal ra, putc
    li   a0, 'M'; jal ra, putc
    li   a0, ' '; jal ra, putc
    li   a0, 'O'; jal ra, putc
    li   a0, 'K'; jal ra, putc
    li   a0, 13;  jal ra, putc
    li   a0, 10;  jal ra, putc
3:  j    3b

fail:
    # "BAD <addr> <got>\r\n"  (t3 = failing address, t5 = value read back)
    li   a0, 'B'; jal ra, putc
    li   a0, 'A'; jal ra, putc
    li   a0, 'D'; jal ra, putc
    li   a0, ' '; jal ra, putc
    mv   a1, t3;  jal ra, puthex32
    li   a0, ' '; jal ra, putc
    mv   a1, t5;  jal ra, puthex32
    li   a0, 13;  jal ra, putc
    li   a0, 10;  jal ra, putc
4:  j    4b

# putc(a0): poll status bit1 (TX shift empty), write the byte.  Leaf; uses s0.
putc:
    lw   t1, 4(s0)
    andi t1, t1, 0x2
    beqz t1, putc
    sw   a0, 0(s0)
    ret

# puthex32(a1): print the low 32 bits of a1 as 8 hex chars, MSB first.  Saves ra
# in s1 (no stack).  Clobbers a0, a1, t2, t6.
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
