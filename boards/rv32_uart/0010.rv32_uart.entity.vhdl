-- SPDX-License-Identifier: Apache-2.0

--! @file
--! @brief Testbench top for a Wishbone UART.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_uart;
use lib_uart.all;
library unisim;
use unisim.vcomponents.all;
library wb;
library wb_uart;

--! A testbench version of a UART that connects to Wishbone.
entity vhdl_top is
    generic(
                   clock_frequency: positive := 50_000_000;
                   uart_address: std_logic_vector :=  x"4000_0010";
                   baud_rate: positive := 115_200
    );
    port (
             sys_clk_p: in std_logic;
             sys_clk_n: in std_logic;
             uart1_txd: out std_logic;
             uart1_rxd: in std_logic;

            -- Active low.
             reset_n: in std_logic;

             led1: out std_logic;
             led2: out std_logic;
             led3: out std_logic;
             led4: out std_logic;

             -- output for the verilog elements
            clk: out std_logic;
            reset: out std_logic;

            -- wishbone, unpacked because of the Verilog conversion. Sigh.
            adr: in std_logic_vector(wb.signals.BITS-1 downto 0);
            dat: in std_logic_vector(wb.signals.BITS-1 downto 0);
            sel: in std_logic_vector(wb.signals.BYTES-1 downto 0);
            we: in std_logic;
            cyc: in std_logic;

            rdt: out std_logic_vector(wb.signals.BITS-1 downto 0);
            ack: out std_logic

         );
end entity;

