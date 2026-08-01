-- SPDX-License-Identifier: Apache-2.0

--! @file
--! @brief A Wishbone debug peripheral.
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.types.WIDTHS_32B;

--! A Wishbone debug peripheral.
entity debug_per is
    port (
        i: in work.per.bus_type
    );
end entity;

architecture tb of debug_per is
    signal rdt: std_ulogic_vector(WIDTHS_32B.rdt-1 downto 0);
    signal ack: std_ulogic;

begin

    rdt <= i.rdt;
    ack <= i.ack;

end architecture;
