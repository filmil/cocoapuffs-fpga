-- SPDX-License-Identifier: Apache-2.0

--! @file clkgen_complex.vhdl
--! @brief A complex clock generator for the Xilinx Artix7 device on the A200T board.
--!
--! The input clock is the 200MHz reference clock from the A200T board.
--! See @ref clkgen_complex for more details.
library ieee;
use ieee.std_logic_1164.all;
library unisim;
--! Xilinx components such as IBUF, BUFH, PLLE2_BASE etc.
use unisim.vcomponents.all;

--! @brief A complex clock generator for the Xilinx Artix7 device on the A200T board.
--!
--! The input clock is the 200MHz reference clock from the A200T board. We generate
--! multiple clocks from it.
entity clkgen_complex is
    port (
        --! System input reference clock (200MHz).
        clk200MHz: in std_logic;
        --! 100MHz output clock.
        clkout0: out std_logic;
        --! 400MHz output clock.
        clkout1: out std_logic;
        --! 200MHz output clock.
        clkout2: out std_logic;
        --! 400MHz output clock with +90 degree phase shift.
        clkout3: out std_logic;
        --! 50MHz output clock.
        clkout4: out std_logic;
        --! Asserted high if the clock generator PLL is locked.
        locked: out std_logic
    );
end entity;

architecture xilinx_rtl of clkgen_complex is

    signal clk200MHz_buf: std_logic;
    signal clkfbout_w, clkfbout_buffered_w: std_logic;
    signal pll_clkout0_w, pll_clkout1_w,
        pll_clkout2_w, pll_clkout3_w, pll_clkout4_w: std_logic;

begin

    -- Clock outputs must be clock-buffered. Vivado does not know to infer
    -- clock buffers here.
    clk0_buf: BUFG port map ( I => pll_clkout0_w, O => clkout0 );
    clk1_buf: BUFG port map ( I => pll_clkout1_w, O => clkout1 );
    clk2_buf: BUFG port map ( I => pll_clkout2_w, O => clkout2 );
    clk3_buf: BUFG port map ( I => pll_clkout3_w, O => clkout3 );
    clk4_buf: BUFG port map ( I => pll_clkout4_w, O => clkout4 );

    ibuf_in: IBUF
    port map (
        I => clk200MHz,
        O => clk200MHz_buf
    );

    clock_generator: PLLE2_BASE
    generic map (
        BANDWIDTH            => "OPTIMIZED",
        CLKFBOUT_PHASE => 0.0,
        CLKIN1_PERIOD => 5.0, -- 200MHz
        CLKFBOUT_MULT => 6, -- Vco = 1200MHz

        CLKOUT0_DIVIDE => 12, -- CLK0=100MHz
        CLKOUT1_DIVIDE => 3, -- CLK0=400MHz
        CLKOUT2_DIVIDE => 6, -- CLK0=200MHz
        CLKOUT3_DIVIDE => 3, -- CLK0=400MHz
        CLKOUT4_DIVIDE => 30, -- CLK4=40MHz (was 24=50MHz; lowered so the RV64 GP core meets timing)

        CLKOUT0_DUTY_CYCLE => 0.5,
        CLKOUT1_DUTY_CYCLE => 0.5,
        CLKOUT2_DUTY_CYCLE => 0.5,
        CLKOUT3_DUTY_CYCLE => 0.5,
        CLKOUT4_DUTY_CYCLE => 0.5,

        CLKOUT0_PHASE => 0.0,
        CLKOUT1_PHASE => 0.0,
        CLKOUT2_PHASE => 0.0,
        CLKOUT3_PHASE => 90.0, -- 90 degrees shift for DDR3
        CLKOUT4_PHASE => 0.0,

        DIVCLK_DIVIDE => 1,
        REF_JITTER1 => 0.0,
        STARTUP_WAIT => "TRUE"
    )
    port map (
        CLKFBOUT => clkfbout_w,
        CLKOUT0 => pll_clkout0_w, --
        CLKOUT1 => pll_clkout1_w,
        CLKOUT2 => pll_clkout2_w,
        CLKOUT3 => pll_clkout3_w,
        CLKOUT4 => pll_clkout4_w,
        CLKOUT5 => open,
        LOCKED => locked,
        PWRDWN => '0',
        RST => '0',
        CLKIN1 => clk200MHz_buf,
        CLKFBIN => clkfbout_buffered_w
    );

    fb_buf: BUFG
    port map (
        I => clkfbout_w,
        O => clkfbout_buffered_w
    );

end architecture;

