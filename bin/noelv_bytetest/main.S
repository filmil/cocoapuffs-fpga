.section .text
.global _start

# Standalone RV64 *byte-write* (sub-word store) test for DDR3 on the NOEL-V board.
#
# Diagnosis context: OpenSBI builds its domain memory-regions correctly (verified
# on HW via 64-bit `sd` stores), but the regions get ZEROED the moment
# sanitize_domain sorts them -- and the sort's only memory op is swap_region ->
# sbi_memcpy, which is byte-by-byte (`char*` => `sb`/`lb`).  memtest (sw, 32-bit)
# and atomictest (sd/AMO, 64-bit) both PASS, so aligned word/dword access is fine.
# The one access width never exercised is the BYTE store.  This test isolates it.
#
# Three cases, all in DDR3 at 0x80000+:
#   1. sb of one byte into a known word -- only that byte must change.
#   2. sb to all four byte lanes of a word -- must assemble the whole word.
#   3. byte-by-byte copy (an sbi_memcpy emulation) of 8 bytes -- must match source.
# Prints "BYTE OK" or "BYTE BAD <case> <got> <expected>" on the APBUART
# @0xFF900000 (scaler 42 = 115200 @ 40 MHz; poll status bit1 = TX shift empty).
#
# Linked at 0x40000 so the SERV ihex loader + boot stub run it directly.  Uses no
# stack.  Word reads (lw) are known-good, so a mismatch isolates the byte write.

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

    li   s1, 0x80000                 # DDR3 scratch base

    # ---- Case 1: single sb must change only its own byte ----
    li   t0, 0x44332211
    sw   t0, 0(s1)                   # word = 0x44332211 (via sw, known-good)
    li   t0, 0xAA
    sb   t0, 0(s1)                   # overwrite byte 0 only
    lw   t5, 0(s1)                   # read whole word back
    li   t6, 0x443322AA              # expected: only byte 0 -> 0xAA
    bne  t5, t6, fail1

    # ---- Case 2: four sb into a zeroed word must assemble it ----
    sw   zero, 8(s1)                 # word = 0
    li   t0, 0x11; sb t0, 8(s1)
    li   t0, 0x22; sb t0, 9(s1)
    li   t0, 0x33; sb t0, 10(s1)
    li   t0, 0x44; sb t0, 11(s1)
    lw   t5, 8(s1)
    li   t6, 0x44332211
    bne  t5, t6, fail2

    # ---- Case 3: byte-by-byte copy (sbi_memcpy emulation), 8 bytes ----
    li   t0, 0x55667788
    sw   t0, 16(s1)                  # source word 0 (via sw)
    li   t0, 0x99aabbcc
    sw   t0, 20(s1)                  # source word 1
    addi t1, s1, 16                  # src  = 0x80010
    addi t2, s1, 32                  # dst  = 0x80020
    li   t3, 8                       # count
3:  lb   t4, 0(t1)                   # *dst++ = *src++  (byte-wise)
    sb   t4, 0(t2)
    addi t1, t1, 1
    addi t2, t2, 1
    addi t3, t3, -1
    bnez t3, 3b
    lw   t5, 32(s1)                  # verify dst word 0
    li   t6, 0x55667788
    bne  t5, t6, fail3
    lw   t5, 36(s1)                  # verify dst word 1
    li   t6, 0x99aabbcc
    bne  t5, t6, fail3

    # ---- all byte writes behaved: "BYTE OK\r\n" ----
    li   a0, 'B'; jal ra, putc
    li   a0, 'Y'; jal ra, putc
    li   a0, 'T'; jal ra, putc
    li   a0, 'E'; jal ra, putc
    li   a0, ' '; jal ra, putc
    li   a0, 'O'; jal ra, putc
    li   a0, 'K'; jal ra, putc
    li   a0, 13;  jal ra, putc
    li   a0, 10;  jal ra, putc
9:  j    9b

fail1:
    li   s2, 1
    mv   s3, t5
    li   s4, 0x443322AA
    j    fail
fail2:
    li   s2, 2
    mv   s3, t5
    li   s4, 0x44332211
    j    fail
fail3:
    li   s2, 3
    mv   s3, t5
    mv   s4, t6
    j    fail

fail:
    # "BYTE BAD <case> <got> <expected>\r\n"  (s2=case, s3=got, s4=expected)
    li   a0, 'B'; jal ra, putc
    li   a0, 'Y'; jal ra, putc
    li   a0, 'T'; jal ra, putc
    li   a0, 'E'; jal ra, putc
    li   a0, ' '; jal ra, putc
    li   a0, 'B'; jal ra, putc
    li   a0, 'A'; jal ra, putc
    li   a0, 'D'; jal ra, putc
    li   a0, ' '; jal ra, putc
    mv   a1, s2;  jal ra, puthex32
    li   a0, ' '; jal ra, putc
    mv   a1, s3;  jal ra, puthex32
    li   a0, ' '; jal ra, putc
    mv   a1, s4;  jal ra, puthex32
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
# in s5 (no stack).  Clobbers a0, a1, t2, t6.
puthex32:
    mv   s5, ra
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
    mv   ra, s5
    ret
