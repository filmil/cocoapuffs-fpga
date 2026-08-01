-- SPDX-License-Identifier: Apache-2.0

--! @file ddr3.pkg.vhdl
--! @brief Contains types and constants for the DDR3 WB interface.
--!
--! See @ref ddr3 for more details.

library ieee;
use ieee.std_logic_1164.all;

--! @brief The DDR3 WB interface for the a200t board.
package ddr3 is

    --! The number of row bits.
    constant row_bits: natural := 15;
    --! The number of column bits.
    constant col_bits: natural := 10;
    --! The number of bank address bits.
    constant ba_bits: natural := 3;
    --! The number of byte lanes.
    constant byte_lanes: natural := 4;
    --! The number of data bits per lane.
    constant dq_bits: natural := 8;

    --! The Wishbone address bus width.
    constant wb_addr_bits: natural := row_bits + col_bits;
    --! The Wishbone data bus width.
    constant wb_data_bits: natural := dq_bits * byte_lanes * 8;
    --! The Wishbone select bus width.
    constant wb_sel_bits: natural := wb_data_bits / 8;
    --! The auxiliary bus width.
    constant aux_width: natural := 4;

    --! Wide Wishbone host type for talking to the DDR3 controller.
    type wb_host_type is record
        cyc, stb, we: std_ulogic;
        adr: std_ulogic_vector(wb_addr_bits-1 downto 0); -- 25
        data: std_ulogic_vector(wb_data_bits-1 downto 0); -- 256
        sel: std_ulogic_vector(wb_sel_bits-1 downto 0); -- 32
        aux: std_ulogic_vector(aux_width-1 downto 0); -- 4
    end record;
    --! @brief Returns a new wb_host_type record with all fields initialized to '0'.
    function new_wb_host_type return wb_host_type;

    --! Wide Wishbone peripheral type for talking to the DDR3 controller.
    type wb_per_type is record
        stall, ack, err: std_ulogic;
        data: std_ulogic_vector(wb_data_bits-1 downto 0); -- 256
        aux: std_ulogic_vector(aux_width-1 downto 0); -- 4
    end record;
    --! @brief Returns a new wb_per_type record with all fields initialized to '0'.
    function new_wb_per_type return wb_per_type;

end package;

package body ddr3 is
    function new_wb_host_type return wb_host_type is
        variable ret: wb_host_type;
    begin
        ret := (
            cyc => '0',
            stb => '0',
            we => '0',
            adr => (others => '0'),
            data => (others => '0'),
            sel => (others => '0'),
            aux => (others => '0')
        );
        return ret;
    end function;

    function new_wb_per_type return wb_per_type is
        variable ret: wb_per_type;
    begin
        ret := (
            stall => '0',
            ack => '0',
            err => '0',
            data => (others => '0'),
            aux => (others => '0')
        );
        return ret;
    end function;

end package body;
