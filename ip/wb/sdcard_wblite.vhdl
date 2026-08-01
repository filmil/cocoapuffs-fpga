-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library wb;
use wb.host;
use wb.per;

library sdcard;
use sdcard.sdcard_pkg.all;

--! @file sdcard_wblite.vhdl
--! @brief Wishbone lite module for interfacing with an SD card over SPI.

--! @brief Wishbone lite SPI SD Card Controller
--!
--! Provides a simple SPI master interface mapped to Wishbone lite to
--! communicate with an SD card in SPI mode.
--!
--! Memory Map (32-bit words):
--! - Offset 0x00 (DATA):
--!   - Write [7:0]: Data to transmit. Starts an SPI transfer.
--!   - Read  [7:0]: Last received data.
--! - Offset 0x04 (CTRL):
--!   - Bit [0] (R/W): CS_N (Chip Select Active Low). 1 = Deselected, 0 = Selected. Default is 1.
--!   - Bit [1] (R/O): BUSY. 1 = Transfer in progress, 0 = Idle.
--!   - Bits [31:16] (R/W): Clock Divider. SCK frequency = CLK / (2 * CLOCK_DIV). Default is 1.
--!
--! @par Typical SPI Transfer (Mode 0):
--! @code
--!          ___     ___     ___     ___     ___     ___     ___     ___     ___
--! clk    _|   |___|   |___|   |___|   |___|   |___|   |___|   |___|   |___|   |
--!
--! cs_n   \___________________________________________________________________/
--!              ___     ___     ___     ___     ___     ___     ___     ___
--! sck    _____/   \___/   \___/   \___/   \___/   \___/   \___/   \___/   \___
--!        _____ _______ _______ _______ _______ _______ _______ _______ _______
--! mosi   _____X_Bit_7_X_Bit_6_X_Bit_5_X_Bit_4_X_Bit_3_X_Bit_2_X_Bit_1_X_Bit_0_
--!        _____ _______ _______ _______ _______ _______ _______ _______ _______
--! miso   _____X_Bit_7_X_Bit_6_X_Bit_5_X_Bit_4_X_Bit_3_X_Bit_2_X_Bit_1_X_Bit_0_
--! @endcode
entity sdcard_wblite is
    generic (
        --! The base address of the peripheral in the address space.
        base_address : std_ulogic_vector(31 downto 0)
    );
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;

        -- Wishbone interface
        wb_host  : in  wb.host.bus_type;
        wb_per   : out wb.per.bus_type;

        -- SPI interface to SD card
        spi_h2d  : out spi_h2d_t;
        spi_d2h  : in  spi_d2h_t
        );
        end entity sdcard_wblite;
architecture rtl of sdcard_wblite is

    -- Registers
    signal cs_n_reg   : std_logic := '1';
    signal clk_div    : unsigned(15 downto 0) := to_unsigned(1, 16);
    signal tx_data    : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_data    : std_logic_vector(7 downto 0) := (others => '0');

    -- SPI state machine
    type state_t is (IDLE, TRANSFER, DONE);
    signal state : state_t := IDLE;

    signal bit_counter : integer range 0 to 7 := 7;
    signal div_counter : unsigned(15 downto 0) := (others => '0');
    signal sck_reg     : std_logic := '0';
    signal busy        : std_logic := '0';

    -- Wishbone ack
    signal ack_reg : std_logic := '0';
    signal rdt_reg : std_logic_vector(31 downto 0) := (others => '0');

    signal address_match : boolean;

begin

    address_match <= std_match(wb_host.adr(31 downto 4), base_address(31 downto 4));

    spi_h2d.cs_n <= cs_n_reg;
    spi_h2d.sck  <= sck_reg;
    spi_h2d.mosi <= tx_data(bit_counter) when state = TRANSFER else '1';

    -- SPI Master Process
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                bit_counter <= 7;
                sck_reg <= '0';
                div_counter <= (others => '0');
                busy <= '0';
            else
                case state is
                    when IDLE =>
                        sck_reg <= '0';
                        bit_counter <= 7;
                        div_counter <= (others => '0');

                        -- Wishbone write to DATA register triggers transfer
                        if wb_host.cyc = '1' and wb_host.we = '1' and ack_reg = '0' and address_match then
                            if wb_host.adr(3 downto 2) = "00" then -- Offset 0x00
                                busy <= '1';
                                state <= TRANSFER;
                            end if;
                        end if;

                    when TRANSFER =>
                        if div_counter = clk_div - 1 then
                            div_counter <= (others => '0');
                            sck_reg <= not sck_reg;

                            if sck_reg = '1' then
                                -- Falling edge of SCK, shift next bit
                                if bit_counter = 0 then
                                    state <= DONE;
                                else
                                    bit_counter <= bit_counter - 1;
                                end if;
                            else
                                -- Rising edge of SCK, sample MISO
                                rx_data(bit_counter) <= spi_d2h.miso;
                            end if;
                        else
                            div_counter <= div_counter + 1;
                        end if;

                    when DONE =>
                        -- Ensure SCK is low at the end
                        sck_reg <= '0';
                        busy <= '0';
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

    -- Wishbone Slave Process
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ack_reg <= '0';
                rdt_reg <= (others => '0');
                cs_n_reg <= '1';
                clk_div <= to_unsigned(1, 16);
            else
                ack_reg <= '0';

                if wb_host.cyc = '1' and ack_reg = '0' and address_match then
                    ack_reg <= '1';

                    if wb_host.we = '1' then
                        -- Write
                        case wb_host.adr(3 downto 2) is
                            when "00" => -- DATA
                                tx_data <= wb_host.dat(7 downto 0);
                            when "01" => -- CTRL
                                if wb_host.sel(0) = '1' then
                                    cs_n_reg <= wb_host.dat(0);
                                end if;
                                if wb_host.sel(2) = '1' or wb_host.sel(3) = '1' then
                                    clk_div <= unsigned(wb_host.dat(31 downto 16));
                                    -- Prevent divide by zero
                                    if unsigned(wb_host.dat(31 downto 16)) = 0 then
                                        clk_div <= to_unsigned(1, 16);
                                    end if;
                                end if;
                            when others =>
                                null;
                        end case;
                    else
                        -- Read
                        rdt_reg <= (others => '0');
                        case wb_host.adr(3 downto 2) is
                            when "00" => -- DATA
                                rdt_reg(7 downto 0) <= rx_data;
                            when "01" => -- CTRL
                                rdt_reg(0) <= cs_n_reg;
                                rdt_reg(1) <= busy;
                                rdt_reg(31 downto 16) <= std_logic_vector(clk_div);
                            when others =>
                                null;
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process;

    wb_per.rdt <= rdt_reg;
    wb_per.ack <= ack_reg;

end architecture rtl;
