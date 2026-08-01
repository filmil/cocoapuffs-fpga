-- SPDX-License-Identifier: Apache-2.0

--! @file phy32.pkg.vhdl
--! @brief The 32-bit DDR3 PHY interfaces.
--!
--! See @ref phy32 for more details.
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.phy;

--! @brief The 32-bit DDR3 PHY interfaces.
package phy32 is

    constant WIDTH: phy.width_type := work.phy.width_32b;

    --! Signals going from the host to the DDR3 chip.
    type host_type is record
        --! Differential clock, clock enable, reset, row address strobe,
        --! column address strobe, write enable, and chip select.
        ck_p, ck_n, cke, reset_n, ras_n, cas_n, we_n, cs_n: std_ulogic;
        --! Bank address.
        ba: std_ulogic_vector(WIDTH.ba-1 downto 0);
        --! Address.
        addr: std_ulogic_vector(WIDTH.addr-1 downto 0);
        --! On-die termination.
        odt: std_ulogic;
        --! Data mask.
        dm: std_ulogic_vector(WIDTH.dm-1 downto 0);
    end record;
    --! @brief Returns a new host_type record with all fields initialized.
    function new_host_type return host_type;

    --! Signals that switch direction.
    type inout_type is record
        --! Differential data strobe.
        dqs, dqs_n: std_logic_vector(WIDTH.dqs-1 downto 0);
        --! Data bus..
        dq: std_logic_vector(WIDTH.dq-1 downto 0);
    end record;
    --! @brief Returns a new inout_type record with all fields initialized.
    function new_inout_type return inout_type;

end package;

package body phy32 is
    --! `host_type` constructor.
    function new_host_type return host_type is
        variable ret: host_type;
        constant baw: std_ulogic_vector(WIDTH.ba-1 downto 0) := (others => 'X');
        constant addrw: std_ulogic_vector(WIDTH.addr-1 downto 0) := (others => 'X');
        constant dmw: std_ulogic_vector(WIDTH.dm-1 downto 0) := (others => 'X');
    begin
        ret := (
            ba => baw,
            addr => addrw,
            dm => dmw,
            others => 'X'
        );
        return ret;
    end function;

    --! `inout_type` constructor.
    function new_inout_type return inout_type is
        variable ret: inout_type;
        constant dqw: std_logic_vector(WIDTH.dqs-1 downto 0) := (others => 'Z');
        constant cdq: std_logic_vector(WIDTH.dq-1 downto 0) := (others => 'Z');
    begin
        ret := (
            dqs => dqw,
            dqs_n => dqw,
            dq => cdq);
        return ret;
    end function;
end package body;
