-- SPDX-License-Identifier: Apache-2.0

--! @file dfi32.pkg.vhdl
--! @brief DFI 32-bit interface package.
--!
--! See @ref dfi32 for more details.
library ieee;
use ieee.std_logic_1164.all;
library work;
use work.dfi;

--! @brief DFI 32-bit interface package.
package dfi32 is

    constant WIDTHS: dfi.widths_type := dfi.B32;

    --! DFI input record.
    type in_type is record
        --! Read data.
        rddata: std_ulogic_vector(WIDTHS.rddata-1 downto 0);
        --! Read data valid.
        rddata_valid: std_ulogic;
        --! Read data does not have valid value.
        rddata_dnv: std_ulogic_vector(WIDTHS.rddata_dnv-1 downto 0);
    end record;
    --! @brief Returns a new in_type record with all fields initialized.
    function new_in_type return in_type;

    --! DFI output record.
    type out_type is record
        --! Address bus.
        address: std_ulogic_vector(WIDTHS.address-1 downto 0);
        --! Bank address bus.
        bank: std_ulogic_vector(WIDTHS.bank-1 downto 0);
        --! Write data bus.
        wrdata: std_ulogic_vector(WIDTHS.wrdata-1 downto 0);
        --! Read data bus.
        rddata: std_ulogic_vector(WIDTHS.rddata-1 downto 0);
        --! Write data mask.
        wrdata_mask: std_ulogic_vector(WIDTHS.wrdata_mask-1 downto 0);
        --! Control signals.
        cas_n, cke, cs_n, odt, ras_n, reset_n, we_n: std_ulogic;
        --! Write and read data enable signals.
        wrdata_en, rddata_en: std_ulogic;
    end record;
    --! Type constructor
    function new_out_type return out_type;

end package;

package body dfi32 is

    function new_in_type return in_type is
        variable ret: in_type;
        constant crddata: std_ulogic_vector(WIDTHS.rddata-1 downto 0) := (others => 'X');
        constant crddata_dnv: std_ulogic_vector(WIDTHS.rddata_dnv-1 downto 0) := (others => 'X');
    begin
        ret := (
            rddata => crddata,
            rddata_valid => 'X',
            rddata_dnv => crddata_dnv
        );
            return ret;
    end function;

    function new_out_type return out_type is
        variable ret: out_type;
        constant caddress: std_ulogic_vector(WIDTHS.address-1 downto 0) := (others => 'X');
        constant cbank: std_ulogic_vector(WIDTHS.bank-1 downto 0) := (others => 'X');
        constant cwrdata: std_ulogic_vector(WIDTHS.wrdata-1 downto 0) := (others => 'X');
        constant crddata: std_ulogic_vector(WIDTHS.rddata-1 downto 0) := (others => 'X');
        constant cwrdata_mask: std_ulogic_vector(WIDTHS.wrdata_mask-1 downto 0) := (others => 'X');
    begin
        ret := (
            address => caddress,
            bank => cbank,
            wrdata => cwrdata,
            wrdata_mask => cwrdata_mask,
            rddata => crddata,
            others => 'X'
        );
        return ret;
    end function;

end package body;
