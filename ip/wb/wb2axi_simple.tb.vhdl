-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
library testing;
library wb;
library axi;

entity tb is
end entity;

architecture test of tb is

    signal clk, reset, reset_n: std_ulogic;

    signal axi_host: axi.host.bus_type := axi.host.new_bus_type;
    signal axi_per: axi.per.bus_type := axi.per.new_bus_type(axi.types.WIDTHS);
    signal wb_host: wb.host.bus_type := wb.host.new_bus_type;
    signal wb_per: wb.per.bus_type := wb.per.new_bus_type;

    signal wb_host_cyc: std_ulogic;

begin
    -- Try to unpack signals from the records, so they could be inspected
    -- with vcd.
    wb_host_cyc <= wb_host.cyc;

    debug_axi_host: entity axi.debug_host port map(i => axi_host);
    debug_axi_per: entity axi.debug_per port map(i => axi_per);
    debug_wb_host: entity wb.debug_host port map(i => wb_host);
    debug_wb_per: entity wb.debug_per port map(i => wb_per);

    clkgen0: entity testing.clkgen
        generic map (
            --! Simulation will terminate automatically.
            sim_duration => 300 ns,
            clock_period => 5 ns -- 200MHz
        )
        port map (
            clk => clk,
            reset => reset,
            reset_n => reset_n
        );

    uut0: entity wb.wb2axi_simple
    port map(
        clk => clk,
        reset => reset,
        wb_host => wb_host,
        wb_per => wb_per,
        axi_host => axi_host,
        axi_per => axi_per
    );

    test0: process
    begin
        wait until reset = '1';
        wb_host <= (adr => (others => '0'), dat => (others => '0'),
            sel => "1111", we => '0', cyc => '0'
        );
        wait until reset = '0';
        wait until rising_edge(clk);
        wb_host <= (
            adr => x"FEFEBABA",
            dat => x"BABAFEFE",
            sel => "1111",
            we => '1', cyc => '1'
        );
        wait until rising_edge(clk);
        wb_host.we <= '0';
        wb_host.cyc <= '0';
        wait until rising_edge(clk);
        wait for 20 ns;
        wait until rising_edge(clk);
        axi_per.aw.ready <= '1';
        wait until rising_edge(clk);
        axi_per.aw.ready <= '0';
        wait for 20 ns;
        wait until rising_edge(clk);
        axi_per.w.ready <= '1';
        wait until rising_edge(clk);
        axi_per.w.ready <= '0';

        wait for 20 ns; wait until rising_edge(clk);
        axi_per.b.valid <= '1';
        wait until rising_edge(clk);
        axi_per.b.valid <= '0';

        wait for 30 ns; wait until rising_edge(clk);
        wb_host <= (
            adr => x"DADADEDE",
            dat => (others => 'X') ,
            sel => "1111",
            we => '0', cyc => '1'
        );
        wait until rising_edge(clk);
        wb_host.cyc <= '0';
        axi_per.ar.ready <= '1';
        wait until rising_edge(clk);
        axi_per.ar.ready <= '0';
        wait for 20 ns; wait until rising_edge(clk);
        axi_per.r <= (
            valid => '1',
            data => x"BBBBBBBB",
            resp => (others => '1'),
            id => (0 => '1', others => '0'),
            last => '1'
        );
        wait until axi_host.r.ready = '1';
        wait until rising_edge(clk);
        axi_per.r.valid <= '0';
        axi_per.r.last <= '0';
        wait for 20 ns; wait until rising_edge(clk);
        axi_per.r.valid <= '1';
        wait until rising_edge(clk);
        axi_per.r.valid <= '0';
        wait until rising_edge(clk);

    end process;


end architecture;
