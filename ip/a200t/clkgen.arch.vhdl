-- SPDX-License-Identifier: Apache-2.0

--! @file clkgen.arch.vhdl
--! @brief A simple clock generator for the A200T board.
--!
--! See @ref clkgen for more details.
library ieee;
use ieee.std_logic_1164.all;

architecture xilinx_rtl of clkgen is

    -- Xilinx-specific simple clock generator
    component PLLE2_BASE
    generic (
          -- VCO frequency range: 600 MHz to 1200 MHz
          BANDWIDTH            : string := "OPTIMIZED";  -- OPTIMIZED, HIGH, LOW
          CLKFBOUT_MULT        : integer := 5;          -- Multiply value for feedback clock (2 to 64)
          CLKFBOUT_PHASE       : integer := 0;          -- Phase shift for feedback clock (0 to 360)
          CLKIN1_PERIOD        : real    := 5.0;        -- Input clock period in ns (200 MHz)
          CLKOUT0_DIVIDE       : integer := 10;         -- Divide value for output clock 0 (1 to 128)
          CLKOUT0_DUTY_CYCLE   : real    := 0.5;        -- Duty cycle for output clock 0 (0.0 to 1.0)
          CLKOUT0_PHASE        : integer := 0;          -- Phase shift for output clock 0 (0 to 360)
          DIVCLK_DIVIDE        : integer := 1;          -- Divide value for DIVCLK (1 to 128)
          REF_JITTER1          : real    := 0.01;       -- Reference input jitter in UI
          STARTUP_WAIT         : string  := "FALSE"      -- Delay config until LOCKED is asserted
        );
        port (
          CLKFBIN  : in  std_logic;
          CLKFBOUT : out std_logic;
          CLKIN1   : in  std_logic;
          CLKOUT0  : out std_logic;
          LOCKED   : out std_logic;
          PWRDWN   : in  std_logic := '0';
          RST      : in  std_logic := '0'
        );
    end component;

    signal clkfb: std_logic;

begin

    clock_generator: PLLE2_BASE
    generic map (
      BANDWIDTH            => "OPTIMIZED",
      CLKFBOUT_MULT        => 5,          -- 200 MHz * 5 = 1000 MHz (VCO)
      CLKFBOUT_PHASE       => 0,
      CLKIN1_PERIOD        => 5.0,        -- 200 MHz input clock period
      CLKOUT0_DIVIDE       => 10,         -- 1000 MHz / 10 = 100 MHz
      CLKOUT0_DUTY_CYCLE   => 0.5,
      CLKOUT0_PHASE        => 0,
      DIVCLK_DIVIDE        => 1,
      REF_JITTER1          => 0.01,
      STARTUP_WAIT         => "FALSE"
    )
    port map (
      CLKFBIN  => clkfb,
      CLKFBOUT => clkfb,
      CLKIN1   => clk200Mhz,
      CLKOUT0  => clk100Mhz,
      LOCKED   => locked,
      PWRDWN   => '0',
      RST      => '0'
    );


end architecture;
