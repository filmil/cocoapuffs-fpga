-- SPDX-License-Identifier: Apache-2.0
-- See LICENSE file.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library wb_uart;

library wb;
use wb.signals;

library testing;

entity wb_uart_tb is
end entity;

architecture tb of wb_uart_tb is
    signal clk, reset: std_logic;
    signal tx, rx: std_logic;

    constant address: std_logic_vector := x"8888FFFF";
    constant reset_duration: time := 10 ns;
    constant sim_duration: time := 1 ms;

    constant clock_frequency_hz: positive := 200_000_000;
    constant clock_period: time := 1.0e9/real(clock_frequency_hz) * 1 ns;
    constant baud_rate_hz: positive := 1_000_000;
    constant bit_period: time := 1 ns* 1.0e9/real(baud_rate_hz);

    signal wb_o: signals.o_wb := signals.o_wb_new;
    signal wb_i: signals.i_wb := signals.i_wb_new;


begin

    -- clock and reset generator
    clkgen: entity testing.clkgen
        generic map(
            clock_period => 5 ns,
            reset_duration => reset_duration,
            sim_duration => sim_duration
        )
        port map(
            clk => clk,
            reset => reset
        );

    uut: entity wb_uart.wb_uart
        generic map(
            baud_rate => baud_rate_hz,
            clock_frequency => clock_frequency_hz,
            uart_address => address
        )
        port map(
            clk => clk,
            reset => reset,

            wb_inputs => wb_o,
            wb_outputs => wb_i,

            tx => tx,
            rx => rx
        );

    -- Receiving
    test: process
        variable tx: signals.o_wb := signals.o_wb_new;
    begin
        rx <= '1';
        wait for reset_duration;
        testing.uart.send_string(bit_period, "Hello world!", rx);
        wait for 100 * reset_duration;

        -- read transaction
        wait until rising_edge(clk);
        tx := (
            adr => address,
            dat => (others => 'X'),
            sel => "0001",
            we => '0',
            cyc => '1'
         );
        testing.wb_tb.send_tx(clk, tx, wb_o);
        wait until rising_edge(wb_i.ack);

        tx.cyc := '0'; tx.sel := (others => '0');
        testing.wb_tb.send_tx(clk, tx, wb_o);

        tx.cyc := '1'; tx.sel := "0001";
        testing.wb_tb.send_tx(clk, tx, wb_o);
        wait until rising_edge(wb_i.ack);

        tx.cyc := '0'; tx.sel := (others => '0');
        testing.wb_tb.send_tx(clk, tx, wb_o) ;
        wait until rising_edge(clk);

        -- now make some write transactions.
        testing.wb_tb.send_string(address, clk, "Hello world!", wb_i, wb_o);

        -- Wait until the rest of the simulation completes.
        wait;
    end process;

end architecture;

