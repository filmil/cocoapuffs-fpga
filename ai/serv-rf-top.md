# serv rf top reshape

This is a change that will allow serv to execute instructions from DDR ram.


## Tasks

* Start from the files in `//boards/rv32_ddr3`, make another directory at
  `//boards/rv32_ddr3exec`, and place all further work there.

* Modify `cpu0` instance to instantiate serv.serv_rf_top instead of serving.
  * Connect the original bus to the extension bus.
  * Connect the "ibus" and "dbus" interface of `serv_rf_top` to the memory system.
  * Both BRAM and DDR3 are mapped starting at address `0x0000_0000`.
  * BRAM has priority over DDR3 (it shadows DDR3 at the same address range).
  * Peripherals are mapped to their original addresses (starting at `0x4000_0000`).

* Generic parameters to set:
  * RESET_PC set to 0x0.
  * COMPRESSED set to 1.
  * MDU set to 0.
  * PRE_REGISTER = 1.
  * RESET_STRATEGY to "MINI"
  * RF_WIDTH to 32.

* Write the build rules to `//boards/rv32_ddr3exec/tool.vivado`.

