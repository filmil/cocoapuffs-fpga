.section .text
.global _start

# NOEL-V boot stub for the Cocoapuffs board.
#
# Two behaviours, selected by the SIM_FAST cpp flag (the same flag the board
# uses to pick :memh for sim vs :memh_hw for hardware):
#
#   SIM_FAST = 1 (default, sim/:test): print "halt." forever. The self-checking
#     testbench expects this banner and there is no SERV upload in simulation,
#     so simulating the full upload/handoff flow is not practical.
#
#   SIM_FAST = 0 (hardware): print "RV64 boot." then jump to 0x40000 -- the
#     address where the SERV ihex loader (//bin/noelv_serv_upload) populated
#     shared RAM with the boot payload (OpenSBI + payload, linked at 0x40000).
#
# APBUART register map (word offsets, base 0xFF900000):
#   0x00  Data      (write = transmit one byte in bits 7..0)
#   0x04  Status    (bit0 DR, bit1 TS = TX shift-reg empty, bit2 TE, bit9 TF =
#                    TX FIFO full)
#   0x08  Control   (bit0 RE = receiver enable, bit1 TE = transmitter enable)
#   0x0C  Scaler    (baud reload: baud = clk / (8 * (scaler + 1)))
#
# The APBUART baud generator is 8x oversampling.  noelvsys runs on clk50 = 40
# MHz (lowered from 50 so the RV64 GP core meets timing): scaler = clk/(baud*8)-1.

#ifndef SIM_FAST
#define SIM_FAST 1
#endif

#if SIM_FAST
/* 40e6/(8*(24+1)) = 200.0 kbaud -- matches the 200 kbaud receiver. */
#define UART_SCALER 24
#else
/* 40e6/(8*(42+1)) = 116279 (+0.9%) for 115200 bps. */
#define UART_SCALER 42
#endif

#define PAYLOAD 0x40000      /* SERV populated this with the boot payload. */

_start:
    nop                      # Reset alignment buffer

    # Enable the L1 caches.  NOEL-V resets with CCTRL (grlib-custom CSR 0x7C1)
    # = 0: BOTH caches DISABLED (csr_out_cctrl_rst dcs="00" ics="00"), and
    # nothing downstream (generic OpenSBI, the shim, Zircon) knows this CSR --
    # grlib convention is that BOOT firmware enables the caches.  Ground truth
    # (AHB recorder, 2026-07-08): without this the core runs fully uncached
    # (every ifetch = a single bus word read, 17 cycles apart) AND sc.w/sc.d
    # can never succeed -- grlib's SC path requires a D$ hit -- which wedged
    # the Zircon kernel's first compare_exchange forever.
    # 0x1CF = dsnoop(8) | dflush(7) | iflush(6) | dcs=11(3:2) | ics=11(1:0).
    li   t0, 0x1CF
    csrw 0x7C1, t0

    # APBUART base 0xFF900000, ZERO-extended: on RV64 `lui t0,0xFF900` sign-
    # extends (bit 31) to 0xFFFFFFFF_FF900000, an invalid high address that wedges.
    li   t0, 0xFF9
    slli t0, t0, 20

    li   t1, UART_SCALER
    sw   t1, 12(t0)          # Scaler (0x0C): set the baud rate
    li   t1, 0x3
    sw   t1, 8(t0)           # Control (0x08): RE | TE (enable rx + tx)

#if SIM_FAST
    # SIM: transmit "halt.\r\n" forever so a terminal opened at any time sees
    # the stream.  Each pass writes 7 bytes into the 8-deep TX FIFO, which fully
    # drains during the delay below, so no FIFO overflow even without polling.
print_loop:
    li   t1, 0x68
    sw   t1, 0(t0)           # 'h'
    li   t1, 0x61
    sw   t1, 0(t0)           # 'a'
    li   t1, 0x6c
    sw   t1, 0(t0)           # 'l'
    li   t1, 0x74
    sw   t1, 0(t0)           # 't'
    li   t1, 0x2e
    sw   t1, 0(t0)           # '.'
    li   t1, 0x0d
    sw   t1, 0(t0)           # '\r'
    li   t1, 0x0a
    sw   t1, 0(t0)           # '\n'

    # ~0.2 s pause at 50 MHz so the output is readable (~5 lines/second).
    li   t3, 0x500000
delay:
    addi t3, t3, -1
    bnez t3, delay

    j    print_loop
#else
    # HW: print "RV64 boot.\r\n" using immediate byte stores -- exactly the
    # mechanism the SIM "halt." path above uses, with NO memory reads.  An
    # earlier version loaded the string from boot BRAM (la/lbu) and emitted
    # garbage on real hardware (the boot-BRAM data read did not return the
    # string), so we build each byte as an immediate instead.  12 bytes > the
    # 8-deep TX FIFO, so write two 6-byte chunks, each fully draining during the
    # delay that follows (no status polling needed).
    li   t1, 0x52
    sw   t1, 0(t0)           # 'R'
    li   t1, 0x56
    sw   t1, 0(t0)           # 'V'
    li   t1, 0x36
    sw   t1, 0(t0)           # '6'
    li   t1, 0x34
    sw   t1, 0(t0)           # '4'
    li   t1, 0x20
    sw   t1, 0(t0)           # ' '
    li   t1, 0x62
    sw   t1, 0(t0)           # 'b'

    li   t3, 0x100000        # drain 6 bytes (>> their ~0.5 ms transmit time)
txdrain1:
    addi t3, t3, -1
    bnez t3, txdrain1

    li   t1, 0x6f
    sw   t1, 0(t0)           # 'o'
    li   t1, 0x6f
    sw   t1, 0(t0)           # 'o'
    li   t1, 0x74
    sw   t1, 0(t0)           # 't'
    li   t1, 0x2e
    sw   t1, 0(t0)           # '.'
    li   t1, 0x0d
    sw   t1, 0(t0)           # '\r'
    li   t1, 0x0a
    sw   t1, 0(t0)           # '\n'

    li   t3, 0x100000        # let the banner fully clear before the handoff
txdrain2:
    addi t3, t3, -1
    bnez t3, txdrain2

    # Hand off to the uploaded payload at 0x40000.  RISC-V boot protocol args:
    # a0 = hartid (0), a1 = device tree (0 -> use OpenSBI's embedded FDT).
    li   a0, 0
    li   a1, 0
    li   t0, PAYLOAD
    jr   t0
#endif
