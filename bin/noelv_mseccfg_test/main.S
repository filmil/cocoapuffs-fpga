.section .text
.global _start

# mseccfg.MML probe for the NOEL-V core.
#
# OpenSBI's hart_detect_features parks the hart in sbi_hart_hang (SBI_EILL) when
# Smepmp is detected AND mseccfg.MML (CSR 0x747 bit 0) is set on entry.  The fix
# in fw_base.S is `csrw 0x747, zero`, which only works if MML is CLEARABLE.  Per
# the Smepmp spec MML is sticky (set-only until reset) -- so this probe checks,
# on the real core, whether:
#   (a) mseccfg is implemented at all (else csrr 0x747 traps, mcause=2), and
#   (b) once MML is set, `csrw 0x747, zero` actually clears it.
#
# Runs from the boot ROM (0xC0000000) in tb_noelvsys_only OR on HW.  The disas
# trace shows the CSR readbacks directly (W[s0/s1/s2=...]); it also prints
#   "I=<hex> S=<hex> C=<hex>\r\n"
# over the APBUART so the result is visible on HW too, where:
#   I = mseccfg as the core hands it to us (initial)
#   S = mseccfg after `csrs 0x747, 1` (set MML)
#   C = mseccfg after `csrw 0x747, zero` (the OpenSBI fix)
# Verdict:
#   (S bit0 == 1) and (C bit0 == 0) -> MML is clearable, the OpenSBI fix works.
#   (C bit0 == 1)                   -> MML is STICKY, the fix is a no-op (plan B).
#   S == 0 (set didn't stick) or a TRAP -> Smepmp/MML not implemented, so
#   mseccfg is NOT the cause of the OpenSBI hang.

#define UART_SCALER 30          /* ~200 kbaud at 40 MHz / 8 / (30+1) in sim */
#define MSECCFG     0x747
#define MTVEC       0x305
#define MCAUSE      0x342

_start:
    nop
    li   sp, 0x800              # small stack in the low scratch RAM

    # ---- APBUART init (base 0xFF900000, zero-extended) ----
    li   t0, 0xFF9
    slli t0, t0, 20
    li   t1, UART_SCALER
    sw   t1, 12(t0)             # scaler (0x0C)
    li   t1, 0x3
    sw   t1, 8(t0)             # control (0x08): RE | TE

    # ---- trap handler so an unimplemented-CSR illegal-instr is visible ----
    lla  t1, trap_handler
    csrw MTVEC, t1

    # ---- the probe ----
    csrr s0, MSECCFG           # s0 = initial mseccfg
    li   t2, 1
    csrs MSECCFG, t2           # set MML (bit 0)
    csrr s1, MSECCFG           # s1 = mseccfg after set
    csrw MSECCFG, zero         # clear (exactly what fw_base.S does)
    csrr s2, MSECCFG           # s2 = mseccfg after clear

    # ---- print "I=<hex> S=<hex> C=<hex>\r\n" ----
    li   a0, 'I'
    call putc
    li   a0, '='
    call putc
    mv   a0, s0
    call puthex2
    li   a0, ' '
    call putc
    li   a0, 'S'
    call putc
    li   a0, '='
    call putc
    mv   a0, s1
    call puthex2
    li   a0, ' '
    call putc
    li   a0, 'C'
    call putc
    li   a0, '='
    call putc
    mv   a0, s2
    call puthex2
    li   a0, 13
    call putc
    li   a0, 10
    call putc

spin:
    j    spin

# putc(a0): poll status bit1 (TS, TX shift-reg empty) then write the byte.  Leaf.
putc:
    li   t3, 0xFF9
    slli t3, t3, 20
1:  lw   t4, 4(t3)
    andi t4, t4, 0x2
    beqz t4, 1b
    sw   a0, 0(t3)
    ret

# puthex2(a0): print the low byte of a0 as two hex chars.
puthex2:
    addi sp, sp, -16
    sd   ra, 8(sp)
    sd   s3, 0(sp)
    mv   s3, a0
    srli a0, s3, 4
    andi a0, a0, 0xf
    call hexnib
    andi a0, s3, 0xf
    call hexnib
    ld   s3, 0(sp)
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret

# hexnib(a0): a0 in 0..15 -> ascii hex char, transmitted.
hexnib:
    addi sp, sp, -16
    sd   ra, 8(sp)
    li   t4, 10
    blt  a0, t4, 2f
    addi a0, a0, 'a' - 10
    j    3f
2:  addi a0, a0, '0'
3:  call putc
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret

    .align 2
trap_handler:
    li   a0, 'T'
    call putc
    li   a0, 'R'
    call putc
    li   a0, 'A'
    call putc
    li   a0, 'P'
    call putc
    li   a0, '='
    call putc
    csrr a0, MCAUSE
    call puthex2
    li   a0, 13
    call putc
    li   a0, 10
    call putc
4:  j    4b
