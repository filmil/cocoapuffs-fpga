-- SPDX-License-Identifier: Apache-2.0

--! @file
--! @brief Xilinx-specific components.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package xilinx is

    --! A Xilinx specific clock generator.
    component clkgen is
    port (
        --! Input clock.
        clkin: in std_ulogic;
        --! Output clock.
        clkout: out std_ulogic;
        --! Whether the clock is locked.
        locked: out std_ulogic
    );
    end component;

end package;
