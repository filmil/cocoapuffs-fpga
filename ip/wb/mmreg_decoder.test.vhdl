-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library wb;
library testing;

entity mmreg_decoder_test is
    generic(
        clock_period: time := 5 ns
        ; sim_duration: time := 200 ns
        ; base_address: std_ulogic_vector(31 downto 0) := x"FF00_0000"
    );
end entity;

architecture sim of mmreg_decoder_test is
    signal clk, reset: std_ulogic;
    signal wbi: wb.host.bus_type;
    signal wbo: wb.per.bus_type;
    signal write: boolean;
    signal regi, rego:  std_ulogic_vector(31 downto 0);
    signal indexo: natural;
begin
    clkgen0: entity testing.clkgen
    generic map(
        clock_period => clock_period
        , sim_duration => sim_duration
    )
    port map(
        clk => clk
        , reset => reset
        , reset_n => open
    );

    mmreg_decoder0: entity wb.mmreg_decoder
    generic map (
        base_address => base_address
        , reg_bit_count => 1
    )
    port map(
        clk => clk, reset => reset
        , regi => regi, rego => rego
        , write => write
        , indexo => indexo
        , wbi => wbi
        , wbo => wbo
    );

    regi <= x"ABABABAB" when indexo = 0
            else x"FEFEFEFE";

    test0: process
    begin
        wait until reset = '0';
        wait until rising_edge(clk);
        wbi <= (
            adr => base_address or x"0000_0004"
            , dat => x"f005ba11"
            , cyc => '1'
            , we => '1'
            , sel => (others => '1')
        );
        wait until rising_edge(clk);
        wbi <= wb.host.new_bus_type;
        wait for 10ns;
        wait until rising_edge(clk);

        wbi <= (
            adr => base_address or x"0000_0000"
            , dat => (others => '-')
            , cyc => '1'
            , we => '0'
            , sel => (others => '1')
        );
        wait until rising_edge(clk);
        wbi <= wb.host.new_bus_type;
        wait for 10ns;
        wait until rising_edge(clk);

        wbi <= (
            adr => base_address or x"0000_0004"
            , dat => (others => '-')
            , cyc => '1'
            , we => '0'
            , sel => (others => '1')
        );
        wait until rising_edge(clk);
        wbi <= wb.host.new_bus_type;
        wait for 10ns;
        wait until rising_edge(clk);
        std.env.stop;
    end process;
end architecture;
