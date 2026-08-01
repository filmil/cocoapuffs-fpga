-- SPDX-License-Identifier: Apache-2.0

--! @file uart.vhdl
--! @brief UART for the A200T board.
--!
--! See @ref uart for more details.
library ieee;
use ieee.std_logic_1164.all;
library wb;
library wb_uart;

--! @brief An entity that provides a UART interface for the A200T board.
entity uart is
    generic(
        baud_rate: positive := 115_200; --!< The baud rate in Hz.
        --! The clock frequency in Hz.
        clock_frequency: positive := 200_000_000;
        --! The 32-bit bus address of the UART.
        uart_address: std_logic_vector(31 downto 0) :=  x"4000_0010"
    );
    port(
        --! The UART transmit signal.
        txd: out std_logic;
        --! The UART receive signal.
        rxd: in std_logic;

        --! The Wishbone signals from the bus host to the peripheral.
        o_wb: in wb.signals.o_wb;
        --! The Wishbone signals from the peripheral back to the host.
        i_wb: out wb.signals.i_wb;

        --! The clock and reset signals.
        clk, reset: in std_ulogic;

        --! The interrupt request signal.
        irq: out std_ulogic
    );
end entity;

architecture rtl of uart is

begin

    uart: entity wb_uart.wb_uart
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
        , irq => irq
    );

end architecture;
