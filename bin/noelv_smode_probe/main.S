.section .text
.global _start

# S-mode PMP-X probe (sim-only diagnosis).
#
# HYPOTHESIS: in RTL simulation the 15 unprogrammed PMP entries power up X
# (NVC even warns pmpaddr metavalues), and the X poisons the NOEL-V's S-mode
# access check -- so an S-mode fetch of the shim at 0x240000 faults (mcause=1)
# even though entry0 grants NAPOT RWX.  On HW the FFs reset to 0 (A=OFF,
# harmless), which is why the same handoff WORKS on hardware (rung 2) while
# zircon_full_boot trap-looped at the sbi_hart_switch_mode mret (2026-07-04,
# saved mepc=0x240000 mcause=1).  This would also retract the earlier
# "this core won't grant S-mode execute of DDR3" stub-diagnosis conclusion.
#
# TEST: zero ALL pmpcfg/pmpaddr CSRs first, program entry0 NAPOT [0,4G) RWX
# (unlocked -- plus mseccfg=0 so standard PMP S/U semantics), then `mret` into
# the shim in S-MODE with the real DTB (a1=0x5c000, zircon SIM firmware).
#   - Shim executes (0x24xxxx line fills, no fault) => X-poisoning CONFIRMED;
#     fix the OpenSBI boot stub (//bin/noelv_sim_boot) to zero PMP the same way
#     and relaunch zircon_full_boot.
#   - Still mcause=1 spin (s0=1 s1=0x240000, 0xdead marker) => real S-mode
#     denial in the core/PMP RTL; dig in the iunv/PMP instead.

#define SHIM   0x240000
#define DTB    0x5c000
#define MTIME  0xe000bff8
#define RDTIME 0xc0102673

_start:
    nop
    /* --- zero the ENTIRE PMP state (kill the sim-X) --- */
    csrw 0x3a0, zero          /* pmpcfg0 */
    csrw 0x3a2, zero          /* pmpcfg2 */
    csrw 0x3b0, zero
    csrw 0x3b1, zero
    csrw 0x3b2, zero
    csrw 0x3b3, zero
    csrw 0x3b4, zero
    csrw 0x3b5, zero
    csrw 0x3b6, zero
    csrw 0x3b7, zero
    csrw 0x3b8, zero
    csrw 0x3b9, zero
    csrw 0x3ba, zero
    csrw 0x3bb, zero
    csrw 0x3bc, zero
    csrw 0x3bd, zero
    csrw 0x3be, zero
    csrw 0x3bf, zero          /* pmpaddr0..15 */
    csrw mseccfg, zero        /* 0x747: standard PMP semantics */
    /* v2: the PMP zeroing alone did NOT fix the S-mode fetch fault (still
       mcause=1 @0x240000) and the VCD shows no X in any dumped leaf of the
       fetch path -- the remaining suspects are the UNDUMPABLE CSR records.
       Zero the translation state too: satp (reset-X = garbage xlate mode). */
    csrw satp, zero           /* 0x180 */
    /* v3: satp did not fix it either.  Zero the HYPERVISOR translation state
       (this core config has H; the failed run even bounced through
       _trap_handler_hyp).  If H is absent these csrw's trap illegal ->
       real_fault latches mcause=2, which is its own answer. */
    csrw 0x600, zero          /* hstatus  */
    csrw 0x680, zero          /* hgatp    */
    csrw 0x280, zero          /* vsatp    */
    csrw 0x200, zero          /* vsstatus */

    li   t0, -1
    csrw mcounteren, t0       /* 0x306 */
    li   t0, 0xf4b509
    csrw medeleg, t0          /* 0x302 */
    li   t0, 0x222
    csrw mideleg, t0          /* 0x303 */

    /* entry0: NAPOT [0,4GiB) RWX, UNLOCKED (what OpenSBI's S/U catch-all is) */
    li   t0, 0x1fffffff
    csrw pmpaddr0, t0         /* 0x3b0 */
    li   t0, 0x1f             /* A=NAPOT (3<<3) | X | W | R, L=0 */
    csrw pmpcfg0, t0          /* 0x3a0 */

    la   t0, m_trap
    csrw mtvec, t0            /* 0x305 */
    li   t0, SHIM
    csrw mepc, t0             /* 0x341 */
    li   t0, 0x800            /* mstatus.MPP = 01 (S-mode) */
    csrw mstatus, t0          /* 0x300 */
    li   a0, 0                /* hartid */
    li   a1, DTB              /* the ZBI-aware devicetree */
    mret                      /* S-MODE entry -- the point of this probe */

    .align 4
m_trap:
    csrr t1, mcause           /* 0x342 */
    li   t2, 2                /* illegal instruction (rdtime emulation) */
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
    li   s3, 0xdead           /* marker for grep */
spin:
    j    spin
