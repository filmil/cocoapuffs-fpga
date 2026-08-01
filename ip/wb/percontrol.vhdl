-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

--! @brief A peripheral bit controller.
--!
--! A peripheral controller. Any value written into it is output to `perctl`.
entity percontrol is
    generic(
        --! The base address of the PIC in the address space.
        base_address: std_ulogic_vector(work.types.WIDTHS_32B.dat-1 downto 0);
        --! The initial value of the outputs when reset is active.
        initial_value: std_ulogic_vector(work.types.WIDTHS_32B.dat-1 downto 0) := (others => '0')
    );
    port(
        --! Clock and reset signals.
        clk, reset: in std_ulogic;
        --! The Wishbone input bus.
        wbi: in work.host.bus_type;
        --! The Wishbone output bus.
        wbo: out work.per.bus_type;
        --! The peripheral bits forwarded out of percontrol.
        perctl: out std_ulogic_vector(work.types.WIDTHS_32B.dat-1 downto 0)
    );
end entity;

architecture rtl of percontrol is
    subtype per_type is std_ulogic_vector(work.types.WIDTHS_32B.dat-1 downto 0);
    type reg_type is record
        perctl: per_type;
    end record;
    constant zero_reg_type: reg_type := (perctl => initial_value);
    signal r, rin: reg_type;

    signal write: boolean;
    signal regi, rego: std_ulogic_vector(31 downto 0);
    signal index: natural;
begin

    decoder0: entity work.mmreg_decoder
    generic map(
        base_address => base_address
    )
    port map(
        clk => clk
        , reset => reset
        , regi => regi
        , rego => rego
        , indexo => index
        , wbi => wbi
        , wbo => wbo
        , write => write
    );

    perctl <= r.perctl;
    regi <= r.perctl;

    seq: process(clk) is
    begin
        if rising_edge(clk) then r <= rin; end if;
    end process;

    comb: process(r, index, reset, wbi, rego, write) is
        variable v: reg_type;
    begin
        v := r;
        if write and index = 0 then
            v.perctl := rego;
        end if;
        if reset = '1' then v := zero_reg_type; end if;
        rin <= ( perctl => v.perctl);
    end process;

end architecture;

