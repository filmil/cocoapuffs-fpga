-- SPDX-License-Identifier: Apache-2.0
-- See LICENSE file.
library ieee;
use ieee.std_logic_1164.all;

-- A200T peripheral simulation model that generates a 200 MHz differential input
-- clock.
entity clk is
    generic (
        clock_period: time := 5 ns; -- 200MHz.
        mgt_clock_period: time := 8 ns; -- 125MHz.
        sim_duration: time := 0 us;
        reset_duration: time := 10 ns
    );
    port (
        -- Differential clock output.
        clk, clk_n: out std_ulogic;
        mgt_clk, mgt_clk_n: out std_ulogic;

        -- Reset generator signal.
        reset, reset_n: out std_ulogic
    );
end entity;

architecture tb of clk is

    signal s_reset: std_ulogic := '1';
    signal s_clk: std_ulogic;
    signal s_mgt_clk: std_ulogic;

begin

    reset_n <= not s_reset;
    reset <= s_reset;

    clk <= s_clk;
    clk_n <= not s_clk;

    rstgen: process
    begin
        s_reset <= '1';
        wait for reset_duration;
        s_reset <= '0';
        wait;
    end process;

    clk_proc: process
        constant half_period: time := clock_period / 2.0;
    begin
        s_clk <= '0';
        wait for 1 ns;

        while true loop
            s_clk <= '1';
            wait for half_period;
            s_clk <= '0';
            wait for half_period;
        end loop;
    end process;

    mgt_clk <= s_mgt_clk;
    mgt_clk_n <= not s_mgt_clk;
    mgt_clk_proc: process
        constant half_period: time := mgt_clock_period / 2.0;
    begin
        s_mgt_clk <= '0';
        wait for 1 ns;

        while true loop
            s_mgt_clk <= '1';
            wait for half_period;
            s_mgt_clk <= '0';
            wait for half_period;
        end loop;
    end process;


    stop_sim: process
    begin
        report "sim_duration is " & time'image(sim_duration);
        if sim_duration /= 0 ns then
            wait for sim_duration;
            report "Simulation limit reached. Stopping.";
            std.env.stop;
        end if;
        wait;
    end process stop_sim;

end architecture;
