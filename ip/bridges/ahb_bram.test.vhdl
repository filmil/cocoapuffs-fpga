-- SPDX-License-Identifier: Apache-2.0
--! @file
--! @brief VUnit testbench for bridges.ahb_bram (direct AHB-slave Block RAM).
--!
--! Runs under the project's VUnit stub on xsim (check_equal supports
--! integer/unsigned and asserts with severity failure on mismatch).
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
library std;
library vunit_lib;
    use vunit_lib.run_types_pkg.all;
    use vunit_lib.run_pkg.all;
    use vunit_lib.runner_pkg.all;
    use vunit_lib.check_pkg.all;
library grlib;
    use grlib.amba.all;
library bridges;

entity tb_ahb_bram is
    generic(runner_cfg: string := runner_cfg_default);
end entity;

architecture sim of tb_ahb_bram is
    signal clk   : std_ulogic := '0';
    signal rstn  : std_ulogic := '0';
    signal ahbsi : ahb_slv_in_type;
    signal ahbso : ahb_slv_out_type;

    constant HADDR_C : integer := 16#C00#;
    constant BASE    : unsigned(31 downto 0) := x"C000_0000";

    -- check_equal(unsigned) wrapper for std_logic_vector operands.
    procedure check_word(got, expected : std_logic_vector(31 downto 0); msg : string) is
    begin
        check_equal(unsigned(got), unsigned(expected), msg);
    end procedure;
begin

    clk <= not clk after 5 ns;

    dut: entity bridges.ahb_bram
        generic map(
            hindex        => 0,
            haddr         => HADDR_C,
            hmask         => 16#FFF#,
            memfile       => "",
            memsize       => 4096,
            reg_bit_count => 12
        )
        port map(
            clk   => clk,
            rstn  => rstn,
            ahbsi => ahbsi,
            ahbso => ahbso
        );

    -- Guard against a hang.
    watchdog: process
    begin
        wait for 50 us;
        assert false report "tb_ahb_bram: timeout" severity failure;
        wait;
    end process;

    main: process
        procedure ahb_init is
        begin
            ahbsi.hsel      <= (others => '0');
            ahbsi.haddr     <= (others => '0');
            ahbsi.hwrite    <= '0';
            ahbsi.htrans    <= HTRANS_IDLE;
            ahbsi.hsize     <= "010";
            ahbsi.hburst    <= (others => '0');
            ahbsi.hwdata    <= (others => '0');
            ahbsi.hprot     <= (others => '0');
            ahbsi.hready    <= '1';
            ahbsi.hmaster   <= (others => '0');
            ahbsi.hmastlock <= '0';
            ahbsi.hmbsel    <= (others => '0');
            ahbsi.hirq      <= (others => '0');
            ahbsi.testen    <= '0';
            ahbsi.testrst   <= '1';
            ahbsi.scanen    <= '0';
            ahbsi.testoen   <= '1';
            ahbsi.testin    <= (others => '0');
            ahbsi.endian    <= '0';
        end procedure;

        procedure bus_write(ofs : integer; data : std_logic_vector(31 downto 0);
                            hsize : std_logic_vector(2 downto 0) := "010") is
        begin
            ahbsi.hsel(0) <= '1';
            ahbsi.haddr   <= std_logic_vector(BASE + ofs);
            ahbsi.hwrite  <= '1';
            ahbsi.hsize   <= hsize;
            ahbsi.htrans  <= HTRANS_NONSEQ;
            wait until rising_edge(clk);
            ahbsi.htrans  <= HTRANS_IDLE;
            ahbsi.hsel(0) <= '0';
            ahbsi.hwrite  <= '0';
            ahbsi.hwdata(31 downto 0) <= data;   -- data phase
            wait until rising_edge(clk);
            ahbsi.hwdata  <= (others => '0');
        end procedure;

        procedure bus_read(ofs : integer; result : out std_logic_vector(31 downto 0)) is
        begin
            ahbsi.hsel(0) <= '1';
            ahbsi.haddr   <= std_logic_vector(BASE + ofs);
            ahbsi.hwrite  <= '0';
            ahbsi.hsize   <= "010";
            ahbsi.htrans  <= HTRANS_NONSEQ;
            wait until rising_edge(clk);          -- address latched
            ahbsi.htrans  <= HTRANS_IDLE;
            ahbsi.hsel(0) <= '0';
            wait until rising_edge(clk);          -- data phase: hrdata = mem[ofs]
            result := ahbso.hrdata(31 downto 0);
        end procedure;

        variable rd  : std_logic_vector(31 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);
        ahb_init;
        rstn <= '0';
        wait for 33 ns;
        rstn <= '1';
        wait until rising_edge(clk);

        while test_suite loop
            if run("write_then_read") then
                bus_write(0, x"1234_5678");
                bus_read(0, rd);
                check_word(rd, x"1234_5678", "word readback");

            end if;
            if run("multiple_addresses") then
                bus_write(0,  x"aaaa_aaaa");
                bus_write(4,  x"bbbb_bbbb");
                bus_write(8,  x"cccc_cccc");
                bus_read(0, rd); check_word(rd, x"aaaa_aaaa", "word0");
                bus_read(4, rd); check_word(rd, x"bbbb_bbbb", "word1");
                bus_read(8, rd); check_word(rd, x"cccc_cccc", "word2");

            end if;
            if run("byte_write") then
                bus_write(0, x"0000_0000");
                bus_write(0, x"0000_00aa", "000");  -- byte 0
                bus_read(0, rd); check_word(rd, x"0000_00aa", "byte0");
                bus_write(1, x"0000_bb00", "000");  -- byte 1
                bus_read(0, rd); check_word(rd, x"0000_bbaa", "byte1");
                bus_write(3, x"dd00_0000", "000");  -- byte 3
                bus_read(0, rd); check_word(rd, x"dd00_bbaa", "byte3");
                bus_write(2, x"eeff_0000", "001");  -- halfword @ offset 2
                bus_read(0, rd); check_word(rd, x"eeff_bbaa", "half@2");

            end if;
            if run("pipelined_burst_read") then
                bus_write(16#10#, x"1111_0000");
                bus_write(16#14#, x"2222_0000");
                bus_write(16#18#, x"3333_0000");
                bus_write(16#1C#, x"4444_0000");

                -- Zero-wait-state pipelined burst: address advances every clock;
                -- read data for the previous beat is valid in the same cycle.
                ahbsi.hsel(0) <= '1';
                ahbsi.hwrite  <= '0';
                ahbsi.hsize   <= "010";
                ahbsi.haddr   <= std_logic_vector(BASE + 16#10#);
                ahbsi.htrans  <= HTRANS_NONSEQ;
                wait until rising_edge(clk);           -- A0 latched

                ahbsi.haddr   <= std_logic_vector(BASE + 16#14#);
                ahbsi.htrans  <= HTRANS_SEQ;
                wait for 1 ns; check_word(ahbso.hrdata(31 downto 0), x"1111_0000", "beat0");
                wait until rising_edge(clk);           -- A1 latched

                ahbsi.haddr   <= std_logic_vector(BASE + 16#18#);
                ahbsi.htrans  <= HTRANS_SEQ;
                wait for 1 ns; check_word(ahbso.hrdata(31 downto 0), x"2222_0000", "beat1");
                wait until rising_edge(clk);           -- A2 latched

                ahbsi.haddr   <= std_logic_vector(BASE + 16#1C#);
                ahbsi.htrans  <= HTRANS_SEQ;
                wait for 1 ns; check_word(ahbso.hrdata(31 downto 0), x"3333_0000", "beat2");
                wait until rising_edge(clk);           -- A3 latched

                ahbsi.htrans  <= HTRANS_IDLE;
                ahbsi.hsel(0) <= '0';
                wait for 1 ns; check_word(ahbso.hrdata(31 downto 0), x"4444_0000", "beat3");
                wait until rising_edge(clk);

            end if;
            if run("hready_always_high") then
                -- A zero-wait-state slave must keep hready asserted.
                assert ahbso.hready = '1' report "hready not high while idle" severity failure;
                ahbsi.hsel(0) <= '1';
                ahbsi.haddr   <= std_logic_vector(BASE + 0);
                ahbsi.hwrite  <= '0';
                ahbsi.htrans  <= HTRANS_NONSEQ;
                wait until rising_edge(clk);
                assert ahbso.hready = '1' report "hready not high while active" severity failure;
                ahbsi.htrans  <= HTRANS_IDLE;
                ahbsi.hsel(0) <= '0';
            end if;
        end loop;

        test_runner_cleanup(runner);
        std.env.finish;
        wait;
    end process;

end architecture;
