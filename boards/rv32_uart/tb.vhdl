-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library rv32_uart;
library testing;
library wb;
library wb_uart;

-- Entity that is the top of the VHDL code.  We still need to connect this to
-- Verilog.
entity tb is
    port (
            wb_inputs: in wb.signals.o_wb;
            wb_outputs: out wb.signals.i_wb;

            -- UART ports
            txd: out std_logic;
            rxd: in std_logic;

            -- output for the verilog elements
            clk: in std_logic;
            reset: in std_logic
         );
end entity;

architecture sim of tb is

    constant wb_word_size: positive := wb.signals.BITS;
    subtype wb_word is std_logic_vector(wb_word_size-1 downto 0);

    constant baud_rate: positive := 115200;
    constant uart_address: wb_word := X"40000010";
    constant clock_frequency: positive := 200_000_000; -- 200Mhz
    constant clock_period: time := real(1e+9)/real(clock_frequency) * 1 ns; -- ~5ns

begin

    uart_1: entity wb_uart.wb_uart
        generic map (
            baud_rate => baud_rate,
            clock_frequency => clock_frequency,
            uart_address => uart_address
        )
        port map (
            clk => clk,
            reset => reset,
            wb_inputs => wb_inputs,
            wb_outputs => wb_outputs,

            tx => txd,
            rx => rxd
        );

end architecture;

