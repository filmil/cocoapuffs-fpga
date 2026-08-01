-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library third_party_uart;
use third_party_uart.all;
library unisim;

entity board_top is
    port (
             sys_clk_p: in std_logic;
             sys_clk_n: in std_logic;
             uart1_txd: out std_logic;
             uart1_rxd: in std_logic;

            -- Active low.
             reset_n: in std_logic;

             led1: out std_logic;
             led2: out std_logic;
             led3: out std_logic;
             led4: out std_logic
         );
end entity;

architecture rtl of board_top is

    component top is
        generic (
                    baud: positive;
                    clock_frequency: positive
                );
        port (
                 clock_y3: in std_logic;
                 user_reset: in std_logic;
                 usb_rs232_rxd: in std_logic;
                 usb_rs232_txd: out std_logic
             );
    end component;

    signal reset, clk: std_logic;

    constant BITS: positive := 28;
    constant MAX_COUNT: unsigned(BITS-1 downto 0) := (others => '1');
    signal count: unsigned(BITS-1 downto 0);

    signal  lights: unsigned(3 downto 0);

begin

    -- Presumably makes a single-ended signal out of a differential clock.
    ibufds_inst : unisim.vcomponents.ibufds
    generic map (
                    DIFF_TERM => true,
                    IOSTANDARD => "LVDS_25" -- Example I/O standard
                )
    port map (
                 I  => sys_clk_p,  -- Connect to positive input pin
                 IB => sys_clk_n,  -- Connect to negative input pin
                 O  => clk  -- Connect to internal signal
             );

    reset <= not reset_n;

    top_inst: top
    generic map(
                   baud => 115_200, -- Hz
                   clock_frequency => 200_000_000 -- Hz (200MHz)
               )
    port map(
                clock_y3 => clk,
                user_reset => reset,
                usb_rs232_rxd => uart1_rxd,
                usb_rs232_txd => uart1_txd
            );

    -- LED pattern

    led1 <= not count(BITS-1);
    led2 <= not count(BITS-2);
    led3 <= not count(BITS-3);
    led4 <= reset_n;

    process (clk, reset)
    begin
        if reset = '1' then
            count <= (others => '0');
            lights <= lights + 1;
        elsif rising_edge(clk) then
            if count = MAX_COUNT then
                count <= (others => '0');
                lights <= lights + 1;
            else
                count <= count + 1;
            end if;
        end if;
    end process;

end architecture rtl;

