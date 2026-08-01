-- SPDX-License-Identifier: Apache-2.0

--! @file phy.pkg.vhdl
--! @brief The definitions related to the DDR3 phy.
--!
--! See @ref phy for more details.
library ieee;
use ieee.std_logic_1164.all;

--! @brief The definitions related to the DDR3 phy.
package phy is

    --! Record of bus widths.
    type width_type is record
        --! Address bus width.
        addr: positive;
        --! Bank address bus width.
        ba: positive;
        --! Data mask bus width.
        dm: positive;
        --! Data bus width.
        dq: positive;
        --! Data strobe bus width.
        dqs: positive;
    end record;

    --! Bus widths for a 32-bit bus type.
    constant WIDTH_32B: width_type := (addr => 15, ba => 3, dm => 4, dq => 32, dqs => 4);
    --! Bus widths for a 16-bit bus type.
    constant WIDTH_16B: width_type := (addr => 14, ba => 3, dm => 2, dq => 16, dqs => 2);

end package;

