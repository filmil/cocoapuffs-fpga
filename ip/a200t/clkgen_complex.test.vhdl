-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
library testing;
library a200t;

entity clkgen_complex_test is
end entity;

architecture tb of clkgen_complex_test is

    signal clk, reset, reset_n: std_logic;
    signal clkout0, clkout1, clkout2, clkout3, locked: std_logic;

begin

    clkgen0: entity testing.clkgen
        generic map (
            --! Simulation will terminate automatically.
            sim_duration => 10 us,
            clock_period => 5 ns -- 200MHz
        )
        port map (
            clk => clk,
            reset => reset,
            reset_n => reset_n
        );

    uut0: entity a200t.clkgen_complex
        port map(
            clk200MHz => clk,
            clkout0 => clkout0,
            clkout1 => clkout1,
            clkout2 => clkout2,
            clkout3 => clkout3,
            locked => locked
        );

end architecture;
