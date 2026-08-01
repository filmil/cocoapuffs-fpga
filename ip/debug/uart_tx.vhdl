-- SPDX-License-Identifier: Apache-2.0

--! @brief Minimal 8N1 UART transmitter (byte stream -> serial line).
--!
--! Accepts one byte at a time through a valid/ready handshake and shifts it out
--! LSB-first as start(0) + 8 data + stop(1) at the configured baud rate. Used to
--! serialize the ahb_recorder's dump byte stream onto the stolen UART TX pin.
--! The line idles high.
library ieee;
use ieee.std_logic_1164.all;

entity uart_tx is
    generic (
        --! Input clock frequency, in Hz.
        clk_freq_hz : positive := 50_000_000;
        --! UART baud rate, in bits/second.
        baud_rate   : positive := 115_200
    );
    port (
        --! Clock.
        clk   : in  std_ulogic;
        --! Active-low synchronous reset.
        rstn  : in  std_ulogic;
        --! Byte to transmit (sampled when valid and ready are both high).
        data  : in  std_ulogic_vector(7 downto 0);
        --! Byte-available strobe.
        valid : in  std_ulogic;
        --! High when the transmitter can accept a new byte (idle).
        ready : out std_ulogic;
        --! Serial output, idles high.
        tx    : out std_ulogic
    );
end entity;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

architecture rtl of uart_tx is
    --! Clock cycles per serial bit.
    constant div : positive := clk_freq_hz / baud_rate;

    --! Baud sub-bit cycle counter.
    signal cnt       : integer range 0 to div-1 := 0;
    --! Number of frame bits (start + 8 data + stop = 10) still to send.
    signal bits_left : integer range 0 to 10 := 0;
    --! Shift register; tx is its bit 0. Idles all-ones (high).
    signal shifter   : std_ulogic_vector(9 downto 0) := (others => '1');
    --! High while a frame is being shifted out.
    signal busy      : std_ulogic := '0';
begin
    tx    <= shifter(0);
    ready <= not busy;

    process(clk) is
    begin
        if rising_edge(clk) then
            if rstn = '0' then
                busy      <= '0';
                shifter   <= (others => '1');
                cnt       <= 0;
                bits_left <= 0;
            elsif busy = '0' then
                shifter <= (others => '1');     --! idle high
                if valid = '1' then
                    --! Load the frame: bit0=start(0), bits1..8=data LSB-first,
                    --! bit9=stop(1).
                    shifter   <= '1' & data & '0';
                    busy      <= '1';
                    cnt       <= 0;
                    bits_left <= 10;
                end if;
            else
                if cnt = div-1 then
                    cnt     <= 0;
                    shifter <= '1' & shifter(9 downto 1);   --! shift, fill stop
                    if bits_left = 1 then
                        busy <= '0';
                    else
                        bits_left <= bits_left - 1;
                    end if;
                else
                    cnt <= cnt + 1;
                end if;
            end if;
        end if;
    end process;
end architecture;
