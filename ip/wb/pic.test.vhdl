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

entity tb_pic is
    generic(runner_cfg: string := runner_cfg_default);
end entity;

architecture sim of tb_pic is
    constant wblite_bus: bus_master_t := new_bus(
        data_length => 32, address_length => 32);

    signal clk: std_ulogic := '0';
    signal rst: std_ulogic := '1';

    signal host: wb.host.bus_type;
    signal per: wb.per.bus_type;

    constant NUM_IRQS: natural := 8;
    signal irqi: std_ulogic_vector(NUM_IRQS-1 downto 0) := (others => '0');
    signal irqo: std_ulogic;

    constant base_addr: std_ulogic_vector(31 downto 0) := x"0000_2000";

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

    dut: entity wb.pic
        generic map(
            base_address => base_addr
        )
        port map(
            clk => clk,
            reset => rst,
            wbi => host,
            wbo => per,
            irqo => irqo,
            irqi => irqi
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
            check_equal(irqo, '0');
            -- Check mask is 0
            wblite_pkg.bus_read(net, wblite_bus, base_addr, rd);
            info("Mask register read: " & to_hstring(rd));
            check_equal(rd, std_logic_vector'(x"0000_0000"));
            -- Check irqs is 0
            wblite_pkg.bus_read(net, wblite_bus, base_addr or x"0000_0004", rd);
            info("IRQS register read: " & to_hstring(rd));
            check_equal(rd, std_logic_vector'(x"0000_0000"));
        end if;

        if run("test_interrupt_trigger") then
            info("Running test_interrupt_trigger");
            if rst /= '0' then wait until rst = '0'; end if;
            -- Enable IRQ 0
            info("Enabling IRQ 0");
            wblite_pkg.bus_write(net, wblite_bus, base_addr, x"0000_0001");
            wait until rising_edge(clk);

            -- Trigger IRQ 0 with a single cycle pulse
            info("Triggering IRQ 0");
            irqi(0) <= '1';
            wait until rising_edge(clk);
            irqi(0) <= '0';
            wait until rising_edge(clk);

            -- Check IRQO is high
            info("Checking IRQO is high");
            check_equal(irqo, '1');

            -- Check IRQS register
            wblite_pkg.bus_read(net, wblite_bus, base_addr or x"0000_0004", rd);
            info("IRQS register read: " & to_hstring(rd));
            check_equal(rd(0), '1');
        end if;

        if run("test_lower_irq_when_zero") then
            info("Running test_lower_irq_when_zero");
            if rst /= '0' then wait until rst = '0'; end if;
            -- Enable IRQ 0 and 1
            info("Enabling IRQ 0 and 1");
            wblite_pkg.bus_write(net, wblite_bus, base_addr, x"0000_0003");
            wait until rising_edge(clk);

            -- Trigger IRQ 0 and 1 with pulses
            info("Triggering IRQ 0 and 1");
            irqi(0) <= '1';
            irqi(1) <= '1';
            wait until rising_edge(clk);
            irqi(0) <= '0';
            irqi(1) <= '0';
            wait until rising_edge(clk);
            check_equal(irqo, '1');

            -- Clear IRQ 0 (by writing to IRQS register, keeping IRQ 1)
            info("Clearing IRQ 0");
            wblite_pkg.bus_write(net, wblite_bus, base_addr or x"0000_0004", x"0000_0002");
            wait until rising_edge(clk);
            info("Checking IRQO is still high");
            check_equal(irqo, '1'); -- Still high because IRQ 1 is set

            -- Clear IRQ 1
            info("Clearing IRQ 1");
            wblite_pkg.bus_write(net, wblite_bus, base_addr or x"0000_0004", x"0000_0000");
            wait until rising_edge(clk);
            info("Checking IRQO is low");
            check_equal(irqo, '0'); -- Should be low now
        end if;

        if run("test_masking") then
            info("Running test_masking");
            if rst /= '0' then wait until rst = '0'; end if;
            -- Mask all
            info("Masking all IRQs");
            wblite_pkg.bus_write(net, wblite_bus, base_addr, x"0000_0000");
            wait until rising_edge(clk);

            -- Trigger IRQ 0
            info("Triggering IRQ 0 (masked)");
            irqi(0) <= '1';
            wait until rising_edge(clk);
            irqi(0) <= '0';
            wait until rising_edge(clk);

            -- Check IRQO is still low
            info("Checking IRQO is low");
            check_equal(irqo, '0');

            -- Check IRQS register is 0
            wblite_pkg.bus_read(net, wblite_bus, base_addr or x"0000_0004", rd);
            info("IRQS register read: " & to_hstring(rd));
            check_equal(rd, std_logic_vector'(x"0000_0000"));
        end if;

        if run("test_reassert_if_active") then
            info("Running test_reassert_if_active");
            if rst /= '0' then wait until rst = '0'; end if;
            -- Enable IRQ 0
            wblite_pkg.bus_write(net, wblite_bus, base_addr, x"0000_0001");
            wait until rising_edge(clk);

            -- Trigger IRQ 0 and KEEP IT HIGH
            info("Triggering IRQ 0 and keeping it high");
            irqi(0) <= '1';
            wait until rising_edge(clk);
            wait until rising_edge(clk);
            check_equal(irqo, '1');

            -- Attempt to clear IRQ 0 while input is still high
            info("Clearing IRQ 0 while input is still high");
            wblite_pkg.bus_write(net, wblite_bus, base_addr or x"0000_0004", x"0000_0000");

            -- It should drop for at least one cycle then re-assert.
            -- In our implementation, it drops for 1 cycle because the write
            -- happens after the irqi check in the comb process, and the 
            -- register is updated on the next rising edge.
            wait until rising_edge(clk);
            info("Checking for re-assertion");
            wait until rising_edge(clk);
            check_equal(irqo, '1');

            -- Finally clear it for real
            irqi(0) <= '0';
            wblite_pkg.bus_write(net, wblite_bus, base_addr or x"0000_0004", x"0000_0000");
            wait until rising_edge(clk);
            check_equal(irqo, '0');
        end if;

        test_runner_cleanup(runner);
    end process;
end architecture;
