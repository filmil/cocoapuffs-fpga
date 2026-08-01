-- SPDX-License-Identifier: Apache-2.0

--! @file
--! @brief A Wishbone debug host.
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.types.WIDTHS_32B;

--! A Wishbone debug host.
entity debug_host is
    port (
        i: in work.host.bus_type
    );
end entity;

architecture tb of debug_host is
    signal adr: std_ulogic_vector(WIDTHS_32B.adr-1 downto 0);
    signal dat: std_ulogic_vector(WIDTHS_32B.dat-1 downto 0);
    signal sel: std_ulogic_vector(WIDTHS_32B.sel-1 downto 0);
    signal we: std_ulogic;
    signal cyc: std_ulogic;

begin

    adr <= i.adr;
    dat <= i.dat;
    sel <= i.sel;
    we  <= i.we;
    cyc <= i.cyc;

end architecture;
