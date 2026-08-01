-- SPDX-License-Identifier: Apache-2.0
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

library tl;
use tl.types.all;

--! @brief TileLink peripheral simulation memory model.
--! @details This entity implements a simple memory with TileLink interface
--!          for testing purposes.
entity tllite_mem is
    generic(
        --! Base address of the memory.
        base_address: std_ulogic_vector(31 downto 0) := (others => '0');
        --! Memory size as power of 2 (2^mem_size_log2 words).
        mem_size_log2: natural := 1;
        --! The VUnit logger.
        logger: logger_t := get_logger("unnamed.tllite_mem")
    );
    port(
        --! Global clock.
        clk: in std_ulogic;
        --! Synchronous reset, active high.
        reset: in std_ulogic;
        --! TileLink peripheral side input.
        host: in host_type;
        --! TileLink peripheral side output.
        per: out per_type
    );
end entity;

architecture sim of tllite_mem is

    type mem_t is array(0 to 2**mem_size_log2-1) of std_ulogic_vector(31 downto 0);
    constant mem_zero: mem_t := (others => (others => '0'));
    signal mem: mem_t := mem_zero;

    signal d_valid: std_ulogic := '0';
    signal a_ready: std_ulogic := '1';

    --! Masks the bytes of `val` based on bits of `sel`. Each bit of `sel` is
    --! a lane selector.
    function masked_value(val: std_ulogic_vector; sel: std_ulogic_vector)
        return std_ulogic_vector is
        variable mask: std_ulogic_vector(val'range) := (others => '0');
    begin
        for i in sel'low to sel'high loop
            mask((i + 1) * 8 - 1 downto i * 8) := (others => sel(i));
        end loop;
        return val and mask;
    end function;

begin
    per.a_ready <= a_ready;
    per.d.valid <= d_valid;

    seq: process(clk) is
        variable relative_addr: std_ulogic_vector(31 downto 0);
        variable idx: natural;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                mem <= mem_zero;
                d_valid <= '0';
                a_ready <= '1';
                log(logger, "reset");
            else
                if d_valid = '1' and host.d_ready = '1' then
                    d_valid <= '0';
                    a_ready <= '1';
                end if;

                if a_ready = '1' and host.a.valid = '1' then
                    a_ready <= '0';
                    d_valid <= '1';
                    
                    relative_addr := std_ulogic_vector(unsigned(host.a.address) - unsigned(base_address));
                    idx := to_integer(unsigned(relative_addr(mem_size_log2 + 1 downto 2)));
                    
                    if host.a.opcode = OP_GET then
                        per.d.opcode <= OP_ACCESS_ACK_DATA;
                        per.d.data <= mem(idx);
                        log(logger, "read mem[" & to_string(idx * 4) & "]");
                    else
                        per.d.opcode <= OP_ACCESS_ACK;
                        per.d.data <= (others => '0');
                        mem(idx) <= (mem(idx) and not masked_value(x"FFFFFFFF", host.a.mask)) or masked_value(host.a.data, host.a.mask);
                        log(logger, "write mem["
                            & to_string(idx * 4) & "] <= 0x" & to_hstring(host.a.data) 
                            & " mask=" & to_string(host.a.mask));
                    end if;
                    
                    per.d.size <= host.a.size;
                    per.d.source <= host.a.source;
                    per.d.sink <= (others => '0');
                    per.d.corrupt <= '0';
                end if;
            end if;
        end if;
    end process;
end architecture;
