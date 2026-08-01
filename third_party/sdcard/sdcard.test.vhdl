-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

library vunit_lib;
context vunit_lib.vunit_context;

library testing;
use testing.spi.all;

library sdcard;
use sdcard.sdcard_pkg.all;

entity sdcard_tb is
    generic (
        runner_cfg: string := runner_cfg_default;
        FILENAME: string := "sdcard_test_data.txt";
        SIZE_BYTES: natural := 8192
    );
end entity sdcard_tb;

architecture sim of sdcard_tb is

    signal spi_h2d : spi_h2d_t := (cs_n => '1', sck => '0', mosi => '1');
    signal spi_d2h : spi_d2h_t;

    constant CLK_PERIOD : time := 10 ns;

begin

    dut: entity sdcard.sdcard
        generic map (
            FILENAME => FILENAME,
            SIZE_BYTES => SIZE_BYTES
        )
        port map (
            h2d => spi_h2d,
            d2h => spi_d2h
        );

    main: process
        variable rcv_byte : std_logic_vector(7 downto 0);
        
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
        
        -- Wait for SD card model to load the file
        wait for 2 ns;

        test_runner_setup(runner, runner_cfg);

        while test_suite loop
            if run("test_cmd0") then
                -- CMD0: 40 00 00 00 00 95
                spi_h2d.cs_n <= '0';
                wait for CLK_PERIOD;
                
                spi_send_byte(x"40", spi_h2d.sck, spi_h2d.mosi, CLK_PERIOD);
                spi_send_byte(x"00", spi_h2d.sck, spi_h2d.mosi, CLK_PERIOD);
                spi_send_byte(x"00", spi_h2d.sck, spi_h2d.mosi, CLK_PERIOD);
                spi_send_byte(x"00", spi_h2d.sck, spi_h2d.mosi, CLK_PERIOD);
                spi_send_byte(x"00", spi_h2d.sck, spi_h2d.mosi, CLK_PERIOD);
                spi_send_byte(x"95", spi_h2d.sck, spi_h2d.mosi, CLK_PERIOD);
                
                -- Wait for response
                spi_h2d.mosi <= '1';
                spi_receive_byte(rcv_byte, spi_h2d.sck, spi_d2h.miso, CLK_PERIOD);
                
                check_equal(rcv_byte, std_logic_vector'(x"01"), "CMD0 response should be 0x01");
                
                spi_h2d.cs_n <= '1';
                wait for CLK_PERIOD;

            elsif run("test_cmd17") then
                -- CMD17 (Read Block 0): 51 00 00 00 00 FF
                spi_h2d.cs_n <= '0';
                wait for CLK_PERIOD;
                
                spi_send_byte(x"51", spi_h2d.sck, spi_h2d.mosi, CLK_PERIOD);
                spi_send_byte(x"00", spi_h2d.sck, spi_h2d.mosi, CLK_PERIOD);
                spi_send_byte(x"00", spi_h2d.sck, spi_h2d.mosi, CLK_PERIOD);
                spi_send_byte(x"00", spi_h2d.sck, spi_h2d.mosi, CLK_PERIOD);
                spi_send_byte(x"00", spi_h2d.sck, spi_h2d.mosi, CLK_PERIOD);
                spi_send_byte(x"FF", spi_h2d.sck, spi_h2d.mosi, CLK_PERIOD);
                
                -- Response R1
                spi_h2d.mosi <= '1';
                spi_receive_byte(rcv_byte, spi_h2d.sck, spi_d2h.miso, CLK_PERIOD);
                check_equal(rcv_byte, std_logic_vector'(x"00"), "CMD17 response should be 0x00");
                
                -- Data Token
                spi_receive_byte(rcv_byte, spi_h2d.sck, spi_d2h.miso, CLK_PERIOD);
                check_equal(rcv_byte, std_logic_vector'(x"FE"), "Data token should be 0xFE");
                
                -- Read first 16 bytes (we only provided 16 in the test file)
                for i in 0 to 15 loop
                    spi_receive_byte(rcv_byte, spi_h2d.sck, spi_d2h.miso, CLK_PERIOD);
                    -- The test data is 00, 11, 22 ... FF
                    check_equal(to_integer(unsigned(rcv_byte)), i * 17, "Byte " & integer'image(i) & " mismatch");
                end loop;
                
                spi_h2d.cs_n <= '1';
                wait for CLK_PERIOD;
            end if;
        end loop;

        test_runner_cleanup(runner);
    end process;

    test_runner_watchdog(runner, 100 ms);

end architecture;
