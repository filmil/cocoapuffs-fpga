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

entity tb_timer is
    generic(runner_cfg: string := runner_cfg_default);
end entity;

architecture sim of tb_timer is
    constant wblite_bus: bus_master_t := new_bus(
        data_length => 32, address_length => 32);

    signal clk: std_ulogic := '0';
    signal rst: std_ulogic := '1';

    signal host: wb.host.bus_type;
    signal per: wb.per.bus_type;
    signal irq: std_ulogic;

    constant base_addr: std_ulogic_vector(31 downto 0) := x"0000_1000";
    constant max_count: natural := 10;

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

    dut: entity wb.timer
        generic map(
            base_address => base_addr,
            max_count => max_count
        )
        port map(
            clk => clk,
            reset => rst,
            wbi => host,
            wbo => per,
            irq => irq
        );

    watchdog: process
    begin
        wait for 10 us;
        assert false report "Watchdog timeout" severity failure;
    end process;

    main: process
        variable rd: std_ulogic_vector(31 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        if run("test_reset_state") then
            info("Running test_reset_state");
            if rst /= '0' then wait until rst = '0'; end if;
            wait until rising_edge(clk);
            -- Check initial count
            wblite_pkg.bus_read(net, wblite_bus, base_addr or x"0000_0004", rd);
            info("Initial count read: " & to_hstring(rd));
            check_relation(unsigned(rd) <= to_unsigned(max_count, 32));
            check_equal(irq, '0');
        end if;

        if run("test_countdown_to_irq") then
            info("Running test_countdown_to_irq");
            if rst /= '0' then wait until rst = '0'; end if;
            wait until rising_edge(irq);
            info("Wait completed, checking IRQ");
            check_equal(irq, '1');
            info("Checking that IRQ is de-asserted");
            wait until falling_edge(irq);
            check_equal(irq, '0');
        end if;

        if run("test_set_countdown") then
            info("Running test_set_countdown");
            if rst /= '0' then wait until rst = '0'; end if;
            -- Set a new countdown value
            info("Setting countdown to 0x20");
            wblite_pkg.bus_write(net, wblite_bus, base_addr or x"0000_0004", x"0000_0020");
            wait until rising_edge(clk);
            -- Read it back (might be a few cycles later)
            wblite_pkg.bus_read(net, wblite_bus, base_addr or x"0000_0004", rd);
            info("Count read back: " & to_hstring(rd));
            check_relation(unsigned(rd) <= x"0000_0020");
            check_relation(unsigned(rd) >= x"0000_0018");

        end if;

        test_runner_cleanup(runner);
    end process;

end architecture;
