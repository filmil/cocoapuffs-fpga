.section .text
.global _start

# S-mode fault REPRO for VCD/X analysis (sim-only).
#
# Reproduces the zircon_full_boot handoff failure (2026-07-04: infinite trap
# loop, mcause=1, mepc=0x240000 after sbi_hart_switch_mode) in ~microseconds:
# program ONLY pmp entry0 (NAPOT [0,4G) RWX -- OpenSBI's S/U catch-all shape),
# leave the other 15 entries UNPROGRAMMED (in RTL sim they hold X!), and `mret`
# into the shim at 0x240000 in S-mode.  Run under the VCD-dumping sim target
# (//boards/noelv/tool.vivado:smode_fault_vcd) and inspect where X appears in
# the PMP/fetch-permission chain (pmpaddr*/pmpcfg*/pmp_precalc/pmp_match ->
# access-fault) at the fault instant.  Counterpart probe: //bin/noelv_smode_probe
# (all PMP CSRs zeroed) -- if that one RUNS while this one faults, the sim-X
# poisoning is proven end to end.
#
# m_trap: latches mcause/mepc/mtval -> s0/s1/s2 (disas W[s0..s2]) and spins so
# the fault instant is easy to find in the waveform (plus rdtime emulation so
# an implemented-CSR trap does not mask the repro).

#define SHIM   0x240000
#define DTB    0x5c000
#define MTIME  0xe000bff8
#define RDTIME 0xc0102673

_start:
    nop
    li   t0, -1
    csrw mcounteren, t0       /* 0x306 */
    li   t0, 0xf4b509
    csrw medeleg, t0          /* 0x302 */
    li   t0, 0x222
    csrw mideleg, t0          /* 0x303 */
    csrw mseccfg, zero        /* 0x747: standard PMP semantics */
    /* entry0 ONLY -- entries 1..15 stay unprogrammed (= X in RTL sim).
       CLOBBER TEST (2026-07-04): the back-to-back csrw pair loses the FIRST
       write (last-writer-wins: the 2nd csr_write builds from a stale csr_file
       when the serializing flush is X-neutralized).  Write cfg FIRST, addr
       LAST, with NOP padding between -- if pmpaddr0 survives, the clobber
       mechanism is confirmed. */
    li   t0, 0x1f             /* A=NAPOT | X | W | R, unlocked */
    csrw pmpcfg0, t0          /* 0x3a0 */
    nop
    nop
    nop
    nop
    li   t0, 0x1fffffff       /* NAPOT [0,4GiB) */
    csrw pmpaddr0, t0         /* 0x3b0 */
    nop
    nop
    nop
    nop
    csrr s4, pmpaddr0         /* READBACK: does the CSR read see the value? */
    nop
    nop
    la   t0, m_trap
    csrw mtvec, t0            /* 0x305 */
    li   t0, SHIM
    csrw mepc, t0             /* 0x341 */
    li   t0, 0x800            /* mstatus.MPP = 01 (S-mode) */
    csrw mstatus, t0          /* 0x300 */
    li   a0, 0                /* hartid */
    li   a1, DTB
    mret                      /* S-mode entry: expected to access-fault */

    .align 4
m_trap:
    csrr t1, mcause           /* 0x342 */
    li   t2, 2
    bne  t1, t2, real_fault
    csrr t3, mepc             /* 0x341 */
    lwu  t4, 0(t3)
    li   t5, RDTIME
    bne  t4, t5, real_fault
    li   t6, MTIME
    ld   a2, 0(t6)
    addi t3, t3, 4
    csrw mepc, t3
    mret

real_fault:
    csrr s0, mcause
    csrr s1, mepc
    csrr s2, mtval
    li   s3, 0xdead
spin:
    j    spin
