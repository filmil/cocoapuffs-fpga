-- SPDX-License-Identifier: Apache-2.0
-- See LICENSE file.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

--! @file
--! @brief UART testing utilities.
--!
--! Public API:
--! * ::uart::BIT_PERIOD_115200
--! * ::uart::send_bits
--! * ::uart::rcv_bits
--! * ::uart::send_string
--! * ::uart::rcv_string
--!
--! @see @ref testing_md "Testing" for an introduction to testing.

--! UART testing utilities.
package uart is

    --! Bit period for 115200 bps serial connection.
    constant BIT_PERIOD_115200: time := 8.6 us;

    --! @brief Send bits.
    --! @param bit_period Time between bits.
    --! @param message Bits to send.
    --! @param tx UART TX signal.
    procedure send_bits(
            bit_period: in time;
            message: in std_logic_vector;
            signal tx: out std_logic);

    --! @brief Receive bits.
    --! @param bit_period Time between bits.
    --! @param message Received bits.
    --! @param rx UART RX signal.
    procedure rcv_bits(
        bit_period: in time;
        message: out std_logic_vector;
        signal rx: in std_logic
    );

    --! @brief Send a string.
    --! @param bit_period Time between bits.
    --! @param message String to send.
    --! @param tx UART TX signal.
    procedure send_string(
            bit_period: in time; message: string; signal tx: out std_logic);

    --! @brief Receive a string.
    --! @param bit_period Time between bits.
    --! @param message Received string.
    --! @param rx UART RX signal.
    procedure rcv_string(
        bit_period: in time; message: out string; signal rx: in std_logic);

end package;

package body uart is

    procedure send_bits(
            bit_period: in time;
            message: in std_logic_vector;
            signal tx: out std_logic) is
        variable uart_all: std_logic_vector(message'high+2 downto message'low) := (others => 'X');
    begin
        -- stop bit, message and send bit.
        -- since send goes from the least significant bit, stop bit must be
        -- at zero index.
        tx <= '1';
        wait for bit_period;
        uart_all := '1' & message & '0';
        for i in uart_all'low to uart_all'high loop
            tx <= uart_all(i);
            wait for bit_period;
        end loop;
        tx <= '1';
    end procedure;

    procedure rcv_bits(
        bit_period: in time;
        message: out std_logic_vector;
        signal rx: in std_logic
    ) is
    begin
        -- Wait for start bit
        wait until rx = '0';
        -- Wait for half a bit period to sample in the middle of the bit
        wait for bit_period / 2;
        if rx /= '0' then
            -- Wait for falling edge.
            wait until rx = '0';
        end if;
        for i in message'low to message'high loop
            wait for bit_period;
            message(i) := rx;
        end loop;
        -- Wait for stop bit
        wait for bit_period;
        -- Assert that stop bit is '1'
        assert rx = '1' report "Did not receive stop bit" severity error;
    end procedure;

    procedure send_string(
            bit_period: in time; message: string; signal tx: out std_logic) is
        variable c: std_logic_vector(7 downto 0);
    begin
        for i in message'low to message'high loop
            c := std_logic_vector(to_unsigned(character'pos(message(i)), 8));
            send_bits(bit_period, c, tx);
            wait for 2 * bit_period;
        end loop;
    end procedure;

    procedure rcv_string(
        bit_period: in time; message: out string; signal rx: in std_logic) is
        variable c: std_logic_vector(7 downto 0);
        variable ret: string(message'range) := (others => ' ');
        variable cc: character;
        variable i: positive := 1;
    begin
        cc := 'x';
        while cc /= LF loop
            rcv_bits(bit_period, c, rx);
            cc := character'val(to_integer(unsigned(c)));
            ret(i) := cc;
            i := i + 1;
        end loop;
        message := ret;
    end procedure;

end package body;

