-- SPDX-License-Identifier: Apache-2.0
-- Force Rebuild 1

--! @file
--! @brief A Wishbone-compatible BRAM controller.
--!
--! This module provides a simple Wishbone peripheral interface to an inferable
--! FPGA Block RAM. It supports byte-level write masking via the Wishbone `sel`
--! signals and can be initialized with contents from a hexadecimal file.
--!
--! ### Memory File Format
--!
--! The initialization file (`memfile`) should contain one 32-bit word per line.
--! Each word must be represented as four 2-digit hexadecimal values separated
--! by spaces, in little-endian order (the first byte on the line corresponds to
--! bits 7 downto 0 of the word).
--!
--! Example:
--! ```text
--! 33 40 00 00  -- Word 0: 0x00004033
--! 93 00 00 00  -- Word 1: 0x00000093
--! ```

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
library std;
use std.textio.all;
library wb;

--! @brief A Wishbone-compatible BRAM controller.
--!
--! The `bram` entity implements a memory-mapped Block RAM with a Wishbone
--! slave interface. It uses the `wb.mmreg_decoder` for address decoding and
--! supports initialization from an external file.
entity bram is
    generic (
        --! The base address of the BRAM in the memory-mapped space.
        base_address: std_ulogic_vector(31 downto 0);
        --! Path to a hexadecimal file used to initialize the BRAM contents.
        --! If empty, the BRAM is initialized to all zeros.
        memfile: string := "";
        --! The total size of the BRAM in bytes.
        memsize: natural := 262144; -- 256KB
        --! The number of address bits used for indexing (e.g., 18 for 256KB).
        reg_bit_count: natural := 18 -- 2^18 = 256KB
    );
    port (
        --! Standard system clock.
        clk: in std_ulogic;
        --! Synchronous reset.
        reset: in std_ulogic;
        --! Wishbone host interface (input to this peripheral).
        wbi: in wb.host.bus_type;
        --! Wishbone peripheral interface (output from this peripheral).
        wbo: out wb.per.bus_type
    );
end entity;

architecture rtl of bram is

    function f(v: std_ulogic) return std_ulogic is
    begin
        if v = '1' then return '1'; else return '0'; end if;
    end function;

    function f(v: std_ulogic_vector) return std_ulogic_vector is
        variable res : std_ulogic_vector(v'range);
    begin
        for i in v'range loop
            res(i) := f(v(i));
        end loop;
        return res;
    end function;

    function f(v: wb.host.bus_type) return wb.host.bus_type is
        variable res : wb.host.bus_type;
    begin
        res.adr := f(v.adr);
        res.dat := f(v.dat);
        res.sel := f(v.sel);
        res.we := f(v.we);
        res.cyc := f(v.cyc);
        return res;
    end function;

    signal wbi_f : wb.host.bus_type;
    signal reset_f : std_ulogic;

    constant mem_words: natural := memsize / 4;
    type mem_t is array(0 to mem_words-1) of std_ulogic_vector(31 downto 0);

    impure function load_mem(file_name : in string) return mem_t is
        file f : text;
        variable l : line;
        variable tmp_mem : mem_t := (others => (others => '0'));
        variable status: file_open_status;
        variable i : integer := 0;
        variable b : std_ulogic_vector(7 downto 0);
    begin
        if file_name = "" then
            return tmp_mem;
        end if;

        file_open(status, f, file_name, read_mode);
        if status /= open_ok then
            report "Could not open memfile: " & file_name severity warning;
            return tmp_mem;
        end if;

        while not endfile(f) and i < mem_words loop
            readline(f, l);
            -- Read 4 bytes per word, skipping whitespace if any
            for j in 0 to 3 loop
                hread(l, b);
                tmp_mem(i)(8*(j+1)-1 downto 8*j) := b;
            end loop;
            i := i + 1;
        end loop;

        file_close(f);
        return tmp_mem;
    end function;

    signal mem: mem_t := load_mem(memfile);

    signal write: boolean;
    signal regi, rego: std_ulogic_vector(31 downto 0);
    signal index: natural;

    -- Unpacked Wishbone signals for simulation debugging.
    signal dbg_wbi_adr : std_ulogic_vector(31 downto 0);
    signal dbg_wbi_dat : std_ulogic_vector(31 downto 0);
    signal dbg_wbi_sel : std_ulogic_vector(3 downto 0);
    signal dbg_wbi_we  : std_ulogic;
    signal dbg_wbi_cyc : std_ulogic;

    signal dbg_wbo_rdt : std_ulogic_vector(31 downto 0);
    signal dbg_wbo_ack : std_ulogic;

    signal wbo_s : wb.per.bus_type;

begin

    wbi_f <= f(wbi);
    reset_f <= f(reset);

    wbo <= wbo_s;

    dbg_wbi_adr <= wbi_f.adr;
    dbg_wbi_dat <= wbi_f.dat;
    dbg_wbi_sel <= wbi_f.sel;
    dbg_wbi_we  <= wbi_f.we;
    dbg_wbi_cyc <= wbi_f.cyc;

    dbg_wbo_rdt <= wbo_s.rdt;
    dbg_wbo_ack <= wbo_s.ack;

    decoder0: entity wb.mmreg_decoder
    generic map(
        base_address => base_address,
        reg_bit_count => reg_bit_count - 2 -- reg_bit_count is bytes, decoder wants word index bits
    )
    port map(
        clk => clk,
        reset => reset_f,
        regi => regi,
        rego => rego,
        indexo => index,
        wbi => wbi_f,
        wbo => wbo_s,
        write => write
    );

    regi <= mem(index mod mem_words);

    process(clk) is
    begin
        if rising_edge(clk) then
            if write then
                for i in 0 to 3 loop
                    if wbi_f.sel(i) = '1' then
                        mem(index mod mem_words)(8*(i+1)-1 downto 8*i) <= rego(8*(i+1)-1 downto 8*i);
                    end if;
                end loop;
            end if;
        end if;
    end process;
end architecture;
