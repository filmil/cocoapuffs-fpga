-- SPDX-License-Identifier: Apache-2.0
--! @file
--! @brief A Wishbone UART entity.
library ieee;
use ieee.std_logic_1164.all;
library wb;

--! A Wishbone UART entity.
entity wb_uart is
    generic (
        baud_rate: positive;
        clock_frequency: positive;

        -- The depths of the read and write datapath buffers, in number of
        -- words that will fit.
        fifo_depth: positive := 128;

        uart_address: std_logic_vector(wb.signals.BITS-1 downto 0)
    );
    port (
            clk: in std_logic;
            reset: in std_logic;

            wb_inputs: in wb.signals.o_wb;
            wb_outputs: out wb.signals.i_wb;

             -- UART signals
             tx: out std_logic;
             rx: in std_logic

            --! Asserted when inbound FIFO becomes nonempty, or when outbound
            --! FIFO becomes empty.
            ; irq: out std_ulogic
         );
end entity;
