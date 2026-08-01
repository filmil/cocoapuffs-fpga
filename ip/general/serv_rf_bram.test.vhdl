-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;

library general;
use general.types.all;

entity serv_rf_bram_tb is
    generic (
        runner_cfg: string := runner_cfg_default
    );
end entity;

architecture sim of serv_rf_bram_tb is
    signal clk : std_ulogic := '0';
    signal rst : std_ulogic := '1';

    signal rf_in  : serv_rf_in_t := (
        wreq   => '0',
        rreq   => '0',
        w0     => (reg => (others => '0'), en => '0', data => (others => '0')),
        w1     => (reg => (others => '0'), en => '0', data => (others => '0')),
        r0     => (reg => (others => '0')),
        r1     => (reg => (others => '0'))
    );
    signal rf_out : serv_rf_out_t;

    procedure wait_cycles(n : natural) is
    begin
        for i in 1 to n loop
            wait until rising_edge(clk);
        end loop;
    end procedure;

begin
    clk <= not clk after 5 ns;

    dut: entity general.serv_rf_bram
        generic map (
            WITH_CSR => 1
        )
        port map (
            clk   => clk,
            i_rst => rst,
            i_rf  => rf_in,
            o_rf  => rf_out
        );

    main: process
        variable data_to_write : std_ulogic_vector(31 downto 0);
        constant zero32 : std_ulogic_vector(31 downto 0) := (others => '0');
        constant AAAA  : std_ulogic_vector(31 downto 0) := x"AAAAAAAA";
        constant FIVE5 : std_ulogic_vector(31 downto 0) := x"55555555";
    begin
        test_runner_setup(runner, runner_cfg);

        while test_suite loop
            if run("test_reset_and_ready") then
                rst <= '1';
                wait_cycles(2);
                rst <= '0';
                wait until rising_edge(clk);
                check_equal(rf_out.ready, '1', "Ready should be high after reset");

            elsif run("test_x0_read_only_zero") then
                rst <= '1'; wait_cycles(2); rst <= '0';
                wait until rising_edge(clk);

                -- 1. Attempt to write 0xFFFFFFFF to x0
                rf_in.w0.reg  <= "000000"; -- x0
                rf_in.w0.data <= x"FFFFFFFF";
                rf_in.w0.en   <= '1';
                wait until rising_edge(clk);
                rf_in.w0.en   <= '0';

                -- 2. Read from x0 and verify it is zero
                rf_in.r0.reg <= "000000"; -- x0
                wait for 1 ns; -- Let combinational signals settle
                check_equal(rf_out.r0.data, zero32, "x0 should always read as zero");

            elsif run("test_x1_write_read") then
                rst <= '1'; wait_cycles(2); rst <= '0';
                wait until rising_edge(clk);

                -- 1. Write 0x12345678 to x1
                data_to_write := x"12345678";
                rf_in.w0.reg  <= "000001"; -- x1
                rf_in.w0.data <= data_to_write;
                rf_in.w0.en   <= '1';
                wait until rising_edge(clk);
                rf_in.w0.en   <= '0';

                -- 2. Read from x1 and verify
                rf_in.r0.reg <= "000001"; -- x1
                wait for 1 ns;
                check_equal(rf_out.r0.data, data_to_write, "x1 read data mismatch");

            elsif run("test_dual_port_write_read") then
                rst <= '1'; wait_cycles(2); rst <= '0';
                wait until rising_edge(clk);

                -- 1. Write to two registers simultaneously
                rf_in.w0.reg  <= "000010"; -- x2
                rf_in.w0.data <= AAAA;
                rf_in.w0.en   <= '1';
                rf_in.w1.reg  <= "000011"; -- x3
                rf_in.w1.data <= FIVE5;
                rf_in.w1.en   <= '1';
                wait until rising_edge(clk);
                rf_in.w0.en   <= '0';
                rf_in.w1.en   <= '0';

                -- 2. Read from both registers simultaneously
                rf_in.r0.reg <= "000010"; -- x2
                rf_in.r1.reg <= "000011"; -- x3
                wait for 1 ns;
                check_equal(rf_out.r0.data, AAAA, "x2 read data mismatch");
                check_equal(rf_out.r1.data, FIVE5, "x3 read data mismatch");
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 1 ms);

end architecture;
