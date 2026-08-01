.section .text
.global _start

# Standalone RV64 CLINT (core-local interruptor) test for the NOEL-V board.
#
# Diagnosis context: OpenSBI now boots fully (banner + boot info) but wedges at
# the S-mode handoff in sbi_hsm_hart_start_finish's atomic_cmpxchg (lr.d/sc.d on
# the hart state @ scratch+0x90).  A single-hart cmpxchg only loops forever if a
# recurring trap keeps invalidating the lr/sc reservation -- almost certainly a
# continuously-firing M-timer interrupt because the CLINT mtime/mtimecmp isn't
# behaving.  This isolates that: it checks the NOEL-V ACLINT @0xE0000000.
#
# Classic CLINT register layout (per board.dts): msip @ +0x0, mtimecmp @ +0x4000,
# mtime @ +0xBFF8.  Two checks:
#   1. mtime must increment over a busy-wait (a stuck/dead mtime -> garbage timer).
#   2. mtimecmp must be writable (read back what we wrote; OpenSBI sets it to
#      "far future" to quiet the timer -- if the write is dropped, MTIP stays
#      pending and the timer fires forever).
# Prints "CLINT OK" or "CLINT BAD <case> <got-lo32> <expected-lo32>" on the
# APBUART @0xFF900000 (scaler 42 = 115200 @ 40 MHz; poll status bit1 = TX empty).
#
# Linked at 0x40000 so the SERV ihex loader + boot stub run it directly (no
# OpenSBI).  No stack.

#define UART_SCALER 42

_start:
    nop
    li   t0, 0xff9
    slli t0, t0, 20                  # APBUART base 0xFF900000
    li   t1, UART_SCALER
    sw   t1, 12(t0)                  # scaler
    li   t1, 0x3
    sw   t1, 8(t0)                   # control: RE | TE
    mv   s0, t0                      # s0 = UART base (kept for putc)

    # CLINT base 0xE0000000 (zero-extended)
    li   s1, 0xe00
    slli s1, s1, 20                  # s1 = 0x00000000E0000000

    # ---- Case 1: mtime (@ +0xBFF8) must increment ----
    li   t1, 0xBFF8
    add  t1, s1, t1                  # t1 = &mtime = 0xE000BFF8
    ld   s2, 0(t1)                   # s2 = mtime sample 1
    li   t2, 0x40000                 # busy-wait ~ a few ms @ 40 MHz
1:  addi t2, t2, -1
    bnez t2, 1b
    ld   s3, 0(t1)                   # s3 = mtime sample 2
    bgeu s2, s3, fail_mtime          # sample1 >= sample2 -> mtime not advancing

    # ---- Case 2: mtimecmp (@ +0x4000) must be writable ----
    li   t1, 0x4000
    add  t1, s1, t1                  # t1 = &mtimecmp = 0xE0004000
    li   s4, 0x0123456789ABCDEF
    sd   s4, 0(t1)                   # write 64-bit mtimecmp
    ld   s5, 0(t1)                   # read it back
    bne  s4, s5, fail_cmp

    # ---- both pass: "CLINT OK\r\n" ----
    li   a0, 'C'; jal ra, putc
    li   a0, 'L'; jal ra, putc
    li   a0, 'I'; jal ra, putc
    li   a0, 'N'; jal ra, putc
    li   a0, 'T'; jal ra, putc
    li   a0, ' '; jal ra, putc
    li   a0, 'O'; jal ra, putc
    li   a0, 'K'; jal ra, putc
    li   a0, 13;  jal ra, putc
    li   a0, 10;  jal ra, putc
9:  j    9b

fail_mtime:
    li   s6, 1
    mv   s7, s3                      # got     = mtime sample 2 (low 32 shown)
    mv   s8, s2                      # expected-ish = sample 1 (should be < got)
    j    fail
fail_cmp:
    li   s6, 2
    mv   s7, s5                      # got      = mtimecmp read-back
    li   s8, 0x89ABCDEF             # expected = low 32 of what we wrote
    j    fail

fail:
    # "CLINT BAD <case> <got> <expected>\r\n"  (s6=case, s7=got, s8=expected)
    li   a0, 'C'; jal ra, putc
    li   a0, 'L'; jal ra, putc
    li   a0, 'I'; jal ra, putc
    li   a0, 'N'; jal ra, putc
    li   a0, 'T'; jal ra, putc
    li   a0, ' '; jal ra, putc
    li   a0, 'B'; jal ra, putc
    li   a0, 'A'; jal ra, putc
    li   a0, 'D'; jal ra, putc
    li   a0, ' '; jal ra, putc
    mv   a1, s6;  jal ra, puthex32
    li   a0, ' '; jal ra, putc
    mv   a1, s7;  jal ra, puthex32
    li   a0, ' '; jal ra, putc
    mv   a1, s8;  jal ra, puthex32
    li   a0, 13;  jal ra, putc
    li   a0, 10;  jal ra, putc
8:  j    8b

# putc(a0): poll status bit1 (TX shift empty), write the byte.  Leaf; uses s0.
putc:
    lw   t1, 4(s0)
    andi t1, t1, 0x2
    beqz t1, putc
    sw   a0, 0(s0)
    ret

# puthex32(a1): print the low 32 bits of a1 as 8 hex chars, MSB first.  Saves ra
# in s9 (no stack).  Clobbers a0, a1, t2, t6.
puthex32:
    mv   s9, ra
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
    mv   ra, s9
    ret
