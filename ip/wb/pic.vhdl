-- SPDX-License-Identifier: Apache-2.0
--! @file 013_pic.vhdl
--! @brief Programmable interrupt controller
--!
--! Allows raising an interrupt. Two registers:
--! * Address 0: Interrupt mask. `1` for allowed interrupts.
--! * Address 4: Interrupt bitmap. `1` set for each triggered interrupt
--! See @ref pic for more details.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

--! @brief Programmable interrupt controller
--!
--! @details Allows raising an interrupt. Two registers:
--! * Address 0: Interrupt mask. `1` for allowed interrupts.
--! * Address 4: Interrupt bitmap. `1` set for each triggered interrupt
entity pic is
    generic(
        --! The base address of the PIC in the address space.
        base_address: std_ulogic_vector(31 downto 0)
    );
    port(
        --! Clock and reset signals.
        clk, reset: in std_ulogic;
        --! The Wishbone input bus.
        wbi: in work.host.bus_type;
        --! The Wishbone output bus.
        wbo: out work.per.bus_type;
        --! The resulting interrupt line.
        irqo: out std_ulogic;
        --! The input interrupt lines. Interrupt lines are asserted for 1 clk
        --! cycle.
        irqi: in std_ulogic_vector
    );
end entity;

architecture rtl of pic is
    subtype irqs_type is std_ulogic_vector(irqi'range);
    type reg_type is record
        --! Interrupt mask, if bit is == 1, that intrrrupt is enabled.
        mask: irqs_type;
        --! The bitmap of currently triggered interrupts.
        irqs: irqs_type;
    end record;
    -- Expose the reg_type for debugging in xsim, since it does not export
    -- structs to VCD.
    signal debug_r_mask: irqs_type;
    signal debug_r_irqs: irqs_type;

    constant zero_reg_type: reg_type := (
        mask => (others => '0'),
        irqs => (others => '0')
    );
    constant reg_mask: natural := 0;
    constant reg_irqs: natural := 1;
    signal r, rin: reg_type;

    signal write: boolean;
    signal regi, rego: std_ulogic_vector(31 downto 0);
    signal index: natural;
begin

    debug_r_mask <= r.mask;
    debug_r_irqs <= r.irqs;

    decoder0: entity work.mmreg_decoder
    generic map(
        base_address => base_address
    )
    port map(
        clk => clk
        , reset => reset
        , regi => regi
        , write => write
        , rego => rego
        , indexo => index
        , wbi => wbi
        , wbo => wbo
    );

    seq: process(clk) is
    begin
        if rising_edge(clk) then r <= rin; end if;
    end process;

    comb: process(r, index, reset, irqi, index, rego, write) is
        variable v: reg_type;
        variable vregi: std_ulogic_vector(31 downto 0);
        variable virqo: std_ulogic;
    begin
        v := r;

        -- Determine whether there is an irq.
        for i in irqi'range loop
            if r.mask(i) = '1' and irqi(i) = '1' then
                v.irqs(i) := '1';
            end if;
        end loop;

        -- Write to peripheral registers.
        if write then
            case index is
                when reg_mask =>
                    v.mask := rego(v.mask'range);
                when reg_irqs =>
                    v.irqs := rego(v.irqs'range);
                when others =>
                    --
            end case;
        end if;

        -- check what happens to all the interrupts.
        if reset = '1' then v := zero_reg_type; end if;

        vregi := (others => '0');
        case index is
            when reg_mask =>
                vregi(r.mask'range) := r.mask;
            when reg_irqs =>
                vregi(r.irqs'range) := r.irqs;
            when others =>
                --
        end case;

        virqo := '0';
        for i in r.irqs'range loop
            virqo := virqo or r.irqs(i);
        end loop;
        irqo <= virqo;

        rin <= v;
        regi <= vregi;
    end process;

end architecture;

