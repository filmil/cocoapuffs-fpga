-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;

--! @brief A peripheral bit input controller.
--!
--! @details A peripheral that allows reading a large number of input bits
--! through memory-mapped registers. The bits are mapped into 32-bit
--! registers starting from the base address.
entity perinput is
    generic(
        --! The base address of the peripheral in the address space.
        base_address: std_ulogic_vector(work.types.WIDTHS_32B.dat-1 downto 0);
        --! The number of input bits to be made available for reading.
        num_bits: positive := 32
    );
    port(
        --! Clock and reset signals.
        clk, reset: in std_ulogic;
        --! The Wishbone input bus.
        wbi: in work.host.bus_type;
        --! The Wishbone output bus.
        wbo: out work.per.bus_type;
        --! The peripheral bits to be read.
        perin: in std_ulogic_vector(num_bits-1 downto 0)
    );
end entity;

architecture rtl of perinput is
    --! Calculate the number of 32-bit registers needed.
    constant num_regs: natural := (num_bits + 31) / 32;

    --! Calculate the number of bits needed to address the registers.
    function calc_reg_bit_count(n: natural) return natural is
    begin
        if n <= 1 then return 1;
        elsif n <= 2 then return 1;
        elsif n <= 4 then return 2;
        elsif n <= 8 then return 3;
        elsif n <= 16 then return 4;
        elsif n <= 32 then return 5;
        else return 6; -- Support up to 64 registers (2048 bits)
        end if;
    end function;

    constant reg_bit_count: natural := calc_reg_bit_count(num_regs);

    signal regi: std_ulogic_vector(31 downto 0);
    signal index: natural;
begin

    --! @brief Decodes Wishbone transactions and provides register indexing.
    decoder0: entity work.mmreg_decoder
    generic map(
        base_address => base_address,
        reg_bit_count => reg_bit_count
    )
    port map(
        clk => clk,
        reset => reset,
        regi => regi,
        rego => open,
        indexo => index,
        wbi => wbi,
        wbo => wbo,
        write => open
    );

    --! Multiplex the input bits into the read register based on the decoded index.
    read_mux: process(perin, index) is
        variable start_bit: natural;
        variable end_bit: natural;
    begin
        regi <= (others => '0');
        if index < num_regs then
            start_bit := index * 32;
            end_bit := (index + 1) * 32 - 1;
            if end_bit >= num_bits then
                regi(num_bits - start_bit - 1 downto 0) <= perin(num_bits-1 downto start_bit);
            else
                regi <= perin(end_bit downto start_bit);
            end if;
        end if;
    end process;

end architecture;
