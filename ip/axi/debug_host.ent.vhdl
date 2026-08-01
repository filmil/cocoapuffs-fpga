-- SPDX-License-Identifier: Apache-2.0

--! @file debug_host.ent.vhdl
--! @brief AXI debug host.
--!
--! See @ref debug_host for more details.
library ieee;
use ieee.std_logic_1164.all;
use work.types.WIDTHS;

--! @brief An entity that allows debugging the AXI host bus.
entity debug_host is
    port(
        --! The AXI host bus to debug.
        i: in work.host.bus_type
    );
end entity;

architecture tb of debug_host is

    signal aw_valid: std_ulogic;
    signal aw_addr: std_ulogic_vector(WIDTHS.addr-1 downto 0);
    signal aw_id: std_ulogic_vector(WIDTHS.id-1 downto 0);
    signal aw_len: std_ulogic_vector(WIDTHS.len-1 downto 0);
    signal aw_burst: std_ulogic_vector(WIDTHS.burst-1 downto 0);

    signal w_valid: std_ulogic;
    signal w_data: std_ulogic_vector(WIDTHS.data-1 downto 0);
    signal w_strb: std_ulogic_vector(WIDTHS.strb-1 downto 0);
    signal w_last: std_ulogic;

    signal b_ready: std_ulogic;

    signal ar_valid: std_ulogic;
    signal ar_addr: std_ulogic_vector(WIDTHS.addr-1 downto 0);
    signal ar_id: std_ulogic_vector(WIDTHS.id-1 downto 0);
    signal ar_len: std_ulogic_vector(WIDTHS.len-1 downto 0);
    signal ar_burst: std_ulogic_vector(WIDTHS.burst-1 downto 0);

    signal r_ready: std_ulogic;

begin

    aw_valid <= i.aw.valid;
    aw_addr <= i.aw.addr;
    aw_id <= i.aw.id;
    aw_len <= i.aw.len;
    aw_burst <= i.aw.burst;

    w_valid <= i.w.valid;
    w_data <= i.w.data;
    w_strb <= i.w.strb;
    w_last <= i.w.last;

    b_ready <= i.b.ready;

    ar_valid <= i.ar.valid;
    ar_addr <= i.ar.addr;
    ar_id <= i.ar.id;
    ar_len <= i.ar.len;
    ar_burst <= i.ar.burst;

    r_ready <= i.r.ready;

end architecture;
