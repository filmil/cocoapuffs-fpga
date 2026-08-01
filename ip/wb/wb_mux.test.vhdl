library ieee;
    use ieee.std_logic_1164.all;
library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;
library testing;
    use testing.wblite_pkg;
library wb;

entity tb is
    generic(runner_cfg: string  := runner_cfg_default);
end entity;

architecture sim of tb is
    constant wblite_bus: bus_master_t := new_bus(
        data_length => 32, address_length => 32);

    signal clk: std_ulogic := '0';
    signal rst: std_ulogic := '1';

    signal host0: wb.host.bus_type;
    signal per0: wb.per.bus_type;

    signal host1: wb.host.bus_type := wb.host.new_bus_type;
    signal per1: wb.per.bus_type := wb.per.new_bus_type;

    signal host: wb.host.bus_type;
    signal per: wb.per.bus_type;

    signal host_ports: wb.host.bus_array_t(0 to 1);
    signal per_ports: wb.per.bus_array_t(0 to 1);

    constant test_host_log: logger_t := get_logger("tb.test_host");
    constant test_per_log: logger_t := get_logger("tb.test_per");

begin
    clk <= not clk after 5 ns;
    rst <= '0' after 100 ns;

    test_host: entity testing.wblite
        generic map(
            bus_handle => wblite_bus,
            logger => test_host_log
        )
        port map(
            clk => clk,
            rst => rst,
            host_port => host0,
            per_port => per0
        );

    test_per: entity testing.wblite_mem
        generic map(
            base_address => x"f000_0000",
            logger => test_per_log,
            mem_size_log2 => 4 -- == 16 bytes
        )
        port map(
            clk => clk,
            reset => rst,
            host => host,
            per => per
        );

    host_ports <= wb.host.bus_array_t'(
        0 => host0,
        1 => host1
    );
    per0 <= per_ports(0);
    per1 <= per_ports(1);
    dut: entity wb.wb_mux
        generic map(
            ports_count => 2
        )
        port map(
            clk => clk,
            rst => rst,
            host_ports => host_ports,
            per_ports => per_ports,
            host_port => host,
            per_port => per
        );

    t0: process
        variable rd: std_ulogic_vector(31 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

            if run("blind_write") then
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"f005_ba11");
            end if;

            if run("blind_read") then
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
            end if;

            if run("write_then_read") then
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"f005_ba11");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
                check_equal(rd, std_logic_vector'(x"f005_ba11"));
            end if;

            if run("composite_write_then_read") then
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"f005_ba11");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
                check_equal(rd, std_logic_vector'(x"f005_ba11"));

                wblite_pkg.bus_write(net, wblite_bus, x"f000_0004", x"dead_beef");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0004", rd);
            end if;

            if run("write_with_sel") then
                -- Sel 3
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"0000_0000");
                wblite_pkg.bus_write(net, wblite_bus,
                    x"f000_0000", x"ffff_ffff", sel => "1000");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
                check_equal(rd, std_logic_vector'(x"ff00_0000"));

                -- Sel 2
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"0000_0000");
                wblite_pkg.bus_write(net, wblite_bus,
                    x"f000_0000", x"ffff_ffff", sel => "0100");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
                check_equal(rd, std_logic_vector'(x"00ff_0000"));

                -- Sel 1
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"0000_0000");
                wblite_pkg.bus_write(net, wblite_bus,
                    x"f000_0000", x"ffff_ffff", sel => "0010");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
                check_equal(rd, std_logic_vector'(x"0000_ff00"));

                -- Sel 0
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"0000_0000");
                wblite_pkg.bus_write(net, wblite_bus,
                    x"f000_0000", x"ffff_ffff", sel => "0001");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
                check_equal(rd, std_logic_vector'(x"0000_00ff"));
            end if;

            if run("read_with_sel") then
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"ffff_ffff");
                wblite_pkg.bus_read(net, wblite_bus,
                    x"f000_0000", rd, sel => "1000");
                check_equal(rd, std_logic_vector'(x"ff00_0000"));
                wblite_pkg.bus_read(net, wblite_bus,
                    x"f000_0000", rd, sel => "0100");
                check_equal(rd, std_logic_vector'(x"00ff_0000"));
                wblite_pkg.bus_read(net, wblite_bus,
                    x"f000_0000", rd, sel => "0010");
                check_equal(rd, std_logic_vector'(x"0000_ff00"));
                wblite_pkg.bus_read(net, wblite_bus,
                    x"f000_0000", rd, sel => "0001");
                check_equal(rd, std_logic_vector'(x"0000_00ff"));
            end if;

        test_runner_cleanup(runner);
    end process;
end architecture;

-- Same as above, but flips host side ports.
architecture sim2 of tb is
    constant wblite_bus: bus_master_t := new_bus(
        data_length => 32, address_length => 32);

    signal clk: std_ulogic := '0';
    signal rst: std_ulogic := '1';

    signal host0: wb.host.bus_type;
    signal per0: wb.per.bus_type;

    signal host1: wb.host.bus_type := wb.host.new_bus_type;
    signal per1: wb.per.bus_type := wb.per.new_bus_type;

    signal host: wb.host.bus_type;
    signal per: wb.per.bus_type;

    signal host_ports: wb.host.bus_array_t(0 to 1);
    signal per_ports: wb.per.bus_array_t(0 to 1);

    constant test_host_log: logger_t := get_logger("tb.test_host");
    constant test_per_log: logger_t := get_logger("tb.test_per");

begin
    clk <= not clk after 5 ns;
    rst <= '0' after 100 ns;

    test_host: entity testing.wblite
        generic map(
            bus_handle => wblite_bus,
            logger => test_host_log
        )
        port map(
            clk => clk,
            rst => rst,
            host_port => host0,
            per_port => per0
        );

    test_per: entity testing.wblite_mem
        generic map(
            base_address => x"f000_0000",
            logger => test_per_log,
            mem_size_log2 => 4 -- == 16 bytes
        )
        port map(
            clk => clk,
            reset => rst,
            host => host,
            per => per
        );

    host_ports <= wb.host.bus_array_t'(
        0 => host1,
        1 => host0
    );
    per0 <= per_ports(1);
    per1 <= per_ports(0);
    dut: entity wb.wb_mux
        generic map(
            ports_count => 2
        )
        port map(
            clk => clk,
            rst => rst,
            host_ports => host_ports,
            per_ports => per_ports,
            host_port => host,
            per_port => per
        );

    t0: process
        variable rd: std_ulogic_vector(31 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

            if run("blind_write") then
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"f005_ba11");
            end if;

            if run("blind_read") then
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
            end if;

            if run("write_then_read") then
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"f005_ba11");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
                check_equal(rd, std_logic_vector'(x"f005_ba11"));
            end if;

            if run("composite_write_then_read") then
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"f005_ba11");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
                check_equal(rd, std_logic_vector'(x"f005_ba11"));

                wblite_pkg.bus_write(net, wblite_bus, x"f000_0004", x"dead_beef");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0004", rd);
            end if;

            if run("write_with_sel") then
                -- Sel 3
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"0000_0000");
                wblite_pkg.bus_write(net, wblite_bus,
                    x"f000_0000", x"ffff_ffff", sel => "1000");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
                check_equal(rd, std_logic_vector'(x"ff00_0000"));

                -- Sel 2
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"0000_0000");
                wblite_pkg.bus_write(net, wblite_bus,
                    x"f000_0000", x"ffff_ffff", sel => "0100");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
                check_equal(rd, std_logic_vector'(x"00ff_0000"));

                -- Sel 1
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"0000_0000");
                wblite_pkg.bus_write(net, wblite_bus,
                    x"f000_0000", x"ffff_ffff", sel => "0010");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
                check_equal(rd, std_logic_vector'(x"0000_ff00"));

                -- Sel 0
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"0000_0000");
                wblite_pkg.bus_write(net, wblite_bus,
                    x"f000_0000", x"ffff_ffff", sel => "0001");
                wblite_pkg.bus_read(net, wblite_bus, x"f000_0000", rd);
                check_equal(rd, std_logic_vector'(x"0000_00ff"));
            end if;

            if run("read_with_sel") then
                wblite_pkg.bus_write(net, wblite_bus, x"f000_0000", x"ffff_ffff");
                wblite_pkg.bus_read(net, wblite_bus,
                    x"f000_0000", rd, sel => "1000");
                check_equal(rd, std_logic_vector'(x"ff00_0000"));
                wblite_pkg.bus_read(net, wblite_bus,
                    x"f000_0000", rd, sel => "0100");
                check_equal(rd, std_logic_vector'(x"00ff_0000"));
                wblite_pkg.bus_read(net, wblite_bus,
                    x"f000_0000", rd, sel => "0010");
                check_equal(rd, std_logic_vector'(x"0000_ff00"));
                wblite_pkg.bus_read(net, wblite_bus,
                    x"f000_0000", rd, sel => "0001");
                check_equal(rd, std_logic_vector'(x"0000_00ff"));
            end if;

        test_runner_cleanup(runner);
    end process;
end architecture;

configuration sim2_cfg of tb is
    for sim2
    end for;
end configuration;
