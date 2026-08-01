.section .text
.global _start

# Shim-trap HW probe: run the REAL Fuchsia boot-shim on hardware under our own
# trap handler, to capture its first fault (the silent recurring trap OpenSBI
# hides by redirecting it).  Sim said S-mode execute is denied, but that was a
# sim artifact -- on HW (noelv_smodetest -> "SMODE OK") S-mode executes DDR3 fine,
# so the shim really runs in S-mode and faults later.
#
# Layout (uploaded via the SERV ihex loader, no OpenSBI):
#   .text at 0x40000  -- this stub + trap handler
#   .shim at 0x240000 -- the shim image (.incbin), where it is linked to run
#
# M-mode sets a catch-all RWX PMP, mtvec=m_trap, medeleg=0 (so EVERY S-mode fault
# comes to M, not the shim's stvec=0), and mrets to the shim at 0x240000.  m_trap
# emulates the shim's opening `rdtime` (if it traps) so it proceeds, and prints
# "SHIM TRAP <mcause> <mepc> <mtval>" on the first real fault.

#define UART_SCALER 42
#define SHIM   0x240000
#define MTIME  0xe000bff8       /* NOEL-V CLINT mtime */
#define RDTIME 0xc0102673       /* csrr a2, time */

_start:
    li   t0, 0xFF9
    slli t0, t0, 20             # APBUART 0xFF900000
    li   t1, UART_SCALER
    sw   t1, 12(t0)
    li   t1, 3
    sw   t1, 8(t0)
    mv   s0, t0                 # s0 = UART base (kept for putc)
    la   a0, msg_run
    jal  ra, puts

    li   t0, 0x1fffffff         # PMP NAPOT [0,4GiB) RWX
    csrw pmpaddr0, t0
    li   t0, 0x1f
    csrw pmpcfg0, t0
    li   t0, -1                 # allow S-mode time/cycle (rdtime)
    csrw mcounteren, t0
    csrw medeleg, zero          # catch EVERY fault in M
    csrw mideleg, zero
    la   t0, m_trap
    csrw mtvec, t0
    li   t0, 0x800             # mstatus.MPP = S
    csrw mstatus, t0
    li   t0, SHIM
    csrw mepc, t0
    li   a0, 0                  # hartid
    li   a1, 0                  # dtb (dummy)
    mret                        # -> shim at 0x240000, S-mode

    .align 4
m_trap:
    # Emulate the shim's opening `rdtime a2` so it proceeds.
    csrr t1, mcause
    li   t2, 2                  # illegal instruction
    bne  t1, t2, real_fault
    csrr t3, mepc
    lwu  t4, 0(t3)
    li   t5, RDTIME
    bne  t4, t5, real_fault
    li   t6, MTIME
    ld   a2, 0(t6)
    addi t3, t3, 4
    csrw mepc, t3
    mret

real_fault:
    li   s0, 0xFF9              # re-establish UART base (shim clobbered s0)
    slli s0, s0, 20
    la   a0, msg_trap
    jal  ra, puts
    csrr a1, mcause; jal ra, puthex32
    li   a0, ' ';    jal ra, putc
    csrr a1, mepc;   jal ra, puthex32
    li   a0, ' ';    jal ra, putc
    csrr a1, mtval;  jal ra, puthex32
    li   a0, '\r';   jal ra, putc
    li   a0, '\n';   jal ra, putc
1:  j    1b

puts:
    mv   s10, ra
    mv   s11, a0
2:  lbu  a0, 0(s11)
    beqz a0, 3f
    jal  ra, putc
    addi s11, s11, 1
    j    2b
3:  mv   ra, s10
    ret

putc:
4:  lw   t1, 4(s0)
    andi t1, t1, 2
    beqz t1, 4b
    sw   a0, 0(s0)
    ret

puthex32:
    mv   s9, ra
    li   t2, 28
5:  srl  t1, a1, t2
    andi t1, t1, 0xf
    li   t3, 10
    blt  t1, t3, 6f
    addi a0, t1, 'a' - 10
    j    7f
6:  addi a0, t1, '0'
7:  jal  ra, putc
    addi t2, t2, -4
    bgez t2, 5b
    mv   ra, s9
    ret

    .align 3
msg_run:  .asciz "SHIM RUN\r\n"
msg_trap: .asciz "SHIM TRAP "

    .section .shim, "a"
    .incbin SHIM_BIN
