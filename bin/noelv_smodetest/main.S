.section .text
.global _start

# Standalone S-mode-execute probe.  Root question behind the Fuchsia shim's silent
# recurring trap: does this NOEL-V let S-mode execute from DDR3 at all?  (Sim says
# no -- the shim faults instruction-access on its first S-mode fetch despite a
# catch-all RWX PMP; this confirms it on hardware.)
#
# Linked at 0x40000 so the SERV ihex loader uploads it and the boot stub jumps to
# it in M-mode -- no OpenSBI.  M-mode sets up a catch-all RWX PMP and mrets to
# S-mode at s_test (in DDR3, 0x40000-range):
#   reached S-mode  -> prints "SMODE OK"          (S-mode execute works)
#   fetch faults    -> prints "SMODE FAULT <mcause> <mepc> <mtval>"  (denied)
#
# APBUART @0xFF900000, scaler 42 = 115200 @ 40 MHz, poll status bit1 = TX empty.

#define UART_SCALER 42

_start:
    li   t0, 0xFF9
    slli t0, t0, 20             # APBUART base 0xFF900000
    li   t1, UART_SCALER
    sw   t1, 12(t0)             # scaler
    li   t1, 3
    sw   t1, 8(t0)              # control: RE | TE
    mv   s0, t0                 # s0 = UART base (kept for putc)

    # PMP entry 0: NAPOT [0, 4 GiB), R|W|X -- catch-all, S/U allowed.
    li   t0, 0x1fffffff
    csrw pmpaddr0, t0           # 0x3b0
    li   t0, 0x1f
    csrw pmpcfg0, t0            # 0x3a0

    la   t0, m_trap
    csrw mtvec, t0              # 0x305
    li   t0, 0x800             # mstatus.MPP = 01 (S-mode)
    csrw mstatus, t0           # 0x300
    la   t0, s_test
    csrw mepc, t0              # 0x341
    mret                       # -> S-mode at s_test

# Reached S-mode: execute-from-DDR3 in S-mode works.
s_test:
    la   a0, msg_ok
    jal  ra, puts
1:  j    1b

# S-mode fetch faulted -> trap to M-mode here.
    .align 4
m_trap:
    la   a0, msg_fault
    jal  ra, puts
    csrr a1, mcause; jal ra, puthex32
    li   a0, ' ';    jal ra, putc
    csrr a1, mepc;   jal ra, puthex32
    li   a0, ' ';    jal ra, putc
    csrr a1, mtval;  jal ra, puthex32
    li   a0, '\n';   jal ra, putc
2:  j    2b

# puts(a0 = ptr): print a NUL-terminated string.  Saves ra in s10; uses s11.
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

# putc(a0): poll status bit1 (TX empty), write the byte.  Leaf; uses s0, t1.
putc:
3:  lw   t1, 4(s0)
    andi t1, t1, 2
    beqz t1, 3b
    sw   a0, 0(s0)
    ret

# puthex32(a1): low 32 bits of a1 as 8 hex chars, MSB first.  Saves ra in s9.
puthex32:
    mv   s9, ra
    li   t2, 28
ph_loop:
    srl  t1, a1, t2
    andi t1, t1, 0xf
    li   t3, 10
    blt  t1, t3, ph_dig
    addi a0, t1, 'a' - 10
    j    ph_emit
ph_dig:
    addi a0, t1, '0'
ph_emit:
    jal  ra, putc
    addi t2, t2, -4
    bgez t2, ph_loop
    mv   ra, s9
    ret

    .align 3
msg_ok:    .asciz "SMODE OK\r\n"
msg_fault: .asciz "SMODE FAULT "
