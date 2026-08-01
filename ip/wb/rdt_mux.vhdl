-- SPDX-License-Identifier: Apache-2.0

--! @file
--! @brief A Wishbone rdt multiplexer.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.signals.all;

--! A Wishbone rdt multiplexer.
entity rdt_mux is
    port (
        rst: in std_ulogic
        ; input: in rdt_mux_in_t
        ; output: out i_wb
    );
end entity;

architecture rtl of rdt_mux is
    signal output_s: i_wb;

    --
    signal debug_rdt: std_logic_vector(31 downto 0);
    signal debug_ack: std_logic;

begin
    output <= output_s;
    debug_rdt <= output_s.rdt;
    debug_ack <= output_s.ack;

    comb: process(input, rst)
        variable output_v: i_wb;
    begin
        output_v := (ack => '0', rdt => (others => '0') );
        if rst = '0' then
            for i in input'high downto input'low loop
                if input(i).ack = '1' then
                    output_v := (rdt => input(i).rdt, ack => input(i).ack);
                end if;
            end loop;
        end if;
        output_s <= output_v;
    end process;
end architecture;
