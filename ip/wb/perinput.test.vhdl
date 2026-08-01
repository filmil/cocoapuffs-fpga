-- SPDX-License-Identifier: Apache-2.0
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;
library testing;
    use testing.wblite_pkg;
library wb;

--! @brief Testbench for the perinput peripheral using VUnit.
entity perinput_test is
    generic(runner_cfg: string  := runner_cfg_default);
end entity;

architecture sim of perinput_test is
    --! Base address for the perinput peripheral under test.
    constant base_address: std_ulogic_vector(31 downto 0) := x"4000_0000";
    --! Wishbone Lite bus master verification component handle.
    constant wblite_bus: bus_master_t := new_bus(
        data_length => 32, address_length => 32);

    signal clk: std_ulogic := '0';
    signal rst: std_ulogic := '1';

    signal host_port: wb.host.bus_type;
    signal per_port: wb.per.bus_type;

    constant NUM_BITS: positive := 70;
    signal perin: std_ulogic_vector(NUM_BITS-1 downto 0);

    --! Expected values for the registers.
    constant REG0_EXPECTED: std_ulogic_vector(31 downto 0) := x"12345678";
    constant REG1_EXPECTED: std_ulogic_vector(31 downto 0) := x"9ABCDEF0";
    constant REG2_EXPECTED: std_ulogic_vector(31 downto 0) := x"000000" & "00" & "101111"; -- bits 69 down to 64

    constant test_host_log: logger_t := get_logger("perinput_test.test_host");

begin
    --! Clock generation.
    clk <= not clk after 5 ns;
    --! Reset generation.
    rst <= '0' after 100 ns;

    --! @brief VUnit Wishbone Lite master component.
    test_host: entity testing.wblite
        generic map(
            bus_handle => wblite_bus,
            logger => test_host_log
        )
        port map(
            clk => clk,
            rst => rst,
            host_port => host_port,
            per_port => per_port
        );

    --! @brief DUT: perinput peripheral.
    dut: entity wb.perinput
        generic map (
            base_address => base_address,
            num_bits => NUM_BITS
        )
        port map(
            clk => clk,
            reset => rst,
            wbi => host_port,
            wbo => per_port,
            perin => perin
        );

    --! Set up the input bits with known patterns.
    perin(31 downto 0) <= REG0_EXPECTED;
    perin(63 downto 32) <= REG1_EXPECTED;
    perin(69 downto 64) <= REG2_EXPECTED(5 downto 0);

    --! @brief Main test runner process.
    t0: process
        variable rd: std_ulogic_vector(31 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        if run("read_registers") then
            -- Read Register 0
            wblite_pkg.bus_read(net, wblite_bus, base_address, rd);
            check_equal(rd, REG0_EXPECTED, "Register 0 read mismatch");

            -- Read Register 1
            wblite_pkg.bus_read(net, wblite_bus, std_ulogic_vector(unsigned(base_address) + 4), rd);
            check_equal(rd, REG1_EXPECTED, "Register 1 read mismatch");

            -- Read Register 2
            wblite_pkg.bus_read(net, wblite_bus, std_ulogic_vector(unsigned(base_address) + 8), rd);
            check_equal(rd, REG2_EXPECTED, "Register 2 read mismatch");
        end if;

        if run("read_out_of_bounds") then
            -- Read non-existent Register (should return 0)
            wblite_pkg.bus_read(net, wblite_bus, std_ulogic_vector(unsigned(base_address) + 12), rd);
            check_equal(rd, std_logic_vector'(x"00000000"), "Out-of-bounds register read should return 0");
        end if;

        test_runner_cleanup(runner);
    end process;
end architecture;
