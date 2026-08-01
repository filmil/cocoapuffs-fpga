-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library testing;
use testing.tl_uh_pkg.all;

library tl;
use tl.types.all;

library wb;

entity tl_uh2wblite_tb is
    generic (
        runner_cfg: string := runner_cfg_default
    );
end entity tl_uh2wblite_tb;

architecture sim of tl_uh2wblite_tb is
    constant tllite_bus: bus_master_t := new_bus(
        data_length => 32, address_length => 32
    );

    signal clk: std_ulogic := '0';
    signal rst: std_ulogic := '1';

    signal tl_host_port: host_type;
    signal tl_per_port: per_type;

    signal wb_host_port: wb.host.bus_type;
    signal wb_per_port: wb.per.bus_type;

begin
    clk <= not clk after 5 ns;

    -- TileLink Host
    tl_host_inst: entity testing.tl_uh_master
        generic map (
            bus_handle => tllite_bus
        )
        port map (
            clk => clk,
            rst => rst,
            host_port => tl_host_port,
            per_port => tl_per_port
        );

    -- Device Under Test
    dut: entity tl.tl_uh2wblite
        port map (
            clk => clk,
            rst => rst,
            tl_i => tl_host_port,
            tl_o => tl_per_port,
            wb_o => wb_host_port,
            wb_i => wb_per_port
        );

    -- Wishbone Peripheral (Memory)
    wb_slave_inst: entity testing.wblite_mem
        generic map (
            base_address => x"00000000",
            mem_size_log2 => 4
        )
        port map (
            clk => clk,
            reset => rst,
            host => wb_host_port,
            per => wb_per_port
        );

    main: process
        variable result_val: std_ulogic_vector(31 downto 0);
        variable result_val2: std_ulogic_vector(31 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        wait for 20 ns;
        rst <= '0';
        wait for 20 ns;

        while test_suite loop
            if run("test_write_read") then
                bus_write(net, tllite_bus, x"00000004", x"DEADBEEF");
                bus_read(net, tllite_bus, x"00000004", result_val);
                check_equal(
                    result_val, std_ulogic_vector'(x"DEADBEEF"),
                    "Data written and read back should match"
                );

            elsif run("test_atomic_add") then
                bus_write(net, tllite_bus, x"00000008", x"00000010");
                bus_atomic(
                    net, tllite_bus, x"00000008", x"00000005",
                    OP_ARITHMETIC_DATA, PARAM_ARITH_ADD, result_val
                );
                check_equal(
                    result_val, std_ulogic_vector'(x"00000010"),
                    "Atomic should return original data"
                );
                
                bus_read(net, tllite_bus, x"00000008", result_val);
                check_equal(
                    result_val, std_ulogic_vector'(x"00000015"),
                    "ADD result should be correctly stored"
                );

            elsif run("test_atomic_xor") then
                bus_write(net, tllite_bus, x"0000000C", x"AAAAAAAA");
                bus_atomic(
                    net, tllite_bus, x"0000000C", x"0000FFFF",
                    OP_LOGICAL_DATA, PARAM_LOGIC_XOR, result_val
                );
                check_equal(
                    result_val, std_ulogic_vector'(x"AAAAAAAA"),
                    "Atomic should return original data"
                );
                
                bus_read(net, tllite_bus, x"0000000C", result_val);
                check_equal(
                    result_val, std_ulogic_vector'(x"AAAA5555"),
                    "XOR result should be correctly stored"
                );

            elsif run("test_atomic_max") then
                bus_write(net, tllite_bus, x"00000010", x"FFFFFFFF"); -- -1
                bus_atomic(
                    net, tllite_bus, x"00000010", x"0000000A",
                    OP_ARITHMETIC_DATA, PARAM_ARITH_MAX, result_val
                );
                check_equal(
                    result_val, std_ulogic_vector'(x"FFFFFFFF"),
                    "Atomic should return original data"
                );
                
                bus_read(net, tllite_bus, x"00000010", result_val);
                check_equal(
                    result_val, std_ulogic_vector'(x"0000000A"),
                    "MAX should prefer positive 10 over -1"
                );
            elsif run("test_burst_write_read") then
                bus_write_burst_8B(
                    net, tllite_bus, x"00000020", x"11111111", x"22222222"
                );
                bus_read_burst_8B(
                    net, tllite_bus, x"00000020", result_val, result_val2
                );
                check_equal(
                    result_val, std_ulogic_vector'(x"11111111"),
                    "First beat read back should match"
                );
                check_equal(
                    result_val2, std_ulogic_vector'(x"22222222"),
                    "Second beat read back should match"
                );
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;
end architecture;
