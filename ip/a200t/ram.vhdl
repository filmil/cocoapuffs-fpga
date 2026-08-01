-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
library a200t_constants;
use a200t_constants.constants.all;
library ddr3;
library uberddr3;
library wb;
library work;

--! @file ram.vhdl
--! @brief Support for the RAM on the Alinx A200T board.
--!
--! This file contains the `ram` entity that interfaces with the DDR3 memory
--! on the A200T board. See @ref ram for more details.

--! @brief An A200T board ram entity.
entity ram is
    generic (
        --! The base address of the RAM in the address space.
        base_address: std_ulogic_vector(31 downto 0) := x"8000_0000"
        --! Set to `true` for simulation.
        ; is_simulation: boolean := false
        --! Set to `true` to skip the internal memory test.
        ; skip_internal_test: boolean := false
        --! The period of the controller clock in picoseconds.
        ; controller_clk_period_ps: positive := 10_000
        --! The period of the DDR3 clock in picoseconds.
        ; ddr3_clk_period_ps: positive := 2_500
    );
    port (
        --! The main clock and reset signals.
          clk, rst: in std_ulogic
        --! The DDR3 clocks.
        ; clk_ddr, clk_ddr90, clk_ref: in std_ulogic

        --! DDR3 interface (out to the chip)
        ; ddr3_ports: out ddr3.phy32.host_type
        --! DDR3 interface (inout)
        -- Can't do this because we need a resolved type that the compiler
        -- understands.
        --; ddr3_inout: inout ddr3.phy32.inout_type
        --! The DDR3 differential data strobes.
        ; ddr3_dqs_n, ddr3_dqs_p: inout std_logic_vector(3 downto 0)
        --! The DDR3 data bus.
        ; ddr3_dq: inout std_logic_vector(31 downto 0)

        --! The Wishbone host interface.
        ; wb_host: in wb.host.bus_type
        --! The Wishbone peripheral interface.
        ; wb_per: out wb.per.bus_type

        --! Auxiliary signals.
        ; debug: out std_ulogic_vector(31 downto 0)
        --! The UART transmit signal.
        ; uart_tx: out std_ulogic
        --! A signal to trigger self-refresh mode.
        ; user_self_refresh: in std_ulogic
        --! A signal that indicates that the calibration is complete.
        ; calib_complete: out std_ulogic
    );

end entity;


architecture xilinx_rtl of ram is
    -- Driven by this circuit: you can't drive outputs directly if you want to
    -- reuse them.
    signal s_phy_ddr3: ddr3.phy32.host_type;
    signal s_ddr3_inout: ddr3.phy32.inout_type;

    signal s_wb_host: wb.host.bus_type;
    signal s_wb_per: wb.per.bus_type;

    signal s_calib_complete: std_ulogic;

    signal ctl0_wide_wb_host: work.ddr3.wb_host_type;
    signal ctl0_wide_wb_per: work.ddr3.wb_per_type;

    signal ctl0_wb2_data: std_ulogic_vector(31 downto 0);
    signal rst_n: std_ulogic;

    constant micron_sim: natural := 1 when is_simulation else 0;
    constant c_skip_internal_test: natural := 1 when skip_internal_test else 0;

    --
    signal debug_ddr3_inout_dqs, debug_ddr3_inout_dqs_n: std_logic_vector(3 downto 0);
    signal debug_ddr3_inout_dq: std_logic_vector(31 downto 0);

    signal debug_host_adr, debug_host_dat: std_ulogic_vector(31 downto 0);
    signal debug_host_sel: std_ulogic_vector(3 downto 0);
    signal debug_host_we, debug_host_cyc: std_ulogic;
    signal debug_per_rdt: std_ulogic_vector(31 downto 0);
    signal debug_per_ack: std_ulogic;
begin
    -- Drive the circuit outputs.
    ddr3_ports <= s_phy_ddr3;
    s_wb_host <= wb_host;
    wb_per <= s_wb_per;

    debug_host_adr <= s_wb_host.adr;
    debug_host_dat <= s_wb_host.dat;
    debug_host_sel <= s_wb_host.sel;
    debug_host_we <= s_wb_host.we;
    debug_host_cyc <= s_wb_host.cyc;
    debug_per_rdt <= s_wb_per.rdt;
    debug_per_ack <= s_wb_per.ack;

    --debug_ddr3_inout_dqs <= ddr3_inout.dqs;
    --debug_ddr3_inout_dqs_n <= ddr3_inout.dqs_n;
    --debug_ddr3_inout_dq <= ddr3_inout.dq;

    adapt0: entity work.wide_wb_ddr3
    port map(
        clk => clk
        , reset => rst
        , hostside_wb_host => s_wb_host
        , hostside_wb_per => s_wb_per
        , perside_wb_host => ctl0_wide_wb_host
        , perside_wb_per => ctl0_wide_wb_per
    );

    rst_n <= not rst;
    calib_complete <= s_calib_complete;
    ctl0: entity uberddr3.ddr3_top
    generic map(
        CONTROLLER_CLK_PERIOD => controller_clk_period_ps,
        DDR3_CLK_PERIOD => ddr3_clk_period_ps, -- picoseconds
        ROW_BITS => 15,
        COL_BITS => 10,
        BA_BITS => 3,
        BYTE_LANES => 4,
        SPEED_BIN => 1,
        SDRAM_CAPACITY => 5, -- gigabits
        DLL_OFF => 0,
        MICRON_SIM => micron_sim
    )
    port map(
        i_controller_clk => clk,
        i_ddr3_clk => clk_ddr,
        i_ref_clk => clk_ref,
        i_ddr3_clk_90 => clk_ddr90,
        i_rst_n => rst_n,

        -- wb
        i_wb_cyc => ctl0_wide_wb_host.cyc,
        i_wb_stb => ctl0_wide_wb_host.stb,
        i_wb_we => ctl0_wide_wb_host.we,
        i_wb_addr => ctl0_wide_wb_host.adr,
        i_wb_data => ctl0_wide_wb_host.data,
        i_wb_sel => ctl0_wide_wb_host.sel,
        i_aux => ctl0_wide_wb_host.aux,

        o_aux => ctl0_wide_wb_per.aux,
        o_wb_stall => ctl0_wide_wb_per.stall,
        o_wb_ack => ctl0_wide_wb_per.ack,
        o_wb_err => ctl0_wide_wb_per.err,
        o_wb_data => ctl0_wide_wb_per.data,

        i_wb2_cyc => '0',
        i_wb2_stb => '0',
        i_wb2_we => '0',
        i_wb2_addr => "0000000",
        i_wb2_data => x"00000000",
        i_wb2_sel => "0000",

        o_wb2_stall => open,
        o_wb2_ack => open,
        o_wb2_data => ctl0_wb2_data,

        -- DDR3 out and inout
        o_ddr3_clk_p => s_phy_ddr3.ck_p,
        o_ddr3_clk_n => s_phy_ddr3.ck_n,
        o_ddr3_reset_n => s_phy_ddr3.reset_n,
        o_ddr3_cs_n => s_phy_ddr3.cs_n,
        o_ddr3_ras_n => s_phy_ddr3.ras_n,
        o_ddr3_cas_n => s_phy_ddr3.cas_n,
        o_ddr3_cke => s_phy_ddr3.cke,
        o_ddr3_we_n => s_phy_ddr3.we_n,
        o_ddr3_addr => s_phy_ddr3.addr,
        o_ddr3_ba_addr => s_phy_ddr3.ba,

        -- XXX: This needs to be attachedback to `ddr3_inout`.
        io_ddr3_dq => ddr3_dq,
        io_ddr3_dqs_n => ddr3_dqs_n,
        io_ddr3_dqs => ddr3_dqs_p,

        o_ddr3_dm => s_phy_ddr3.dm,
        o_ddr3_odt => s_phy_ddr3.odt,

        -- Auxiliary
        o_calib_complete => s_calib_complete,
        i_user_self_refresh => user_self_refresh,
        uart_tx => uart_tx,
        o_debug1 => debug
    );

end architecture;

library ieee;
use ieee.std_logic_1164.all;
library a200t_constants;
use a200t_constants.constants.all;
library wb;

architecture sim of ram is
    signal wbi: wb.host.bus_type;
    signal wbo: wb.per.bus_type;
    signal write: boolean;
    signal regi, rego: std_ulogic_vector(31 downto 0);
    signal index: natural;

    constant mem_size_words: positive := 2**10;
    type mem_type is array(0 to mem_size_words-1) of std_ulogic_vector(31 downto 0);

    signal memory: mem_type := (others => (others => '0'));


begin
    debug_host0: entity wb.debug_host port map( i => wbi);
    debug_per0: entity wb.debug_per port map( i => wbo);

    calib_complete <= not rst;
    wbi <= wb_host;
    wb_per <= wbo;
    decoder0: entity wb.mmreg_decoder
    generic map(
        base_address => base_address
        , reg_bit_count => 20
    )
    port map(
        clk => clk
        , reset => rst
        , write => write
        , regi => regi
        , rego => rego
        , indexo => index
        , wbi => wbi
        , wbo => wbo
    );

    regi <= memory(index mod mem_size_words);
    ram0: process(clk, rst) is
    begin
        if rising_edge(clk) then
            if write then
                for i in wbi.sel'range loop
                    -- Handle write data masking.
                    if wbi.sel(i) = '1' then
                        memory(index mod mem_size_words)(8*(i+1)-1 downto 8*i)
                            <= rego(8*(i+1)-1 downto 8*i);
                    end if;
                end loop;
            end if;
        end if;
    end process;

end architecture;
