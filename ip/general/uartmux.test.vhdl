-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library general;

entity uartmux_tb is
    generic (
        runner_cfg: string := runner_cfg_default
    );
end entity uartmux_tb;

architecture sim of uartmux_tb is

    constant remote_tx_master : uart_master_t := new_uart_master;
    constant remote_tx_stream : stream_master_t := as_stream(remote_tx_master);

    constant remote_rx_slave : uart_slave_t := new_uart_slave(data_length => 8);
    constant remote_rx_stream : stream_slave_t := as_stream(remote_rx_slave);

    constant local0_tx_master : uart_master_t := new_uart_master;
    constant local0_tx_stream : stream_master_t := as_stream(local0_tx_master);

    constant local0_rx_slave : uart_slave_t := new_uart_slave(data_length => 8);
    constant local0_rx_stream : stream_slave_t := as_stream(local0_rx_slave);

    constant local1_tx_master : uart_master_t := new_uart_master;
    constant local1_tx_stream : stream_master_t := as_stream(local1_tx_master);

    constant local1_rx_slave : uart_slave_t := new_uart_slave(data_length => 8);
    constant local1_rx_stream : stream_slave_t := as_stream(local1_rx_slave);

    signal remote_rx_sig : std_logic := '1';
    signal remote_tx_sig : std_logic;

    signal local_rx_sig : std_logic_vector(1 downto 0);
    signal local_tx_sig : std_logic_vector(1 downto 0) := (others => '1');

    constant BAUD_RATE : natural := 115200;

begin

    dut: entity general.uartmux
        generic map (
            num_ports => 2
        )
        port map (
            remote_rx => remote_rx_sig,
            remote_tx => remote_tx_sig,
            local_rx  => local_rx_sig,
            local_tx  => local_tx_sig
        );

    remote_master_inst: entity vunit_lib.uart_master
        generic map (uart => remote_tx_master)
        port map (tx => remote_rx_sig);

    remote_slave_inst: entity vunit_lib.uart_slave
        generic map (uart => remote_rx_slave)
        port map (rx => remote_tx_sig);

    local0_master_inst: entity vunit_lib.uart_master
        generic map (uart => local0_tx_master)
        port map (tx => local_tx_sig(0));

    local0_slave_inst: entity vunit_lib.uart_slave
        generic map (uart => local0_rx_slave)
        port map (rx => local_rx_sig(0));

    local1_master_inst: entity vunit_lib.uart_master
        generic map (uart => local1_tx_master)
        port map (tx => local_tx_sig(1));

    local1_slave_inst: entity vunit_lib.uart_slave
        generic map (uart => local1_rx_slave)
        port map (rx => local_rx_sig(1));

    main: process
    begin
        test_runner_setup(runner, runner_cfg);

        set_baud_rate(net, remote_tx_master, BAUD_RATE);
        set_baud_rate(net, remote_rx_slave, BAUD_RATE);
        set_baud_rate(net, local0_tx_master, BAUD_RATE);
        set_baud_rate(net, local0_rx_slave, BAUD_RATE);
        set_baud_rate(net, local1_tx_master, BAUD_RATE);
        set_baud_rate(net, local1_rx_slave, BAUD_RATE);

        while test_suite loop
            if run("test_local0_send_receive") then
                -- Local 0 sends to Remote
                push_stream(net, local0_tx_stream, x"A5");
                check_stream(net, remote_rx_stream, x"A5");
                wait_until_idle(net, as_sync(local0_tx_master));

                -- Remote sends to Local 0 and 1 (both receive)
                push_stream(net, remote_tx_stream, x"5A");
                check_stream(net, local0_rx_stream, x"5A");
                check_stream(net, local1_rx_stream, x"5A");
                wait_until_idle(net, as_sync(remote_tx_master));

            elsif run("test_local1_send_receive") then
                -- Local 1 sends to Remote
                push_stream(net, local1_tx_stream, x"C3");
                check_stream(net, remote_rx_stream, x"C3");
                wait_until_idle(net, as_sync(local1_tx_master));

                -- Remote sends to Local 0 and 1 (both receive)
                push_stream(net, remote_tx_stream, x"3C");
                check_stream(net, local0_rx_stream, x"3C");
                check_stream(net, local1_rx_stream, x"3C");
                wait_until_idle(net, as_sync(remote_tx_master));

            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 100 ms);

end architecture;
