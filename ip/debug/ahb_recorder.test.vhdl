-- SPDX-License-Identifier: Apache-2.0

--! @brief NVC unit test for the ahb_recorder: drive a few AHB transfers, dump,
--! and check the streamed ASCII-hex lines.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library debug;

entity ahb_recorder_test_tb is
end entity;

architecture sim of ahb_recorder_test_tb is
    --! Clock half-period.
    constant half_period : time := 5 ns;

    signal clk   : std_ulogic := '0';
    signal rstn  : std_ulogic := '0';

    --! Snooped AHB request signals (driven by the stimulus).
    signal haddr  : std_ulogic_vector(31 downto 0) := (others => '0');
    signal hwdata : std_ulogic_vector(31 downto 0) := (others => '0');
    signal htrans : std_ulogic_vector(1 downto 0)  := "00";
    signal hwrite : std_ulogic := '0';
    signal hready : std_ulogic := '1';
    signal dump   : std_ulogic := '0';

    --! Dump byte stream.
    signal tx_data   : std_ulogic_vector(7 downto 0);
    signal tx_valid  : std_ulogic;
    signal tx_ready  : std_ulogic := '1';   --! consumer always ready
    signal recording : std_ulogic;
    signal full      : std_ulogic;
begin
    --! Free-running clock.
    clk <= not clk after half_period;

    --! Power-on reset.
    rstn <= '0', '1' after 40 ns;

    --! Safety timeout.
    watchdog: process is
    begin
        wait for 200 us;
        assert false report "ahb_recorder_test timeout" severity failure;
    end process;

    --! Device under test (16-record buffer).
    uut: entity debug.ahb_recorder
        generic map (addr_bits => 4)
        port map (
            clk => clk, rstn => rstn,
            haddr => haddr, htrans => htrans, hwrite => hwrite,
            hready => hready, hwdata => hwdata,
            dump => dump,
            tx_data => tx_data, tx_valid => tx_valid, tx_ready => tx_ready,
            recording => recording, full => full, dumping => open
        );

    --! Stimulus + checks.
    test: process is
        variable collected : string(1 to 512);
        variable n         : natural := 0;

        --! Drive one accepted AHB transfer (single address beat).
        procedure ahb_xfer(addr : std_ulogic_vector(31 downto 0);
                           wr   : std_ulogic;
                           data : std_ulogic_vector(31 downto 0)) is
        begin
            haddr  <= addr;
            hwrite <= wr;
            hwdata <= data;
            htrans <= "10";                 --! NONSEQ; hready already '1'
            wait until rising_edge(clk);
            htrans <= "00";                 --! IDLE
            wait until rising_edge(clk);
        end procedure;
    begin
        wait until rstn = '1';
        wait until rising_edge(clk);

        --! Record three transfers.
        ahb_xfer(x"00040000", '0', x"00000000");   --! read DDR3 @ 0x40000
        ahb_xfer(x"C0000000", '0', x"00000000");   --! read boot BRAM
        ahb_xfer(x"FF900000", '1', x"00000048");   --! write 'H' to the UART

        --! Trigger a dump.
        wait until rising_edge(clk);
        dump <= '1';
        wait until rising_edge(clk);
        dump <= '0';

        --! Collect streamed bytes until the recorder rewinds and resumes.
        loop
            wait until rising_edge(clk);
            if tx_valid = '1' and tx_ready = '1' then
                n := n + 1;
                collected(n) := character'val(to_integer(unsigned(tx_data)));
            end if;
            exit when recording = '1';
        end loop;

        --! 3 records * 30 chars/line.
        assert n = 90
            report "expected 90 bytes, got " & integer'image(n) severity failure;
        --! Record 1 is chars 1..30: W/R at col 10, addr at cols 12..19.
        assert collected(10) = 'R'
            report "record 1 should be a read" severity failure;
        assert collected(12 to 19) = "00040000"
            report "record 1 addr mismatch: '" & collected(12 to 19) & "'"
            severity failure;
        --! Record 3 (chars 61..90): W/R at col 70, addr at cols 72..79.
        assert collected(70) = 'W'
            report "record 3 should be a write" severity failure;
        assert collected(72 to 79) = "ff900000"
            report "record 3 addr mismatch: '" & collected(72 to 79) & "'"
            severity failure;

        --! Phase 2: overfill the 16-record buffer so the circular window wraps,
        --! then dump and confirm it kept exactly the latest 16 transfers, streamed
        --! oldest-first. 16 more transfers tagged 0x100+i leave the window holding
        --! i=0..15 (the earlier 3 records scrolled out).
        for i in 0 to 15 loop
            ahb_xfer(std_ulogic_vector(to_unsigned(16#100# + i, 32)), '0',
                     x"00000000");
        end loop;
        wait until rising_edge(clk);
        dump <= '1';
        wait until rising_edge(clk);
        dump <= '0';
        n := 0;
        loop
            wait until rising_edge(clk);
            if tx_valid = '1' and tx_ready = '1' then
                n := n + 1;
                collected(n) := character'val(to_integer(unsigned(tx_data)));
            end if;
            exit when recording = '1';
        end loop;
        --! 16 records * 30 chars.
        assert n = 480
            report "phase2: expected 480 bytes, got " & integer'image(n)
            severity failure;
        --! Oldest kept record is the first 0x100+i write (i=0), addr at cols 12..19.
        assert collected(12 to 19) = "00000100"
            report "phase2 oldest addr mismatch: '" & collected(12 to 19) & "'"
            severity failure;
        --! Newest is i=15; record 16's addr is at chars 462..469.
        assert collected(462 to 469) = "0000010f"
            report "phase2 newest addr mismatch: '" & collected(462 to 469) & "'"
            severity failure;

        report "ahb_recorder_test PASS";
        std.env.finish;
    end process;
end architecture;
