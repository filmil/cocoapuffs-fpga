.section .text
.global _start

# Minimal M-mode handoff stub for the ZIRCON boot simulation (rung 3): jump
# straight into the riscv64-boot-shim inside the opensbi_fw_zircon image with a
# REAL device tree, bypassing the full OpenSBI boot (whose post-banner fdt scan
# wedges under xsim -- see the 2026-07-02 opensbi_trace_zircon_zbi run).
#
# Differs from ../noelv_shim_handoff (the fault-DIAGNOSIS stub) in one way:
#   a1 = 0x5c000 = fw_fdt_bin, the ZBI-aware board_zircon.dtb embedded in the
#   opensbi_fw_zircon image (chosen/linux,initrd-{start,end} -> the ZBI at
#   0x10000000, served by the tb's zbi bank).  OpenSBI would normally relocate
#   this DTB to 0x2240000 and pass THAT; passing the .rodata original is
#   equivalent for the shim (it only reads it).  No OpenSBI also means the DTB
#   carries no OpenSBI memreserve -- fine in sim, nothing to protect.
#
# Handoff state matches OpenSBI's S-mode handoff (mcounteren/medeleg/mideleg/
# PMP), the rdtime trap emulation included; entry stays M-mode (`jr`) since an
# S-mode mret faults instruction-access on this core via a minimal PMP setup
# (see doc/fuchsia-shim-diagnosis.md).  M-mode carries the shim + physboot's
# PHYSICAL phase; a real fault latches mcause/mepc/mtval -> s0/s1/s2 and spins.

#define SHIM   0x240000
#define DTB    0x5c000       /* fw_fdt_bin: board_zircon.dtb inside the image */
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
    csrw mseccfg, zero        /* 0x747: MML=0 = standard PMP */
    li   t0, 0x1fffffff       /* NAPOT [0,4GiB) */
    csrw pmpaddr0, t0         /* 0x3b0 */
    li   t0, 0x9f             /* L | A=NAPOT | X | W | R */
    csrw pmpcfg0, t0          /* 0x3a0 */
    la   t0, m_trap
    csrw mtvec, t0            /* 0x305 */
    li   t0, SHIM
    csrw mepc, t0             /* 0x341 */
    li   t0, 0x800            /* MPP = 01 (S-mode), for a future mret re-test */
    csrw mstatus, t0          /* 0x300 */
    li   a0, 0                /* hartid */
    li   a1, DTB              /* the ZBI-aware devicetree */
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
    csrr s0, mcause           /* the real fault cause */
    csrr s1, mepc             /* the faulting PC */
    csrr s2, mtval            /* the faulting address / value */
    li   s3, 0xdead           /* marker for grep */
spin:
    j    spin
