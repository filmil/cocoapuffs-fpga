-- SPDX-License-Identifier: Apache-2.0

--- A testbench version of a UART that connects to Wishbone.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library lib_uart;
use lib_uart.all;
library unisim;
use unisim.vcomponents.all;
library wb;
library wb_uart;

architecture sim of vhdl_top is

    constant BITS: positive := 28;
    constant MAX_COUNT: unsigned(BITS-1 downto 0) := (others => '1');
    signal count: unsigned(BITS-1 downto 0);
    signal  lights: unsigned(3 downto 0);

    -- Needs to be routed out.
    signal o_wb: wb.signals.o_wb;
    signal i_wb: wb.signals.i_wb;

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

begin

    reset <= not reset_n;
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
                 O  => clk  -- Connect to internal signal
             );

    uart: entity wb_uart.wb_uart -- UART's top
    generic map(
                   baud_rate => baud_rate, -- Hz
                   clock_frequency => clock_frequency, -- Hz (200MHz)
                   uart_address =>  uart_address
               )
    port map(
                clk => clk,
                reset => reset,

                wb_inputs => o_wb,
                wb_outputs => i_wb,

                tx => uart1_txd,
                rx => uart1_rxd
            );

    -- LED pattern

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

end architecture;

