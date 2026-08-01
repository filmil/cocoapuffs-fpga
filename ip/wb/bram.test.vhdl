library ieee;
    use ieee.std_logic_1164.all;
library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;
library testing;
    use testing.wblite_pkg;
library wb;

entity tb_bram is
    generic(runner_cfg: string := runner_cfg_default);
end entity;

architecture sim of tb_bram is
    constant wblite_bus: bus_master_t := new_bus(
        data_length => 32, address_length => 32);

    signal clk: std_ulogic := '0';
    signal rst: std_ulogic := '1';

    signal host: wb.host.bus_type;
    signal per: wb.per.bus_type;

    constant base_addr: std_ulogic_vector(31 downto 0) := x"0000_0000";
    constant mem_size: natural := 1024; -- 1KB

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

    dut: entity wb.bram
        generic map(
            base_address => base_addr,
            memsize => mem_size,
            reg_bit_count => 10 -- 2^10 = 1024
        )
        port map(
            clk => clk,
            reset => rst,
            wbi => host,
            wbo => per
        );

    main: process
        variable rd: std_ulogic_vector(31 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        while is_active(runner) loop
            if run("write_then_read") then
                wblite_pkg.bus_write(net, wblite_bus, base_addr, x"1234_5678");
                wblite_pkg.bus_read(net, wblite_bus, base_addr, rd);
                check_equal(rd, std_logic_vector'(x"1234_5678"));
            elsif run("byte_write") then
                -- Write word
                wblite_pkg.bus_write(net, wblite_bus, base_addr, x"0000_0000");
                -- Write byte 0
                wblite_pkg.bus_write(net, wblite_bus, base_addr, x"0000_00aa", sel => "0001");
                wblite_pkg.bus_read(net, wblite_bus, base_addr, rd);
                check_equal(rd, std_logic_vector'(x"0000_00aa"));
                -- Write byte 1
                wblite_pkg.bus_write(net, wblite_bus, base_addr, x"0000_bb00", sel => "0010");
                wblite_pkg.bus_read(net, wblite_bus, base_addr, rd);
                check_equal(rd, std_logic_vector'(x"0000_bbaa"));
                -- Write byte 2
                wblite_pkg.bus_write(net, wblite_bus, base_addr, x"00cc_0000", sel => "0100");
                wblite_pkg.bus_read(net, wblite_bus, base_addr, rd);
                check_equal(rd, std_logic_vector'(x"00cc_bbaa"));
                -- Write byte 3
                wblite_pkg.bus_write(net, wblite_bus, base_addr, x"dd00_0000", sel => "1000");
                wblite_pkg.bus_read(net, wblite_bus, base_addr, rd);
                check_equal(rd, std_logic_vector'(x"ddcc_bbaa"));
            elsif run("multiple_addresses") then
                wblite_pkg.bus_write(net, wblite_bus, base_addr, x"aaaa_aaaa");
                wblite_pkg.bus_write(net, wblite_bus, base_addr or x"0000_0004", x"bbbb_bbbb");
                wblite_pkg.bus_read(net, wblite_bus, base_addr, rd);
                check_equal(rd, std_logic_vector'(x"aaaa_aaaa"));
                wblite_pkg.bus_read(net, wblite_bus, base_addr or x"0000_0004", rd);
                check_equal(rd, std_logic_vector'(x"bbbb_bbbb"));
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;
end architecture;
