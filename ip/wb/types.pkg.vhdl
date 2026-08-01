-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;

--! Defines the wishbone bus signal parameters.
package types is

constant BITS_PER_BYTE: positive := 8;

--! Bit widths configuration.
type widths_type is record
    --! The width of the address bus.
    adr: positive;
    --! The width of the data buses, both read and write.
    dat: positive;
    --! The width of the selector mask, one bit per byte of data.
    sel: positive;
    rdt: positive;
end record;

--! The widths definition for a 32-bit Wishbone bus.
constant WIDTHS_32B: widths_type := (
    adr => 32, dat => 32, sel => 32 / BITS_PER_BYTE,
    rdt => 32
);

end package;

