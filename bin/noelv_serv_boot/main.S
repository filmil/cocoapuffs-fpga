.section .text
.global _start

# Dual-core handoff boot for the (bit-serial) SERV core, with a link-test banner.
#
# SERV wb_uart @ 0x40000010:
#   write -> transmit one byte (low 8 bits)
#   read  -> status: bit11 = TX FIFO full, bit10 = TX FIFO empty, bit8 = RX empty
#   The wb_uart baud is fixed in hardware by the BAUD_RATE generic (115200), so
#   this banner is a known-good 115200 8N1 reference on the shared TX pin.
# percontrol @ 0x40000040: bit0 = UART mux (1 = NoelV), bit1 = NoelV run.
#
# While the mux bit is 0, THIS UART drives the shared pin.  SERV streams a
# "SERV" banner for a few seconds first (proof the serial link works), then
# drains the FIFO and hands the UART + reset over to NoelV.

#define UART      0x40000010
#define PERCTL    0x40000040
#define TX_FULL   0x800       /* status bit 11 */
#define TX_EMPTY  0x400       /* status bit 10 */

_start:
    li   s0, UART
    li   s1, 64               # banner lines before handing off (~3 s)

banner:
    li   a0, 0x53             # 'S'
    jal  putc
    li   a0, 0x45             # 'E'
    jal  putc
    li   a0, 0x52             # 'R'
    jal  putc
    li   a0, 0x56             # 'V'
    jal  putc
    li   a0, 0x0d             # '\r'
    jal  putc
    li   a0, 0x0a             # '\n'
    jal  putc

    # Pause so the banner is readable (not a flood).  SERV is bit-serial (slow),
    # so this is tens of ms per line.
    li   t0, 0x10000
bdelay:
    addi t0, t0, -1
    bnez t0, bdelay

    addi s1, s1, -1
    bnez s1, banner

    # Wait for the TX FIFO to drain (bit 10) so the handoff does not truncate.
drain:
    lw   t1, 0(s0)
    andi t1, t1, TX_EMPTY
    beqz t1, drain

    # Hand off: UART mux -> NoelV, release NoelV from reset.
    li   t0, PERCTL
    li   t1, 0x3
    sw   t1, 0(t0)

spin:
    j    spin

# putc: wait until the TX FIFO is not full, then transmit a0.  Clobbers t1.
# (TX_FULL = bit 11 = 0x800 is out of andi's 12-bit signed immediate range, so
# shift bit 11 into the sign bit and test with bltz instead.)
putc:
    lw   t1, 0(s0)
    slli t1, t1, 20         # status bit 11 (TX full) -> bit 31 (sign)
    bltz t1, putc           # TX full -> spin until it drains
    sw   a0, 0(s0)
    ret
