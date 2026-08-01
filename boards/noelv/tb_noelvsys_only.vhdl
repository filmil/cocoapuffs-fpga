-- SPDX-License-Identifier: Apache-2.0
-- Force Rebuild 18
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

entity tb_noelvsys_only is
    generic (
        runner_cfg: string := runner_cfg_default
        ; sim_duration_ns: natural := 5000 -- 5us default
        ; noelv_memfile: string := ""
        ; noelv_memsize: natural := 4096
        ; baud_rate: positive := 200_000
        -- Low ("DDR3") region 0x00000000-0x3FFFFFFF backing store.  Defaults keep
        -- the original 4 KiB scratch RAM (memfile empty).  The OpenSBI bring-up
        -- sim overrides these to pre-load OpenSBI at 0x40000: lowmem_regbits must
        -- be wide enough to decode the load address (>=21 for 0x40000) and
        -- lowmem_size = 2**lowmem_regbits so the region maps without aliasing.
        ; lowmem_file: string := ""
        ; lowmem_size: natural := 4096
        ; lowmem_regbits: natural := 12
        -- NOEL-V instruction-disassembly trace (grlib `disas`): 0 = off,
        -- 1 = print every retired instruction (PC + opcode + reg writeback) to
        -- stdout.  The single most useful signal for the OpenSBI boot debug.
        ; disas: integer := 0
        -- Hang detection: if non-zero, the testbench finishes (PASS-style, no
        -- watchdog failure) once the core spins fetching in
        -- [hang_addr, hang_addr+0x40) -- i.e. it reached a known spin loop such
        -- as OpenSBI's sbi_hart_hang.  Lets a generous sim_duration_ns be set
        -- without wasting wall time on the post-hang wfi spin.
        ; hang_addr: natural := 0
        -- Second low-region bank for the ZBI at 0x10000000.  A single ahb_bram
        -- caps at 256 MiB (xsim 2**31-bit array limit), so lowmem backs
        -- 0x0-0xFFFFFFF (boot + placement) and this bank backs
        -- 0x10000000-0x103FFFFF (the ZBI).  Empty (4 KiB scratch) when zbi_file="".
        ; zbi_file: string := ""
        ; zbi_size: natural := 4096
        ; zbi_regbits: natural := 12
        ; zbi_haddr: natural := 16#100#
        ; zbi_hmask: natural := 16#FFC#
    );
end entity;

architecture sim of tb_noelvsys_only is
    signal clk: std_ulogic := '0';
    signal rstn: std_ulogic := '0';
    signal rst: std_ulogic;

    signal noelv_ahbsi: ahb_slv_in_type;
    signal noelv_ahbso_vec: ahb_slv_out_vector_type(2 downto 0);
    signal noelv_gclk : std_ulogic_vector(0 to 0);
    signal noelv_uarti : uart_in_type;
    signal uarto_noelv : uart_out_type;
    signal noelv_apbo : apb_slv_out_vector;
    signal noelv_ahbmo : ahb_mst_out_vector_type(1 downto 1);
    signal noelv_dbgmo : ahb_mst_out_vector_type(0 downto 0);

    signal txd, rxd: std_ulogic := '1';

    constant uart_slave : uart_slave_t := (p_actor => (p_id_number => 101), p_baud_rate => baud_rate, p_idle_state => '1', p_data_length => 8);
    constant uart_rx_stream : stream_slave_t := (p_actor => (p_id_number => 101));

    constant sim_duration : time := sim_duration_ns * 1 ns;

begin

    clk <= not clk after 12500 ps; -- 40MHz core clock (matches board.dts clock/timebase + HW)
    noelv_gclk(0) <= clk;
    rst <= not rstn;

    rst_process: process
    begin
        rstn <= '0';
        wait for 100 ns;
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
                info("Noel-V released from reset, waiting for 'halt.' on UART...");
                wait_for_string(net, uart_rx_stream, "halt.");
                info("Received 'halt.' on the NOEL-V APB UART -- PASS");
            end if;
        end loop;

        test_runner_cleanup(runner);
        std.env.finish;
        wait;
    end process;

    -- Fail the test if 'halt.' is not received within the allotted time.
    watchdog: process
    begin
        wait for sim_duration - 100 ns;
        assert false
            report "Test FAILED: 'halt.' not received on UART within "
                   & time'image(sim_duration)
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
        nextslv  => 3,
        nextapb  => 0,
        ndbgmst  => 1,
        nintdom  => 1,
        neiid    => 0,
        -- Match the board (board.arch_rtl.vhdl): cache the low 1 GB so LR/SC
        -- reservations live in L1. Lets us sanity-check the boot with caching on.
        cached   => 16#000F#,
        wbmask   => 0,
        busw     => 32,
        cmemconf => 0,
        rfconf   => 0,
        fpuconf  => 0,
        tcmconf  => 0,
        mulconf  => 0,
        intcconf => 0,
        disas    => disas,   -- instruction trace (generic; set 1 to debug; very verbose)
        ahbtrace => 0,
        -- 16#30x# selects the NOEL-V general-purpose (NV-GP) core: FPU, RV-C.
        -- cfg_typ = (cfg/256) mod 16: 4 = HP, 3 = GP.  Low bit = single-issue
        -- (cfg_sissue = cfg mod 2): 0x300 = dual-issue, 0x301 = single-issue.
        -- A timing-sensitive core hazard intermittently derails OpenSBI's
        -- fdt_next_node device-tree walk (sim-only; the FPGA boots).  Single-
        -- issue (0x301) only SHIFTED when it triggers (early-console scan OK,
        -- but sbi_init's scan still hangs ~55ms) -- NOT a dual-issue-specific
        -- forwarding bug.  Back on 0x300 (dual-issue) for the waveform hunt:
        -- it hits the loop at ~5ms (10x faster) for diagnosis.
        cfg      => 16#300#,
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

    -- Boot memory connected directly to the AHB bus (no Wishbone bridge), so
    -- NOEL-V's instruction-fetch bursts are served at one word per clock.
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

    -- Low-region slave: a responding RAM so the core's reset-time SPECULATIVE
    -- instruction fetches into this region complete (and get squashed) instead
    -- of hanging. (Previously an ahb2wb_bridge to an unconnected Wishbone bus,
    -- which never asserted hready -> a hung fetch froze the whole core.)
    noelv_lowmem: entity bridges.ahb_bram
    generic map (
        hindex        => 1,
        haddr         => 16#000#,
        hmask         => 16#F00#,  -- 0x0-0xFFFFFFF (256 MiB); the ZBI bank carves out 0x10000000+
        memfile       => lowmem_file,
        memsize       => lowmem_size,
        reg_bit_count => lowmem_regbits
    )
    port map (
        clk   => clk,
        rstn  => rstn,
        ahbsi => noelv_ahbsi,
        ahbso => noelv_ahbso_vec(1)
    );

    -- ZBI bank (hindex 2): the real ZBI lives at 0x10000000 on hardware.  A single
    -- ahb_bram caps at 256 MiB (xsim 2**31-bit array limit), so this second bank
    -- backs 0x10000000-0x103FFFFF (4 MiB) for the ZBI while lowmem covers
    -- 0x0-0xFFFFFFF.  Empty 4 KiB scratch when zbi_file = "".
    noelv_zbimem: entity bridges.ahb_bram
    generic map (
        hindex        => 2,
        haddr         => zbi_haddr,
        hmask         => zbi_hmask,
        memfile       => zbi_file,
        memsize       => zbi_size,
        reg_bit_count => zbi_regbits
    )
    port map (
        clk   => clk,
        rstn  => rstn,
        ahbsi => noelv_ahbsi,
        ahbso => noelv_ahbso_vec(2)
    );

    -- AHB-slave-bus monitor for the low ("DDR3") region 0x0..0x3FFFFFFF.  The HW
    -- AHB recorder can only snoop haddr/hwrite/hwdata; here we additionally see
    -- hready and hrdata, so we can tell whether a NOEL-V store/load actually
    -- ISSUES and COMPLETES on noelv_ahbsi.  AHB is pipelined: the address is
    -- captured in the address phase and the data printed in the following data
    -- phase.  A "REQ" line is emitted for every presented low-region transfer
    -- (with hready), so a transfer that is presented-but-never-accepted (hready
    -- stuck low) -- or never presented at all -- is directly visible.  Boot-ROM
    -- fetches (0xC0000000) are excluded, so the boot-only :sim_only stays quiet.
    ahb_monitor: process (clk) is
        variable l       : line;
        variable p_addr  : std_logic_vector(31 downto 0) := (others => '0');
        variable p_write : std_ulogic := '0';
        variable p_valid : boolean := false;
    begin
        if rising_edge(clk) and rstn = '1' then
            -- Data phase: a previously-accepted low-region transfer completes.
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

            -- Address phase: report every presented NONSEQ transfer ("10"), ANY
            -- region, with hready -- this includes instruction fetches, so we can
            -- see how far the PC progresses and whether the store ever appears.
            -- A presented-but-stalled transfer (hready held low) repeats here.
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

    -- Hang detector: count instruction fetches presented in the spin window
    -- [hang_addr, hang_addr+0x40).  Once the core has fetched there enough times
    -- it is stuck in that loop (e.g. sbi_hart_hang's wfi loop); print a marker
    -- and finish so we stop wasting wall time on the post-hang spin.  Disabled
    -- when hang_addr = 0.
    hang_detect: process (clk) is
        variable hits : natural := 0;
        variable l    : line;
    begin
        if rising_edge(clk) and rstn = '1' and hang_addr /= 0 then
            if noelv_ahbsi.htrans = "10" and noelv_ahbsi.hwrite = '0'
               and noelv_ahbsi.hready = '1'
               and unsigned(noelv_ahbsi.haddr) >= to_unsigned(hang_addr, 32)
               and unsigned(noelv_ahbsi.haddr) < to_unsigned(hang_addr + 16#40#, 32) then
                hits := hits + 1;
                if hits = 200 then
                    write(l, string'("HANGDETECT ") & time'image(now)
                          & string'("  core spinning at 0x")
                          & to_hstring(noelv_ahbsi.haddr)
                          & string'(" (>=200 fetches in spin window) -- finishing"));
                    writeline(output, l);
                    std.env.finish;
                end if;
            end if;
        end if;
    end process;

    -- UART monitor: decode the NOEL-V apbuart TX (txd) and print OpenSBI's banner +
    -- any vendored fw_base.S trap prints ("T <mcause> <mepc>") to stdout.  The AHB
    -- monitor can't see the UART (0xFF900000 is outside the low region), so this is
    -- the only window into how far OpenSBI actually gets.  Bit period 8600 ns =
    -- 116279 baud = apbuart scaler 42 @ 40 MHz (baud = clk/((scaler+1)*8) = 40e6/344).
    uart_mon: process is
        constant BIT_T        : time := 8600 ns;
        variable ch           : std_logic_vector(7 downto 0);
        variable l            : line;
        variable line_started : boolean := false;
    begin
        loop
            wait until falling_edge(txd);   -- start bit
            wait for BIT_T / 2;             -- sample at start-bit center
            if txd = '0' then               -- confirm it is a real start bit
                wait for BIT_T;             -- advance to data bit 0 center
                for i in 0 to 7 loop
                    ch(i) := txd;
                    wait for BIT_T;
                end loop;
                if not line_started then
                    write(l, string'("UART: "));
                    line_started := true;
                end if;
                if ch = x"0A" then          -- LF -> flush the accumulated line
                    writeline(output, l);
                    line_started := false;
                elsif ch /= x"0D" then      -- skip CR
                    write(l, character'val(to_integer(unsigned(ch))));
                end if;
            end if;
        end loop;
    end process;

    -- UART edge logger: log every txd transition with a timestamp, so the apbuart
    -- output can be decoded OFFLINE at the actual baud (the uart_mon decoder above
    -- guesses 8600 ns and may be off).  ~5 transitions per character, so small.
    uart_edge_mon: process (txd) is
        variable l : line;
    begin
        if now > 1 ns then
            write(l, string'("TXEDGE ") & time'image(now) & string'(" ")
                  & std_ulogic'image(txd));
            writeline(output, l);
        end if;
    end process;

    -- UART THR spy: a COMPLETE, drop-free console transcript straight off the bus.
    -- The apbuart transmit-holding register (Data reg) is at offset 0 = 0xFF900000.
    -- In sim the apbuart TS status bit reads always-ready, so the firmware writes
    -- chars faster than the serializer emits them; the TX FIFO overruns and the txd
    -- wire (hence the TXEDGE/uart_mon decode above) drops ~90% of the console.  The
    -- AHB write TRANSACTION, however, carries every char the firmware emits, so we
    -- snoop the write data here.  (The main AHB monitor logs hwdata only for the low
    -- region 0x0..0x3FFFFFFF, so it never records these 0xFF9xxxxx writes.)  AHB is
    -- pipelined: capture the address phase, read hwdata in the following data phase.
    -- NOEL-V is little-endian and the THR is word-aligned, so the byte lands in
    -- hwdata(7 downto 0).  Filtered to writes of the Data reg only (status polls at
    -- 0xFF900004 and reads are ignored), so it is pure TX.
    uart_thr_spy: process (clk) is
        variable l       : line;
        variable s_addr  : std_logic_vector(31 downto 0) := (others => '0');
        variable s_write : std_ulogic := '0';
        variable s_valid : boolean := false;
        variable started : boolean := false;
        variable ch      : std_logic_vector(7 downto 0);
    begin
        if rising_edge(clk) and rstn = '1' then
            -- Data phase: a previously-accepted THR write completes.
            if s_valid and s_write = '1' and noelv_ahbsi.hready = '1'
               and s_addr = x"FF900000" then
                ch := noelv_ahbsi.hwdata(7 downto 0);
                if not started then
                    write(l, string'("UARTW: "));
                    started := true;
                end if;
                if ch = x"0A" then          -- LF -> flush the accumulated line
                    writeline(output, l);
                    started := false;
                elsif ch /= x"0D" then      -- skip CR
                    write(l, character'val(to_integer(unsigned(ch))));
                end if;
            end if;

            -- Address phase: capture the presented transfer for the next cycle.
            if noelv_ahbsi.hready = '1' then
                if noelv_ahbsi.htrans = "10" or noelv_ahbsi.htrans = "11" then
                    s_addr  := noelv_ahbsi.haddr;
                    s_write := noelv_ahbsi.hwrite;
                    s_valid := true;
                else
                    s_valid := false;
                end if;
            end if;
        end if;
    end process;

end architecture;
