-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library testing;
use testing.wblite_pkg.all;

--! @file
--! @brief Test utilities for sdcard_wblite peripheral over Wishbone.

package sdcard_wblite_pkg is

    --! @brief Helper procedure to wait for SPI transfer to complete with timeout
    procedure wait_spi_ready(
        signal net: inout network_t;
        bus_handle: bus_master_t;
        ctrl_addr: std_ulogic_vector(31 downto 0)
    );

    --! @brief Helper procedure to send a byte and wait
    procedure spi_tx(
        signal net: inout network_t;
        bus_handle: bus_master_t;
        ctrl_addr: std_ulogic_vector(31 downto 0);
        data_addr: std_ulogic_vector(31 downto 0);
        data: std_ulogic_vector(31 downto 0)
    );

    --! @brief Helper procedure to receive a byte
    procedure spi_rx(
        signal net: inout network_t;
        bus_handle: bus_master_t;
        ctrl_addr: std_ulogic_vector(31 downto 0);
        data_addr: std_ulogic_vector(31 downto 0);
        variable data: out std_ulogic_vector(31 downto 0)
    );

    --! @brief Helper procedure to wait for a specific token with timeout
    procedure wait_for_token(
        signal net: inout network_t;
        bus_handle: bus_master_t;
        ctrl_addr: std_ulogic_vector(31 downto 0);
        data_addr: std_ulogic_vector(31 downto 0);
        expected_token: std_ulogic_vector(7 downto 0)
    );

end package sdcard_wblite_pkg;

package body sdcard_wblite_pkg is

    procedure wait_spi_ready(
        signal net: inout network_t;
        bus_handle: bus_master_t;
        ctrl_addr: std_ulogic_vector(31 downto 0)
    ) is
        variable rd_status : std_ulogic_vector(31 downto 0);
        variable timeout_counter : integer := 0;
    begin
        loop
            bus_read(net, bus_handle, ctrl_addr, rd_status, x"F");
            exit when rd_status(1) = '0';
            timeout_counter := timeout_counter + 1;
            check(timeout_counter < 1000, "Timeout waiting for SPI transfer");
        end loop;
    end procedure;

    procedure spi_tx(
        signal net: inout network_t;
        bus_handle: bus_master_t;
        ctrl_addr: std_ulogic_vector(31 downto 0);
        data_addr: std_ulogic_vector(31 downto 0);
        data: std_ulogic_vector(31 downto 0)
    ) is
    begin
        bus_write(net, bus_handle, data_addr, data, x"F");
        wait_spi_ready(net, bus_handle, ctrl_addr);
    end procedure;

    procedure spi_rx(
        signal net: inout network_t;
        bus_handle: bus_master_t;
        ctrl_addr: std_ulogic_vector(31 downto 0);
        data_addr: std_ulogic_vector(31 downto 0);
        variable data: out std_ulogic_vector(31 downto 0)
    ) is
    begin
        spi_tx(net, bus_handle, ctrl_addr, data_addr, x"0000_00FF");
        bus_read(net, bus_handle, data_addr, data, x"F");
    end procedure;

    procedure wait_for_token(
        signal net: inout network_t;
        bus_handle: bus_master_t;
        ctrl_addr: std_ulogic_vector(31 downto 0);
        data_addr: std_ulogic_vector(31 downto 0);
        expected_token: std_ulogic_vector(7 downto 0)
    ) is
        variable timeout_counter : integer := 0;
        variable rcv_data : std_ulogic_vector(31 downto 0);
    begin
        loop
            spi_rx(net, bus_handle, ctrl_addr, data_addr, rcv_data);
            exit when rcv_data(7 downto 0) = expected_token;
            timeout_counter := timeout_counter + 1;
            check(timeout_counter < 1000, "Timeout waiting for token " & to_string(expected_token));
        end loop;
    end procedure;

end package body sdcard_wblite_pkg;
