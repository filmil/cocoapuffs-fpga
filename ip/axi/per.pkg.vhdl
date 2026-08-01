-- SPDX-License-Identifier: Apache-2.0

--! @file per.pkg.vhdl
--! @brief Defines the AXI peripheral (PER) signal parameters.
--!
--! See @ref per for more details.
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.types.WIDTHS;

--! @brief Defines the AXI peripheral (PER) signal parameters.
package per is

--! AXI write address bus channel (AW).
--! Direction peripheral to host.
type aw_type is record
    --! Asserted high when the peripheral is ready to accept command from
    --! the host.
    ready: std_ulogic;
end record;
--! @brief Returns a new aw_type record with all fields initialized.
function new_aw_type(constant widths: work.types.widths_type) return aw_type;

--! AXI write data bus channel (W).
--! Direction peripheral to host.
type w_type is record
    --! Asserted high when the peripheral is ready to accept command from
    --! the host.
    ready: std_ulogic;
end record;
--! @brief Returns a new w_type record with all fields initialized.
function new_w_type(constant widths: work.types.widths_type) return w_type;

--! AXI write response bus channel (B).
--! Direction peripheral to host.
type b_type is record
    --! AXI valid signal.
    valid: std_ulogic;
    --! AXI response.
    resp: std_ulogic_vector(WIDTHS.RESP-1 downto 0);
    --! AXI transaction identifier.
    id: std_ulogic_vector(WIDTHS.ID-1 downto 0);
end record;
--! @brief Returns a new b_type record with all fields initialized.
function new_b_type(constant widths: work.types.widths_type) return b_type;


--! AXI read data bus channel (R).
--! Direction peripheral to host.
type r_type is record
    --! AXI valid signal.
    valid: std_ulogic;
    --! AXI read data.
    data: std_ulogic_vector(WIDTHS.data-1 downto 0);
    --! AXI response.
    resp: std_ulogic_vector(WIDTHS.RESP-1 downto 0);
    --! AXI transaction identifier.
    id: std_ulogic_vector(WIDTHS.ID-1 downto 0);
    --! Asserted when the last data burst is put on the bus.
    last: std_ulogic;
end record;
--! @brief Returns a new r_type record with all fields initialized.
function new_r_type(constant widths: work.types.widths_type) return r_type;


--! AXI read address bus channel (AR).
--! Direction peripheral to host.
type ar_type is record
    --! Asserted high when the peripheral is ready to accept command from
    --! the host.
    ready: std_ulogic;
end record;
--! @brief Returns a new ar_type record with all fields initialized.
function new_ar_type(constant widths: work.types.widths_type) return ar_type;


--! An AXI peripheral bus supporting channels AW, W, B, AR, R.
type bus_type is record
    --! Write address channel.
    aw: aw_type;
    --! Write data channel.
    w: w_type;
    --! Write response channel.
    b: b_type;
    --! Read address channel.
    ar: ar_type;
    --! Read data channel.
    r: r_type;
end record;
--! @brief Returns a new bus_type record with all fields initialized.
function new_bus_type(constant widths: work.types.widths_type) return bus_type;

end package;

package body per is


    function new_aw_type(constant widths: work.types.widths_type) return aw_type is
        variable ret: aw_type;
    begin
        ret := (ready => '0');
        return ret;
    end function;

    function new_w_type(constant widths: work.types.widths_type) return w_type is
        variable ret: w_type;
    begin
        ret := (ready => '0');
        return ret;
    end function;

    function new_r_type(constant widths: work.types.widths_type) return r_type is
        variable ret: r_type;
    begin
        ret := (
            valid => '0',
            data => (others => 'X'),
            resp => (others => 'X') ,
            id => (others => 'X') ,
            last => '1'
        );
        return ret;
    end function;


    function new_b_type(constant widths: work.types.widths_type) return b_type is
        variable ret: b_type;
    begin
        ret := (valid => '0', resp => (others => 'X'), id => (others => 'X') );
        return ret;
    end function;

    function new_ar_type(constant widths: work.types.widths_type) return ar_type is
        variable ret: ar_type;
    begin
        ret := (ready => '0');
        return ret;
    end function;


    function new_bus_type(constant widths: work.types.widths_type) return bus_type is
        variable ret: bus_type;
    begin
        ret := (
            aw => new_aw_type(widths),
            w => new_w_type(widths),
            b => new_b_type(widths),
            ar => new_ar_type(widths),
            r => new_r_type(widths)
        );
        return ret;
    end function;

end package body;
