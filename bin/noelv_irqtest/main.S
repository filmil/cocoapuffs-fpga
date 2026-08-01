.section .text
.global _start

# HW clean re-measurement of APBUART (PLIC source 1) interrupt delivery to the
# NOEL-V hart.  Runs bare-metal on real hardware (linked at 0x40000, uploaded via
# the SERV ihex loader; the boot stub jumps here in M-mode, no OpenSBI).
#
# Unlike the NVC sim -- which takes no interrupts at all -- real hardware does,
# so this answers the open question directly.  For each external phase it arms
# the interrupt with the global enable OFF (mstatus.MIE=0 / sstatus.SIE=0) so the
# pending bit lands in mip/sip WITHOUT trapping, then reads and prints mip/sip and
# the PLIC pending register (0xF8001000) -- NEVER the claim register (reading
# claim clears the eip, which is what corrupted the earlier measurement).  Then it
# sets the global enable and confirms the trap actually fires.
#
#   A  M-software (MSIP)   sanity: proves HW takes interrupts + trap/UART work
#   B  M-external (ctx0)   prints "B mip=<mip> pend=<plic>" then TRAP/NOIRQ
#   C  S-external (ctx1)   prints "C sip=<sip> pend=<plic>" then TRAP/NOIRQ
# mip bit11 (0x800)=MEIP, sip bit9 (0x200)=SEIP, pending bit1 (0x2)=source 1.
#
# APBUART @0xFF900000 (scaler 42 = 115200 @ 40 MHz).  PLIC @0xF8000000.
# Registers: s0=UART base  s1=PLIC base  s2=cause  s3=claimed src  s4=trapped

#define UART_SCALER 42

_start:
    li   t0, 0xFF9
    slli t0, t0, 20
    li   t1, UART_SCALER
    sw   t1, 12(t0)                 # scaler
    li   t1, 0x3
    sw   t1, 8(t0)                  # control: RE | TE
    mv   s0, t0

    li   s1, 0xF80
    slli s1, s1, 20                 # PLIC 0xF8000000

    # Smrnmi (SMRNMI_SUPPORT=1 in this core): mnstatus.NMIE (bit3, CSR 0x744)
    # resets to 0, which MASKS ALL INTERRUPTS until firmware sets it.  This is
    # THE reason no trap ever fired -- set it before arming anything.
    li   t6, 0x8
    csrs 0x744, t6                  # mnstatus.NMIE = 1

    la   a0, msg_banner
    jal  ra, puts

    #########################################################
    # PHASE A: M-mode software interrupt (MSIP) -- HW sanity
    #########################################################
    la   t0, m_trap
    csrw mtvec, t0

    li   t2, 0xE00
    slli t2, t2, 20                 # CLINT 0xE0000000
    li   t1, 1
    sw   t1, 0(t2)                  # msip[0] = 1

    li   s4, 0
    li   t6, 0x8
    csrs mie, t6                    # MSIE
    li   t6, 0x8
    csrs mstatus, t6               # MIE = 1 -> if the core takes it, traps HERE
    # No '*' trigger in this phase, so the dump prints cleanly.  If we reach it
    # un-trapped, all three MSIP trap conditions are on one line:
    csrr a1, mstatus
    la   a0, msg_ams;  jal ra, puts; jal ra, puthex32
    csrr a1, mie
    la   a0, msg_aie;  jal ra, puts; jal ra, puthex32
    csrr a1, mip
    la   a0, msg_aip;  jal ra, puts; jal ra, puthex32
    li   a0, 13; jal ra, putc
    li   a0, 10; jal ra, putc

    li   t0, 0x40000
A_spin:
    bnez s4, A_done
    addi t0, t0, -1
    bnez t0, A_spin
A_done:
    li   a0, 'A'
    jal  ra, report

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
    li   a0, 0x2A
    jal  ra, putc                                 # transmit (polled) -> TX irq

    li   t6, 0x800
    csrs mie, t6                    # MEIE (mie now = MSIE | MEIE)

    li   t0, 0x40000               # let the APBUART assert + PLIC propagate
Bd: addi t0, t0, -1
    bnez t0, Bd

    li   s4, 0
    li   t6, 0x8
    csrs mstatus, t6               # MIE = 1 -> if the core takes it, traps HERE
    # If control reaches here un-trapped, EVERY trap condition is visible below:
    # mstatus.MIE (bit3), mie.M*IE, mip.M*IP -- pending + enabled, yet no trap.
    csrr a1, mstatus
    la   a0, msg_ms;   jal ra, puts; jal ra, puthex32
    csrr a1, mie
    la   a0, msg_mie;  jal ra, puts; jal ra, puthex32
    csrr a1, mip
    la   a0, msg_mip;  jal ra, puts; jal ra, puthex32
    li   t0, 0x1000
    add  t0, s1, t0
    lw   a1, 0(t0)                 # PLIC pending word 0 (no side effect)
    la   a0, msg_pend; jal ra, puts; jal ra, puthex32
    li   a0, 13; jal ra, putc
    li   a0, 10; jal ra, putc

    li   t0, 0x40000
B_spin:
    bnez s4, B_done
    addi t0, t0, -1
    bnez t0, B_spin
B_done:
    li   a0, 'B'
    jal  ra, report

    #########################################################
    # PHASE C: S-mode PLIC external interrupt (context 1)
    #########################################################
    li   t0, 0x222
    csrw mideleg, t0

    li   t0, 0x1fffffff
    csrw pmpaddr0, t0
    li   t0, 0x1f
    csrw pmpcfg0, t0

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
    li   a0, 0x2A
    jal  ra, putc                                # transmit (polled) -> TX irq

    li   t0, 0x200
    csrs sie, t0                  # SEIE
    li   t0, 0x800               # mstatus.MPP = S (SIE bit1 left 0)
    csrw mstatus, t0
    la   t0, s_entry
    csrw mepc, t0
    mret                          # -> S-mode, S-interrupts still disabled

s_entry:
    li   t0, 0x40000             # let the APBUART assert + PLIC propagate
Cd: addi t0, t0, -1
    bnez t0, Cd

    csrr a1, sip                  # read sip WITHOUT taking the trap
    la   a0, msg_sip
    jal  ra, puts
    jal  ra, puthex32
    li   t0, 0x1000
    add  t0, s1, t0
    lw   a1, 0(t0)                # PLIC pending word 0
    la   a0, msg_pend
    jal  ra, puts
    jal  ra, puthex32
    li   a0, 13; jal ra, putc
    li   a0, 10; jal ra, putc

    li   s4, 0
    li   t0, 0x2
    csrs sstatus, t0              # SIE = 1 -> take it if SEIP pending
    li   t0, 0x40000
C_spin:
    bnez s4, C_done
    addi t0, t0, -1
    bnez t0, C_spin
C_done:
    li   a0, 'C'
    jal  ra, report

    la   a0, msg_done
    jal  ra, puts
hang:
    j    hang

    #########################################################
    # report(a0 = phase char): "<c>: TRAP c=<s2> src=<s3>" or "<c>: NOIRQ"
    #########################################################
    .align 4
report:
    mv   s8, ra
    jal  ra, putc
    li   a0, ':';  jal ra, putc
    li   a0, ' ';  jal ra, putc
    beqz s4, report_no
    la   a0, msg_trap; jal ra, puts
    mv   a1, s2;   jal ra, puthex32
    la   a0, msg_src;  jal ra, puts
    mv   a1, s3;   jal ra, puthex32
    j    report_end
report_no:
    la   a0, msg_noirq; jal ra, puts
report_end:
    li   a0, 13;  jal ra, putc
    li   a0, 10;  jal ra, putc
    mv   ra, s8
    ret

    #########################################################
    # Trap handlers.  They DO read claim (to clear+identify), but only AFTER the
    # mip/sip measurement above -- so the measurement is never perturbed.
    #########################################################
    .align 4
m_trap:
    csrr t0, mcause
    mv   s2, t0
    andi t1, t0, 0x3f
    li   t2, 11
    beq  t1, t2, m_ext
    li   t2, 3
    beq  t1, t2, m_sw
    j    m_end
m_sw:
    li   t3, 0xE00
    slli t3, t3, 20
    sw   x0, 0(t3)                # msip = 0
    li   t4, 0x8
    csrc mie, t4                  # mask MSIE
    j    m_end
m_ext:
    li   t3, 0x200004
    add  t3, s1, t3
    lw   s3, 0(t3)               # claim ctx0
    sw   s3, 0(t3)               # complete
    li   t4, 0x800
    csrc mie, t4                 # mask MEIE
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
    la   t3, C_done              # fault/other: land cleanly, don't loop
    csrw sepc, t3
    j    s_end
s_ext:
    li   t3, 0x201004
    add  t3, s1, t3
    lw   s3, 0(t3)               # claim ctx1
    sw   s3, 0(t3)               # complete
    li   t4, 0x200
    csrc sie, t4                 # mask SEIE
s_end:
    li   s4, 1
    sret

# puts(a0): print NUL-terminated string.  Saves ra in s10; uses s11.
puts:
    mv   s10, ra
    mv   s11, a0
puts_loop:
    lbu  a0, 0(s11)
    beqz a0, puts_done
    jal  ra, putc
    addi s11, s11, 1
    j    puts_loop
puts_done:
    mv   ra, s10
    ret

# putc(a0): poll status bit1 (TX shift empty), then write.  Leaf; uses s0, t1.
putc:
    lw   t1, 4(s0)
    andi t1, t1, 0x2
    beqz t1, putc                 # wait until the transmitter is idle
    sw   a0, 0(s0)
pc1:
    lw   t1, 4(s0)
    andi t1, t1, 0x2
    beqz t1, pc1                  # wait until THIS char has fully drained
    ret

# puthex32(a1): low 32 bits of a1 as 8 hex chars, MSB first.  Saves ra in s9.
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

    .align 3
msg_banner: .asciz "\r\n\r\nIRQTEST\r\n"
msg_ams:    .asciz "MS="
msg_aie:    .asciz "/IE="
msg_aip:    .asciz "/IP="
msg_ms:     .asciz "B ms="
msg_mie:    .asciz " mie="
msg_mip:    .asciz " mip="
msg_sip:    .asciz "C sip="
msg_pend:   .asciz " pend="
msg_trap:   .asciz "TRAP c="
msg_src:    .asciz " src="
msg_noirq:  .asciz "NOIRQ"
msg_done:   .asciz "DONE\r\n"
