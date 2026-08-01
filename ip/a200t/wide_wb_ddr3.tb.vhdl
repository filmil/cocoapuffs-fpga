-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library a200t;
library wb;

entity tb is
    generic(
        sim_duration: time := 2000ns
        ; clock_period: time := 5ns
    );
end entity;

architecture sim of tb is

    -- Inline clock/reset (the shared testing.clkgen library does not
    -- currently compile under NVC -- vunit vc_context bit-rot -- and this tb
    -- only needs a plain clock).
    signal clk: std_ulogic := '0';
    signal reset: std_ulogic := '1';
    signal sim_done: boolean := false;

    signal hs_wb_host: wb.host.bus_type := wb.host.new_bus_type;
    signal hs_wb_per: wb.per.bus_type := wb.per.new_bus_type;

    signal ps_wb_host: a200t.ddr3.wb_host_type := a200t.ddr3.new_wb_host_type;
    signal ps_wb_per: a200t.ddr3.wb_per_type := a200t.ddr3.new_wb_per_type;

    signal test_count: natural := 1;
begin

    clk <= not clk after clock_period / 2 when not sim_done else '0';
    reset <= '0' after 10ns;

    watchdog: process
    begin
        wait for sim_duration;
        assert sim_done
            report "TB TIMEOUT: checks did not complete within "
                   & time'image(sim_duration)
            severity failure;
        wait;
    end process;

    uut0: entity a200t.wide_wb_ddr3
    port map(
        clk => clk
        , reset => reset
        , hostside_wb_host => hs_wb_host
        , hostside_wb_per => hs_wb_per
        , perside_wb_host => ps_wb_host
        , perside_wb_per => ps_wb_per
    );

    test0: process
        -- The UberDDR3 wishbone address is BURST-addressable: one unit per
        -- 32-byte burst (8 columns x 4-byte lanes), 25 bits spanning the full
        -- 1 GB (2**25 * 32 B).  For a host byte address A the peripheral-side
        -- address must therefore be A(29 downto 5).  The historical bug kept
        -- only A(26 downto 5) (and appended "000"), so byte-address bits
        -- 29:27 were DROPPED -- on hardware the 1 GB window aliased every
        -- 128 MB (JTAG-proven 2026-07-08) and the ZBI upload at 0x10000000
        -- wrapped onto physical 0x0, wiping the firmware.
        procedure check_write_adr(
            constant byte_addr: in std_ulogic_vector(31 downto 0);
            constant wdata: in std_ulogic_vector(31 downto 0);
            constant label_v: in string) is
            variable expect_adr: std_ulogic_vector(24 downto 0);
            variable index_v: natural;
        begin
            expect_adr := byte_addr(29 downto 5);
            index_v := to_integer(unsigned(byte_addr(4 downto 2)));

            -- Present the write with the peripheral stalled, so the buffered
            -- request stays observable.
            ps_wb_per.stall <= '1';
            ps_wb_per.ack <= '0';
            hs_wb_host <= (
                adr => byte_addr
                , sel => (others => '1')
                , dat => wdata
                , we => '1'
                , cyc => '0'
            );
            wait until rising_edge(clk);
            hs_wb_host.cyc <= '1';
            wait until rising_edge(clk);
            hs_wb_host <= wb.host.new_bus_type;

            -- The adapter latches in `idle` and drives the buffered request on
            -- the peripheral side one cycle later.
            wait until rising_edge(clk);
            wait until rising_edge(clk);

            assert ps_wb_host.cyc = '1'
                report label_v & ": perside cyc not asserted"
                severity failure;
            assert ps_wb_host.adr = expect_adr
                report label_v & ": perside burst adr mismatch for byte addr 0x"
                       & to_hstring(byte_addr)
                       & ": got 0x" & to_hstring(ps_wb_host.adr)
                       & " expected 0x" & to_hstring(expect_adr)
                       & " (byte-address bits 29:27 dropped => 128 MB aliasing)"
                severity failure;
            assert ps_wb_host.sel(4*index_v + 3 downto 4*index_v) = "1111"
                report label_v & ": perside sel lane mismatch for index "
                       & natural'image(index_v)
                severity failure;
            assert ps_wb_host.data(32*index_v + 31 downto 32*index_v) = wdata
                report label_v & ": perside data lane mismatch for index "
                       & natural'image(index_v)
                severity failure;

            -- Complete the transaction (stall released with ack, as the
            -- controller does) and let the adapter come back to idle.
            ps_wb_per.ack <= '1';
            wait until rising_edge(clk);
            ps_wb_per.stall <= '0';
            wait until rising_edge(clk);
            ps_wb_per.ack <= '0';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            test_count <= test_count + 1;
        end procedure;
    begin

        wait until reset = '0';
        wait until rising_edge(clk);

        -- Below the 128 MB boundary: byte 0x20 = burst 1, word lane 0.
        check_write_adr(x"00000020", x"cafebabe", "low");

        -- The aliasing regression: bit 27 set.  Differs from "low" ONLY in
        -- byte-address bit 27; the buggy slice mapped both to the same burst.
        check_write_adr(x"08000020", x"0000d00d", "bit27");

        -- Bit 29 (top of the 1 GB window) + a high word lane (index 7).
        check_write_adr(x"2000007C", x"f005ba11", "bit29");

        -- The original mid-range pattern: 0x1234567C, word lane 7.
        check_write_adr(x"1234567C", x"deadbeef", "mid");

        -- Read transaction: returned wide data must be sliced at the word
        -- lane selected by the byte address (index 7 => bits 255:224).
        ps_wb_per.stall <= '1';
        hs_wb_host <= (
            adr => x"1234567C"
            , sel => (others => '1')
            , dat => x"00000000"
            , we => '0'
            , cyc => '1'
        );
        wait until rising_edge(clk);
        hs_wb_host.cyc <= '0';
        ps_wb_per.data <= (others => '0');
        ps_wb_per.data(255 downto 256-32) <= x"f005ba11";
        ps_wb_per.ack <= '1';
        wait until rising_edge(clk);
        ps_wb_per.stall <= '0';
        wait until rising_edge(clk);
        ps_wb_per.ack <= '0';
        wait until rising_edge(clk);
        assert hs_wb_per.ack = '1'
            report "read: hostside ack not asserted" severity failure;
        assert hs_wb_per.rdt = x"f005ba11"
            report "read: hostside data mismatch: got 0x"
                   & to_hstring(hs_wb_per.rdt) severity failure;

        report "wide_wb_ddr3 TB PASS: 4 burst-address checks + read lane check"
            severity note;
        sim_done <= true;
        wait;

    end process;

end architecture;
