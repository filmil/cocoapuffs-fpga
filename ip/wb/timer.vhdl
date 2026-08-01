-- SPDX-License-Identifier: Apache-2.0
--! @file 012_timer.vhdl
--! @brief A countdown timer that raises an interrupt when it counts down to zero.
--!
--! The timer has two 32-bit registers:
--!
--! * At address 0: the IRQ register, write a zero here to ack the interrupt.
--! * At address 4: the countdown value, write something nonzero here to
--!   adjust the alarm period.
--! See @ref timer for more details.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

--! @brief A countdown timer that raises an interrupt when it counts down to zero.
--!
--! @details The timer has two 32-bit registers:
--!
--! * At address 0: the IRQ register, write a zero here to ack the interrupt.
--! * At address 4: the countdown value, write something nonzero here to
--!   adjust the alarm period.
entity timer is
    generic(
        --! The base address of the timer in the address space.
        base_address: std_ulogic_vector(31 downto 0);
        --! The max number to count from.
        max_count: natural := 400_000_000
    );
    port(
        --! Clock and reset signals.
        clk, reset: in std_ulogic;
        --! The Wishbone input bus.
        wbi: in work.host.bus_type;
        --! The Wishbone output bus.
        wbo: out work.per.bus_type;
        --! The interrupt request signal. It is asserted for 1 clk cycle on
        --! timer expiry.
        irq: out std_ulogic
    );
end entity;

architecture rtl of timer is

    type reg_type is record
        irq: std_ulogic;
        count: unsigned(31 downto 0);
    end record;
    constant zero_reg_type: reg_type := (
        irq => '0',
        count => to_unsigned(max_count, 32)
    );

    signal write: boolean;
    signal regi, rego: std_ulogic_vector(31 downto 0);
    signal index: natural;

    signal r, rin: reg_type := zero_reg_type;

    signal debug_irq: std_ulogic;
    signal debug_count, debug_index: std_ulogic_vector(31 downto 0);

begin

    debug_irq <= r.irq;
    debug_count <= std_ulogic_vector(r.count);
    debug_index <= std_ulogic_vector(to_unsigned(index, 32));

    decoder0: entity work.mmreg_decoder
    generic map(
        base_address => base_address
    )
    port map(
        clk => clk
        , reset => reset
        , write => write
        , regi => regi
        , rego => rego
        , indexo => index
        , wbi => wbi
        , wbo => wbo
    );


    seq: process(clk) is
    begin
        if rising_edge(clk) then r <= rin; end if;
    end process;

    comb: process(r, index, reset, wbi, write, rego) is
        variable v: reg_type;
    begin
        v := r;
        v.irq := '0';
        regi <= (others => '0'); -- Initializing here avoids latch creation.

        -- Always count down, and raise the interrupt when you reach zero.
        v.count := r.count - 1;
        if r.count = 0 then
            v.irq := '1';
        end if;

        if write then
            case index is
                when 0 =>
                    v.irq := rego(0);
                when 1 =>
                    v.count := unsigned(rego);
            when others =>
                    --
            end case;
        end if;

        if reset = '1' then v := zero_reg_type; end if;

        -- Drive the WB output.
        case index is
            when 0 => --
                regi <= ( 0 => r.irq, others => '0');
            when 1 =>
                regi <= std_ulogic_vector(r.count);
            when others =>
        end case;


        irq <= r.irq;

        rin <= v;
    end process;

end architecture;
