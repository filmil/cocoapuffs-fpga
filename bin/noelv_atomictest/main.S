.section .text
.global _start

# Standalone RV64 ATOMIC test for the NOEL-V board's DDR3 region.
#
# noelv_memtest proved plain lw/sw to 0x80000+ works.  But OpenSBI dies in
# sbi_domain_init with massive spin_lock / sbi_fifo_enqueue / atomic_xchg churn --
# and ALL of those run on RISC-V atomics (amoswap/amoadd) to 0x80000+ DDR3.  A
# common AHB->DDR3 bridge limitation is no AMO support, which would break every
# lock (the churn) while ordinary load/store still works.  This isolates that:
# it runs amoswap.w / amoswap.d / amoadd.w at 0x80000 and checks each returns the
# correct OLD value AND leaves the correct NEW value in memory.
#
# Linked at 0x40000 (SERV ihex loader + boot stub run it directly, no OpenSBI).
# No stack.  Prints "ATOMIC OK" or "ATOMIC BAD <tag>" on the APBUART, using the
# drained method (poll status bit1 = TX shift empty), which is clean on this board.

#define UART_SCALER 42
#define A 0x80000                    /* DDR3 scratch word, away from this code */

_start:
    nop
    li   t0, 0xff9
    slli t0, t0, 20                  # APBUART base
    li   t1, UART_SCALER
    sw   t1, 12(t0)
    li   t1, 0x3
    sw   t1, 8(t0)
    mv   s0, t0                      # s0 = UART base for putc

    li   s2, A                       # s2 = test address

    # ---- 1) amoswap.w: old must read back, new must land ----
    li   t1, 0x12345678
    sw   t1, 0(s2)                   # [A] = 0x12345678
    li   t2, 0x0badf00d
    amoswap.w t3, t2, (s2)           # t3 <- old [A]; [A] <- t2
    li   t4, 0x12345678
    bne  t3, t4, fail_sw_old         # old value wrong?
    lw   t5, 0(s2)
    li   t4, 0x0badf00d
    bne  t5, t4, fail_sw_new         # new value not stored?

    # ---- 2) amoadd.w: read-modify-write ----
    li   t1, 0x00000100
    sw   t1, 0(s2)                   # [A] = 0x100
    li   t2, 0x00010000
    amoadd.w t3, t2, (s2)            # t3 <- old [A]; [A] <- old + t2
    li   t4, 0x00000100
    bne  t3, t4, fail_add_old
    lw   t5, 0(s2)
    li   t4, 0x00010100
    bne  t5, t4, fail_add_new

    # ---- 3) amoswap.d: 64-bit ----
    li   t1, 0x1122334455667788
    sd   t1, 0(s2)
    li   t2, 0x00c0ffee0badcafe
    amoswap.d t3, t2, (s2)
    li   t4, 0x1122334455667788
    bne  t3, t4, fail_sd_old
    ld   t5, 0(s2)
    li   t4, 0x00c0ffee0badcafe
    bne  t5, t4, fail_sd_new

    la   a1, msg_ok
    j    puts_spin

fail_sw_old:  la a1, m_swo; j puts_spin
fail_sw_new:  la a1, m_swn; j puts_spin
fail_add_old: la a1, m_ado; j puts_spin
fail_add_new: la a1, m_adn; j puts_spin
fail_sd_old:  la a1, m_sdo; j puts_spin
fail_sd_new:  la a1, m_sdn; j puts_spin

# puts_spin: print the NUL-terminated string at a1, then spin.
puts_spin:
1:  lbu  a0, 0(a1)
    beqz a0, 2f
    jal  ra, putc
    addi a1, a1, 1
    j    1b
2:  li   a0, 13; jal ra, putc
    li   a0, 10; jal ra, putc
3:  j    3b

# putc(a0): poll TS (status bit1), write byte.  Leaf; uses s0.
putc:
    lw   t1, 4(s0)
    andi t1, t1, 0x2
    beqz t1, putc
    sw   a0, 0(s0)
    ret

.section .rodata
msg_ok: .asciz "ATOMIC OK"
m_swo:  .asciz "ATOMIC BAD amoswap.w old"
m_swn:  .asciz "ATOMIC BAD amoswap.w new"
m_ado:  .asciz "ATOMIC BAD amoadd.w old"
m_adn:  .asciz "ATOMIC BAD amoadd.w new"
m_sdo:  .asciz "ATOMIC BAD amoswap.d old"
m_sdn:  .asciz "ATOMIC BAD amoswap.d new"
