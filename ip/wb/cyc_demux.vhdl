-- SPDX-License-Identifier: Apache-2.0

--! @file
--! @brief A Wishbone cycle demultiplexer.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! A Wishbone cycle demultiplexer.
entity cyc_demux is
    generic (
        demux_width: positive := 2
    );
    port (
        cyc: in std_ulogic
        ; sel: in std_ulogic_vector(demux_width-1 downto 0)
        ; cyc_out: out std_ulogic_vector(2**(demux_width)-1 downto 0)
    );
end entity;

architecture rtl of cyc_demux is
begin
    comb: process(cyc, sel)
        variable index: integer;
        variable q: std_ulogic_vector(2**(demux_width)-1 downto 0);
    begin
        index := to_integer(unsigned(sel));
        q := (others => '0');
        if cyc = '1' then
            q(index) := '1';
        end if;
        cyc_out <= q;
    end process;
end architecture;
