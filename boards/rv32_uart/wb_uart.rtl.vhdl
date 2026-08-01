-- SPDX-License-Identifier: Apache-2.0

--! @file
--! @brief The top VHDL entity for a wishbone-enabled UART peripheral.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_uart;
use lib_uart.all;
library unisim;
use unisim.vcomponents.all;
library wb;
library wb_uart;

--! The top VHDL entity for a wishbone-enabled UART peripheral.
entity wb_uart_top is
    generic (
        -- Clock generator configuration.
       DIFF_TERM: boolean := true; -- Whether to terminate the differential input.
       IOSTANDARD: string := "LVDS_25"; -- The iostandard to use for internal IBUFDS
        -- UART configuration.
       baud_rate: positive := 115_200; -- Hz
       clock_frequency: positive := 200_000_000; -- Hz (200MHz)
       uart_address: std_logic_vector(31 downto 0) :=  x"4000_0010" -- The 32-bit bus address of the UART.
    );
    port (
            -- differential clock inputs
             sys_clk_p: in std_logic;
             sys_clk_n: in std_logic;

            -- UART ports
             txd: out std_logic;
             rxd: in std_logic;

            -- Wishbone bus connection. Note that the "i" and "o" are with
            -- respect to the wishbone bus host.  So in a peripheral, an "o"
            -- interface will be input, while "i" interface will be output.
            o_wb: in wb.signals.o_wb; -- Signals from bus host to peripheral.
            i_wb: out wb.signals.i_wb; -- Signals from peripheral back to host.


            -- Active low.
             reset_n: in std_logic;

             -- Individual LED control, as an easy way to notice whether things
             -- work as expected.
             led1: out std_logic;
             led2: out std_logic;
             led3: out std_logic;
             led4: out std_logic;

             -- output for the verilog elements
            clk: out std_logic;
            reset: out std_logic
         );
end entity;


architecture rtl of wb_uart_top is

    constant BITS: positive := 28;
    constant MAX_COUNT: unsigned(BITS-1 downto 0) := (others => '1');
    signal count: unsigned(BITS-1 downto 0);
    signal lights: unsigned(3 downto 0);

    -- From unisim.vcomponents.
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

begin

    -- Presumably makes a single-ended signal out of a differential clock.
    ibufds_inst : ibufds
    generic map (
                    DIFF_TERM => DIFF_TERM,
                    IOSTANDARD => IOSTANDARD
                )
    port map (
                 I  => sys_clk_p,  -- Connect to positive input pin
                 IB => sys_clk_n,  -- Connect to negative input pin
                 O  => clk  -- Connect to internal signal
             );

    reset <= not reset_n;

    uart: entity wb_uart.wb_uart -- UART's top
    generic map(
                   baud_rate => baud_rate,
                   clock_frequency => clock_frequency,
                   uart_address =>  uart_address
               )
    port map(
                clk => clk,
                reset => reset,

                wb_inputs => o_wb,
                wb_outputs => i_wb,

                tx => txd,
                rx => rxd
            );

    -- LED pattern used to confirm that the board has been programmed.

    led1 <= not count(BITS-1);
    led2 <= not count(BITS-2);
    led3 <= not count(BITS-3);
    led4 <= reset_n;

    process (clk, reset)
    begin
        if reset = '1' then
            count <= (others => '0');
            lights <= lights + 1;
        elsif rising_edge(clk) then
            if count = MAX_COUNT then
                count <= (others => '0');
                lights <= lights + 1;
            else
                count <= count + 1;
            end if;
        end if;
    end process;

end architecture rtl;

