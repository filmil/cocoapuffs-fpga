-- SPDX-License-Identifier: Apache-2.0

--! @file clk.vhdl
--! @brief Contains the `clk` entity for differential clock generation.
--!
--! See @ref clk for more details.

library ieee;
use ieee.std_logic_1164.all;

--! @brief differential clock generation for the Artix 7 on A200T.
--!
--! Takes the hardware clock provided by the Alinx board (200MHz oscillator),
--! and adapts for internal use.  You may need to condition the clock further,
--! such as pass it through PLL hardware to create clocks with other
--! clock periods.
entity clk is
    generic(
        --! Differential driver. Normally this should not be changed.
        diff_term: string := "FALSE";
        --! Differential driver I/O standard is low-voltage differential
        --! at 1.5 volts. Normally this should not be changed.
        iostandard: string := "DIFF_SSTL15"
    );
    port(
        --! 200MHz input differential clock.
        clk_p: in std_logic;
        --! 200MHz input differential clock, inverse signal.
        clk_n: in std_logic;
        --! 200Mhz output single-ended clock for internal use.
        clk: out std_logic
    );

end entity;

--! The `clk` implementation for the Xilinx chips.
architecture xilinx_rtl of clk is

    -- Xilinx-specific clock buffer primitive.
    component IBUFDS is
        generic(
            DIFF_TERM: string := diff_term;
            IOSTANDARD: string
        );
        port(
            I: in std_logic;
            IB: in std_logic;
            O: out std_logic
        );
    end component;

begin

    ibufds_inst: IBUFDS
    generic map (
        DIFF_TERM => diff_term,
        IOSTANDARD => iostandard
    )
    port map (
     I  => clk_p,
     IB => clk_n,
     O  => clk
 );

end architecture;

