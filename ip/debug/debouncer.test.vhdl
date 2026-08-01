-- SPDX-License-Identifier: Apache-2.0

--! @brief NVC unit test for the debouncer: it must reject bounces and only
--! commit a new level after the input has been stable for the full window.
library ieee;
use ieee.std_logic_1164.all;

library debug;

entity debouncer_test_tb is
end entity;

architecture sim of debouncer_test_tb is
    --! Small debounce window (8 cycles) to keep the simulation short.
    constant count_bits  : positive := 3;
    --! Clock half-period.
    constant half_period : time := 5 ns;

    signal clk   : std_ulogic := '0';
    signal rstn  : std_ulogic := '0';
    signal raw   : std_ulogic := '0';
    signal clean : std_ulogic;
begin
    --! Free-running clock.
    clk <= not clk after half_period;

    --! Power-on reset, released after a few cycles.
    rstn <= '0', '1' after 40 ns;

    --! Safety timeout so a hung test fails instead of running forever.
    watchdog: process is
    begin
        wait for 50 us;
        assert false report "debouncer_test timeout" severity failure;
    end process;

    --! Device under test.
    uut: entity debug.debouncer
        generic map (count_bits => count_bits)
        port map (clk => clk, rstn => rstn, raw => raw, clean => clean);

    --! Stimulus + checks.
    test: process is
    begin
        wait until rstn = '1';
        wait until rising_edge(clk);

        --! Idle low: clean stays low.
        raw <= '0';
        for i in 0 to 12 loop wait until rising_edge(clk); end loop;
        assert clean = '0' report "clean must be 0 at idle" severity failure;

        --! Bounce: toggle faster than the window. clean must NOT assert.
        raw <= '1'; wait until rising_edge(clk);
        raw <= '0'; wait until rising_edge(clk);
        raw <= '1'; wait until rising_edge(clk);
        raw <= '0'; wait until rising_edge(clk);
        raw <= '1'; wait until rising_edge(clk);
        raw <= '0'; wait until rising_edge(clk);
        assert clean = '0'
            report "clean must not oscillate/assert during a bounce" severity failure;

        --! Stable high beyond the window: clean must commit to 1.
        raw <= '1';
        for i in 0 to 20 loop wait until rising_edge(clk); end loop;
        assert clean = '1'
            report "clean must be 1 after a stable-high input" severity failure;

        --! Stable low beyond the window: clean must commit back to 0.
        raw <= '0';
        for i in 0 to 20 loop wait until rising_edge(clk); end loop;
        assert clean = '0'
            report "clean must be 0 after a stable-low input" severity failure;

        report "debouncer_test PASS";
        std.env.finish;
    end process;
end architecture;
