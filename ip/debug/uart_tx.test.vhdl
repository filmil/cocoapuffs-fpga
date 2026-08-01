-- SPDX-License-Identifier: Apache-2.0

--! @brief NVC unit test for uart_tx: transmit a byte and decode the serial
--! frame (start + 8 data LSB-first + stop), checking the byte round-trips.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library debug;

entity uart_tx_test_tb is
end entity;

architecture sim of uart_tx_test_tb is
    --! 1 MHz clock, 250 kbaud -> div = 4 cycles/bit -> 4 us/bit. Short sim.
    constant clk_freq_hz : positive := 1_000_000;
    constant baud_rate   : positive := 250_000;
    constant clk_period  : time     := 1 us;
    constant bit_time    : time     := 4 us;

    signal clk   : std_ulogic := '0';
    signal rstn  : std_ulogic := '0';
    signal data  : std_ulogic_vector(7 downto 0) := (others => '0');
    signal valid : std_ulogic := '0';
    signal ready : std_ulogic;
    signal tx    : std_ulogic;
begin
    clk  <= not clk after clk_period/2;
    rstn <= '0', '1' after 5 us;

    --! Safety timeout.
    watchdog: process is
    begin
        wait for 500 us;
        assert false report "uart_tx_test timeout" severity failure;
    end process;

    uut: entity debug.uart_tx
        generic map (clk_freq_hz => clk_freq_hz, baud_rate => baud_rate)
        port map (clk => clk, rstn => rstn, data => data,
                  valid => valid, ready => ready, tx => tx);

    test: process is
        variable got : std_ulogic_vector(7 downto 0);
    begin
        wait until rstn = '1';
        wait until rising_edge(clk);

        --! Offer a byte. Arm the start-bit wait while the line is still idle
        --! (tx = '1') so we lock onto the real start bit, not a later data '0'.
        data  <= x"41";                 --! 'A' = 0100_0001
        valid <= '1';
        wait until tx = '0';            --! start bit (tx falls when loaded)
        valid <= '0';                   --! transmitter is busy now; don't re-send

        --! Decode the serial frame: sample at mid-bit, LSB first.
        wait for bit_time + bit_time/2; --! middle of data bit 0
        for i in 0 to 7 loop
            got(i) := tx;               --! LSB first
            wait for bit_time;
        end loop;
        assert tx = '1' report "stop bit must be high" severity failure;
        assert got = x"41"
            report "uart_tx byte mismatch" severity failure;

        report "uart_tx_test PASS";
        std.env.finish;
    end process;
end architecture;
