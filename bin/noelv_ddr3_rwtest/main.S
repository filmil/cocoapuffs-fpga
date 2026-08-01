.section .text
.global _start

# NOEL-V DDR3 data load/store test, run FROM DDR3 (linked at 0x40000, reached via
# the boot stub's `jr 0x40000` handoff).
#
# Companion to bin/noelv_hello_ddr3, which proved DDR3 *instruction fetch* and
# *APBUART stores* work.  That test never touched DDR3 *data*: it only stored to a
# peripheral.  This test exercises the DDR3 DATA path -- a store to a DDR3 scratch
# word followed by a load back -- which is the prime suspect for the OpenSBI hang
# (OpenSBI does stack / .data / relocation loads almost immediately).
#
#   write 0xCAFEF00D -> 0x80000 (DDR3 scratch, well clear of this code at 0x40000)
#   read it back, then:
#     match    -> "OK\r\n"   (DDR3 data load/store round-trip works)
#     mismatch -> "BAD\r\n"  (DDR3 load returns wrong data -- corruption)
#     neither, and the recorder shows no progress past the load -> the load stalls
#
# Result strings use immediate byte stores (no .rodata loads), so the ONLY data
# load in the program is the one under test.  APBUART @ 0xFF900000, scaler 42 =
# 115200 at clk50 = 40 MHz, matching the boot stub.

#define UART_SCALER 42
# Low DDR3 address in the 0x0..0x1c region we watched NOEL-V READ successfully on
# hardware (the jr-misprediction prefetches), so a hang here implicates the WRITE
# path in general rather than an aperture/calibration limit at a high address.
#define SCRATCH     0x1000

_start:
    nop
    # APBUART base 0xFF900000, ZERO-extended: on RV64 `lui t0,0xFF900` sign-
    # extends (bit 31) to 0xFFFFFFFF_FF900000, an invalid high address that wedges.
    li   t0, 0xFF9
    slli t0, t0, 20
    li   t1, UART_SCALER
    sw   t1, 12(t0)          # Scaler (0x0C)
    li   t1, 0x3
    sw   t1, 8(t0)           # Control (0x08): RE | TE

    # The single DDR3 data round-trip under test.
    li   t2, SCRATCH
    li   t3, 0xCAFEF00D
    sw   t3, 0(t2)           # DDR3 store
    lwu  t4, 0(t2)           # DDR3 load (lwu: lw would sign-extend 0xCAFEF00D)
    bne  t3, t4, bad

    # Match -> "OK\r\n".
    li   t1, 0x4f
    sw   t1, 0(t0)           # 'O'
    li   t1, 0x4b
    sw   t1, 0(t0)           # 'K'
    li   t1, 0x0d
    sw   t1, 0(t0)           # '\r'
    li   t1, 0x0a
    sw   t1, 0(t0)           # '\n'
    j    drain

bad:
    # Mismatch -> "BAD\r\n".
    li   t1, 0x42
    sw   t1, 0(t0)           # 'B'
    li   t1, 0x41
    sw   t1, 0(t0)           # 'A'
    li   t1, 0x44
    sw   t1, 0(t0)           # 'D'
    li   t1, 0x0d
    sw   t1, 0(t0)           # '\r'
    li   t1, 0x0a
    sw   t1, 0(t0)           # '\n'

drain:
    # Let the FIFO drain before spinning, so the ~30 s recorder dump does not race
    # the last bytes out.
    li   t3, 0x100000
drain_loop:
    addi t3, t3, -1
    bnez t3, drain_loop

spin:
    j    spin
