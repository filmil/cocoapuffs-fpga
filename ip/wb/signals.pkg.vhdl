-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
use work.types.widths_type;

package signals is

constant WIDTHS: widths_type := work.types.WIDTHS_32B;

--! Default bit-width of the Wishbone bus.
constant BITS: positive := 32;
--! Default bits per byte.
constant BITS_PER_BYTE: positive := 8;
--! Default byts.
constant BYTES: positive := BITS/BITS_PER_BYTE;

--! Narrow bus number of bits.
constant BITS_NARROW: positive := 8;

--! Wishbone controller output
--!
--! Name encoding is `o_*` means output from the *controller*.
--! So if you areimplementing a client, this would be an **input** parameter.
type o_wb is record
    --! Address bus.
    adr: std_logic_vector(WIDTHS.adr-1 downto 0);
    --! Write data bus.
    dat: std_logic_vector(WIDTHS.dat-1 downto 0);
    --! Write mask, one for each byte of `dat`.
    sel: std_logic_vector(WIDTHS.sel-1 downto 0);
    --! Write cycle indicator. Asserted when a write cycle is requested.
    we: std_logic;
    --! Active cycle indicator. Asserted when a valid write or read cycle is
    --! active on the bus.
    cyc: std_logic;
end record;

--! Constructs a new empty @p o_wb.
function o_wb_new return o_wb;

--! Wishbone controller input (i.e. from peripherals)
type i_wb is record
    --! Data bus read data.
    rdt: std_logic_vector(WIDTHS.rdt-1 downto 0);
    --! Data bus return data valid.
    ack: std_logic;
end record;

--! Constructs a new empty @p i_wb.
function i_wb_new return i_wb;

--! Multiple Wishbone read paths.
type rdt_mux_in_t is array(natural range <>) of i_wb;

component rdt_mux is
    port (
        input: in rdt_mux_in_t;
        output: out i_wb
    );
end component;

end package;

package body signals is

    function o_wb_new return o_wb is
    begin
        return (
            adr => (others => '0'),
            dat => (others => '0'),
            sel => (others => '0'),
            we => '0',
            cyc => '0'
        );
    end function;

    function i_wb_new return i_wb is
    begin
        return (
            rdt => (others => '0'),
            ack => '0'
        );
    end function;

end package body;

