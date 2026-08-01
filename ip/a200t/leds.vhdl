-- SPDX-License-Identifier: Apache-2.0

--! @file leds.vhdl
--! @brief Simple LED driver for the A200T board.
--!
--! See @ref leds for more details.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @brief An entity that drives the LEDs on the A200T board.
entity leds is
    port (
        --! The input clock.
        clk: in std_ulogic;
        --! Whether the `clk` signal is locked in phase.
        locked: in std_ulogic;
        --! Raw reset signal from the board (active low).
        reset_n: in std_ulogic;
        --! LED driver signals (active low).
        led1, led2, led3, led4: out std_ulogic;
        --! Conditioned reset signal (active high).
        reset: out std_ulogic
    );
end entity;

architecture rtl of leds is

    constant BITS: positive := 28;
    constant MAX_COUNT: unsigned(BITS-1 downto 0) := (others => '1');

    signal clk_internal, reset_internal: std_ulogic;
    signal count: unsigned(BITS-1 downto 0);

begin

    led1 <= not count(BITS-1);
    led2 <= not count(BITS-2);
    led3 <= not count(BITS-3);
    led4 <= not reset_internal;

    clk_internal <= clk;
    reset_internal <= (not reset_n) or (not locked);
    reset <= reset_internal;

    process (clk_internal, reset_internal)
    begin
        if reset_internal = '1' then
            count <= (others => '0');
        elsif rising_edge(clk_internal) then
            if count = MAX_COUNT then
                count <= (others => '0');
            else
                count <= count + 1;
            end if;
        end if;
    end process;

end architecture;

