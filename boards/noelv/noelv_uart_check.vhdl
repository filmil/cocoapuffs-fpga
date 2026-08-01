-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_check is
    generic (
        baud_rate : positive;
        target_string : string;
        sim_duration : time
    );
    port (
        clk : in std_logic;
        rx : in std_logic;
        success : out boolean := false
    );
end entity;

architecture sim of uart_check is
    constant bit_period : time := 1.0 / real(baud_rate) * 1 sec;
    signal received_char : std_logic_vector(7 downto 0);
    signal char_ready : boolean := false;
begin

    process
        variable data : std_logic_vector(7 downto 0);
    begin
        loop
            -- Wait for start bit (falling edge)
            wait until falling_edge(rx);
            wait for bit_period / 2;
            if rx = '0' then
                -- Sample 8 bits
                for i in 0 to 7 loop
                    wait for bit_period;
                    data(i) := rx;
                end loop;
                -- Wait for stop bit
                wait for bit_period;
                received_char <= data;
                char_ready <= true;
                wait for 1 ns;
                char_ready <= false;
            end if;
        end loop;
    end process;

    process
        variable match_idx : integer := 1;
        variable current_target : string(1 to target_string'length) := target_string;
    begin
        loop
            wait until char_ready;
            report "UART received: " & character'val(to_integer(unsigned(received_char)));
            if character'val(to_integer(unsigned(received_char))) = current_target(match_idx) then
                if match_idx = current_target'length then
                    report "SUCCESS: Found target string '" & target_string & "'";
                    success <= true;
                    wait;
                else
                    match_idx := match_idx + 1;
                end if;
            else
                match_idx := 1; -- Reset on mismatch
                -- Check if the mismatching char is the first char of target
                if character'val(to_integer(unsigned(received_char))) = current_target(1) then
                    match_idx := 2;
                end if;
            end if;
        end loop;
    end process;

end architecture;
