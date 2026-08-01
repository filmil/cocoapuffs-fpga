-- SPDX-License-Identifier: Apache-2.0
-- See LICENSE file.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library wb;

package wb_tb is

    procedure send_tx(
        signal clk: in std_logic;
        tx: in wb.signals.o_wb;
        signal input: out wb.signals.o_wb);

    procedure send_string(
        address: in std_logic_vector(31 downto 0);
        signal clk: in std_logic;
        message: string;
        signal i_wb: inout wb.signals.i_wb;
        signal o_wb: inout wb.signals.o_wb);

    procedure receive_string_until(
        line: inout string;
        address: in std_logic_vector(31 downto 0);
        timeout: time;
        signal clk: std_logic;
        signal i_wb: in wb.signals.i_wb;
        signal o_wb: out wb.signals.o_wb);
end package;

package body wb_tb is

    procedure send_tx(
        signal clk: in std_logic;
        tx: in wb.signals.o_wb;
        signal input: out wb.signals.o_wb) is
    begin
        input <= tx;
        wait until rising_edge(clk);
    end procedure;

    procedure send_string(
            address: in std_logic_vector(31 downto 0);
            signal clk: in std_logic; message: string;
            signal i_wb: inout wb.signals.i_wb;
            signal o_wb: inout wb.signals.o_wb) is
        variable c: std_logic_vector(7 downto 0);
        variable tx: wb.signals.o_wb := wb.signals.o_wb_new;
        constant fill: std_logic_vector(47 downto 0) := (others => 'X');
    begin
        wait until rising_edge(clk);
        for i in message'low to message'high loop
            c := std_logic_vector(to_unsigned(character'pos(message(i)), 8));
            tx := (
                adr => address,
                dat => fill & c,
                sel => "0001",
                we => '1',
                cyc => '1'
             );
             send_tx(clk, tx, o_wb);
             tx.cyc := '0'; tx.sel := (others => '0'); tx.we := '0';
             send_tx(clk, tx, o_wb);
        end loop;
    end procedure;

    procedure receive_string_until(
        line: inout string;
        address: in std_logic_vector(31 downto 0);
        timeout: time;
        signal clk: std_logic;
        signal i_wb: in wb.signals.i_wb;
        signal o_wb: out wb.signals.o_wb
    ) is
        variable tx: wb.signals.o_wb := wb.signals.o_wb_new;
        variable current_char: character := nul;
        variable start: time := now;
        variable t: time := start;
        variable empty: std_logic := '0';
        variable i: positive := 1;
    begin
        t := now;
        wait until rising_edge(clk);
        while now < start + timeout  loop
            tx := (
                adr => address,
                dat => (others => 'X'),
                sel => "0011",
                we => '0',
                cyc => '1'
             );
             send_tx(clk, tx, o_wb);

            empty := i_wb.rdt(8);
            if empty = '0' then
                current_char := character'val(
                    to_integer(unsigned(i_wb.rdt(7 downto 0))));
                line(i) := current_char;
                i := i + 1;
            end if;

            tx.cyc := '0'; tx.sel := (others => '0'); tx.we := '0';
            send_tx(clk, tx, o_wb);
        end loop;
    end procedure;
end package body;

