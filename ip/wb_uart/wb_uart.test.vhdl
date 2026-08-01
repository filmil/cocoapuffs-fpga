-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library wb_uart;

library wb;
use wb.signals;

library testing;

entity wb_uart_test_tb is
end entity;

architecture sim of wb_uart_test_tb is

    signal clk, reset: std_logic;
    signal tx_uut1_to_uut2, rx_uut1_to_uut2: std_logic;

    constant address: std_logic_vector := x"8888FFFF";
    constant reset_duration: time := 10 ns;
    constant sim_duration: time := 150 us;
    constant clock_frequency_hz: positive := 200_000_000;
    constant clock_period: time := 1.0e9/real(clock_frequency_hz) * 1 ns;
    constant baud_rate_hz: positive := 1_000_000;

    constant bit_period: time := 1 ns* 1.0e9/real(baud_rate_hz);

    signal o_wb: signals.o_wb := signals.o_wb_new;
    signal i_wb: signals.i_wb := signals.i_wb_new;

    signal o_wb_2: signals.o_wb := signals.o_wb_new;
    signal i_wb_2: signals.i_wb := signals.i_wb_new;
begin

    -- clock and reset generator
    clkgen: entity testing.clkgen
        generic map(
            clock_period => 5 ns,
            reset_duration => reset_duration
        )
        port map(
            clk => clk,
            reset => reset
        );


    uut1: entity wb_uart.wb_uart
        generic map(
            baud_rate => baud_rate_hz,
            clock_frequency => clock_frequency_hz,
            uart_address => address
        )
        port map(
            clk => clk,
            reset => reset,

            wb_inputs => o_wb,
            wb_outputs => i_wb,

            tx => tx_uut1_to_uut2,
            rx => rx_uut1_to_uut2
        );

    uut2: entity wb_uart.wb_uart
        generic map(
            baud_rate => baud_rate_hz,
            clock_frequency => clock_frequency_hz,
            -- OK to reuse the uart peripheral adderss here.
            uart_address => address
        )
        port map(
            clk => clk,
            reset => reset,

            wb_inputs => o_wb_2,
            wb_outputs => i_wb_2,

            -- Note the tx and rx are flipped around here.
            tx => rx_uut1_to_uut2,
            rx => tx_uut1_to_uut2
        );

    test: process
        variable line: string(1 to 1024);
        constant timeout: time := sim_duration;
    begin
        wait for 2*reset_duration;

        wait until rising_edge(clk);
        testing.wb_tb.send_string(address, clk, "Hello world!", i_wb, o_wb);
        testing.wb_tb.receive_string_until(
            line,
            address,
            timeout,
            clk,
            i_wb_2,
            o_wb_2
        );

       testing.asserts.eq(line, "Hello world!");
       std.env.finish;
    end process;


end architecture;

