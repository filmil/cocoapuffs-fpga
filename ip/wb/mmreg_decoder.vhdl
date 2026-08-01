-- SPDX-License-Identifier: Apache-2.0
--! @file 011_mmreg_decoder.vhdl
--! @brief A decoder for a set of memory-mapped registers. A register file.
--!
--! The decoder implementation assumes that both the read and the write last
--! for exactly one cycle. So this is only useful for operations that can be
--! cleanly mapped onto registers, and have no delays.
--! See @ref mmreg_decoder for more details.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

--! @brief A decoder for a set of memory-mapped registers. A register file.
--!
--! @details The decoder implementation assumes that both the read and the write last
--! for exactly one cycle. So this is only useful for operations that can be
--! cleanly mapped onto registers, and have no delays.
entity mmreg_decoder is
    generic(
        --! The width, in bits of the base address of the register file.
        base_address_width: natural := 32;
        --! The width, in bits, of the data bus width.
        data_address_width: natural := 32;
        --! The number of bits in the address used for registers. If this
        --! value is `N`, there are `2^N` registers.
        reg_bit_count: natural := 1; -- 2 registers
        --! The base address of the register file. Required.
        base_address: std_ulogic_vector(31 downto 0)
    );
    port(
        --! Clock and reset signals.
        clk, reset: in std_ulogic;
        --! The register input.
        regi: in std_ulogic_vector(data_address_width-1 downto 0);
        --! Asserted high when a write cycle is in progress.
        write: out boolean;
        --! The register output.
        rego: out std_ulogic_vector(data_address_width-1 downto 0);
        --! The index of the register being accessed.
        indexo: out natural;
        --! The Wishbone input bus.
        wbi: in work.host.bus_type;
        --! The Wishbone output bus.
        wbo: out work.per.bus_type
    );
end entity;

architecture rtl of mmreg_decoder is
    type state_type is (idle, wait1);
    --! @brief The register state type.
    type reg_type is record
        --! The bus cycle state.
        state: state_type;
        --! The WB input data buffer.
        data: std_ulogic_vector(data_address_width-1 downto 0);
        --! The input register.
        index: natural;
        --! Set if the bus cycle is a write bus cycle.
        write: boolean;
        --! The wb output bus ack signal.
        ack: std_ulogic;
    end record;
    constant zero_reg_type: reg_type := (
        state => idle, data => (others => '-'), index => 0,
        write => false, ack => '0'
    );

    signal r, rin: reg_type;

    signal debug_state: state_type;
    signal debug_data, debug_index, debug_base_address:
        std_ulogic_vector(data_address_width-1 downto 0);
    signal debug_ack, debug_write: std_ulogic;
begin
    debug_state <= r.state;
    debug_data <= r.data;
    debug_index <= std_ulogic_vector(to_unsigned(r.index, 32));
    debug_write <= '1' when r.write else '0';
    debug_ack <= r.ack;

    seq: process(clk) is
    begin
        if rising_edge(clk) then r <= rin; end if;
    end process;

    comb: process(reset, regi, wbi, r) is
        variable v: reg_type;
        variable vbase, vreg, adr_mask: std_ulogic_vector(base_address_width-1 downto 0);

    begin
        vreg := (others => '0');
        adr_mask := (others => '1');
        adr_mask(reg_bit_count+1 downto 0) := (others => '0');
        debug_base_address <= base_address;
        v := r;
        vbase := wbi.adr and adr_mask;
        case v.state is
            when idle =>
                if vbase = base_address then
                    if wbi.cyc = '1' then
                        v.data := wbi.dat;
                        vreg := wbi.adr and (not adr_mask);
                        v.index := to_integer(unsigned(
                            vreg(reg_bit_count+1 downto 2)));
                        if wbi.we = '1' then -- write cycle
                            v.write := true;
                        end if;
                        v.ack := '1'; v.state := wait1;
                    end if;
                end if;
            when wait1 => -- wait to collect the values.
                v := zero_reg_type; v.state := idle;
        end case;

        if reset = '1' then
            v := zero_reg_type;
        end if;

        wbo <= ( rdt => regi, ack => r.ack);
        rego <= r.data; write <= r.write;
        indexo <= r.index;
        rin <= v;
    end process;

end architecture;
