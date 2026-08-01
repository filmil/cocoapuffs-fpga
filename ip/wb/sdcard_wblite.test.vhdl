-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library vunit_lib;
context vunit_lib.vunit_context;
context vunit_lib.vc_context;

library testing;
use testing.wblite_pkg;
use testing.sdcard_wblite_pkg.all;

library wb;
library sdcard;
use sdcard.sdcard_pkg.all;

entity sdcard_wblite_tb is
    generic (
        runner_cfg: string := runner_cfg_default;
        FILENAME: string := "sdcard_wblite_test_data.txt";
        SIZE_BYTES: natural := 8192
    );
end entity sdcard_wblite_tb;

architecture sim of sdcard_wblite_tb is

    constant wblite_bus: bus_master_t := new_bus(
        data_length => 32, address_length => 32);

    signal clk: std_ulogic := '0';
    signal rst: std_ulogic := '1';

    signal wb_host : wb.host.bus_type;
    signal wb_per  : wb.per.bus_type;

    signal spi_h2d : spi_h2d_t;
    signal spi_d2h : spi_d2h_t;

    constant test_host_log: logger_t := get_logger("tb.test_host");

    constant CLK_PERIOD : time := 10 ns;

    constant BASE_ADDR : std_ulogic_vector(31 downto 0) := x"1234_5600";
    constant DATA_REG_ADDR : std_ulogic_vector(31 downto 0) := BASE_ADDR;
    constant CTRL_REG_ADDR : std_ulogic_vector(31 downto 0) := x"1234_5604";

begin

    clk <= not clk after CLK_PERIOD / 2;
    rst <= '0' after 100 ns;

    -- Wishbone Lite Master
    test_host: entity testing.wblite
        generic map(
            bus_handle => wblite_bus,
            logger => test_host_log
        )
        port map(
            clk => clk,
            rst => rst,
            host_port => wb_host,
            per_port  => wb_per
        );

    -- DUT: Wishbone to SD Card SPI bridge
    dut: entity wb.sdcard_wblite
        generic map (
            base_address => BASE_ADDR
        )
        port map (
            clk      => clk,
            rst      => rst,
            wb_host  => wb_host,
            wb_per   => wb_per,
            spi_h2d  => spi_h2d,
            spi_d2h  => spi_d2h
        );

    -- SD Card Simulation Model
    sdcard: entity sdcard.sdcard
        generic map (
            FILENAME => FILENAME,
            SIZE_BYTES => SIZE_BYTES
        )
        port map (
            h2d => spi_h2d,
            d2h => spi_d2h
        );

    main: process
        variable rd_data : std_ulogic_vector(31 downto 0);
        variable rd_status : std_ulogic_vector(31 downto 0);

        file f : text;
        variable l : line;
        variable status : file_open_status;

    begin
        -- Create the test data file
        file_open(status, f, FILENAME, write_mode);
        if status = open_ok then
            write(l, string'("00")); writeline(f, l);
            write(l, string'("11")); writeline(f, l);
            write(l, string'("22")); writeline(f, l);
            write(l, string'("33")); writeline(f, l);
            write(l, string'("44")); writeline(f, l);
            write(l, string'("55")); writeline(f, l);
            write(l, string'("66")); writeline(f, l);
            write(l, string'("77")); writeline(f, l);
            write(l, string'("88")); writeline(f, l);
            write(l, string'("99")); writeline(f, l);
            write(l, string'("AA")); writeline(f, l);
            write(l, string'("BB")); writeline(f, l);
            write(l, string'("CC")); writeline(f, l);
            write(l, string'("DD")); writeline(f, l);
            write(l, string'("EE")); writeline(f, l);
            write(l, string'("FF")); writeline(f, l);
            file_close(f);
        end if;

        wait for 2 ns;

        test_runner_setup(runner, runner_cfg);

        wait until rst = '0';

        while test_suite loop
            if run("test_cmd0") then
                -- Assert CS_N (Bit 0 of CTRL = 0)
                wblite_pkg.bus_write(net, wblite_bus, CTRL_REG_ADDR, x"0001_0000", x"F");

                -- Send CMD0: 40 00 00 00 00 95
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0040");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0095");

                -- Send 0xFF (wait for response)
                spi_rx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, rd_data);
                check_equal(rd_data(7 downto 0), std_ulogic_vector'(x"01"), "CMD0 response should be 0x01");

                -- Deassert CS_N (Bit 0 of CTRL = 1)
                wblite_pkg.bus_write(net, wblite_bus, CTRL_REG_ADDR, x"0001_0001", x"F");
            elsif run("test_cmd17") then
                -- Assert CS_N (Bit 0 of CTRL = 0)
                wblite_pkg.bus_write(net, wblite_bus, CTRL_REG_ADDR, x"0001_0000", x"F");

                -- Send CMD17: 51 00 00 00 00 FF
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0051");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_00FF");

                -- Read response R1
                spi_rx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, rd_data);
                check_equal(rd_data(7 downto 0), std_ulogic_vector'(x"00"), "CMD17 response should be 0x00");

                -- Read Data Token
                wait_for_token(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"FE");

                -- Read 16 bytes of data
                for i in 0 to 15 loop
                    spi_rx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, rd_data);
                    check_equal(to_integer(unsigned(rd_data(7 downto 0))), i * 17, "Byte " & integer'image(i) & " mismatch");
                end loop;

                -- Deassert CS_N (Bit 0 of CTRL = 1)
                wblite_pkg.bus_write(net, wblite_bus, CTRL_REG_ADDR, x"0001_0001", x"F");
            elsif run("test_cmd24_write_read") then
                -- Assert CS_N (Bit 0 of CTRL = 0)
                wblite_pkg.bus_write(net, wblite_bus, CTRL_REG_ADDR, x"0001_0000", x"F");

                -- Send CMD24 (Write Block): 58 00 00 00 00 FF
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0058");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_00FF");

                -- Read response R1
                spi_rx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, rd_data);
                check_equal(rd_data(7 downto 0), std_ulogic_vector'(x"00"), "CMD24 response should be 0x00");

                -- Send dummy byte before data token
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_00FF");

                -- Send Data Token for write
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_00FE");

                -- Write 512 bytes of data
                for i in 0 to 511 loop
                    spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, std_ulogic_vector(to_unsigned(i mod 256, 32)));
                end loop;

                -- Send dummy CRC
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_00FF");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_00FF");

                -- Read data response token
                spi_rx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, rd_data);
                check_equal(rd_data(4 downto 0), std_ulogic_vector'("00101"), "Data response should indicate accepted (0x05)");

                -- Wait for busy to clear
                wait_for_token(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"FF");

                -- Deassert CS_N
                wblite_pkg.bus_write(net, wblite_bus, CTRL_REG_ADDR, x"0001_0001", x"F");

                -- Extra clock cycles
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_00FF");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_00FF");

                -- Now read back to verify
                -- Assert CS_N
                wblite_pkg.bus_write(net, wblite_bus, CTRL_REG_ADDR, x"0001_0000", x"F");

                -- Send CMD17 (Read block 0): 51 00 00 00 00 FF
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0051");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_0000");
                spi_tx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"0000_00FF");

                -- Read response R1
                spi_rx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, rd_data);
                check_equal(rd_data(7 downto 0), std_ulogic_vector'(x"00"), "CMD17 response should be 0x00");

                -- Wait for Data Token
                wait_for_token(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, x"FE");

                -- Read 512 bytes and verify
                for i in 0 to 511 loop
                    spi_rx(net, wblite_bus, CTRL_REG_ADDR, DATA_REG_ADDR, rd_data);
                    check_equal(to_integer(unsigned(rd_data(7 downto 0))), i mod 256, "Readback byte " & integer'image(i) & " mismatch");
                end loop;

                -- Deassert CS_N
                wblite_pkg.bus_write(net, wblite_bus, CTRL_REG_ADDR, x"0001_0001", x"F");
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 20 ms);

end architecture;
