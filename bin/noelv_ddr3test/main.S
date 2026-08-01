.section .text
.global _start

# NOEL-V memory write/read self-test for tb_noelvsys_only.
#
# Writes a known pattern to 0x40000 (the low-region RAM, same address the boot
# payload lives at), reads it back, and:
#   - on match  -> prints "halt.\r\n"  => the testbench's wait_for_string("halt.")
#                  succeeds and the test PASSES (NOEL-V AHB write+read works).
#   - on mismatch -> prints "bad.\r\n" (and never "halt.") => the test FAILS.
#
# Kept deliberately short (<= 7 bytes, fits the 8-deep TX FIFO, no drain loops)
# so the simulation finishes quickly. Strings are immediate byte stores (no
# .rodata reads). APBUART @ 0xFF900000; sim baud uses scaler 30 (~201.6 kbaud).

#define UART_SCALER 30
#define TESTADDR    0x40000

_start:
    nop
    # APBUART base 0xFF900000.  Build it ZERO-extended: on RV64 a plain
    # `lui t0,0xFF900` sign-extends (bit 31 set) to 0xFFFFFFFF_FF900000, an
    # invalid high physical address whose store never decodes -> pipeline wedge.
    li   t0, 0xFF9
    slli t0, t0, 20              # t0 = 0x00000000_FF900000
    li   t1, UART_SCALER
    sw   t1, 12(t0)              # scaler (0x0C)
    li   t1, 0x3
    sw   t1, 8(t0)               # control (0x08): RE | TE

    # Write a pattern to TESTADDR and read it back.
    li   t2, TESTADDR
    li   t3, 0xCAFEF00D
    sw   t3, 0(t2)
    lwu  t4, 0(t2)              # lwu (zero-extend): lw would sign-extend bit31 of
                               # 0xCAFEF00D -> 0xFFFFFFFF_CAFEF00D and mismatch t3
    bne  t3, t4, bad

    # Match -> "halt.\r\n" (7 bytes).
    li   t1, 0x68
    sw   t1, 0(t0)              # 'h'
    li   t1, 0x61
    sw   t1, 0(t0)              # 'a'
    li   t1, 0x6c
    sw   t1, 0(t0)              # 'l'
    li   t1, 0x74
    sw   t1, 0(t0)              # 't'
    li   t1, 0x2e
    sw   t1, 0(t0)              # '.'
    li   t1, 0x0d
    sw   t1, 0(t0)              # '\r'
    li   t1, 0x0a
    sw   t1, 0(t0)              # '\n'
    j    spin

bad:
    # Mismatch -> "bad.\r\n" (6 bytes); never prints "halt.".
    li   t1, 0x62
    sw   t1, 0(t0)              # 'b'
    li   t1, 0x61
    sw   t1, 0(t0)              # 'a'
    li   t1, 0x64
    sw   t1, 0(t0)              # 'd'
    li   t1, 0x2e
    sw   t1, 0(t0)              # '.'
    li   t1, 0x0d
    sw   t1, 0(t0)              # '\r'
    li   t1, 0x0a
    sw   t1, 0(t0)              # '\n'

spin:
    j    spin
