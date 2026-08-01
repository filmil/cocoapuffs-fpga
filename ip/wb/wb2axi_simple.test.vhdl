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
library axi;

entity wb2axi_simple_test is
    generic (runner_cfg : string := runner_cfg_default);
end entity;

architecture sim of wb2axi_simple_test is
    constant wblite_bus: bus_master_t := new_bus(
        data_length => 32, address_length => 32);

    signal clk: std_ulogic := '0';
    signal rst: std_ulogic := '1';

    signal wb_host: wb.host.bus_type;
    signal wb_per: wb.per.bus_type;

    signal axi_host: axi.host.bus_type;
    signal axi_per: axi.per.bus_type := axi.per.new_bus_type(axi.types.WIDTHS);

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
            host_port => wb_host,
            per_port => wb_per
        );

    dut: entity wb.wb2axi_simple
        port map(
            clk => clk,
            reset => rst,
            wb_host => wb_host,
            wb_per => wb_per,
            axi_host => axi_host,
            axi_per => axi_per
        );

    -- Simple AXI Slave Model
    axi_slave: process
    begin
        axi_per <= axi.per.new_bus_type(axi.types.WIDTHS);
        wait until rst = '0';
        
        loop
            wait until rising_edge(clk);
            
            -- Handle AW and W
            if axi_host.aw.valid = '1' then
                axi_per.aw.ready <= '1';
            end if;
            if axi_host.w.valid = '1' then
                axi_per.w.ready <= '1';
            end if;
            
            if axi_per.aw.ready = '1' and axi_host.aw.valid = '1' then
                -- AW handshake done
            end if;
            if axi_per.w.ready = '1' and axi_host.w.valid = '1' then
                -- W handshake done
            end if;
            
            -- Send B response after AW and W are done
            -- (In this simple model, we just do it)
            if axi_host.aw.valid = '1' and axi_host.w.valid = '1' then
                wait until rising_edge(clk);
                axi_per.aw.ready <= '0';
                axi_per.w.ready <= '0';
                axi_per.b.valid <= '1';
                axi_per.b.id <= axi_host.aw.id;
                wait until axi_host.b.ready = '1' and rising_edge(clk);
                axi_per.b.valid <= '0';
            end if;

            -- Handle AR and R
            if axi_host.ar.valid = '1' then
                axi_per.ar.ready <= '1';
                wait until rising_edge(clk);
                axi_per.ar.ready <= '0';
                
                axi_per.r.valid <= '1';
                axi_per.r.data <= x"BADC0FFE";
                axi_per.r.last <= '1';
                axi_per.r.id <= axi_host.ar.id;
                wait until axi_host.r.ready = '1' and rising_edge(clk);
                axi_per.r.valid <= '0';
            end if;
        end loop;
    end process;

    main: process
        variable rd: std_ulogic_vector(31 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while is_active(runner) loop
            if run("test_write") then
                info("Testing Wishbone to AXI write");
                if rst /= '0' then wait until rst = '0'; end if;
                
                wblite_pkg.bus_write(net, wblite_bus, x"1000_0000", x"1234_5678");
                -- If we got here, ack was received, so write completed.
                info("Write completed successfully");

            elsif run("test_read") then
                info("Testing Wishbone to AXI read");
                if rst /= '0' then wait until rst = '0'; end if;
                
                wblite_pkg.bus_read(net, wblite_bus, x"2000_0000", rd);
                check_equal(rd, std_logic_vector'(x"BADC0FFE"), "Read data mismatch");
                info("Read completed successfully");
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;

    watchdog: process
    begin
        wait for 20 us;
        assert false report "Watchdog timeout" severity failure;
    end process;

end architecture;
