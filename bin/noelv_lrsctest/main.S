.section .text
.global _start

# Standalone RV64 LR/SC (load-reserved / store-conditional) test on DDR3.
#
# Diagnosis context: OpenSBI now boots fully but wedges at the S-mode handoff in
# sbi_hsm_hart_start_finish's atomic_cmpxchg -- the ONLY lr.d/sc.d in the whole
# firmware (its spinlocks use amoadd, which works).  The CLINT is fine, so the
# cmpxchg isn't looping on a trap; sc.d itself must keep failing.  Hypothesis:
# LR/SC reservations are not maintained for uncached DDR3 (mmu-type=none, caches
# disabled) because the AHB->DDR3 path has no exclusive-access monitor.
#
# This isolates it: it runs lr.d/sc.d on 0x80000 (DDR3) with no intervening
# memory ops (a constrained sequence that MUST eventually succeed per spec) and
# counts how many of N attempts the sc.d reports success.  AMO (amoswap.d) is
# tested too as a control -- it should always work.
#   "LRSC OK <successes>"   sc.d succeeds          -> reservations work
#   "LRSC BAD 00000000 ..." sc.d never succeeds    -> LR/SC broken on DDR3
# APBUART @0xFF900000 (scaler 42 = 115200 @ 40 MHz; poll status bit1 = TX empty).
# Linked at 0x40000 (SERV ihex loader + boot stub run it directly; no OpenSBI).

#define UART_SCALER 42
#define N_TRIES     1000

_start:
    nop
    li   t0, 0xff9
    slli t0, t0, 20                  # APBUART base 0xFF900000
    li   t1, UART_SCALER
    sw   t1, 12(t0)                  # scaler
    li   t1, 0x3
    sw   t1, 8(t0)                   # control: RE | TE
    mv   s0, t0                      # s0 = UART base (kept for putc)

    # ---- A/B: the same lr.d/sc.d loop against two slaves ----
    # A) DDR3 0x80000 (cacheable region, SLOW slave: ahb2wb -> wide_wb ->
    #    UberDDR3, many-cycle writes).  On HW this historically fails 0/1000.
    # B) boot BRAM 0xC0000800 (UNCACHED region -- outside the 0x000F mask --
    #    but a FAST 1-cycle AHB slave, like the sim's ahb_bram where sc.d
    #    passes).  If B succeeds while A fails, the reservation is killed by
    #    the slow store path, not by the core.
    li   s1, 0x80000                 # A: DDR3 scratch word
    jal  s10, lrsc_loop
    mv   s4, s2                      # s4 = DDR3 successes

    # Publish the count for JTAG readback, then PARK QUIETLY (wfi, no bus
    # traffic) so the AHB recorder's 8192-record sliding window retains the
    # lr/sc phase when the SERV auto-dump fires ~30 s later.  (The old leg B
    # -- lr.d to the uncached boot BRAM -- FAULTS: uncached LR raises an
    # access fault on this core, trap-to-0 spin.  Removed.)
    li   s5, 0x80008
    sd   s4, 0(s5)                   # 0x80008 = leg-A success count
park:
    wfi
    j    park

    li   s1, 0x80000                 # AMO control runs on DDR3 as before

    # ---- AMO control: amoswap.d must work (proven by atomictest) ----
    li   t4, 0x1234
    amoswap.d t5, t4, (s1)           # swap; t5 = old, mem = 0x1234
    ld   t6, 0(s1)
    li   a2, 0x1234
    bne  t6, a2, fail_amo            # AMO broken (unexpected) -> report

    # "LRSC D=<ddr3 successes> B=<bram successes> N=<tries>\r\n"
    li   a0, 'L'; jal ra, putc
    li   a0, 'R'; jal ra, putc
    li   a0, 'S'; jal ra, putc
    li   a0, 'C'; jal ra, putc
    li   a0, ' '; jal ra, putc
    li   a0, 'D'; jal ra, putc
    li   a0, '='; jal ra, putc
    mv   a1, s4;  jal ra, puthex32
    li   a0, ' '; jal ra, putc
    li   a0, 'B'; jal ra, putc
    li   a0, '='; jal ra, putc
    mv   a1, s5;  jal ra, puthex32
    li   a0, ' '; jal ra, putc
    li   a0, 'N'; jal ra, putc
    li   a0, '='; jal ra, putc
    li   a1, N_TRIES; jal ra, puthex32
    li   a0, 13;  jal ra, putc
    li   a0, 10;  jal ra, putc
9:  j    9b

# lrsc_loop: N_TRIES lr.d/sc.d increments on (s1); s2 = success count.
# Returns via s10.  Clobbers t1-t3, s2, s3.
lrsc_loop:
    sd   zero, 0(s1)
    li   s2, 0                       # success count
    li   s3, N_TRIES                 # remaining attempts
1:
    lr.d t1, (s1)                    # reserve
    addi t2, t1, 1                   # new value = old + 1 (no memory access)
    sc.d t3, t2, (s1)                # t3 = 0 on success, 1 on failure
    bnez t3, 2f                      # sc failed -> skip count
    addi s2, s2, 1                   # sc succeeded
2:
    addi s3, s3, -1
    bnez s3, 1b
    jr   s10

fail_amo:
    li   a0, 'A'; jal ra, putc
    li   a0, 'M'; jal ra, putc
    li   a0, 'O'; jal ra, putc
    li   a0, ' '; jal ra, putc
    li   a0, 'B'; jal ra, putc
    li   a0, 'A'; jal ra, putc
    li   a0, 'D'; jal ra, putc
    li   a0, 13;  jal ra, putc
    li   a0, 10;  jal ra, putc
7:  j    7b

# putc(a0): poll status bit1 (TX shift empty), write the byte.  Leaf; uses s0.
putc:
    lw   t1, 4(s0)
    andi t1, t1, 0x2
    beqz t1, putc
    sw   a0, 0(s0)
    ret

# puthex32(a1): low 32 bits of a1 as 8 hex chars, MSB first. Saves ra in s9.
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
