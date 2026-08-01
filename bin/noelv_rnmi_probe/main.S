.section .text
.global _start

# RNMI trap-handler probe for the NOEL-V Smrnmi/Smdbltrp wedge diagnosis.
#
# This core (GP cfg, noelv_cpu_cfg.vhd) hardwires the RNMI trap vectors to
#   PC_RNMI_ITRAP = 0x30010000   (RNMI interrupt handler)
#   PC_RNMI_XTRAP = 0x30011000   (RNMI exception / double-trap handler)
# both inside DDR3.  With mnstatus.NMIE=1 the full Zircon boot wedges silently
# at the kernel entry; the hypothesis is a double-trap in OpenSBI's M-trap path
# (mstatus.MDT set) vectoring to PC_RNMI_XTRAP where nothing lives.  This blob
# plants printing handlers at BOTH vectors: each prints a marker + mncause +
# mnepc (+ mepc) over the APBUART (already initialized by OpenSBI) and parks.
# If the marker appears during the wedge, the mechanism is confirmed and mnepc
# names the faulting instruction inside OpenSBI.
#
# Linked at 0x30010000; the XTRAP handler is placed at +0x1000 with .org.
# M-mode, no stack, polled UART @0xFF900000 (drain after each char).
# Smrnmi CSRs: mnscratch=0x740 mnepc=0x741 mncause=0x742 mnstatus=0x744.

_start:
rnmi_itrap:
    li   s0, 0xFF9
    slli s0, s0, 20                 # UART base
    li   a0, 'R';  jal ra, putc
    li   a0, 'N';  jal ra, putc
    li   a0, 'I';  jal ra, putc     # "RNI" = RNMI Interrupt handler hit
    j    dump

    .org 0x1000                     # -> 0x30011000 = PC_RNMI_XTRAP
rnmi_xtrap:
    li   s0, 0xFF9
    slli s0, s0, 20                 # UART base
    li   a0, 'R';  jal ra, putc
    li   a0, 'N';  jal ra, putc
    li   a0, 'X';  jal ra, putc     # "RNX" = RNMI eXception (double-trap) hit
dump:
    li   a0, ' ';  jal ra, putc
    li   a0, 'c';  jal ra, putc
    li   a0, '=';  jal ra, putc
    csrr a1, 0x742                 # mncause
    jal  ra, puthex64
    li   a0, ' ';  jal ra, putc
    li   a0, 'e';  jal ra, putc
    li   a0, '=';  jal ra, putc
    csrr a1, 0x741                 # mnepc
    jal  ra, puthex64
    li   a0, ' ';  jal ra, putc
    li   a0, 'm';  jal ra, putc
    li   a0, '=';  jal ra, putc
    csrr a1, mepc                  # last regular M trap pc, for context
    jal  ra, puthex64
    li   a0, 13;   jal ra, putc
    li   a0, 10;   jal ra, putc
park:
    j    park

# putc(a0): poll TX-empty, write, wait for drain.  Leaf; uses s0, t1.
putc:
    lw   t1, 4(s0)
    andi t1, t1, 0x2
    beqz t1, putc
    sw   a0, 0(s0)
pc1:
    lw   t1, 4(s0)
    andi t1, t1, 0x2
    beqz t1, pc1
    ret

# puthex64(a1): 16 hex chars, MSB first.  Saves ra in s9.  Clobbers a0,t1,t2,t6.
puthex64:
    mv   s9, ra
    li   t2, 16
ph_loop:
    srli a0, a1, 60
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
