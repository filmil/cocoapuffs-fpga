-- SPDX-License-Identifier: Apache-2.0

--! @file types.pkg.vhdl
--! @brief Defines the AXI bus signal parameters.
--!
--! The AXI bus signals are subdivided into channels, each gets its separate
--! `record` types.
--! - Address read (AR)
--! - Read data (R)
--! - Address Write (AW)
--! - Write data (W)
--! - Write response (B)
--!
--! In addition, each of the declared types is subdivided into "host" signal
--! set and the "per(ipheral)" signal set, depending on the direction of the
--! signal. This is because VHDL does not support signal direction in
--! interfaces like for example SystemVerilog does.
--! See @ref types for more details.
library ieee;
use ieee.std_logic_1164.all;

--! @brief Defines the AXI bus signal parameters.
package types is

--! Bit widths configuration.
type widths_type is record
    --! Transaction identifier bit width.
    id: positive;
    --! Transaction length field bit width.
    len: positive;
    --! Transaction burst number field bit width.
    burst: positive;
    --! Strobe signal bit width.
    strb: positive;
    --! Response signal bit width.
    resp:positive;
    --! Address signal bit width.
    addr: positive;
    --! Data signal bit width.
    data: positive;
end record;

--! AXI bus signal bit widths.
constant WIDTHS: widths_type := (
    id => 4, len => 8, burst => 2, strb => 4, resp => 2, addr => 32, data => 32);

end package;

