-- SPDX-License-Identifier: Apache-2.0

--! @brief Push-button / asynchronous-input debouncer.
--!
--! Synchronizes a raw, asynchronous, mechanically-bouncing input (e.g. a board
--! push-button) to `clk` and only propagates a new level after it has been
--! stable for 2**count_bits clock cycles. Without this a raw key would
--! oscillate and re-trigger edge-sensitive consumers many times per press.
--!
--! Polarity-agnostic: `clean` simply follows a debounced `raw`. The consumer
--! (or the board) applies any active-low inversion.
library ieee;
use ieee.std_logic_1164.all;

entity debouncer is
    generic (
        --! Debounce window, in clk cycles, is 2**count_bits
        --! (e.g. 20 -> ~21 ms @ 50 MHz).
        count_bits : positive := 20
    );
    port (
        --! Clock; everything is synchronous to its rising edge.
        clk   : in  std_ulogic;
        --! Active-low synchronous reset.
        rstn  : in  std_ulogic;
        --! Raw, possibly bouncing / asynchronous input.
        raw   : in  std_ulogic;
        --! Debounced, clk-synchronous output (follows `raw` once stable).
        clean : out std_ulogic
    );
end entity;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

architecture rtl of debouncer is
    --! Two-FF synchronizer for the asynchronous input (`sync(1)` is the
    --! metastability-settled, clk-domain copy of `raw`).
    signal sync    : std_ulogic_vector(1 downto 0);
    --! Stability counter: counts cycles for which `sync(1)` differs from the
    --! currently committed level.
    signal cnt     : unsigned(count_bits-1 downto 0);
    --! Currently committed (debounced) output level.
    signal clean_r : std_ulogic;
begin
    clean <= clean_r;

    --! Synchronize, then commit a new level only after the full stable window.
    process(clk) is
    begin
        if rising_edge(clk) then
            if rstn = '0' then
                sync    <= (others => '0');
                cnt     <= (others => '0');
                clean_r <= '0';
            else
                sync <= sync(0) & raw;        --! shift `raw` through the synchronizer
                if sync(1) = clean_r then
                    --! Input already matches the committed level: hold counter reset.
                    cnt <= (others => '0');
                elsif cnt = to_unsigned(2**count_bits - 1, count_bits) then
                    --! Input has differed for the full window: commit the new level.
                    clean_r <= sync(1);
                    cnt     <= (others => '0');
                else
                    cnt <= cnt + 1;
                end if;
            end if;
        end if;
    end process;
end architecture;
