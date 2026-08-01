-- SPDX-License-Identifier: Apache-2.0

--! @file board.ent.vhdl
--! @brief This file contains the entity definition for the Alinx A200T board.
--!
--! The main public API element is the `board` entity, which can be reused
--! for multiple projects by providing different architectures.
--! See @ref board for more details.

library ieee;
use ieee.std_logic_1164.all;
library a200t_constants;
use a200t_constants.constants.all;

--! @brief The definition of the Alinx A200T board entity.
--!
--! Reuse this board entity for multiple projects. You can provide different
--! architectures.
entity board is

    generic (
        --! The base frequency of the onboard crystal oscillator (in Hz).
        SYS_CLK_HZ: positive := 200_000_000; -- 200 MHz.
        --! The clock period of the onboard crystal oscillator.
        SYS_CLK_PERIOD_SEC: real := 1.0/real(200_000_000);
        --! The base frequency of the onboard oscillator used for the GTP
        --! transceivers.
        GTP_CLK_HZ: positive := 125_000_000; -- 125 Mhz.
        --! The clock period above.
        GTP_CLK_PERIOD_SEC: real := 1.0/real(125_000_000);

        -- DDR3 parameters.

        --! Number of DQS lines on the board.
        DDR3_DQS_LINES_COUNT: positive := DQS_WIDTH;
        --! The width of the data bus, in bits.
        DDR3_DQ_LINES_COUNT: positive := DQ_WIDTH;
        --! The number of data mask lines.
        DDR3_DM_LINES_COUNT: positive := DQ_WIDTH / 8;
        --! The width of the address bus.
        DDR3_A_LINES_COUNT: positive := 15;
        --! The number of bank address lines.
        DDR3_BA_LINES_COUNT: positive := 3;

        --! Set to `true` if this is a simulation.
        --! Some circuits use this information to configure themselves
        --! differently from synth.
        IS_SIMULATION: boolean := false

        --! Used for programming any internal controllers.
        ; memfile: string := "memh.mem"
        --! The reset strategy to use.
        ; reset_strategy: string := "NONE"
        --! The size of the memory.
        ; memsize: natural := 4096

        --! Used for programming Muntjac independent BRAM.
        ; muntjac_memfile: string := ""
        --! The size of Muntjac independent BRAM.
        ; muntjac_memsize: natural := 16384

        --! Used for programming Noel-V boot controller.
        ; noelv_memfile: string := ""
        --! The size of the Noel-V boot memory.
        ; noelv_memsize: natural := 4096

        --! UART parameters
        ; baud_rate: positive := 115_200
    );

    port (
        --! The system differential clock. Must be routed into a differential router.
        sys_clk_p, sys_clk_n: in std_ulogic;

        --! The board's MGT clock. Must be routed into clock shaping circuitry.
        mgt_clk0_n, mgt_clk0_p: in std_ulogic;

        --! The DDR3 differential data strobes.
        ddr3_dqs_p, ddr3_dqs_n: inout std_logic_vector(
            DDR3_DQS_LINES_COUNT-1 downto 0);
        --! The DDR3 data bus.
        ddr3_dq_p: inout std_logic_vector(DDR3_DQ_LINES_COUNT-1 downto 0);

        --! The DDR3 data mask.
        ddr3_dm: out std_ulogic_vector(DDR3_DM_LINES_COUNT-1 downto 0);
        --! The DDR3 address bus.
        ddr3_a: out std_ulogic_vector(DDR3_A_LINES_COUNT-1 downto 0);
        --! Chip select active zero. (a.k.a. `cs_n`).
        ddr3_s0: out std_ulogic;
        --! The DDR3 bank address.
        ddr3_ba: out std_ulogic_vector(DDR3_BA_LINES_COUNT-1 downto 0);
        --! The DDR3 control signals: Row Address Strobe, Column Address Strobe, Write Enable, On-Die Termination, reset, and Clock Enable.
        ddr3_ras, ddr3_cas, ddr3_we, ddr3_odt, ddr3_reset, ddr3_cke: out std_ulogic;
        --! The DDR3 differential clock.
        ddr3_clk_p, ddr3_clk_n: out std_ulogic;

        --! UART send wire, directed from the FPGA out.
        uart1_txd: out std_ulogic;
        --! UART receive wire, directed from out into the FPGA.
        uart1_rxd: in std_ulogic;
        --! LED driver pins, all active low.
        led1, led2, led3, led4: out std_ulogic;
        --! Onboard reset, active low.
        reset_n: in std_ulogic;
        --! Buttons, all active low.
        key1_n, key2_n, key3_n, key4_n: in std_ulogic

        --! @name QSPI Flash
        --! @{
        --! QSPI QSPI_CLK
        ; qspi_clk: inout std_ulogic
        --! QSPI QSPI_CS
        ; qspi_cs: inout std_ulogic
        --! QSPI QSPI_DQ0
        ; qspi_dq0: inout std_ulogic
        --! QSPI QSPI_DQ1
        ; qspi_dq1: inout std_ulogic
        --! QSPI QSPI_DQ2
        ; qspi_dq2: inout std_ulogic
        --! QSPI QSPI_DQ3
        ; qspi_dq3: inout std_ulogic
        --! @}

        --! @name XADC
        --! @{
        --! XADC XADC_VN
        ; xadc_vn: inout std_ulogic
        --! XADC XADC_VP
        ; xadc_vp: inout std_ulogic
        --! @}

        --! @name Expansion Connector 1 (CON1)
        --! @{
        --! CON1 PIN16
        ; con1_pin16: inout std_ulogic
        --! CON1 PIN18
        ; con1_pin18: inout std_ulogic
        --! CON1 PIN22
        ; con1_pin22: inout std_ulogic
        --! CON1 PIN24
        ; con1_pin24: inout std_ulogic
        --! CON1 PIN26
        ; con1_pin26: inout std_ulogic
        --! CON1 PIN28
        ; con1_pin28: inout std_ulogic
        --! CON1 PIN31
        ; con1_pin31: inout std_ulogic
        --! CON1 PIN32
        ; con1_pin32: inout std_ulogic
        --! CON1 PIN33
        ; con1_pin33: inout std_ulogic
        --! CON1 PIN34
        ; con1_pin34: inout std_ulogic
        --! CON1 PIN35
        ; con1_pin35: inout std_ulogic
        --! CON1 PIN36
        ; con1_pin36: inout std_ulogic
        --! CON1 PIN37
        ; con1_pin37: inout std_ulogic
        --! CON1 PIN38
        ; con1_pin38: inout std_ulogic
        --! CON1 PIN41
        ; con1_pin41: inout std_ulogic
        --! CON1 PIN42
        ; con1_pin42: inout std_ulogic
        --! CON1 PIN43
        ; con1_pin43: inout std_ulogic
        --! CON1 PIN44
        ; con1_pin44: inout std_ulogic
        --! CON1 PIN45
        ; con1_pin45: inout std_ulogic
        --! CON1 PIN46
        ; con1_pin46: inout std_ulogic
        --! CON1 PIN47
        ; con1_pin47: inout std_ulogic
        --! CON1 PIN54
        ; con1_pin54: inout std_ulogic
        --! CON1 PIN56
        ; con1_pin56: inout std_ulogic
        --! CON1 PIN61
        ; con1_pin61: inout std_ulogic
        --! CON1 PIN63
        ; con1_pin63: inout std_ulogic
        --! CON1 PIN65
        ; con1_pin65: inout std_ulogic
        --! CON1 PIN67
        ; con1_pin67: inout std_ulogic
        --! CON1 PIN71
        ; con1_pin71: inout std_ulogic
        --! CON1 PIN73
        ; con1_pin73: inout std_ulogic
        --! CON1 PIN75
        ; con1_pin75: inout std_ulogic
        --! CON1 PIN77
        ; con1_pin77: inout std_ulogic
        --! @}

        --! @name Expansion Connector 2 (CON2)
        --! @{
        --! CON2 PIN1
        ; con2_pin1: inout std_ulogic
        --! CON2 PIN2
        ; con2_pin2: inout std_ulogic
        --! CON2 PIN3
        ; con2_pin3: inout std_ulogic
        --! CON2 PIN4
        ; con2_pin4: inout std_ulogic
        --! CON2 PIN5
        ; con2_pin5: inout std_ulogic
        --! CON2 PIN6
        ; con2_pin6: inout std_ulogic
        --! CON2 PIN7
        ; con2_pin7: inout std_ulogic
        --! CON2 PIN8
        ; con2_pin8: inout std_ulogic
        --! CON2 PIN11
        ; con2_pin11: inout std_ulogic
        --! CON2 PIN12
        ; con2_pin12: inout std_ulogic
        --! CON2 PIN13
        ; con2_pin13: inout std_ulogic
        --! CON2 PIN14
        ; con2_pin14: inout std_ulogic
        --! CON2 PIN15
        ; con2_pin15: inout std_ulogic
        --! CON2 PIN16
        ; con2_pin16: inout std_ulogic
        --! CON2 PIN17
        ; con2_pin17: inout std_ulogic
        --! CON2 PIN18
        ; con2_pin18: inout std_ulogic
        --! CON2 PIN21
        ; con2_pin21: inout std_ulogic
        --! CON2 PIN22
        ; con2_pin22: inout std_ulogic
        --! CON2 PIN23
        ; con2_pin23: inout std_ulogic
        --! CON2 PIN24
        ; con2_pin24: inout std_ulogic
        --! CON2 PIN25
        ; con2_pin25: inout std_ulogic
        --! CON2 PIN26
        ; con2_pin26: inout std_ulogic
        --! CON2 PIN27
        ; con2_pin27: inout std_ulogic
        --! CON2 PIN28
        ; con2_pin28: inout std_ulogic
        --! CON2 PIN31
        ; con2_pin31: inout std_ulogic
        --! CON2 PIN32
        ; con2_pin32: inout std_ulogic
        --! CON2 PIN33
        ; con2_pin33: inout std_ulogic
        --! CON2 PIN34
        ; con2_pin34: inout std_ulogic
        --! CON2 PIN35
        ; con2_pin35: inout std_ulogic
        --! CON2 PIN36
        ; con2_pin36: inout std_ulogic
        --! CON2 PIN37
        ; con2_pin37: inout std_ulogic
        --! CON2 PIN38
        ; con2_pin38: inout std_ulogic
        --! CON2 PIN41
        ; con2_pin41: inout std_ulogic
        --! CON2 PIN42
        ; con2_pin42: inout std_ulogic
        --! CON2 PIN43
        ; con2_pin43: inout std_ulogic
        --! CON2 PIN44
        ; con2_pin44: inout std_ulogic
        --! CON2 PIN45
        ; con2_pin45: inout std_ulogic
        --! CON2 PIN46
        ; con2_pin46: inout std_ulogic
        --! CON2 PIN47
        ; con2_pin47: inout std_ulogic
        --! CON2 PIN48
        ; con2_pin48: inout std_ulogic
        --! CON2 PIN51
        ; con2_pin51: inout std_ulogic
        --! CON2 PIN52
        ; con2_pin52: inout std_ulogic
        --! CON2 PIN53
        ; con2_pin53: inout std_ulogic
        --! CON2 PIN54
        ; con2_pin54: inout std_ulogic
        --! CON2 PIN55
        ; con2_pin55: inout std_ulogic
        --! CON2 PIN56
        ; con2_pin56: inout std_ulogic
        --! CON2 PIN57
        ; con2_pin57: inout std_ulogic
        --! CON2 PIN58
        ; con2_pin58: inout std_ulogic
        --! CON2 PIN61
        ; con2_pin61: inout std_ulogic
        --! CON2 PIN62
        ; con2_pin62: inout std_ulogic
        --! CON2 PIN63
        ; con2_pin63: inout std_ulogic
        --! CON2 PIN65
        ; con2_pin65: inout std_ulogic
        --! CON2 PIN66
        ; con2_pin66: inout std_ulogic
        --! CON2 PIN67
        ; con2_pin67: inout std_ulogic
        --! CON2 PIN68
        ; con2_pin68: inout std_ulogic
        --! CON2 PIN71
        ; con2_pin71: inout std_ulogic
        --! CON2 PIN72
        ; con2_pin72: inout std_ulogic
        --! CON2 PIN73
        ; con2_pin73: inout std_ulogic
        --! CON2 PIN74
        ; con2_pin74: inout std_ulogic
        --! CON2 PIN75
        ; con2_pin75: inout std_ulogic
        --! CON2 PIN76
        ; con2_pin76: inout std_ulogic
        --! CON2 PIN77
        ; con2_pin77: inout std_ulogic
        --! CON2 PIN78
        ; con2_pin78: inout std_ulogic
        --! CON2 PIN79
        ; con2_pin79: inout std_ulogic
        --! CON2 PIN80
        ; con2_pin80: inout std_ulogic
        --! @}

        --! @name Expansion Connector 3 (CON3)
        --! @{
        --! CON3 PIN1
        ; con3_pin1: inout std_ulogic
        --! CON3 PIN2
        ; con3_pin2: inout std_ulogic
        --! CON3 PIN4
        ; con3_pin4: inout std_ulogic
        --! CON3 PIN5
        ; con3_pin5: inout std_ulogic
        --! CON3 PIN6
        ; con3_pin6: inout std_ulogic
        --! CON3 PIN7
        ; con3_pin7: inout std_ulogic
        --! CON3 PIN8
        ; con3_pin8: inout std_ulogic
        --! CON3 PIN11
        ; con3_pin11: inout std_ulogic
        --! CON3 PIN12
        ; con3_pin12: inout std_ulogic
        --! CON3 PIN13
        ; con3_pin13: inout std_ulogic
        --! CON3 PIN14
        ; con3_pin14: inout std_ulogic
        --! CON3 PIN15
        ; con3_pin15: inout std_ulogic
        --! CON3 PIN16
        ; con3_pin16: inout std_ulogic
        --! CON3 PIN17
        ; con3_pin17: inout std_ulogic
        --! CON3 PIN18
        ; con3_pin18: inout std_ulogic
        --! CON3 PIN21
        ; con3_pin21: inout std_ulogic
        --! CON3 PIN22
        ; con3_pin22: inout std_ulogic
        --! CON3 PIN23
        ; con3_pin23: inout std_ulogic
        --! CON3 PIN24
        ; con3_pin24: inout std_ulogic
        --! CON3 PIN25
        ; con3_pin25: inout std_ulogic
        --! CON3 PIN26
        ; con3_pin26: inout std_ulogic
        --! CON3 PIN27
        ; con3_pin27: inout std_ulogic
        --! CON3 PIN28
        ; con3_pin28: inout std_ulogic
        --! CON3 PIN31
        ; con3_pin31: inout std_ulogic
        --! CON3 PIN32
        ; con3_pin32: inout std_ulogic
        --! CON3 PIN33
        ; con3_pin33: inout std_ulogic
        --! CON3 PIN34
        ; con3_pin34: inout std_ulogic
        --! CON3 PIN35
        ; con3_pin35: inout std_ulogic
        --! CON3 PIN36
        ; con3_pin36: inout std_ulogic
        --! CON3 PIN37
        ; con3_pin37: inout std_ulogic
        --! CON3 PIN38
        ; con3_pin38: inout std_ulogic
        --! CON3 PIN42
        ; con3_pin42: inout std_ulogic
        --! CON3 PIN44
        ; con3_pin44: inout std_ulogic
        --! CON3 PIN46
        ; con3_pin46: inout std_ulogic
        --! CON3 PIN52
        ; con3_pin52: inout std_ulogic
        --! CON3 PIN54
        ; con3_pin54: inout std_ulogic
        --! CON3 PIN56
        ; con3_pin56: inout std_ulogic
        --! CON3 PIN58
        ; con3_pin58: inout std_ulogic
        --! CON3 PIN61
        ; con3_pin61: inout std_ulogic
        --! CON3 PIN62
        ; con3_pin62: inout std_ulogic
        --! CON3 PIN63
        ; con3_pin63: inout std_ulogic
        --! CON3 PIN64
        ; con3_pin64: inout std_ulogic
        --! @}

        --! @name PCI Express
        --! @{
        --! PCIe differential clock (MGT_CLK1)
        --; pcie_clk_p: in std_ulogic := '0'
        --; pcie_clk_n: in std_ulogic := '0'
        ----! PCIe receive lanes
        --; pcie_rx_p: in std_ulogic_vector(1 downto 0) := (others => '0')
        --; pcie_rx_n: in std_ulogic_vector(1 downto 0) := (others => '0')
        ----! PCIe transmit lanes
        --; pcie_tx_p: out std_ulogic_vector(1 downto 0)
        --; pcie_tx_n: out std_ulogic_vector(1 downto 0)
        --! @}
);

end entity;

