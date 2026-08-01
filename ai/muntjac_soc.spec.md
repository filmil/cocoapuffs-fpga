# Task: wire up the hardware for a muntjac-based system.

In this task, I ask you to implement a muntjac based SoC board and place it
into //boards/muntjac. This is hard for a human to get right because there is
a lot of wiring involved, and humans tend to make mistakes and not wire things
up correctly.

For now no software parts are to be implemented, focus only on hardware
definition.

## Preliminaries

* If there is an unclear part in the spec, stop and ask user for clarification.

## Overview

System components are as follows:

  * There is a 32-bit part based on the serv RV32 processor, which must be the
    same as in `//boards/rv32_ddr3`. You can copy that part of the design,
    changing what needs to be changed, including all hardware around the RV32
    processor.
  * We will be adding Muntjac and uart for it.
  * Define toolchain build file in `//boards/rv32_ddr3/tool.vivado`.
  * Use VHDL to implement the logic where new logic is needed. But if there are
    verilog modules keep them verilog and use them in their original form.
  * The 64-bit part of the system will be built around the Muntjac CPU.
    * All resets for the 64-bit part of the system should be controlled by bits
      from a peripheral `//ip/wb/percontrol`, so that the 32-bit system can do
      the initial setup, and then write to percontrol to de-assert the reset
      signal for the 64-bit part of the system.
  * Attach DDR3 to a wb multiplexer, attach one output of the multiplexer to
    the wblite bus controlled by the RV32 process. The other attach to a tl to
    wblite converter, so it can be attached to muntjac.
  * Attach Muntjac to a tilelink complex from the muntjac library.
  * Attach a TL-UL to the tilelink complex. Attach the UART16650 from
    `//third_party/uart16550` to this complex. Use `//ip/general/uartmux.vhdl`
    to multiplex the outbound uart lines with the UART which is used by RV32.
    Assume that the two uarts will never be used at the same time.

