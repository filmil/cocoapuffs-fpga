-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @file
--! @brief SPI testing utilities.
--!
--! Public API:
--! * ::spi::spi_send_byte
--! * ::spi::spi_receive_byte

--! SPI testing utilities.
package spi is

    --! @brief Send a byte over SPI.
    --! @param byte Byte to send.
    --! @param sck SPI clock signal.
    --! @param mosi SPI MOSI signal.
    --! @param clk_period Time for one full clock cycle.
    procedure spi_send_byte(
        byte : in std_logic_vector(7 downto 0);
        signal sck : out std_logic;
        signal mosi : out std_logic;
        constant clk_period : in time
    );

    --! @brief Receive a byte over SPI.
    --! @param byte Received byte.
    --! @param sck SPI clock signal.
    --! @param miso SPI MISO signal.
    --! @param clk_period Time for one full clock cycle.
    procedure spi_receive_byte(
        byte : out std_logic_vector(7 downto 0);
        signal sck : out std_logic;
        signal miso : in std_logic;
        constant clk_period : in time
    );

end package spi;

package body spi is

    procedure spi_send_byte(
        byte : in std_logic_vector(7 downto 0);
        signal sck : out std_logic;
        signal mosi : out std_logic;
        constant clk_period : in time
    ) is
    begin
        for i in 7 downto 0 loop
            mosi <= byte(i);
            wait for clk_period/2;
            sck <= '1';
            wait for clk_period/2;
            sck <= '0';
        end loop;
    end procedure;

    procedure spi_receive_byte(
        byte : out std_logic_vector(7 downto 0);
        signal sck : out std_logic;
        signal miso : in std_logic;
        constant clk_period : in time
    ) is
    begin
        for i in 7 downto 0 loop
            wait for clk_period/2;
            sck <= '1';
            byte(i) := miso;
            wait for clk_period/2;
            sck <= '0';
        end loop;
    end procedure;

end package body spi;
