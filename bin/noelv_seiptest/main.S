.section .text
.global _start

# Core-level NVC-sim reproduction of the Zircon APBUART interrupt-console bug.
#
# The grplic RTL is proven correct in isolation (//ip/plic grplic_tb).  This
# program closes the loop through the actual NOEL-V core: does an APBUART
# interrupt (PLIC source 1, APBUART_PIRQ=1) actually reach the hart's mip.MEIP /
# mip.SEIP and cause a trap?  Runs bare-metal from the boot BRAM (reset PC
# 0xC0000000), no OpenSBI.
#
# Output is via WORD WRITES to low RAM (0x1000+), which the tb's AHB monitor
# logs as "WR 0x<addr> hwdata=0x<data>" -- far faster than the 86us/char UART.
# Each phase writes a packed result word: (trapped<<28)|(claimed_src<<8)|cause8.
#   0x1000 = 0x000B0075                  booted marker
#   0x1004 = phase A result  (M-mode CLINT timer  -> trap sanity, no PLIC)
#   0x1008 = phase B result  (M-mode PLIC ext irq -> meip -> mip.MEIP,  ctx0)
#   0x100C = phase C result  (S-mode PLIC ext irq -> seip -> mip.SEIP,  ctx1)
#   0x1010 = 0x0000C0DE                  S-mode reached marker
#   0x1014 = 0x0000D09E                  all-done marker
# Expected good result words: A=0x10000007, B=0x1000010B, C=0x10000109.
# A 0x0....... word (bit28 clear) means that phase's interrupt never arrived.
#
# Registers kept across phases:
#   s0 = APBUART base 0xFF900000   s1 = PLIC base 0xF8000000   s7 = 0x1000
#   s2 = last mcause/scause        s3 = last claimed PLIC src  s4 = trapped flag

#define UART_SCALER 1

_start:
    li   t0, 0xFF9
    slli t0, t0, 20                 # APBUART 0xFF900000
    li   t1, UART_SCALER
    sw   t1, 12(t0)                 # scaler
    li   t1, 0x3
    sw   t1, 8(t0)                  # control: RE | TE
    mv   s0, t0

    li   s1, 0xF80
    slli s1, s1, 20                 # PLIC 0xF8000000

    li   s7, 0x1000                 # results base (low RAM, backed + AHBMON-logged)
    li   s2, 0
    li   s3, 0
    li   s4, 0

    # Smrnmi: mnstatus.NMIE (bit 3) resets to 0, which MASKS ALL INTERRUPTS.
    # Firmware must set it before any interrupt can be taken.  (CSR 0x744.)
    li   t6, 0x8
    csrs 0x744, t6                  # mnstatus.NMIE = 1

    li   t0, 0xB0075
    sw   t0, 0(s7)                  # 0x1000 booted marker

    #########################################################
    # PHASE A: M-mode software interrupt (MSIP) -- the most direct
    # "does this core take interrupts at all" probe: no mtime, no peripheral.
    #########################################################
    la   t0, m_trap
    csrw mtvec, t0

    li   t2, 0xE00
    slli t2, t2, 20                 # CLINT 0xE0000000
    li   t1, 1
    sw   t1, 0(t2)                  # msip[hart0] = 1 -> MSIP pending

    li   s4, 0
    li   t6, 0x8
    csrs mie, t6                    # MSIE (bit 3)
    li   t6, 0x8
    csrs mstatus, t6               # MIE

    li   t0, 0x100
A_spin:
    bnez s4, A_done
    addi t0, t0, -1
    bnez t0, A_spin
A_done:
    li   a0, 4
    jal  ra, record

    #########################################################
    # PHASE B: M-mode PLIC external interrupt (context 0)
    #########################################################
    li   t0, 0x04
    add  t0, s1, t0
    li   t1, 1
    sw   t1, 0(t0)                  # priority[1] = 1
    li   t0, 0x2000
    add  t0, s1, t0
    li   t1, 0x2
    sw   t1, 0(t0)                  # enable ctx0 source 1
    li   t0, 0x200000
    add  t0, s1, t0
    sw   x0, 0(t0)                  # threshold ctx0 = 0

    li   t1, 0xB
    sw   t1, 8(s0)                  # APBUART control: RE | TE | TI
    li   t1, 0x2A
    sw   t1, 0(s0)                  # transmit '*' -> TX irq

    li   s4, 0
    li   t6, 0x800
    csrs mie, t6                    # MEIE
    li   t6, 0x8
    csrs mstatus, t6               # MIE

    li   t0, 0x100
B_spin:
    bnez s4, B_done
    addi t0, t0, -1
    bnez t0, B_spin
B_done:
    li   a0, 8
    jal  ra, record

    #########################################################
    # PHASE C: S-mode PLIC external interrupt (context 1)
    #########################################################
    li   t0, 0x222
    csrw mideleg, t0               # delegate S sw/timer/ext

    li   t0, 0x1fffffff
    csrw pmpaddr0, t0             # NAPOT [0, 4 GiB)
    li   t0, 0x1f
    csrw pmpcfg0, t0             # R|W|X

    la   t0, s_trap
    csrw stvec, t0

    li   t0, 0x04
    add  t0, s1, t0
    li   t1, 1
    sw   t1, 0(t0)                 # priority[1] = 1
    li   t0, 0x2080
    add  t0, s1, t0
    li   t1, 0x2
    sw   t1, 0(t0)                 # enable ctx1 source 1
    li   t0, 0x201000
    add  t0, s1, t0
    sw   x0, 0(t0)                 # threshold ctx1 = 0

    li   t1, 0xB
    sw   t1, 8(s0)                 # APBUART control: RE | TE | TI
    li   t1, 0x2A
    sw   t1, 0(s0)                 # transmit '*' -> TX irq

    li   s4, 0
    li   t0, 0x200
    csrs sie, t0                  # SEIE
    li   t0, 0x802               # mstatus: MPP=S | SIE
    csrw mstatus, t0
    la   t0, s_entry
    csrw mepc, t0
    mret                          # -> S-mode

s_entry:
    li   t0, 0xC0DE
    sw   t0, 16(s7)               # 0x1010 S-mode reached marker
    li   t0, 0x100
C_spin:
    bnez s4, C_done
    addi t0, t0, -1
    bnez t0, C_spin
C_done:
    li   a0, 12
    jal  ra, record

    li   t0, 0xD09E
    sw   t0, 20(s7)               # 0x1014 done marker
hang:
    wfi                           # idle (keep the AHB trace quiet after done)
    j    hang

    #########################################################
    # record(a0 = byte offset): store (s4<<28)|((s3&0xff)<<8)|(s2&0xff)
    #########################################################
    .align 4
record:
    slli t0, s4, 28
    andi t1, s3, 0xff
    slli t1, t1, 8
    or   t0, t0, t1
    andi t1, s2, 0xff
    or   t0, t0, t1
    add  t1, s7, a0
    sw   t0, 0(t1)
    ret

    #########################################################
    # Trap handlers
    #########################################################
    .align 4
m_trap:
    csrr t0, mcause
    mv   s2, t0
    andi t1, t0, 0x3f
    li   t2, 11
    beq  t1, t2, m_ext
    li   t2, 7
    beq  t1, t2, m_tmr
    li   t2, 3
    beq  t1, t2, m_sw
    j    m_end
m_sw:
    li   t3, 0xE00
    slli t3, t3, 20
    sw   x0, 0(t3)                 # msip = 0 (clear MSIP)
    li   t4, 0x8
    csrc mie, t4                   # mask MSIE
    j    m_end
m_ext:
    li   t3, 0x200004
    add  t3, s1, t3
    lw   s3, 0(t3)                 # claim ctx0
    sw   s3, 0(t3)                 # complete
    li   t4, 0x800
    csrc mie, t4                   # mask MEIE
    j    m_end
m_tmr:
    li   t3, 0xE00
    slli t3, t3, 20
    li   t4, 0x4000
    add  t3, t3, t4
    li   t4, -1
    sd   t4, 0(t3)                # mtimecmp = far future
    li   t4, 0x80
    csrc mie, t4                   # mask MTIE
m_end:
    li   s4, 1
    mret

    .align 4
s_trap:
    csrr t0, scause
    mv   s2, t0
    andi t1, t0, 0x3f
    li   t2, 9
    beq  t1, t2, s_ext
    # non S-ext (a fault or other interrupt): don't retry the faulting insn
    # (would loop); record what we have by landing at C_done, which stores
    # s2/s3/s4.  A fault gives scause in the low byte (e.g. 0x1 instr-access).
    la   t3, C_done
    csrw sepc, t3
    j    s_end
s_ext:
    li   t3, 0x201004
    add  t3, s1, t3
    lw   s3, 0(t3)                 # claim ctx1
    sw   s3, 0(t3)                 # complete
    li   t4, 0x200
    csrc sie, t4                   # mask SEIE
s_end:
    li   s4, 1
    sret
