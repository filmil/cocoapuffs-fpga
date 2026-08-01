-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;

-- A fake vcomponents package to substitute when needed.
package vcomponents is
    -- making this into a component allows old GHDL to work.
    -- See:
    -- https://github.com/ghdl/ghdl/issues/2766
    component ibufds is
        generic(
            DIFF_TERM: boolean := true;
            IOSTANDARD: string
        );
        port(
            i: in std_logic;
            ib: in std_logic;
            o: out std_logic
        );
    end component;

    -- Fake.
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
end;

library ieee;
use ieee.std_logic_1164.all;

entity ibufds is
    generic(
        DIFF_TERM: boolean := true;
        IOSTANDARD: string
    );
    port(
        i: in std_logic;
        ib: in std_logic;
        o: out std_logic
    );
end entity;

architecture sim of ibufds is

begin
    o <= i;
end architecture;
