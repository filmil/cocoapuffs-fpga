# SPDX-License-Identifier: Apache-2.0

.section .text
.global _start

_start:
    li t0, 0x40000010    # Muntjac UART16550 Base Address

    # 1. Disable all interrupts to ensure clean polling operation
    # IER is at offset 4 (Standard register 1)
    li t1, 0x00
    sw t1, 4(t0)

    # 2. Enable DLAB (Divisor Latch Access Bit) to configure baud rate divisor
    # LCR is at offset 12 (Standard register 3), DLAB is bit 7 (0x80)
    li t1, 0x80
    sw t1, 12(t0)

    # 3. Write divisor DLL and DLM for 115200 baud under 50MHz clock
    # Divisor = 50,000,000 / (16 * 115,200) = 27.1267... -> 27 (0x1b)
    # DLL is at offset 0 (Standard register 0)
    li t1, 0x1b
    sw t1, 0(t0)
    # DLM is at offset 4 (Standard register 1)
    li t1, 0x00
    sw t1, 4(t0)

    # 4. Clear DLAB and configure character format: 8N1 (8 data bits, no parity, 1 stop bit)
    # LCR is at offset 12 (Standard register 3), 8N1 is 0x03
    li t1, 0x03
    sw t1, 12(t0)

    # 5. Enable and clear FIFOs
    # FCR is at offset 8 (Standard register 2)
    # Bit 0: Enable FIFO (0x01)
    # Bit 1: Clear RX FIFO (0x02)
    # Bit 2: Clear TX FIFO (0x04)
    # Total = 0x07
    li t1, 0x07
    sw t1, 8(t0)

    # 'h'
    li t1, 0x68
    jal ra, send_char
    # 'a'
    li t1, 0x61
    jal ra, send_char
    # 'l'
    li t1, 0x6c
    jal ra, send_char
    # 't'
    li t1, 0x74
    jal ra, send_char
    # '.'
    li t1, 0x2e
    jal ra, send_char

spin:
    j spin

send_char:
wait_thre:
    lw t2, 20(t0)        # Read Line Status Register (Offset 20)
    andi t2, t2, 0x20    # Check THRE (Bit 5, which is 0x20)
    beqz t2, wait_thre
    sw t1, 0(t0)         # Write character to Transmitter Holding Register (Offset 0)
    ret
