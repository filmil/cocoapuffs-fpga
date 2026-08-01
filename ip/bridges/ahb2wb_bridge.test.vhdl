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

-- Testbench for ahb2wb_bridge, focused on per-byte write strobes.
--
-- Regression for the DDR3 corruption bug: the bridge used to hardwire the
-- Wishbone `sel` (byte mask) to all-ones, so a sub-word store (`sb`/`sh`) wrote
-- every byte of the 32-bit word.  Because the NOEL-V replicates the data byte
-- across all lanes for sub-word writes, an `sb 0xAA` produced 0xAAAAAAAA -- which
-- silently corrupted DDR3 and broke OpenSBI's sbi_memcpy/sbi_memset.  The mock
-- Wishbone slave below is a real memory that honors `sel`, so it only passes if
-- the bridge drives the correct strobes for byte/halfword/word transfers.
entity ahb2wb_bridge_tb is
end entity;

architecture sim of ahb2wb_bridge_tb is
    -- Clocks and reset
    signal clk_ahb : std_ulogic := '0'; -- 50MHz
    signal clk_wb  : std_ulogic := '0'; -- 100MHz
    signal rst     : std_ulogic := '1';

    -- AHB Interface
    signal ahb_ahbsi : ahb_slv_in_type;
    signal ahb_ahbso : ahb_slv_out_type;

    -- Wishbone Interface
    signal wb_wbo    : wb.host.bus_type;
    signal wb_wbi    : wb.per.bus_type;

    signal stop_sim : boolean := false;

    -- Mock Wishbone slave memory (16 words), addressed by adr(5 downto 2).
    type mem_t is array(0 to 15) of std_ulogic_vector(31 downto 0);
    signal mem : mem_t := (others => (others => '0'));

    signal fail_count : natural := 0;
begin
    -- 50MHz Clock (20ns period)
    clk_ahb <= not clk_ahb after 10 ns when not stop_sim else '0';
    -- 100MHz Clock (10ns period)
    clk_wb  <= not clk_wb after 5 ns when not stop_sim else '0';

    rst <= '0' after 100 ns;

    dut: entity bridges.ahb2wb_bridge
        port map (
            clk_ahb   => clk_ahb,
            clk_wb    => clk_wb,
            rst       => rst,
            ahb_ahbsi => ahb_ahbsi,
            ahb_ahbso => ahb_ahbso,
            wb_wbo    => wb_wbo,
            wb_wbi    => wb_wbi
        );

    -- Mock Wishbone slave: a real memory that honors the per-byte `sel` strobes
    -- on writes (so byte writes only touch the selected lanes) and returns the
    -- stored word on reads.
    wb_slave: process(clk_wb)
        variable idx : integer range 0 to 15;
    begin
        if rising_edge(clk_wb) then
            if rst = '1' then
                wb_wbi.ack <= '0';
                wb_wbi.rdt <= (others => '0');
            else
                wb_wbi.ack <= '0';
                if wb_wbo.cyc = '1' and wb_wbi.ack = '0' then
                    idx := to_integer(unsigned(wb_wbo.adr(5 downto 2)));
                    if wb_wbo.we = '1' then
                        -- Apply each byte only if its strobe is set.
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
        -- Issue one AHB transfer of the given size.  For writes, `data` is the
        -- 32-bit data bus value (the NOEL-V replicates the byte/halfword across
        -- lanes, so callers pass a replicated pattern for sub-word writes).
        procedure ahb_xfer(addr  : std_logic_vector(31 downto 0);
                           data  : std_logic_vector(31 downto 0);
                           hsize : std_logic_vector(2 downto 0);
                           wr    : std_ulogic;
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

        -- Write `data` (size `hsize`) to `addr`, then read the containing word
        -- back and assert it equals `expect`.
        procedure check_word(addr   : std_logic_vector(31 downto 0);
                             data   : std_logic_vector(31 downto 0);
                             hsize  : std_logic_vector(2 downto 0);
                             expect : std_logic_vector(31 downto 0);
                             name   : string) is
            variable got : std_logic_vector(31 downto 0);
        begin
            ahb_xfer(addr, data, hsize, '1', dummy);
            -- Read the aligned word (offset bits cleared).
            ahb_xfer(addr(31 downto 2) & "00", x"00000000", "010", '0', got);
            if got = expect then
                report name & ": OK (0x" & to_hstring(got) & ")";
            else
                report name & ": FAIL got 0x" & to_hstring(got) &
                       " expected 0x" & to_hstring(expect) severity error;
                fail_count <= fail_count + 1;
            end if;
        end procedure;

        -- Full-word store followed by a full-word load; the read must return
        -- exactly what was written.
        procedure check_rw_word(addr : std_logic_vector(31 downto 0);
                                data : std_logic_vector(31 downto 0);
                                name : string) is
            variable got : std_logic_vector(31 downto 0);
        begin
            ahb_xfer(addr, data, "010", '1', dummy);
            ahb_xfer(addr, x"00000000", "010", '0', got);
            if got = data then
                report name & ": OK (0x" & to_hstring(got) & ")";
            else
                report name & ": FAIL got 0x" & to_hstring(got) &
                       " expected 0x" & to_hstring(data) severity error;
                fail_count <= fail_count + 1;
            end if;
        end procedure;

        -- Multi-beat INCR write burst.  Cache-line write-backs arrive as AHB
        -- bursts (NONSEQ then back-to-back SEQ), not the isolated single transfers
        -- the other tests use.  Drives n beats, holding each address until hready
        -- so the bridge's per-beat serialization is exercised, with the data phase
        -- of beat i overlapping the address phase of beat i+1 (real AHB pipelining).
        -- Beat i writes 0xB0000000+i to base+4*i; the read-back below proves the
        -- bridge pairs every beat's address with the CORRECT data (a mis-pair or
        -- dropped beat is exactly how a burst would corrupt OpenSBI's data).
        procedure ahb_burst_write(base : std_logic_vector(31 downto 0);
                                  n    : integer) is
        begin
            wait until rising_edge(clk_ahb) and ahb_ahbso.hready = '1';
            ahb_ahbsi.hsel(0) <= '1';
            ahb_ahbsi.hwrite  <= '1';
            ahb_ahbsi.hsize   <= "010";
            ahb_ahbsi.hburst  <= "001";          -- INCR
            ahb_ahbsi.haddr   <= base;
            ahb_ahbsi.htrans  <= HTRANS_NONSEQ;
            for i in 0 to n - 1 loop
                -- wait until beat i's address phase is accepted (hready high)
                loop
                    wait until rising_edge(clk_ahb);
                    exit when ahb_ahbso.hready = '1';
                end loop;
                -- present beat i's write data and, overlapping it, beat i+1's addr
                ahb_ahbsi.hwdata(31 downto 0) <=
                    std_logic_vector(unsigned'(x"B0000000") + to_unsigned(i, 32));
                if i < n - 1 then
                    ahb_ahbsi.haddr  <=
                        std_logic_vector(unsigned(base) + to_unsigned((i + 1) * 4, 32));
                    ahb_ahbsi.htrans <= HTRANS_SEQ;
                else
                    ahb_ahbsi.htrans <= HTRANS_IDLE;
                end if;
            end loop;
            -- let the final beat's data phase complete
            loop
                wait until rising_edge(clk_ahb);
                exit when ahb_ahbso.hready = '1';
            end loop;
            ahb_ahbsi.hsel(0) <= '0';
            ahb_ahbsi.hburst  <= (others => '0');
        end procedure;

    begin
        -- Initialize AHB signals
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

        -- 1) Word store writes the whole word.
        check_word(x"00000000", x"11223344", "010", x"11223344", "word store");

        -- 2) Byte stores: start from a known word, then overwrite one lane at a
        --    time.  NOEL-V replicates the byte across all lanes, so the data bus
        --    carries 0xNNNNNNNN; only the addressed lane must change.
        dummy := (others => '0');
        ahb_xfer(x"00000004", x"00000000", "010", '1', dummy);          -- clear word @4
        check_word(x"00000004", x"AAAAAAAA", "000", x"000000AA", "byte store @+0");
        check_word(x"00000005", x"BBBBBBBB", "000", x"0000BBAA", "byte store @+1");
        check_word(x"00000006", x"CCCCCCCC", "000", x"00CCBBAA", "byte store @+2");
        check_word(x"00000007", x"DDDDDDDD", "000", x"DDCCBBAA", "byte store @+3");

        -- 3) Halfword stores: low and high halves independently.
        ahb_xfer(x"00000008", x"00000000", "010", '1', dummy);          -- clear word @8
        check_word(x"00000008", x"22222222", "001", x"00002222", "hword store @+0");
        check_word(x"0000000A", x"44444444", "001", x"44442222", "hword store @+2");

        -- 4) Word read/write at specific addresses (data-bus integrity).
        check_rw_word(x"00000000", x"DEADBEEF", "word rw @0x00");
        check_rw_word(x"00000004", x"0BADF00D", "word rw @0x04");
        check_rw_word(x"00000020", x"A5A5A5A5", "word rw @0x20");
        check_rw_word(x"0000003C", x"5A5A5A5A", "word rw @0x3C");

        -- 5) Word read/write sweep over the whole mock memory (16 words): each
        --    word holds a distinct value, then all are read back -- catches
        --    address aliasing and stuck data lines.
        for i in 0 to 15 loop
            ahb_xfer(std_logic_vector(to_unsigned(i * 4, 32)),
                     std_logic_vector(unsigned'(x"C0DE0000") + to_unsigned(i, 32)),
                     "010", '1', dummy);
        end loop;
        for i in 0 to 15 loop
            ahb_xfer(std_logic_vector(to_unsigned(i * 4, 32)), x"00000000",
                     "010", '0', dummy);
            if dummy = std_logic_vector(unsigned'(x"C0DE0000") + to_unsigned(i, 32)) then
                report "word sweep @" & integer'image(i * 4) & ": OK";
            else
                report "word sweep @" & integer'image(i * 4) & ": FAIL got 0x" &
                       to_hstring(dummy) & " expected 0x" &
                       to_hstring(std_logic_vector(unsigned'(x"C0DE0000") + to_unsigned(i, 32)))
                       severity error;
                fail_count <= fail_count + 1;
            end if;
        end loop;

        -- 6) Multi-beat INCR write burst (models a cache-line write-back).  Beat i
        --    writes 0xB0000000+i to base+4i; read each word back and confirm the
        --    bridge paired every beat's address with the right data.
        ahb_burst_write(x"00000010", 4);
        for i in 0 to 3 loop
            ahb_xfer(std_logic_vector(to_unsigned(16 + i * 4, 32)), x"00000000",
                     "010", '0', dummy);
            if dummy = std_logic_vector(unsigned'(x"B0000000") + to_unsigned(i, 32)) then
                report "burst beat @" & integer'image(16 + i * 4) & ": OK (0x" &
                       to_hstring(dummy) & ")";
            else
                report "burst beat @" & integer'image(16 + i * 4) & ": FAIL got 0x" &
                       to_hstring(dummy) & " expected 0x" &
                       to_hstring(std_logic_vector(unsigned'(x"B0000000") + to_unsigned(i, 32)))
                       severity error;
                fail_count <= fail_count + 1;
            end if;
        end loop;

        if fail_count = 0 then
            report "ALL BYTE-STROBE TESTS PASSED";
        else
            report "BYTE-STROBE TESTS FAILED: " & integer'image(fail_count) &
                   " case(s)" severity failure;
        end if;

        stop_sim <= true;
        wait;
    end process;

end architecture;
