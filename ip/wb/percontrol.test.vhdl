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

entity percontrol_test is
    generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture sim of percontrol_test is
    constant wblite_bus: bus_master_t := new_bus(
        data_length => 32, address_length => 32);

    signal clk: std_ulogic := '0';
    signal rst: std_ulogic := '1';

    signal host: wb.host.bus_type;
    signal per: wb.per.bus_type;
    signal perctl: std_ulogic_vector(31 downto 0);

    constant base_addr: std_ulogic_vector(31 downto 0) := x"4000_1000";
    constant initial_val: std_ulogic_vector(31 downto 0) := x"DEADBEEF";

begin
    clk <= not clk after 5 ns;
    rst <= '0' after 100 ns;

    test_host: entity testing.wblite
        generic map(
            bus_handle => wblite_bus
        )
        port map(
            clk => clk,
            rst => rst,
            host_port => host,
            per_port => per
        );

    dut: entity wb.percontrol
        generic map (
            base_address => base_addr,
            initial_value => initial_val
        )
        port map(
            clk => clk,
            reset => rst,
            wbi => host,
            wbo => per,
            perctl => perctl
        );

    main: process
        variable rd: std_ulogic_vector(31 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while is_active(runner) loop
            if run("test_reset_initial_value") then
                info("Checking initial value after reset");
                if rst /= '0' then wait until rst = '0'; end if;
                wait until rising_edge(clk);
                check_equal(perctl, initial_val, "Initial value mismatch");

            elsif run("test_write_read") then
                info("Testing write then read");
                if rst /= '0' then wait until rst = '0'; end if;
                
                wblite_pkg.bus_write(net, wblite_bus, base_addr, x"12345678");
                wait until rising_edge(clk);
                check_equal(perctl, std_logic_vector'(x"12345678"), "perctl output mismatch after write");
                
                wblite_pkg.bus_read(net, wblite_bus, base_addr, rd);
                check_equal(rd, std_logic_vector'(x"12345678"), "Read back value mismatch");
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;

    watchdog: process
    begin
        wait for 10 us;
        assert false report "Watchdog timeout" severity failure;
    end process;

end architecture;
