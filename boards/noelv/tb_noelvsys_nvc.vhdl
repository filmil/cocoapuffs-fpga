-- SPDX-License-Identifier: Apache-2.0
--
-- VUnit-FREE copy of tb_noelvsys_only for NVC.  Identical DUT (gaisler.noelvsys +
-- the three bridges.ahb_bram banks + the firmware) and identical monitors (AHB
-- bus monitor, decoded UART, TXEDGE logger), but with a plain clock/reset and a
-- run-for-sim_duration harness instead of the VUnit runner + VUnit UART
-- verification component (rules_vunit does not package the VCs for NVC).
--
-- Purpose: boot OpenSBI under NVC -- a DIFFERENT VHDL simulator than xsim -- to
-- test whether the fdt_next_node device-tree-walk HANG is an xsim simulation bug
-- (xsim's optimizer even crashes on the iunv).  If OpenSBI boots past the FDT
-- loop here while it hangs under xsim with the SAME RTL, the bug is xsim's, not
-- the NOEL-V's.  cfg = 0x300 (dual-issue) matches the xsim config that hangs.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;
use std.env.all;

library grlib;
use grlib.amba.all;
use grlib.devices.all;

library gaisler;
use gaisler.uart.all;

library bridges;

entity tb_noelvsys_nvc is
    generic (
        sim_duration_ns: natural := 5000;
        noelv_memfile:   string  := "";
        noelv_memsize:   natural := 4096;
        lowmem_file:     string  := "";
        lowmem_size:     natural := 4096;
        lowmem_regbits:  natural := 12;
        disas:           integer := 0;
        hang_addr:       natural := 0;
        zbi_file:        string  := "";
        zbi_size:        natural := 4096;
        zbi_regbits:     natural := 12;
        zbi_haddr:       natural := 16#100#;
        zbi_hmask:       natural := 16#FFC#
    );
end entity;

architecture sim of tb_noelvsys_nvc is
    signal clk:  std_ulogic := '0';
    signal rstn: std_ulogic := '0';
    signal rst:  std_ulogic;

    signal noelv_ahbsi:      ahb_slv_in_type;
    signal noelv_ahbso_vec:  ahb_slv_out_vector_type(2 downto 0);
    signal noelv_gclk:       std_ulogic_vector(0 to 0);
    signal noelv_uarti:      uart_in_type;
    signal uarto_noelv:      uart_out_type;
    signal noelv_apbo:       apb_slv_out_vector;
    signal noelv_ahbmo:      ahb_mst_out_vector_type(1 downto 1);
    signal noelv_dbgmo:      ahb_mst_out_vector_type(0 downto 0);

    signal txd, rxd: std_ulogic := '1';

    constant sim_duration: time := sim_duration_ns * 1 ns;
begin

    clk <= not clk after 12500 ps; -- 40 MHz core clock (matches board.dts + HW)
    noelv_gclk(0) <= clk;
    rst <= not rstn;

    rst_process: process
    begin
        rstn <= '0';
        wait for 100 ns;
        rstn <= '1';
        wait;
    end process;

    -- Plain run-for-duration harness (replaces the VUnit runner).  hang_detect
    -- below finishes early if the core enters a known spin window.
    run_process: process
        variable l: line;
    begin
        wait for sim_duration;
        write(l, string'("SIMDONE ") & time'image(now)
              & string'(" -- sim_duration reached"));
        writeline(output, l);
        finish;
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
        cached   => 16#000F#,
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
        cfg      => 16#300#,  -- dual-issue GP, matches the xsim hang config
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

    noelv_boot_ram: entity bridges.ahb_bram
    generic map (
        hindex => 0, haddr => 16#C00#, hmask => 16#FFF#,
        memfile => noelv_memfile, memsize => noelv_memsize, reg_bit_count => 12
    )
    port map (clk => clk, rstn => rstn, ahbsi => noelv_ahbsi, ahbso => noelv_ahbso_vec(0));

    noelv_lowmem: entity bridges.ahb_bram
    generic map (
        hindex => 1, haddr => 16#000#, hmask => 16#F00#,
        memfile => lowmem_file, memsize => lowmem_size, reg_bit_count => lowmem_regbits
    )
    port map (clk => clk, rstn => rstn, ahbsi => noelv_ahbsi, ahbso => noelv_ahbso_vec(1));

    noelv_zbimem: entity bridges.ahb_bram
    generic map (
        hindex => 2, haddr => zbi_haddr, hmask => zbi_hmask,
        memfile => zbi_file, memsize => zbi_size, reg_bit_count => zbi_regbits
    )
    port map (clk => clk, rstn => rstn, ahbsi => noelv_ahbsi, ahbso => noelv_ahbso_vec(2));

    -- AHB bus monitor (low region 0x0..0x3FFFFFFF) -- identical to the xsim tb.
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
                          & string'("  hwdata=0x") & to_hstring(noelv_ahbsi.hwdata(31 downto 0)));
                else
                    write(l, string'("AHBMON ") & time'image(now)
                          & string'("  RD 0x") & to_hstring(p_addr)
                          & string'("  hrdata=0x") & to_hstring(noelv_ahbso_vec(1).hrdata(31 downto 0)));
                end if;
                writeline(output, l);
            end if;
            -- Boot-RAM (0xC00xxxxx, hindex 0) completion: log the returned
            -- instruction word so we can see whether the fetch COMPLETES and
            -- what it reads (U/0/NOP).  vec(0) is the boot RAM slave.
            if p_valid and noelv_ahbsi.hready = '1'
               and p_addr(31 downto 20) = x"C00" then
                write(l, string'("AHBMON ") & time'image(now)
                      & string'("  BOOTRAM ") );
                if p_write = '1' then write(l, string'("WR ")); else write(l, string'("RD ")); end if;
                write(l, string'("0x") & to_hstring(p_addr)
                      & string'("  hrdata=0x") & to_hstring(noelv_ahbso_vec(0).hrdata(31 downto 0))
                      & string'("  resp=") & std_ulogic'image(noelv_ahbso_vec(0).hresp(0)));
                writeline(output, l);
            end if;
            if noelv_ahbsi.htrans = "10" then
                write(l, string'("AHBMON ") & time'image(now) & string'("  REQ "));
                if noelv_ahbsi.hwrite = '1' then write(l, string'("WR ")); else write(l, string'("RD ")); end if;
                write(l, string'("0x") & to_hstring(noelv_ahbsi.haddr)
                      & string'("  hready=") & std_ulogic'image(noelv_ahbsi.hready));
                writeline(output, l);
            end if;
            if noelv_ahbsi.hready = '1' then
                if noelv_ahbsi.htrans = "10" or noelv_ahbsi.htrans = "11" then
                    p_addr := noelv_ahbsi.haddr; p_write := noelv_ahbsi.hwrite; p_valid := true;
                else
                    p_valid := false;
                end if;
            end if;
        end if;
    end process;

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
                          & string'("  core spinning at 0x") & to_hstring(noelv_ahbsi.haddr)
                          & string'(" -- finishing"));
                    writeline(output, l);
                    finish;
                end if;
            end if;
        end if;
    end process;

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
                    write(l, string'("UART: ")); line_started := true;
                end if;
                if ch = x"0A" then
                    writeline(output, l); line_started := false;
                elsif ch /= x"0D" then
                    write(l, character'val(to_integer(unsigned(ch))));
                end if;
            end if;
        end loop;
    end process;

    uart_edge_mon: process (txd) is
        variable l : line;
    begin
        if now > 1 ns then
            write(l, string'("TXEDGE ") & time'image(now) & string'(" ")
                  & std_ulogic'image(txd));
            writeline(output, l);
        end if;
    end process;

    -- DEBUG: does the sync-reset actually land on r.csr under NVC?  Probe the
    -- PMP CSR state at reset (100ns) and a few times after.  If pmpaddr / the
    -- pipeline hold are 'U' after reset, the reset isn't landing (NVC record
    -- reset issue); if defined, the X is elsewhere.
    reset_probe: process is
        variable l : line;
    begin
        for t in 0 to 59 loop
            wait for 100 ns;
            write(l, string'("PROBE ") & time'image(now)
                  & string'("  holdn=")
                  & std_ulogic'image(<< signal noelv0.cpuloop(0).core.u0.c0.c0.iu0.holdn : std_ulogic >>)
                  & string'("  rstn=") & std_ulogic'image(rstn));
            writeline(output, l);
        end loop;
        wait;
    end process;

end architecture;
