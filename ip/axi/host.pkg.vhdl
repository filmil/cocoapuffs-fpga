-- SPDX-License-Identifier: Apache-2.0

--! @file host.pkg.vhdl
--! @brief Defines the AXI host bus signals.
--!
--! See @ref host for more details.
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.types.WIDTHS;

--! @brief Defines the AXI host bus signals.
package host is

--! AXI write address bus channel (AW).
--! Direction host to peripheral.
type aw_type is record
    --! AXI bus has a valid signal.
    valid: std_ulogic;
    --! AXI address.
    addr: std_ulogic_vector(WIDTHS.addr-1 downto 0);
    --! AXI transaction identifier.
    id: std_ulogic_vector(WIDTHS.ID-1 downto 0);
    --! AXI transaction length designator.
    len: std_ulogic_vector(WIDTHS.LEN-1 downto 0);
    --! AXI transaction burst size.
    burst: std_ulogic_vector(WIDTHS.burst-1 downto 0);
end record;
--! @brief Returns a new aw_type record with all fields initialized.
function new_aw_type return aw_type;

--! AXI write data bus channel (W).
--! Direction host to peripheral.
type w_type is record
    --! AXI valid signal.
    valid: std_ulogic;
    --! AXI write data.
    data: std_ulogic_vector(WIDTHS.data-1 downto 0);
    --! AXI write strobes.
    strb: std_ulogic_vector(WIDTHS.STRB-1 downto 0);
    --! Asserted when the last data burst is put on the bus.
    last: std_ulogic;
end record;
--! @brief Returns a new w_type record with all fields initialized.
function new_w_type return w_type;

--! AXI write response bus channel (B).
--! Direction host to peripheral.
type b_type is record
    --! AXI ready signal.
    ready: std_ulogic;
end record;
--! @brief Returns a new b_type record with all fields initialized.
function new_b_type return b_type;

--! AXI read response bus channel (R).
--! Direction host to peripheral.
type r_type is record
    --! AXI ready signal.
    ready: std_ulogic;
end record;
--! @brief Returns a new r_type record with all fields initialized.
function new_r_type return r_type;

--! AXI bus read bus (AR)
type ar_type is record
    --! AXI bus has a valid signal.
    valid: std_ulogic;
    --! AXI address.
    addr: std_ulogic_vector(WIDTHS.addr-1 downto 0);
    --! AXI transaction identifier.
    id: std_ulogic_vector(WIDTHS.ID-1 downto 0);
    --! AXI transaction length designator.
    len: std_ulogic_vector(WIDTHS.LEN-1 downto 0);
    --! AXI transaction burst size.
    burst: std_ulogic_vector(WIDTHS.BURST-1 downto 0);

end record;
--! @brief Returns a new ar_type record with all fields initialized.
function new_ar_type return ar_type;


--! An AXI peripheral bus supporting channels AW, W, B, AR, R.
type bus_type is record
    aw: aw_type;
    w: w_type;
    b: b_type;
    ar: ar_type;
    r: r_type;
end record;
--! @brief Returns a new bus_type record with all fields initialized.
function new_bus_type return bus_type;

end package;

package body host is

    function new_aw_type return aw_type is
        variable ret: aw_type;
    begin
        ret:= (
            valid => '0',
            addr => (others => 'X') ,
            id => (others => 'X') ,
            len => (others => 'X') ,
            burst => (others => 'X')
        );
        return ret;
    end function;

    function new_w_type return w_type is
        variable ret: w_type;
    begin
        ret := (
            valid => '0',
            data => (others => 'X') ,
            strb => (others => 'X'),
            last => '0'
        );
        return ret;
    end function;

    function new_b_type return b_type is
        variable ret: b_type;
    begin
        ret := (ready => '0');
        return ret;
    end function;

    function new_r_type return r_type is
        variable ret: r_type;
    begin
        ret := (ready => '0');
        return ret;
    end function;

    function new_ar_type return ar_type is
        variable ret: ar_type;
    begin
        ret:= (
            valid => '0',
            addr => (others => 'X') ,
            id => (others => 'X') ,
            len => (others => 'X') ,
            burst => (others => 'X')
        );
        return ret;
    end function;

    function new_bus_type return bus_type is
        variable ret: bus_type;
    begin
        ret := (
            aw => new_aw_type,
            w => new_w_type,
            b => new_b_type,
            ar => new_ar_type,
            r => new_r_type
        );
        return ret;
    end function;

end package body;
