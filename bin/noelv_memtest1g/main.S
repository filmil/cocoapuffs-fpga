.section .text
.global _start

# Full-1GB DDR3 aliasing + read/write test for the NOEL-V a200t board.
#
# Linked at 0x40000 so the SERV ihex loader + boot stub jump here directly
# (no OpenSBI).  Caches are DISABLED at entry so every load/store goes through
# the AHB->WB->DDR3 adapter: the historical aliasing (the wide-WB adapter
# dropping byte-address bits 29:27, aliasing the 1GB window every 128MB) lives
# BELOW the L1 cache, so a cached read would mask it.
#
# Two phases, all on the APBUART @0xFF900000 (scaler 42 = 115200 @ 40 MHz):
#   BANKS: write a distinct value (0xCAFE0000+i) to +0x100000 in each of the 8
#          128MB banks (0, 128M, ... 896M), then read all 8 back.  If any two
#          banks alias, a later write clobbers an earlier bank -> mismatch.
#          This is the direct test of address bits 29:27.
#   MARCH: write value=addr to every 8MB from 0x100000 to 1GB, then read+verify
#          all 128 points -- broad coverage that the whole 1GB stores distinctly.
# Emits "ALL OK ..." on success, or "BANK BAD .." / "MARCH BAD .." with the
# offending address / value.  Stack-free; uses saved regs s1..s9, s11 for helper
# return address (helpers touch only a0,a1,t0-t6,s11 and read s0=UART base).

#define UART_SCALER 42

_start:
    csrw 0x7C1, zero                 # disable I$ + D$ (test raw DDR3)

    li   t0, 0xff9
    slli t0, t0, 20                  # APBUART base 0xFF900000
    li   t1, UART_SCALER
    sw   t1, 12(t0)                  # scaler
    li   t1, 0x3
    sw   t1, 8(t0)                   # control: RE | TE
    mv   s0, t0                      # s0 = UART base (helpers read it)

    la   a1, m_hdr
    jal  ra, puts

    # ---------- BANK aliasing test (8 x 128MB = 1GB) ----------
    li   s3, 0x100000                # per-bank test offset (above the program)
    # write all 8 banks
    li   s1, 0
1:  slli s9, s1, 27                  # bank base = i * 0x08000000
    add  s9, s9, s3                  # addr = base + off
    li   t1, 0x5AFE0000              # bit 31 clear so lw read-back doesn't sign-extend
    add  t1, t1, s1                  # val_i = 0x5AFE0000 + i
    sw   t1, 0(s9)
    addi s1, s1, 1
    li   t3, 8
    blt  s1, t3, 1b
    # read all 8 back and verify each still holds its own value
    li   s1, 0
2:  slli s9, s1, 27
    add  s9, s9, s3
    lw   s6, 0(s9)                   # got
    li   s8, 0x5AFE0000
    add  s8, s8, s1                  # expected
    bne  s6, s8, bank_bad
    addi s1, s1, 1
    li   t3, 8
    blt  s1, t3, 2b
    la   a1, m_banks_ok
    jal  ra, puts

    # ---------- MARCH the full 1GB ----------
    li   s4, 0x40000000              # 1GB limit
    li   s5, 0x800000                # 8MB stride -> 128 points
    li   s1, 0x100000
3:  sw   s1, 0(s1)                   # store low32(addr) at addr
    add  s1, s1, s5
    blt  s1, s4, 3b
    li   s1, 0x100000
    li   s2, 0                       # count of verified points
4:  lw   s6, 0(s1)                   # got
    bne  s6, s1, march_bad
    addi s2, s2, 1
    add  s1, s1, s5
    blt  s1, s4, 4b
    la   a1, m_march_ok
    jal  ra, puts
    mv   a1, s2
    jal  ra, puthex32                # print n (count)
    li   a0, 13; jal ra, putc
    li   a0, 10; jal ra, putc
    la   a1, m_all_ok
    jal  ra, puts
5:  j    5b

bank_bad:                            # s1=i, s6=got, s8=expected
    mv   s7, s6
    la   a1, m_bank_bad; jal ra, puts
    mv   a0, s1; addi a0, a0, '0'; jal ra, putc
    la   a1, m_got; jal ra, puts
    mv   a1, s7; jal ra, puthex32
    la   a1, m_exp; jal ra, puts
    mv   a1, s8; jal ra, puthex32
    li   a0, 13; jal ra, putc
    li   a0, 10; jal ra, putc
6:  j    6b

march_bad:                           # s1=addr, s6=got
    mv   s7, s6
    mv   s8, s1
    la   a1, m_march_bad; jal ra, puts
    mv   a1, s8; jal ra, puthex32
    la   a1, m_got; jal ra, puts
    mv   a1, s7; jal ra, puthex32
    li   a0, 13; jal ra, putc
    li   a0, 10; jal ra, putc
7:  j    7b

# ---- helpers: touch only a0,a1,t0-t6,s11; read s0; never touch s1..s9 ----
putc:
    lw   t1, 4(s0)
    andi t1, t1, 0x2                 # status bit1 = TX shift empty
    beqz t1, putc
    sw   a0, 0(s0)
    ret

puts:                                # a1 = asciz ptr
    mv   s11, ra
pt: lb   a0, 0(a1)
    beqz a0, pt_done
    jal  ra, putc
    addi a1, a1, 1
    j    pt
pt_done:
    mv   ra, s11
    ret

puthex32:                            # a1 = value; prints 8 hex chars MSB-first
    mv   s11, ra
    li   t2, 8
ph: srli a0, a1, 28
    andi a0, a0, 0xf
    li   t6, 10
    blt  a0, t6, ph_d
    addi a0, a0, 'a' - 10
    j    ph_e
ph_d:
    addi a0, a0, '0'
ph_e:
    jal  ra, putc
    slli a1, a1, 4
    addi t2, t2, -1
    bnez t2, ph
    mv   ra, s11
    ret

.section .rodata
m_hdr:       .asciz "DDR3 1GB TEST (caches off)\r\n"
m_banks_ok:  .asciz "BANKS OK: 8x128MB distinct (no 29:27 aliasing)\r\n"
m_march_ok:  .asciz "MARCH OK n="
m_all_ok:    .asciz "ALL OK -- full 1GB addressable, no aliasing\r\n"
m_bank_bad:  .asciz "BANK BAD i="
m_march_bad: .asciz "MARCH BAD @"
m_got:       .asciz " got="
m_exp:       .asciz " exp="
