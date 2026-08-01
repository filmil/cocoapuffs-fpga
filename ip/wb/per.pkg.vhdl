-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
use work.types.widths_type;
use work.types.WIDTHS_32B;

--! Peripheral side Wishbone bus definitions.
package per is

--! The peripheral-side Wishbone bus.
--!
--! Signal direction is from the peripheral to the  Wishbone host.
type bus_type is record
    --! The read data bus.
    rdt: std_ulogic_vector(WIDTHS_32B.rdt-1 downto 0);
    --! If `ack='1'`, the value on `rdt` is valid.
    ack: std_ulogic;
end record;

type bus_array_t is array(natural range <>) of bus_type;

--! Creates a new `bus_type`. Pass in `width` value, such as `wb.types.WIDTH_32B` to
--! initialize a new variable.
function new_bus_type return bus_type;

function from_old_type(input: work.signals.i_wb) return bus_type;
function into_old_type(input: bus_type) return work.signals.i_wb;

end package;

package body per is

   function new_bus_type return bus_type is
      constant crdt: std_ulogic_vector(widths_32B.dat-1 downto 0) := (others => '0');
      variable ret: bus_type;
   begin
      ret := (rdt => crdt, ack => '0');
      return ret;
   end function;

   function from_old_type(input: work.signals.i_wb) return bus_type is
      variable ret: bus_type;
   begin
      ret := (
         rdt => std_ulogic_vector(input.rdt),
         ack => std_ulogic(input.ack)
      );
      return ret;
   end function;


   function into_old_type(input: bus_type) return work.signals.i_wb is
      variable ret: work.signals.i_wb;
   begin
      ret := (
         rdt => std_logic_vector(input.rdt),
         ack => std_logic(input.ack)
      );
      return ret;
   end function;

end package body;
