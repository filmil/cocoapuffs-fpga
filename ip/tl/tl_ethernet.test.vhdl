-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library tl;
use tl.types.all;

library testing;
use testing.tl_uh_pkg.all;

library ethernet;

--! @file
--! @brief Testbench for TileLink-UH Ethernet Controller.

--! @brief Testbench entity.
entity tl_ethernet_test is
    generic (
        runner_cfg : string := runner_cfg_default
    );
end entity tl_ethernet_test;

architecture tb of tl_ethernet_test is
    constant tl_bus : bus_master_t := new_bus(
        data_length => 32, address_length => 32
    );

    signal clk   : std_ulogic := '0';
    signal rst   : std_ulogic := '1';

    signal tl_i  : host_type := host_type_new;
    signal tl_o  : per_type  := per_type_new;

    signal eth_txck  : std_ulogic;
    signal eth_txctl : std_ulogic;
    signal eth_txd   : std_ulogic_vector(3 downto 0);
    signal eth_rxck  : std_ulogic;
    signal eth_rxctl : std_ulogic;
    signal eth_rxd   : std_ulogic_vector(3 downto 0);
    signal eth_mdc   : std_ulogic;
    signal eth_mdio  : std_logic;
    signal eth_reset : std_ulogic;
    signal irq       : std_ulogic;

    signal done      : std_ulogic := '0';
begin

    -- Clock generation
    clk_gen : entity testing.clkgen
        generic map (
            clock_period => 10 ns,
            reset_duration => 20 ns
        )
        port map (
            clk => clk,
            reset => rst
        );

    -- TileLink Master
    tl_master_inst : entity testing.tl_uh_master
        generic map (
            bus_handle => tl_bus
        )
        port map (
            clk       => clk,
            rst       => rst,
            host_port => tl_i,
            per_port  => tl_o
        );

    -- Device under test
    dut : entity tl.tl_ethernet
        generic map (
            BASE_ADDRESS => x"10000000"
        )
        port map (
            clk       => clk,
            rst       => rst,
            tl_i      => tl_i,
            tl_o      => tl_o,
            eth_txck  => eth_txck,
            eth_txctl => eth_txctl,
            eth_txd   => eth_txd,
            eth_rxck  => eth_rxck,
            eth_rxctl => eth_rxctl,
            eth_rxd   => eth_rxd,
            eth_mdc   => eth_mdc,
            eth_mdio  => eth_mdio,
            eth_reset => eth_reset,
            irq       => irq
        );

    -- PHY model
    phy : entity ethernet.phy
        port map (
            eth_txck  => eth_txck,
            eth_txctl => eth_txctl,
            eth_txd   => eth_txd,
            eth_rxck  => eth_rxck,
            eth_rxctl => eth_rxctl,
            eth_rxd   => eth_rxd,
            eth_mdc   => eth_mdc,
            eth_mdio  => eth_mdio,
            eth_reset => eth_reset
        );

    -- Test sequence
    main : process
        variable data_read : std_ulogic_vector(31 downto 0);
    begin
        test_runner_setup(runner, runner_cfg);

        wait until falling_edge(rst);
        wait for 10 ns;

        while test_suite loop
            if run("test_mdio_register_write_read") then
                -- Write 0xDEADBEEF to address 0x10000004
                bus_write(net, tl_bus, x"10000004", x"DEADBEEF");
                -- Read back from address 0x10000004
                bus_read(net, tl_bus, x"10000004", data_read);
                assert data_read = x"DEADBEEF" report "MDIO Read mismatch";

            elsif run("test_data_transfer_loopback") then
                -- Write 0x12345678 to address 0x10000010 (TX FIFO)
                bus_write(net, tl_bus, x"10000010", x"12345678");
                -- Read back from address 0x10000020 (RX FIFO loopback)
                bus_read(net, tl_bus, x"10000020", data_read);
                assert data_read = x"12345678" report "Loopback mismatch";
            end if;
        end loop;

        done <= '1';
        test_runner_cleanup(runner);
    end process;

end architecture tb;
