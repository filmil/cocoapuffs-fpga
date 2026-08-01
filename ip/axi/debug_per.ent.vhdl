-- SPDX-License-Identifier: Apache-2.0

--! @file debug_per.ent.vhdl
--! @brief AXI debug peripheral.
--!
--! See @ref debug_per for more details.
library ieee;
use ieee.std_logic_1164.all;
use work.types.WIDTHS;

--! @brief A debugging widget that just unmpacks the input record into separate signals
--! because Vivado's xsim can not write records to VCD files.
entity debug_per is
    port(
        --! The AXI peripheral bus to debug.
        i: in work.per.bus_type
    );
end entity;

architecture tb of debug_per is

    signal aw_ready: std_ulogic;

    signal w_ready: std_ulogic;

    signal b_valid: std_ulogic;
    signal b_resp: std_ulogic_vector(WIDTHS.resp-1 downto 0);
    signal b_id: std_ulogic_vector(WIDTHS.id-1 downto 0);

    signal ar_ready: std_ulogic;

    signal r_valid: std_ulogic;
    signal r_data: std_ulogic_vector(WIDTHS.data-1 downto 0);
    signal r_resp: std_ulogic_vector(WIDTHS.resp-1 downto 0);
    signal r_id: std_ulogic_vector(WIDTHS.id-1 downto 0);
    signal r_last: std_ulogic;
begin

    aw_ready <= i.aw.ready;

    w_ready <= i.w.ready;

    b_valid <= i.b.valid;
    b_resp <= i.b.resp;
    b_id <= i.b.id;

    ar_ready <= i.ar.ready;

    r_valid <= i.r.valid;
    r_data <= i.r.data;
    r_resp <= i.r.resp;
    r_id <= i.r.id;
    r_last <= i.r.last;

end architecture;

