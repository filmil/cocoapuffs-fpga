.section .text
.global _start

# Minimal NOEL-V "hello" writer that runs FROM DDR3.
#
# The boot stub (bin/noelv_boot, SIM_FAST=0) prints "RV64 boot." from boot BRAM,
# then `jr` to 0x40000 -- the address where the SERV ihex loader populated shared
# DDR3 RAM with this payload.  So every instruction below is fetched from DDR3.
#
# Purpose: isolate ONE question -- can code fetched from DDR3 perform a D-side
# STORE to the APBUART?  It emits "hello\r\n" with IMMEDIATE byte stores only (no
# .rodata loads), so a clean "hello" proves DDR3 instruction fetch + peripheral
# store both work, without depending on any DDR3 data LOAD.  (A follow-up can add
# a DDR3 scratch load/store to test the read path separately.)
#
# APBUART @ 0xFF900000: 0x00 data (write = transmit one byte), 0x08 control
# (bit0 RE, bit1 TE), 0x0C scaler.  clk50 = 40 MHz, 115200 bps -> scaler =
# 40e6/(8*115200) - 1 = 42, matching the boot stub so the host stays in sync.

#define UART_SCALER 42

_start:
    nop                      # reset alignment buffer
    # APBUART base 0xFF900000, ZERO-extended: on RV64 `lui t0,0xFF900` sign-
    # extends (bit 31) to 0xFFFFFFFF_FF900000, an invalid high address that wedges.
    li   t0, 0xFF9
    slli t0, t0, 20

    li   t1, UART_SCALER
    sw   t1, 12(t0)          # Scaler (0x0C): baud rate
    li   t1, 0x3
    sw   t1, 8(t0)           # Control (0x08): RE | TE

    # "hello\r\n" -- 7 bytes, fits the 8-deep TX FIFO, so no inter-byte polling.
    li   t1, 0x68
    sw   t1, 0(t0)           # 'h'
    li   t1, 0x65
    sw   t1, 0(t0)           # 'e'
    li   t1, 0x6c
    sw   t1, 0(t0)           # 'l'
    li   t1, 0x6c
    sw   t1, 0(t0)           # 'l'
    li   t1, 0x6f
    sw   t1, 0(t0)           # 'o'
    li   t1, 0x0d
    sw   t1, 0(t0)           # '\r'
    li   t1, 0x0a
    sw   t1, 0(t0)           # '\n'

    # Let the FIFO fully transmit before spinning, so the ~30 s AHB-recorder dump
    # does not race the last bytes off the wire.
    li   t3, 0x100000
drain:
    addi t3, t3, -1
    bnez t3, drain

spin:
    j    spin
