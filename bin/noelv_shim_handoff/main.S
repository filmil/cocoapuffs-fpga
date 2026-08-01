.section .text
.global _start

# Minimal M-mode handoff stub for the Fuchsia boot-shim DIAGNOSIS simulation.
#
# The full OpenSBI boot is far too FDT/UART-heavy to simulate all the way to the
# S-mode handoff (tens-to-hundreds of ms of sim time).  So instead of booting
# OpenSBI, this stub reproduces *exactly the S-mode environment OpenSBI hands off
# with* and `mret`s straight into the shim entry at 0x240000.  The shim then runs
# in ~microseconds and hits its fault, which we capture offline.
#
# Reuses the opensbi_fw_lowram_mem image (the shim is already linked at 0x240000
# inside it); only the boot-BRAM stub differs from the OpenSBI bring-up sim.
#
# Handoff state (matches OpenSBI / the RISC-V SBI boot protocol):
#   mcounteren = all-ones  -> S-mode may read time/cycle/instret (rdtime)
#   medeleg    = 0xf4b509   -> matches the HW value from log42 (does NOT delegate
#                             access faults bits 1/5/7 -> they come to M, which is
#                             why the real fault is visible here)
#   mideleg    = 0x222
#   mstatus.MPP = S, mepc = 0x240000, a0 = hartid = 0, a1 = 0 (dtb; the shim
#   stashes a1 and does not parse it during the early setup where it faults).
#
# The shim's opening instruction is `rdtime a2` (csrr a2, time = 0xc0102673).  If
# this core does not implement the S-mode time CSR it traps illegal-instruction
# (medeleg bit 2 clear -> comes to M); m_trap emulates it from the CLINT mtime,
# exactly as OpenSBI's illegal-insn handler would, so the shim proceeds.
#
# Any OTHER trap is the shim's REAL fault: m_trap latches mcause/mepc/mtval into
# s0/s1/s2 (the disas trace prints W[s0=..]/W[s1=..]/W[s2=..]) and spins, so the
# first fault's cause + faulting PC + address are captured directly.

#define SHIM   0x240000
#define MTIME  0xe000bff8     /* NOEL-V CLINT mtime */
#define RDTIME 0xc0102673     /* csrr a2, time */

_start:
    nop
    li   t0, -1
    csrw mcounteren, t0       /* 0x306 */
    li   t0, 0xf4b509
    csrw medeleg, t0          /* 0x302 */
    li   t0, 0x222
    csrw mideleg, t0          /* 0x303 */
    /* Clear mseccfg (Smepmp): if the core resets MML=1, an L=0 RWX pmp entry is
       reinterpreted under MML rules and won't grant S-mode execute -- the likely
       reason the S-mode fetch at 0x240000 faulted.  MML=0 = standard PMP. */
    csrw mseccfg, zero        /* 0x747 */
    /* PMP entry 0: NAPOT over all of memory, R|W|X -- OpenSBI sets this up from
       its catch-all S/U domain region.  Without ANY pmp entry, S/U mode is denied
       all access by default, so the very first S-mode fetch at 0x240000 faults. */
    li   t0, 0x1fffffff       /* NAPOT [0,4GiB): fits the core's 30-bit pmpaddr.
                                 all-ones encodes size 2^33 > pmp space -> no match */
    csrw pmpaddr0, t0         /* 0x3b0 */
    li   t0, 0x9f             /* L | A=NAPOT (3<<3) | X | W | R  (locked: applies to
                                 all modes incl S, sidesteps the unlocked->S grant) */
    csrw pmpcfg0, t0          /* 0x3a0 */
    la   t0, m_trap
    csrw mtvec, t0            /* 0x305 */
    li   t0, SHIM
    csrw mepc, t0             /* 0x341 */
    li   t0, 0x800            /* MPP = 01 (S-mode) */
    csrw mstatus, t0          /* 0x300 */
    li   a0, 0                /* hartid */
    li   a1, 0                /* dtb (dummy) */
    /* Enter the shim in M-mode: M bypasses PMP, so the shim's privilege-independent
       early setup runs and proves the code is healthy (~1900 insns to ~0x26e0xx, no
       fault).  An S-mode handoff (`mret`) instead faults instruction-access at
       0x240000 -- this core won't grant S-mode execute of DDR3 via a minimal
       PMP/mseccfg setup (none of: unlocked/locked NAPOT, mseccfg clear helped).
       See doc/fuchsia-shim-diagnosis.md.  To re-test S-mode, swap `jr` for `mret`. */
    li   t0, SHIM
    jr   t0

    .align 4
m_trap:
    csrr t1, mcause           /* 0x342 */
    li   t2, 2                /* illegal instruction */
    bne  t1, t2, real_fault
    csrr t3, mepc             /* 0x341 */
    lwu  t4, 0(t3)
    li   t5, RDTIME
    bne  t4, t5, real_fault
    /* emulate rdtime: a2 = CLINT mtime, advance past the 4-byte insn */
    li   t6, MTIME
    ld   a2, 0(t6)
    addi t3, t3, 4
    csrw mepc, t3
    mret

real_fault:
    csrr s0, mcause           /* the shim's real fault cause */
    csrr s1, mepc             /* the faulting PC inside the shim */
    csrr s2, mtval            /* the faulting address / value */
    li   s3, 0xdead           /* marker for grep */
spin:
    j    spin
