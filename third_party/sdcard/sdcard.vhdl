-- SPDX-License-Identifier: Apache-2.0
-- SPI mode SD Card simulation model
--
-- This is a simple simulation model for an SD card in SPI mode.
-- It loads memory content from a file (specified by FILENAME) formatted as hex strings
-- or text, and responds to basic SPI SD card commands (CMD0, CMD8, CMD17, etc.)
-- for simulation purposes.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

use work.sdcard_pkg.all;

--! @file sdcard.vhdl
--! @brief Simulation model for an SD card in SPI mode.
--!
--! This file contains the `sdcard` entity, which serves as a simplified SPI mode
--! SD card simulation model.

--! @brief SPI mode SD Card simulation model
--!
--! This is a simple simulation model for an SD card in SPI mode.
--! It loads memory content from a file (specified by FILENAME) and responds
--! to basic SPI SD card commands (CMD0, CMD8, CMD17, etc.) for simulation purposes.
--!
--! @section sd_file_format SD Card Content File Format
--! The file specified by `FILENAME` must be a plain text file containing
--! hexadecimal representations of the card's byte content.
--!
--! Rules for the file format:
--! - Each line must contain exactly one 2-digit hexadecimal byte (e.g., `A5`).
--! - Bytes are loaded sequentially into memory starting from address 0.
--! - The number of bytes loaded is limited by the `SIZE_BYTES` generic or the
--!   end of the file, whichever comes first.
--! - Empty lines or non-hexadecimal content may cause the simulation to fail
--!   or load incorrect values, depending on the simulator's `hread` implementation.
--!
--! Example file content:
--! @code
--! 00
--! 01
--! DE
--! AD
--! BE
--! EF
--! @endcode
entity sdcard is
    generic (
        FILENAME : string := "sdcard.txt";
        SIZE_BYTES : natural := 8192
    );
    port (
        h2d : in  spi_h2d_t;
        d2h : out spi_d2h_t
    );
end entity sdcard;

architecture sim of sdcard is

    type state_t is (IDLE, RECEIVE_CMD, SEND_RESPONSE, SEND_DATA_TOKEN, SEND_DATA, SEND_CRC, RECEIVE_DATA_TOKEN, RECEIVE_DATA, RECEIVE_CRC, SEND_DATA_RESPONSE, WAIT_BUSY, WAIT_IDLE);
    signal state : state_t := IDLE;

    -- SPI shift register for 48-bit commands
    signal shift_reg : std_logic_vector(47 downto 0) := (others => '1');
    signal bit_count : integer := 0;

    --! @brief Memory array to hold block data (default 8192 bytes = 16 blocks of 512 bytes).
    type ram_type is array (0 to SIZE_BYTES - 1) of std_logic_vector(7 downto 0);

    --! @brief Impure function to load RAM content from a hex text file.
    impure function load_ram(filename : string) return ram_type is
        file f : text;
        variable l : line;
        variable val : std_logic_vector(7 downto 0);
        variable ram : ram_type := (others => (others => '0'));
        variable status : file_open_status;
        variable idx : integer := 0;
    begin
        file_open(status, f, filename, read_mode);
        if status = open_ok then
            while not endfile(f) and idx < SIZE_BYTES loop
                readline(f, l);
                hread(l, val);
                ram(idx) := val;
                idx := idx + 1;
            end loop;
            file_close(f);
        end if;
        return ram;
    end function;

    signal ram : ram_type := (others => (others => '0'));

    -- SD Card signals
    signal resp_reg : std_logic_vector(7 downto 0) := (others => '1');
    signal resp_bit : integer := 0;

    signal cmd_idx : std_logic_vector(5 downto 0);
    signal cmd_arg : std_logic_vector(31 downto 0);

    signal current_addr : integer := 0;
    signal byte_count   : integer := 0;
    signal current_byte : std_logic_vector(7 downto 0) := (others => '1');

    --! @brief Load RAM signal
    signal ram_init : std_logic := '0';

begin

    ram_init <= '1' after 1 ns, '0' after 2 ns;

    --! @brief Process for input signals (MOSI sampled on rising edge).
    process(h2d.sck, h2d.cs_n, ram_init)
    begin
        if ram_init = '1' then
            ram <= load_ram(FILENAME);
        elsif h2d.cs_n = '1' then
            state <= IDLE;
            bit_count <= 0;
        elsif rising_edge(h2d.sck) then
            case state is
                when IDLE =>
                    if h2d.mosi = '0' then
                        -- Start bit of command detected
                        shift_reg <= (others => '1');
                        shift_reg(47) <= '0';
                        bit_count <= 46;
                        state <= RECEIVE_CMD;
                    end if;

                when RECEIVE_CMD =>
                    shift_reg(bit_count) <= h2d.mosi;
                    if bit_count = 0 then                        -- Full 48-bit command received
                        cmd_idx <= shift_reg(45 downto 40);
                        cmd_arg <= shift_reg(39 downto 8);

                        resp_bit <= 7;
                        if shift_reg(45 downto 40) = "000000" then -- CMD0
                            resp_reg <= x"01"; -- R1 Idle
                            state <= SEND_RESPONSE;
                        elsif shift_reg(45 downto 40) = "010001" then -- CMD17 (Read block)
                            resp_reg <= x"00"; -- R1 Success
                            current_addr <= to_integer(unsigned(shift_reg(39 downto 8)));
                            state <= SEND_RESPONSE;
                        elsif shift_reg(45 downto 40) = "011000" then -- CMD24 (Write block)
                            resp_reg <= x"00"; -- R1 Success
                            current_addr <= to_integer(unsigned(shift_reg(39 downto 8)));
                            state <= SEND_RESPONSE;
                        else
                            resp_reg <= x"00"; -- R1 Success default
                            state <= SEND_RESPONSE;
                        end if;
                    else
                        bit_count <= bit_count - 1;
                    end if;

                when SEND_RESPONSE =>
                    if resp_bit = 0 then
                        if cmd_idx = "010001" then -- CMD17
                            state <= SEND_DATA_TOKEN;
                            current_byte <= x"FE"; -- Data token
                            resp_bit <= 7;
                        elsif cmd_idx = "011000" then -- CMD24
                            state <= RECEIVE_DATA_TOKEN;
                        else
                            state <= WAIT_IDLE;
                        end if;
                    else
                        resp_bit <= resp_bit - 1;
                    end if;

                when SEND_DATA_TOKEN =>
                    if resp_bit = 0 then
                        state <= SEND_DATA;
                        byte_count <= 0;
                        current_byte <= ram(current_addr);
                        resp_bit <= 7;
                    else
                        resp_bit <= resp_bit - 1;
                    end if;

                when SEND_DATA =>
                    if resp_bit = 0 then
                        if byte_count = 511 then
                            state <= SEND_CRC;
                            current_byte <= x"AA"; -- dummy CRC
                            byte_count <= 0;
                            resp_bit <= 7;
                        else
                            byte_count <= byte_count + 1;
                            current_byte <= ram(current_addr + byte_count + 1);
                            resp_bit <= 7;
                        end if;
                    else
                        resp_bit <= resp_bit - 1;
                    end if;

                when SEND_CRC =>
                    if resp_bit = 0 then
                        if byte_count = 1 then
                            state <= WAIT_IDLE;
                        else
                            byte_count <= byte_count + 1;
                            current_byte <= x"55"; -- dummy CRC 2nd byte
                            resp_bit <= 7;
                        end if;
                    else
                        resp_bit <= resp_bit - 1;
                    end if;

                when RECEIVE_DATA_TOKEN =>
                    shift_reg(7 downto 0) <= shift_reg(6 downto 0) & h2d.mosi;
                    if (shift_reg(6 downto 0) & h2d.mosi) = x"FE" then
                        state <= RECEIVE_DATA;
                        byte_count <= 0;
                        resp_bit <= 7;
                    end if;

                when RECEIVE_DATA =>
                    shift_reg(7 downto 0) <= shift_reg(6 downto 0) & h2d.mosi;
                    if resp_bit = 0 then
                        ram(current_addr + byte_count) <= shift_reg(6 downto 0) & h2d.mosi;
                        if byte_count = 511 then
                            state <= RECEIVE_CRC;
                            byte_count <= 0;
                            resp_bit <= 15; -- 16 bit CRC
                        else
                            byte_count <= byte_count + 1;
                            resp_bit <= 7;
                        end if;
                    else
                        resp_bit <= resp_bit - 1;
                    end if;

                when RECEIVE_CRC =>
                    if resp_bit = 0 then
                        state <= SEND_DATA_RESPONSE;
                        resp_reg <= x"05"; -- Data accepted
                        resp_bit <= 7;
                    else
                        resp_bit <= resp_bit - 1;
                    end if;

                when SEND_DATA_RESPONSE =>
                    if resp_bit = 0 then
                        state <= WAIT_BUSY;
                        -- simulate busy for a few cycles
                        byte_count <= 10;
                    else
                        resp_bit <= resp_bit - 1;
                    end if;

                when WAIT_BUSY =>
                    if byte_count = 0 then
                        state <= WAIT_IDLE;
                    else
                        byte_count <= byte_count - 1;
                    end if;

                when WAIT_IDLE =>
                    if h2d.mosi = '1' then
                        state <= IDLE;
                    end if;
            end case;
        end if;
    end process;

    --! @brief Process for output signals (MISO updated on falling edge).
    process(h2d.sck, h2d.cs_n)
    begin
        if h2d.cs_n = '1' then
            d2h.miso <= 'Z';
        elsif falling_edge(h2d.sck) then
            if state = SEND_RESPONSE or state = SEND_DATA_RESPONSE then
                d2h.miso <= resp_reg(resp_bit);
            elsif state = SEND_DATA_TOKEN or state = SEND_DATA or state = SEND_CRC then
                d2h.miso <= current_byte(resp_bit);
            elsif state = WAIT_BUSY then
                d2h.miso <= '0';
            else
                d2h.miso <= '1';
            end if;
        end if;
    end process;

end architecture sim;
