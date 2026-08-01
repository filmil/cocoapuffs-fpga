.section .text
.global _start

# Minimal RV64 "hello world" program, built as a flat binary to serve as an
# OpenSBI fw_payload *next stage* (see //boards/noelv:opensbi_fw_hello).
#
# Unlike //bin/noelv_hello_ddr3 (which the NOEL-V boot stub jumps to directly at
# 0x40000), this runs as the stage OpenSBI hands control to after its M-mode
# init, at OpenSBI's payload load address.  It is position-independent
# (PC-relative branches; only the absolute APBUART address) so the link address
# is irrelevant, and _start sits at offset 0 where OpenSBI jumps.
#
# Purpose: a clean isolation test -- once OpenSBI's M-mode init is fixed, a
# "hello world" here proves the OpenSBI->payload handoff and the console path
# work, independent of the (complex) Linux boot shim.  It prints the string in an
# ENDLESS LOOP (one line every ~0.6 s) so the host-side serial program can be
# vetted: a clean, steady stream of identical "hello world" lines rules out a
# host serial reader that drops / duplicates / garbles -- any corruption then
# lives in the device/UART path, not the terminal program.
#
# APBUART @ 0xFF900000 (zero-extended; on RV64 `lui 0xFF900` sign-extends to an
# invalid high address): 0x00 data, 0x04 status (bit1 TS = TX shift empty),
# 0x08 control (RE|TE), 0x0C scaler.  clk = 40 MHz, 115200 bps -> scaler = 42.

_start:
    li   t0, 0xff9
    slli t0, t0, 20           # APBUART base = 0x00000000_FF900000
    li   t1, 42
    sw   t1, 12(t0)           # scaler  (0x0C)
    li   t1, 0x3
    sw   t1, 8(t0)            # control (0x08): RE | TE

print_loop:
    # "hello world\r\n", one byte per putc (polls TS so the 13-byte string does
    # not overflow the 8-deep TX FIFO).
    li   a0, 0x68; jal ra, putc   # h
    li   a0, 0x65; jal ra, putc   # e
    li   a0, 0x6c; jal ra, putc   # l
    li   a0, 0x6c; jal ra, putc   # l
    li   a0, 0x6f; jal ra, putc   # o
    li   a0, 0x20; jal ra, putc   # (space)
    li   a0, 0x77; jal ra, putc   # w
    li   a0, 0x6f; jal ra, putc   # o
    li   a0, 0x72; jal ra, putc   # r
    li   a0, 0x6c; jal ra, putc   # l
    li   a0, 0x64; jal ra, putc   # d
    li   a0, 0x0d; jal ra, putc   # \r
    li   a0, 0x0a; jal ra, putc   # \n

    # ~0.6 s pause at 40 MHz (~8.4M iters * ~3 cycles) so the lines are readable
    # and the 13-byte burst fully drains the TX FIFO between lines.
    li   t2, 0x800000
1:  addi t2, t2, -1
    bnez t2, 1b

    j    print_loop

# putc: wait for the TX shift register to be empty (status bit1), then write the
# low byte of a0.  Clobbers t1; preserves t0 (UART base) and a0.
putc:
    lw   t1, 4(t0)
    andi t1, t1, 0x2
    beqz t1, putc
    sw   a0, 0(t0)
    ret
