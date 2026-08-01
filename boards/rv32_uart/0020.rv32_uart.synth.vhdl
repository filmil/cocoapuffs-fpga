-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library third_party_uart;
use third_party_uart.all;
library unisim;
use unisim.vcomponents.all;
library wb;
library wb_uart;

-- Synthesis architecture.
architecture synth of vhdl_top is

    constant BITS: positive := 28;
    constant MAX_COUNT: unsigned(BITS-1 downto 0) := (others => '1');
    signal count: unsigned(BITS-1 downto 0);
    signal  lights: unsigned(3 downto 0);

    -- Needs to be routed out.
    signal o_wb: wb.signals.o_wb;
    signal i_wb: wb.signals.i_wb;
    signal clk_internal: std_logic;
    signal reset_internal: std_logic;

    -- Xilinx primitive.
    component IBUFDS is
        generic(
            DIFF_TERM: boolean := true;
            IOSTANDARD: string
        );
        port(
            I: in std_logic;
            IB: in std_logic;
            O: out std_logic
        );
    end component;

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

    signal clkin, locked: std_logic;

    -- Feedback clock.
    signal clkfb: std_logic;

begin

    reset <= (not reset_n) or (not locked);
    o_wb <=  (
        adr => adr,
        dat => dat,
        sel => sel,
        we => we,
        cyc => cyc
    );
    rdt <= i_wb.rdt;
    ack <= i_wb.ack;

    -- Presumably makes a single-ended signal out of a differential clock.
    ibufds_inst : IBUFDS
    generic map (
                    DIFF_TERM => true,
                    IOSTANDARD => "LVDS_25" -- Example I/O standard
                )
    port map (
                 I  => sys_clk_p,  -- Connect to positive input pin
                 IB => sys_clk_n,  -- Connect to negative input pin
                 O  => clkin  -- Connect to internal signal
             );

    clock_generator: PLLE2_BASE
    generic map (
      BANDWIDTH            => "OPTIMIZED",
      CLKFBOUT_MULT        => 5,          -- 200 MHz * 5 = 1000 MHz (VCO)
      CLKFBOUT_PHASE       => 0,
      CLKIN1_PERIOD        => 5.0,        -- 200 MHz input clock period
      CLKOUT0_DIVIDE       => 20,         -- 1000 MHz / 10 = 100 MHz
      CLKOUT0_DUTY_CYCLE   => 0.5,
      CLKOUT0_PHASE        => 0,
      DIVCLK_DIVIDE        => 1,
      REF_JITTER1          => 0.01,
      STARTUP_WAIT         => "FALSE"
    )
    port map (
      CLKFBIN  => clkfb,
      CLKFBOUT => clkfb,
      CLKIN1   => clkin,                -- 200 MHz input clock
      CLKOUT0  => clk,               -- 100 MHz output clock
      LOCKED   => locked,
      PWRDWN   => '0',
      RST      => '0'
    );


    uart: entity wb_uart.wb_uart -- UART's top
    generic map(
                   baud_rate => baud_rate,
                   clock_frequency => clock_frequency,
                   uart_address => uart_address
               )
    port map(
                clk => clk_internal,
                reset => reset_internal,

                wb_inputs => o_wb,
                wb_outputs => i_wb,

                tx => uart1_txd,
                rx => uart1_rxd
            );

    -- LED pattern

    led1 <= not count(BITS-1);
    led2 <= not count(BITS-2);
    led3 <= not count(BITS-3);
    led4 <= not reset_internal;
    clk <= clk_internal;
    reset <= reset_internal;

    process (clk_internal, reset_internal, lights)
    begin
        if reset_internal = '1' then
            count <= (others => '0');
            lights <= lights + 1;
        elsif rising_edge(clk_internal) then
            if count = MAX_COUNT then
                count <= (others => '0');
                lights <= lights + 1;
            else
                count <= count + 1;
            end if;
        end if;
    end process;

end architecture;

