-- SPDX-License-Identifier: Apache-2.0
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library grlib;
    use grlib.amba.all;

library wb;
    use wb.host;
    use wb.per;

library bridges;

-- Full-blown memory test for ahb2wb_bridge: the comprehensive on-demand sweep.
-- (Ideally tagged "manual" to keep it out of wildcard runs, but the rules_nvc
-- vhdl_test macro does not yet forward `tags`; it is fast, ~sub-second, so it is
-- harmless to run by default for now.)  It sweeps a 256-word backing memory
-- through the bridge with three passes:
--   1. Word write-all / read-all with an address-derived pattern (catches
--      address aliasing, stuck data lines, write-doesn't-stick).
--   2. Per-byte write-all / read-all: every byte lane of every word is written
--      with a distinct value via `sb` and the assembled word is verified
--      (the exhaustive version of the byte-strobe regression).
--   3. Halfword write-all / read-all on both halves.
-- Mirrors the standalone //bin/noelv_memtest / noelv_bytetest hardware probes,
-- but exercises the RTL bridge directly in simulation.
entity ahb2wb_bridge_memtest_tb is
end entity;

architecture sim of ahb2wb_bridge_memtest_tb is
    constant N_WORDS : integer := 256;        -- 1 KiB backing store

    signal clk_ahb : std_ulogic := '0';
    signal clk_wb  : std_ulogic := '0';
    signal rst     : std_ulogic := '1';

    signal ahb_ahbsi : ahb_slv_in_type;
    signal ahb_ahbso : ahb_slv_out_type;

    signal wb_wbo    : wb.host.bus_type;
    signal wb_wbi    : wb.per.bus_type;

    signal stop_sim : boolean := false;

    type mem_t is array(0 to N_WORDS - 1) of std_ulogic_vector(31 downto 0);
    signal mem : mem_t := (others => (others => '0'));

    signal fail_count : natural := 0;
begin
    clk_ahb <= not clk_ahb after 10 ns when not stop_sim else '0';
    clk_wb  <= not clk_wb  after 5 ns  when not stop_sim else '0';
    rst <= '0' after 100 ns;

    dut: entity bridges.ahb2wb_bridge
        port map (
            clk_ahb => clk_ahb, clk_wb => clk_wb, rst => rst,
            ahb_ahbsi => ahb_ahbsi, ahb_ahbso => ahb_ahbso,
            wb_wbo => wb_wbo, wb_wbi => wb_wbi
        );

    -- Mock Wishbone slave honoring per-byte strobes; N_WORDS deep.
    wb_slave: process(clk_wb)
        variable idx : integer range 0 to N_WORDS - 1;
    begin
        if rising_edge(clk_wb) then
            if rst = '1' then
                wb_wbi.ack <= '0';
                wb_wbi.rdt <= (others => '0');
            else
                wb_wbi.ack <= '0';
                if wb_wbo.cyc = '1' and wb_wbi.ack = '0' then
                    idx := to_integer(unsigned(wb_wbo.adr(31 downto 2))) mod N_WORDS;
                    if wb_wbo.we = '1' then
                        for b in 0 to 3 loop
                            if wb_wbo.sel(b) = '1' then
                                mem(idx)(8*b+7 downto 8*b) <= wb_wbo.dat(8*b+7 downto 8*b);
                            end if;
                        end loop;
                    else
                        wb_wbi.rdt <= mem(idx);
                    end if;
                    wb_wbi.ack <= '1';
                end if;
            end if;
        end if;
    end process;

    main: process
        procedure ahb_xfer(addr : std_logic_vector(31 downto 0);
                           data : std_logic_vector(31 downto 0);
                           hsize : std_logic_vector(2 downto 0);
                           wr : std_ulogic;
                           rd_val : out std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk_ahb) and ahb_ahbso.hready = '1';
            ahb_ahbsi.hsel(0) <= '1';
            ahb_ahbsi.haddr   <= addr;
            ahb_ahbsi.hsize   <= hsize;
            ahb_ahbsi.hwrite  <= wr;
            ahb_ahbsi.htrans  <= HTRANS_NONSEQ;
            wait until rising_edge(clk_ahb);
            ahb_ahbsi.hwdata(31 downto 0) <= data;
            ahb_ahbsi.htrans  <= HTRANS_IDLE;
            loop
                wait until rising_edge(clk_ahb);
                if ahb_ahbso.hready = '1' then
                    rd_val := ahb_ahbso.hrdata(31 downto 0);
                    exit;
                end if;
            end loop;
            ahb_ahbsi.hsel(0) <= '0';
        end procedure;

        variable dummy : std_logic_vector(31 downto 0);
        variable got   : std_logic_vector(31 downto 0);
        variable exp   : std_logic_vector(31 downto 0);

        -- 32-bit word address for word index i.
        function waddr(i : integer) return std_logic_vector is
        begin
            return std_logic_vector(to_unsigned(i * 4, 32));
        end function;

        -- Replicate a byte across all 4 lanes, as the NOEL-V drives sub-word
        -- write data.
        function rep(b : std_logic_vector(7 downto 0)) return std_logic_vector is
        begin
            return b & b & b & b;
        end function;
    begin
        ahb_ahbsi.hsel <= (others => '0');
        ahb_ahbsi.haddr <= (others => '0');
        ahb_ahbsi.hwrite <= '0';
        ahb_ahbsi.htrans <= HTRANS_IDLE;
        ahb_ahbsi.hsize <= (others => '0');
        ahb_ahbsi.hburst <= (others => '0');
        ahb_ahbsi.hwdata <= (others => '0');
        ahb_ahbsi.hprot <= (others => '0');
        ahb_ahbsi.hready <= '1';
        ahb_ahbsi.hmaster <= (others => '0');
        ahb_ahbsi.hmastlock <= '0';
        ahb_ahbsi.hmbsel <= (others => '0');
        ahb_ahbsi.hirq <= (others => '0');
        ahb_ahbsi.testen <= '0';
        ahb_ahbsi.testrst <= '1';
        ahb_ahbsi.scanen <= '0';
        ahb_ahbsi.testoen <= '1';
        ahb_ahbsi.testin <= (others => '0');
        ahb_ahbsi.endian <= '0';

        wait until rst = '0';
        wait until rising_edge(clk_ahb);

        ---------------------------------------------------------------------
        report "PASS 1: word write-all / read-all (address pattern)";
        for i in 0 to N_WORDS - 1 loop
            ahb_xfer(waddr(i),
                     std_logic_vector(unsigned'(x"A5A50000") + to_unsigned(i, 32)),
                     "010", '1', dummy);
        end loop;
        for i in 0 to N_WORDS - 1 loop
            exp := std_logic_vector(unsigned'(x"A5A50000") + to_unsigned(i, 32));
            ahb_xfer(waddr(i), x"00000000", "010", '0', got);
            if got /= exp then
                report "word @" & integer'image(i*4) & ": got 0x" & to_hstring(got) &
                       " exp 0x" & to_hstring(exp) severity error;
                fail_count <= fail_count + 1;
            end if;
        end loop;

        ---------------------------------------------------------------------
        report "PASS 2: per-byte write-all / read-all";
        for i in 0 to N_WORDS - 1 loop
            for b in 0 to 3 loop
                -- byte value = (word index + lane) mod 256
                ahb_xfer(std_logic_vector(to_unsigned(i*4 + b, 32)),
                         rep(std_logic_vector(to_unsigned((i + b) mod 256, 8))),
                         "000", '1', dummy);
            end loop;
        end loop;
        for i in 0 to N_WORDS - 1 loop
            exp := std_logic_vector(to_unsigned((i+3) mod 256, 8)) &
                   std_logic_vector(to_unsigned((i+2) mod 256, 8)) &
                   std_logic_vector(to_unsigned((i+1) mod 256, 8)) &
                   std_logic_vector(to_unsigned((i+0) mod 256, 8));
            ahb_xfer(waddr(i), x"00000000", "010", '0', got);
            if got /= exp then
                report "byte word @" & integer'image(i*4) & ": got 0x" & to_hstring(got) &
                       " exp 0x" & to_hstring(exp) severity error;
                fail_count <= fail_count + 1;
            end if;
        end loop;

        ---------------------------------------------------------------------
        report "PASS 3: halfword write-all / read-all";
        for i in 0 to N_WORDS - 1 loop
            ahb_xfer(waddr(i), x"00000000", "010", '1', dummy);                 -- clear
            ahb_xfer(waddr(i),
                     std_logic_vector(to_unsigned(i, 16)) & std_logic_vector(to_unsigned(i, 16)),
                     "001", '1', dummy);                                        -- low half
            ahb_xfer(std_logic_vector(to_unsigned(i*4 + 2, 32)),
                     std_logic_vector(to_unsigned((16#FFFF# - i), 16)) &
                     std_logic_vector(to_unsigned((16#FFFF# - i), 16)),
                     "001", '1', dummy);                                        -- high half
        end loop;
        for i in 0 to N_WORDS - 1 loop
            exp := std_logic_vector(to_unsigned((16#FFFF# - i), 16)) &
                   std_logic_vector(to_unsigned(i, 16));
            ahb_xfer(waddr(i), x"00000000", "010", '0', got);
            if got /= exp then
                report "hword word @" & integer'image(i*4) & ": got 0x" & to_hstring(got) &
                       " exp 0x" & to_hstring(exp) severity error;
                fail_count <= fail_count + 1;
            end if;
        end loop;

        if fail_count = 0 then
            report "FULL MEMORY TEST PASSED (" & integer'image(N_WORDS) & " words)";
        else
            report "FULL MEMORY TEST FAILED: " & integer'image(fail_count) &
                   " mismatch(es)" severity failure;
        end if;

        stop_sim <= true;
        wait;
    end process;
end architecture;
