-- SPDX-License-Identifier: Apache-2.0

--! @file clkgen.ent.vhdl
--! @brief A simple clock generator for the A200T board.
--!
--! See @ref clkgen for more details.
library ieee;
use ieee.std_logic_1164.all;

--! @brief A simple clock generator for the A200T board.
entity clkgen is
    port (
        --! The 200MHz input clock.
        clk200MHz: in std_logic;
        --! When `locked = '1'`, this contains a 100MHz clock to use.
        clk100MHz: out std_logic;
        --! Asserted high if the clock generator PLL is locked.
        locked: out std_logic
    );
end entity;
