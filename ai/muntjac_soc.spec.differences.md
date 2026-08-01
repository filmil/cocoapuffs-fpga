# Summary of Differences: Original vs. Clarified Muntjac SoC Spec

The following clarifications and corrections were made to the original `muntjac_soc.spec.md` to resolve ambiguities and errors encountered during implementation:

1. **Toolchain Build Directory Correction:**
   * **Original:** Instructed to define the toolchain build file in `//boards/rv32_ddr3/tool.vivado`.
   * **Clarified:** Corrected this to `//boards/muntjac/tool.vivado` since we are building a new board in the `muntjac` directory.

2. **Bus Architecture and Interconnect Clarification:**
   * **Original:** Vaguely stated to "Attach Muntjac to a tilelink complex from the muntjac library" and "Attach a TL-UL to the tilelink complex. Attach the UART16650 from `//third_party/uart16550` to this complex."
   * **Clarified:** The UART16550 core uses a Wishbone interface, not TileLink (TL-UL). The spec was updated to explicitly instruct using a TileLink-to-Wishbone converter (`tl_c2wblite` or `tl2wb`) attached to Muntjac. It also specifies using a Wishbone demultiplexer to route the Wishbone traffic from Muntjac to both the DDR3 memory (via the DDR3 multiplexer) and the UART16550.