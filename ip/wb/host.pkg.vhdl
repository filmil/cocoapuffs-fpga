-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
use work.types.widths_type;
use work.types.WIDTHS_32B;

--! Host side Wishbone bus definitions.
package host is

--! The host-side Wishbone bus.
--!
--! Signal direction is from the Wishbone host to the peripherals.
type bus_type is record
    --! The address bus.
    adr: std_ulogic_vector(WIDTHS_32B.adr-1 downto 0);
    --! The write data bus.
    dat: std_ulogic_vector(WIDTHS_32B.dat-1 downto 0);
    --! The write data bus mask, one bit per byte of `dat`.
    sel: std_ulogic_vector(WIDTHS_32B.sel-1 downto 0);
    --! Write enable, if set while `cyc='1'`, the bus cycle is a write cycle.
    we: std_ulogic;
    --! If `cyc=1` signals on the `adr`, `dat, and `sel` buses are valid.
    cyc: std_ulogic;
end record;

--! Unconstrined array of `bus_type` ports.
type bus_array_t is array(natural range <>) of bus_type;

--! Creates a new `bus_type`. Pass in `width` value, such as `wb.types.WIDTH_32B` to
--! initialize a new variable.
function new_bus_type return bus_type;

function from_old_type(input: work.signals.o_wb) return bus_type;
function into_old_type(input: bus_type) return work.signals.o_wb;

end package;

package body host is

function new_bus_type return bus_type is
        constant cadr: std_ulogic_vector(widths_32b.adr-1 downto 0) := (others => '0');
        constant cdat: std_ulogic_vector(widths_32b.dat-1 downto 0) := (others => '0');
        constant csel: std_ulogic_vector(widths_32b.sel-1 downto 0) := (others => '0');
        variable ret: bus_type;
    begin
       ret := (adr => cadr, dat => cdat, sel => csel, we => '0',
                cyc => '0');
       return ret;
    end function;

   function from_old_type(input: work.signals.o_wb) return bus_type is
      variable ret: bus_type;

   begin
      ret := (
        adr => std_ulogic_vector(input.adr),
        dat => std_ulogic_vector(input.dat),
        sel => std_ulogic_vector(input.sel),
        we => std_ulogic(input.we),
        cyc => std_ulogic(input.cyc)
      );
      return ret;
   end function;


   function into_old_type(input: bus_type) return work.signals.o_wb is
      variable ret: work.signals.o_wb;
   begin
      ret := (
        adr => std_logic_vector(input.adr),
        dat => std_logic_vector(input.dat),
        sel => std_logic_vector(input.sel),
        we => std_logic(input.we),
        cyc => std_logic(input.cyc)
      );
      return ret;
   end function;

end package body;
