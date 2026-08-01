-- SPDX-License-Identifier: Apache-2.0

--! @file board.arch.vhdl
--! @brief A null architecture for the Alinx A200T board entity.
--!
--! This architecture assigns neutral values to all outputs and leaves inputs open.
--! It is useful for testbenches or projects where a complete board implementation
--! is not required but compilation of the entity is.

library ieee;
use ieee.std_logic_1164.all;

architecture null_arch of board is
begin

    -- Outputs assigned to neutral/safe values
    ddr3_dm <= (others => '0');
    ddr3_a <= (others => '0');
    ddr3_s0 <= '0';
    ddr3_ba <= (others => '0');
    ddr3_ras <= '0';
    ddr3_cas <= '0';
    ddr3_we <= '0';
    ddr3_odt <= '0';
    ddr3_reset <= '0';
    ddr3_cke <= '0';
    ddr3_clk_p <= '0';
    ddr3_clk_n <= '0';
    uart1_txd <= '0';
    led1 <= '0';
    led2 <= '0';
    led3 <= '0';
    led4 <= '0';

    -- Inouts assigned to high impedance
    ddr3_dqs_p <= (others => 'Z');
    ddr3_dqs_n <= (others => 'Z');
    ddr3_dq_p <= (others => 'Z');
    qspi_clk <= 'Z';
    qspi_cs <= 'Z';
    qspi_dq0 <= 'Z';
    qspi_dq1 <= 'Z';
    qspi_dq2 <= 'Z';
    qspi_dq3 <= 'Z';
    xadc_vn <= 'Z';
    xadc_vp <= 'Z';
    con1_pin16 <= 'Z';
    con1_pin18 <= 'Z';
    con1_pin22 <= 'Z';
    con1_pin24 <= 'Z';
    con1_pin26 <= 'Z';
    con1_pin28 <= 'Z';
    con1_pin31 <= 'Z';
    con1_pin32 <= 'Z';
    con1_pin33 <= 'Z';
    con1_pin34 <= 'Z';
    con1_pin35 <= 'Z';
    con1_pin36 <= 'Z';
    con1_pin37 <= 'Z';
    con1_pin38 <= 'Z';
    con1_pin41 <= 'Z';
    con1_pin42 <= 'Z';
    con1_pin43 <= 'Z';
    con1_pin44 <= 'Z';
    con1_pin45 <= 'Z';
    con1_pin46 <= 'Z';
    con1_pin47 <= 'Z';
    con1_pin54 <= 'Z';
    con1_pin56 <= 'Z';
    con1_pin61 <= 'Z';
    con1_pin63 <= 'Z';
    con1_pin65 <= 'Z';
    con1_pin67 <= 'Z';
    con1_pin71 <= 'Z';
    con1_pin73 <= 'Z';
    con1_pin75 <= 'Z';
    con1_pin77 <= 'Z';
    con2_pin1 <= 'Z';
    con2_pin2 <= 'Z';
    con2_pin3 <= 'Z';
    con2_pin4 <= 'Z';
    con2_pin5 <= 'Z';
    con2_pin6 <= 'Z';
    con2_pin7 <= 'Z';
    con2_pin8 <= 'Z';
    con2_pin11 <= 'Z';
    con2_pin12 <= 'Z';
    con2_pin13 <= 'Z';
    con2_pin14 <= 'Z';
    con2_pin15 <= 'Z';
    con2_pin16 <= 'Z';
    con2_pin17 <= 'Z';
    con2_pin18 <= 'Z';
    con2_pin21 <= 'Z';
    con2_pin22 <= 'Z';
    con2_pin23 <= 'Z';
    con2_pin24 <= 'Z';
    con2_pin25 <= 'Z';
    con2_pin26 <= 'Z';
    con2_pin27 <= 'Z';
    con2_pin28 <= 'Z';
    con2_pin31 <= 'Z';
    con2_pin32 <= 'Z';
    con2_pin33 <= 'Z';
    con2_pin34 <= 'Z';
    con2_pin35 <= 'Z';
    con2_pin36 <= 'Z';
    con2_pin37 <= 'Z';
    con2_pin38 <= 'Z';
    con2_pin41 <= 'Z';
    con2_pin42 <= 'Z';
    con2_pin43 <= 'Z';
    con2_pin44 <= 'Z';
    con2_pin45 <= 'Z';
    con2_pin46 <= 'Z';
    con2_pin47 <= 'Z';
    con2_pin48 <= 'Z';
    con2_pin51 <= 'Z';
    con2_pin52 <= 'Z';
    con2_pin53 <= 'Z';
    con2_pin54 <= 'Z';
    con2_pin55 <= 'Z';
    con2_pin56 <= 'Z';
    con2_pin57 <= 'Z';
    con2_pin58 <= 'Z';
    con2_pin61 <= 'Z';
    con2_pin62 <= 'Z';
    con2_pin63 <= 'Z';
    con2_pin65 <= 'Z';
    con2_pin66 <= 'Z';
    con2_pin67 <= 'Z';
    con2_pin68 <= 'Z';
    con2_pin71 <= 'Z';
    con2_pin72 <= 'Z';
    con2_pin73 <= 'Z';
    con2_pin74 <= 'Z';
    con2_pin75 <= 'Z';
    con2_pin76 <= 'Z';
    con2_pin77 <= 'Z';
    con2_pin78 <= 'Z';
    con2_pin79 <= 'Z';
    con2_pin80 <= 'Z';
    con3_pin1 <= 'Z';
    con3_pin2 <= 'Z';
    con3_pin4 <= 'Z';
    con3_pin5 <= 'Z';
    con3_pin6 <= 'Z';
    con3_pin7 <= 'Z';
    con3_pin8 <= 'Z';
    con3_pin11 <= 'Z';
    con3_pin12 <= 'Z';
    con3_pin13 <= 'Z';
    con3_pin14 <= 'Z';
    con3_pin15 <= 'Z';
    con3_pin16 <= 'Z';
    con3_pin17 <= 'Z';
    con3_pin18 <= 'Z';
    con3_pin21 <= 'Z';
    con3_pin22 <= 'Z';
    con3_pin23 <= 'Z';
    con3_pin24 <= 'Z';
    con3_pin25 <= 'Z';
    con3_pin26 <= 'Z';
    con3_pin27 <= 'Z';
    con3_pin28 <= 'Z';
    con3_pin31 <= 'Z';
    con3_pin32 <= 'Z';
    con3_pin33 <= 'Z';
    con3_pin34 <= 'Z';
    con3_pin35 <= 'Z';
    con3_pin36 <= 'Z';
    con3_pin37 <= 'Z';
    con3_pin38 <= 'Z';
    con3_pin42 <= 'Z';
    con3_pin44 <= 'Z';
    con3_pin46 <= 'Z';
    con3_pin52 <= 'Z';
    con3_pin54 <= 'Z';
    con3_pin56 <= 'Z';
    con3_pin58 <= 'Z';
    con3_pin61 <= 'Z';
    con3_pin62 <= 'Z';
    con3_pin63 <= 'Z';
    con3_pin64 <= 'Z';
    -- PCIe signals
    -- pcie_tx_p unassigned
    -- pcie_tx_n unassigned


    -- Inputs are left open (unused)
    -- No assignments needed for inputs

end architecture;
