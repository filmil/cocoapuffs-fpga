-- SPDX-License-Identifier: Apache-2.0

--! @file dfi.pkg.vhdl
--! @brief Declarations of ddr3 types.
--!
--! See @ref dfi for more details.
library ieee;
use ieee.std_logic_1164.all;

--! @brief Declarations of ddr3 types.
package dfi is

    --! Records the bit-widths of each of the bus signals.
    --!
    --! This allows easy generation of types for different bit widths.
    --!
    --! ```
    --! -- Declares a 32-bit dfi input type.
    --! variable foo: in_type := new_in_type(B32);
    --! ```
    type widths_type is record
        rddata: positive;
        rddata_dnv: positive;
        address: positive;
        wrdata: positive;
        wrdata_mask: positive;
        bank: positive;
    end record;

    --! 32-bit bus signals widths
    constant B32: widths_type := (
        rddata => 32,
        rddata_dnv => 2,
        address => 15,
        wrdata => 32,
        wrdata_mask => 32/8, -- 4 mask bits, one per each byte of data.
        bank => 3
    );

end package;

