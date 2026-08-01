-- SPDX-License-Identifier: Apache-2.0
--
-- NOEL-V against the REAL DDR3 memory path: ahb2wb_bridge (40->100 MHz CDC)
-- -> wb_mux -> a200t.ram(sim) (wide_wb_ddr3 + UberDDR3) -> Micron DDR3 model.
--
-- Purpose: reproduce the hardware LR/SC failure offline.  sc.d to DDR3 fails
-- 0/1000 on the board (and the Zircon kernel spins forever at its first
-- compare_exchange in Scheduler::InitializeFirstThread), while the SAME core
-- against a 1-cycle behavioral ahb_bram (tb_noelvsys_only / :lrsctest_sim)
-- succeeds on every try.  This tb swaps in the exact board memory chain so
-- the reservation kill can be watched with full RTL visibility (suspects:
-- busif5x lr_valid snoop-clear during the long write-through store drain, and
-- the FIXME lr_addr := bifi_stdata hack).
--
-- The program (noelv_memfile) loads into the boot BRAM at 0xC0000000 and runs
-- from there (DDR3 powers up uninitialized); lr/sc targets 0x80000 = real
-- DDR3.  NOEL-V is held in reset until the DDR3 controller calibrates.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;

library grlib;
use grlib.amba.all;
use grlib.devices.all;

library gaisler;
use gaisler.uart.all;

library bridges;
library wb;
library a200t;
library ddr3;
library a200t_ddr3;

library vunit_lib;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.runner_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.com_types_pkg.all;
use vunit_lib.com_pkg.all;
use vunit_lib.stream_master_pkg.all;
use vunit_lib.stream_slave_pkg.all;
use vunit_lib.uart_pkg.all;

entity tb_noelvsys_ddr3 is
    generic (
        runner_cfg: string := runner_cfg_default
        ; sim_duration_ns: natural := 500000 -- 500us default
        ; noelv_memfile: string := ""
        ; noelv_memsize: natural := 4096
        ; baud_rate: positive := 200_000
        -- NOEL-V instruction-disassembly trace (grlib `disas`).
        ; disas: integer := 0
    );
end entity;

architecture sim of tb_noelvsys_ddr3 is
    -- Core/AHB clock: 40 MHz, as on the board (PLL clkout4).
    signal clk: std_ulogic := '0';
    -- DDR3 controller domain, as on the board (clkgen_complex).
    signal clk100: std_ulogic := '0';
    signal clk400pi0: std_ulogic := '0';
    signal clk400pi2: std_ulogic := '0';
    signal clk200: std_ulogic := '0';

    -- Power-on reset for the bridge/RAM (active high) and the gated NOEL-V
    -- reset (released after DDR3 calibration).
    signal reset: std_ulogic := '1';
    signal rstn: std_ulogic := '0';
    signal calib_complete: std_ulogic;

    signal noelv_ahbsi: ahb_slv_in_type;
    signal noelv_ahbso_vec: ahb_slv_out_vector_type(1 downto 0);
    signal noelv_gclk : std_ulogic_vector(0 to 0);
    signal noelv_uarti : uart_in_type;
    signal uarto_noelv : uart_out_type;
    signal noelv_apbo : apb_slv_out_vector;
    signal noelv_ahbmo : ahb_mst_out_vector_type(1 downto 1);
    signal noelv_dbgmo : ahb_mst_out_vector_type(0 downto 0);

    -- Wishbone chain to the RAM.
    signal noelv_wb_host: wb.host.bus_type;
    signal noelv_wb_per: wb.per.bus_type;
    signal ram_mux_host_ports: wb.host.bus_array_t(1 downto 0);
    signal ram_mux_per_ports: wb.per.bus_array_t(1 downto 0);
    signal ram_wb_host_muxed: wb.host.bus_type;
    signal ram_wb_per_from_slave: wb.per.bus_type;

    -- DDR3 pins between the controller and the Micron model.
    signal ddr3_ports: ddr3.phy32.host_type;
    signal ddr3_dq: std_logic_vector(31 downto 0);
    signal ddr3_dqs_p, ddr3_dqs_n: std_logic_vector(3 downto 0);
    signal ddr3_dm: std_logic_vector(3 downto 0);
    signal ddr3_a: std_logic_vector(14 downto 0);
    signal ddr3_ba: std_logic_vector(2 downto 0);

    signal txd, rxd: std_ulogic := '1';

    constant uart_slave : uart_slave_t := (p_actor => (p_id_number => 101), p_baud_rate => baud_rate, p_idle_state => '1', p_data_length => 8);
    constant uart_rx_stream : stream_slave_t := (p_actor => (p_id_number => 101));

    constant sim_duration : time := sim_duration_ns * 1 ns;

begin

    clk <= not clk after 12500 ps;      -- 40 MHz
    clk100 <= not clk100 after 5000 ps; -- 100 MHz
    clk400pi0 <= not clk400pi0 after 1250 ps;            -- 400 MHz
    clk400pi2 <= transport clk400pi0 after 625 ps;       -- 400 MHz +90 deg
    clk200 <= not clk200 after 2500 ps; -- 200 MHz
    noelv_gclk(0) <= clk;

    rst_process: process
    begin
        reset <= '1';
        wait for 200 ns;
        reset <= '0';
        wait;
    end process;

    -- Release NOEL-V only after DDR3 calibration, like the board (the SERV
    -- gates the handoff on ram_inited).
    noelv_release: process
        variable l : line;
    begin
        rstn <= '0';
        wait until calib_complete = '1';
        write(l, string'("CALIB done at ") & time'image(now));
        writeline(output, l);
        wait for 1 us;
        rstn <= '1';
        wait;
    end process;

    uart_slave_inst: entity vunit_lib.uart_slave
        generic map (uart => uart_slave)
        port map (rx => txd);

    main: process
    begin
        test_runner_setup(runner, runner_cfg);
        set_baud_rate(net, uart_slave, baud_rate);

        while test_suite loop
            if run("test_run") then
                wait until rstn = '1';
                info("NOEL-V released (DDR3 calibrated), waiting for 'halt.'...");
                wait_for_string(net, uart_rx_stream, "halt.");
                info("Received 'halt.' -- PASS");
            end if;
        end loop;

        test_runner_cleanup(runner);
        std.env.finish;
        wait;
    end process;

    watchdog: process
    begin
        wait for sim_duration - 100 ns;
        assert false
            report "Sim end (watchdog) after " & time'image(sim_duration)
            severity failure;
        wait;
    end process;

    noelv_uarti.rxd <= rxd;
    noelv_uarti.ctsn <= '0';
    noelv_uarti.extclk <= '0';
    noelv_apbo(0) <= apb_none;

    noelv0: entity gaisler.noelvsys
    generic map (
        fabtech  => 0,
        memtech  => 0,
        ncpu     => 1,
        nextmst  => 1,
        nextslv  => 2,
        nextapb  => 0,
        ndbgmst  => 1,
        nintdom  => 1,
        neiid    => 0,
        cached   => 16#000F#,  -- match the board: cache the low 1 GB
        wbmask   => 0,
        busw     => 32,
        cmemconf => 0,
        rfconf   => 0,
        fpuconf  => 0,
        tcmconf  => 0,
        mulconf  => 0,
        intcconf => 0,
        disas    => disas,
        ahbtrace => 0,
        cfg      => 16#300#,   -- RV64 GP dual-issue, as on the board
        devid    => 0,
        nodbus   => 0,
        trace    => 0,
        scantest => 0
    )
    port map (
        clk => clk,
        gclk => std_logic_vector(noelv_gclk),
        rstn => rstn,
        ahbsi => noelv_ahbsi,
        ahbso => noelv_ahbso_vec,
        uarti => noelv_uarti,
        uarto => uarto_noelv,
        ahbmo => noelv_ahbmo,
        dbgmo => noelv_dbgmo,
        apbo => noelv_apbo,
        dsuen => '0',
        dsubreak => '0'
    );

    txd <= uarto_noelv.txd;

    -- Boot memory (the test program runs from here; DDR3 is uninitialized).
    noelv_boot_ram: entity bridges.ahb_bram
    generic map (
        hindex        => 0,
        haddr         => 16#C00#,
        hmask         => 16#FFF#,
        memfile       => noelv_memfile,
        memsize       => noelv_memsize,
        reg_bit_count => 12
    )
    port map (
        clk   => clk,
        rstn  => rstn,
        ahbsi => noelv_ahbsi,
        ahbso => noelv_ahbso_vec(0)
    );

    -- ================= the REAL board memory path =================
    noelv_bridge: entity bridges.ahb2wb_bridge
    generic map (
        HSEL_INDEX => 1,
        HINDEX     => 1
    )
    port map (
        clk_ahb => clk,
        clk_wb => clk100,
        rst => reset,
        ahb_ahbsi => noelv_ahbsi,
        ahb_ahbso => noelv_ahbso_vec(1),
        wb_wbo => noelv_wb_host,
        wb_wbi => noelv_wb_per
    );

    -- Two-port mux exactly as on the board (port 0 = SERV, idle here).
    ram_mux_host_ports(0) <= wb.host.new_bus_type;
    ram_mux_host_ports(1) <= noelv_wb_host;

    ram_mux: entity wb.wb_mux
    generic map (
        PORTS_COUNT => 2
    )
    port map (
        clk => clk100,
        rst => reset,
        host_ports => ram_mux_host_ports,
        per_ports => ram_mux_per_ports,
        host_port => ram_wb_host_muxed,
        per_port => ram_wb_per_from_slave
    );

    noelv_wb_per <= ram_mux_per_ports(1);

    ram0: entity a200t.ram(sim)
    generic map(
        is_simulation => true
        , controller_clk_period_ps => 10000
        , ddr3_clk_period_ps => 2500
        , base_address => x"0000_0000"
    )
    port map(
        clk => clk100,
        rst => reset,
        clk_ddr => clk400pi0,
        clk_ddr90 => clk400pi2,
        clk_ref => clk200,
        ddr3_ports => ddr3_ports,
        ddr3_dqs_n => ddr3_dqs_n,
        ddr3_dqs_p => ddr3_dqs_p,
        ddr3_dq => ddr3_dq,
        wb_host => ram_wb_host_muxed,
        wb_per => ram_wb_per_from_slave,
        calib_complete => calib_complete,
        uart_tx => open,
        user_self_refresh => '0',
        debug => open
    );

    -- Micron DDR3 model, wired as in tb.arch_sim (discrete signals; the
    -- board maps the record to pins the same way).
    ddr3_dm <= std_logic_vector(ddr3_ports.dm);
    ddr3_a <= std_logic_vector(ddr3_ports.addr);
    ddr3_ba <= std_logic_vector(ddr3_ports.ba);

    ddr3_model: entity a200t_ddr3.a200t_ddr3
    port map(
        ddr3_dqs => ddr3_dqs_p
        , ddr3_dqs_n => ddr3_dqs_n
        , ddr3_dq => ddr3_dq
        , ddr3_dm => ddr3_dm
        , ddr3_a => ddr3_a
        , ddr3_ba => ddr3_ba
        , ddr3_ras => ddr3_ports.ras_n
        , ddr3_cas => ddr3_ports.cas_n
        , ddr3_we => ddr3_ports.we_n
        , ddr3_odt => ddr3_ports.odt
        , clk_n => ddr3_ports.ck_n
        , clk_p => ddr3_ports.ck_p
        , ddr3_cke => ddr3_ports.cke
        , rst_n => ddr3_ports.reset_n
        , cs_n => ddr3_ports.cs_n
        , tdqs_n => open
    );

    -- ================= observability (from tb_noelvsys_only) =================
    -- AHB monitor: address+data phases of every low-region transfer.
    ahb_monitor: process (clk) is
        variable l       : line;
        variable p_addr  : std_logic_vector(31 downto 0) := (others => '0');
        variable p_write : std_ulogic := '0';
        variable p_valid : boolean := false;
    begin
        if rising_edge(clk) and rstn = '1' then
            if p_valid and noelv_ahbsi.hready = '1'
               and p_addr(31 downto 30) = "00" then
                if p_write = '1' then
                    write(l, string'("AHBMON ") & time'image(now)
                          & string'("  WR 0x") & to_hstring(p_addr)
                          & string'("  hwdata=0x")
                          & to_hstring(noelv_ahbsi.hwdata(31 downto 0)));
                else
                    write(l, string'("AHBMON ") & time'image(now)
                          & string'("  RD 0x") & to_hstring(p_addr)
                          & string'("  hrdata=0x")
                          & to_hstring(noelv_ahbso_vec(1).hrdata(31 downto 0)));
                end if;
                writeline(output, l);
            end if;

            if noelv_ahbsi.htrans = "10" then
                write(l, string'("AHBMON ") & time'image(now) & string'("  REQ "));
                if noelv_ahbsi.hwrite = '1' then
                    write(l, string'("WR "));
                else
                    write(l, string'("RD "));
                end if;
                write(l, string'("0x") & to_hstring(noelv_ahbsi.haddr)
                      & string'("  hready=") & std_ulogic'image(noelv_ahbsi.hready));
                writeline(output, l);
            end if;

            if noelv_ahbsi.hready = '1' then
                if noelv_ahbsi.htrans = "10" or noelv_ahbsi.htrans = "11" then
                    p_addr  := noelv_ahbsi.haddr;
                    p_write := noelv_ahbsi.hwrite;
                    p_valid := true;
                else
                    p_valid := false;
                end if;
            end if;
        end if;
    end process;

    -- UART decode (the test prints its verdict at 115200 = 8600 ns/bit).
    uart_mon: process is
        constant BIT_T        : time := 8600 ns;
        variable ch           : std_logic_vector(7 downto 0);
        variable l            : line;
        variable line_started : boolean := false;
    begin
        loop
            wait until falling_edge(txd);
            wait for BIT_T / 2;
            if txd = '0' then
                wait for BIT_T;
                for i in 0 to 7 loop
                    ch(i) := txd;
                    wait for BIT_T;
                end loop;
                if not line_started then
                    write(l, string'("UART: "));
                    line_started := true;
                end if;
                if ch = x"0A" then
                    writeline(output, l);
                    line_started := false;
                elsif ch /= x"0D" then
                    write(l, character'val(to_integer(unsigned(ch))));
                end if;
            end if;
        end loop;
    end process;

end architecture;
