-- SPDX-License-Identifier: Apache-2.0
-- See LICENSE file.
library ieee;
use ieee.std_logic_1164.all;

--! Generates clock and reset signals for simulations.
entity clkgen is
    generic (
        --! The requested clock period.
        clock_period: time := 5 ns;
        --! The duration after which to stop the simulation. If left unset,
        --! then you must explicitly stop the simulation from elsewhere.
        sim_duration: time := 0 us;
        --! The duration of the reset signal after sim startup.
        reset_duration: time := 10 ns
    );
    port (
        --! The generated output clock signal.
        clk: out std_logic;
        --! The reset signals generated.
        reset, reset_n: out std_logic
    );
end entity;

architecture tb of clkgen is

    signal s_reset: std_logic;

begin

    reset <= s_reset;
    reset_n <= not s_reset;
    rstgen: process
    begin
        s_reset <= '1';
        wait for reset_duration;
        s_reset <= '0';
        wait;
    end process;

    clkgen_proc: process
        constant half_period: time := clock_period / 2.0;
    begin
        clk <= '0';
        wait for 1 ns;

        while true loop
            clk <= '1';
            wait for half_period;
            clk <= '0';
            wait for half_period;
        end loop;
    end process;

    stop_sim: process
    begin
        wait for sim_duration;
        if sim_duration /= 0 ns then
            std.env.stop;
        end if;
    end process stop_sim;

end architecture;
