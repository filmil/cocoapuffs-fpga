-- SPDX-License-Identifier: Apache-2.0
--! @file
--! @brief A GRLIB AHB-slave Block RAM with hex-file initialization.
--!
--! This connects directly to a GRLIB AHB bus (no Wishbone bridge in between).
--! It is a zero-wait-state slave: HREADY is held high and read data is returned
--! in the data phase, so fully pipelined sequential (burst) accesses run at one
--! beat per clock. Intended as a fast boot ROM/RAM for NOEL-V whose i-cache
--! issues incrementing instruction-fetch bursts.
--!
--! Bus-width aware: the backing store is 32-bit words, but reads/writes are mapped
--! onto the full AHBDW-wide data bus by lane, so it works on 32-, 64- or 128-bit
--! AHB. A read returns the AHBDW/32 consecutive words at the beat-aligned address
--! (one per 32-bit lane); a write takes the addressed bytes from the correct lane.
--! At AHBDW=32 this reduces exactly to the original single-word behaviour.
--!
--! Memory file format matches ip/wb/bram.vhdl: one 32-bit word per line as four
--! little-endian hex bytes (first byte = bits 7..0).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
library std;
use std.textio.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;

entity ahb_bram is
    generic (
        hindex        : integer := 0;
        haddr         : integer := 16#C00#;     -- AHB bank address (bits 31:20)
        hmask         : integer := 16#FFF#;     -- AHB bank mask
        memfile       : string  := "";
        memsize       : natural := 4096;        -- bytes
        reg_bit_count : natural := 12;          -- byte-address width (2^12 = 4 KiB)
        cacheable     : std_ulogic := '1';      -- AHB PnP cacheable bit for the bank
        prefetch      : std_ulogic := '1'       -- AHB PnP prefetchable bit for the bank
    );
    port (
        clk   : in  std_ulogic;
        rstn  : in  std_ulogic;
        ahbsi : in  ahb_slv_in_type;
        ahbso : out ahb_slv_out_type
    );
end entity;

architecture rtl of ahb_bram is

    -- Bus geometry, derived from the global AHB data width (grlib.amba.AHBDW).
    constant WORDS : natural := AHBDW / 32;     -- 32-bit words per AHB beat
    constant BYTES : natural := AHBDW / 8;      -- bytes per AHB beat

    -- ceil(log2) without pulling in grlib.stdlib (avoids the stdio hread/hwrite
    -- homograph that forces VHDL-93 on the synth library).
    function clog2(n : natural) return natural is
        variable r : natural := 0;
        variable v : natural := n;
    begin
        while v > 1 loop
            v := v / 2;
            r := r + 1;
        end loop;
        return r;
    end function;
    constant OFFW : natural := clog2(BYTES);    -- in-beat byte-offset address bits

    constant mem_words : natural := memsize / 4;
    type mem_t is array (0 to mem_words - 1) of std_logic_vector(31 downto 0);

    impure function load_mem(file_name : in string) return mem_t is
        file f          : text;
        variable l      : line;
        variable tmp    : mem_t := (others => (others => '0'));
        variable status : file_open_status;
        variable i      : integer := 0;
        variable b      : std_logic_vector(7 downto 0);
    begin
        if file_name = "" then
            return tmp;
        end if;
        file_open(status, f, file_name, read_mode);
        if status /= open_ok then
            report "ahb_bram: could not open memfile: " & file_name severity warning;
            return tmp;
        end if;
        while not endfile(f) and i < mem_words loop
            readline(f, l);
            for j in 0 to 3 loop
                hread(l, b);
                tmp(i)(8 * (j + 1) - 1 downto 8 * j) := b;
            end loop;
            i := i + 1;
        end loop;
        file_close(f);
        return tmp;
    end function;

    signal mem : mem_t := load_mem(memfile);

    -- GRLIB plug&play: device record + cacheable/prefetchable memory bank.
    -- Identify as a Gaisler AHBRAM and, crucially, encode the bank's access size
    -- in the version field exactly as grlib's own ahbram does
    -- (abits+2+log2(maccsz/32); maccsz=32 here, so version = reg_bit_count).  The
    -- NOEL-V cache controller reads this to size accesses; a 0 version (our old
    -- value) leaves the store path without the bank's access width.
    constant hconfig : ahb_config_type := (
        0 => ahb_device_reg(VENDOR_GAISLER, GAISLER_AHBRAM, 0, reg_bit_count, 0),
        4 => ahb_membar(haddr, prefetch, cacheable, hmask),
        others => (others => '0'));

    -- Address-phase capture, used in the following data phase.
    signal sel_q     : std_ulogic := '0';
    signal write_q   : std_ulogic := '0';
    signal index_q   : natural    := 0;                       -- captured 32-bit word index
    signal hsize_q   : std_logic_vector(2 downto 0) := (others => '0');
    signal offset_q  : std_logic_vector(OFFW - 1 downto 0) := (others => '0'); -- in-beat byte offset

    signal hrdata_w  : std_logic_vector(AHBDW - 1 downto 0);

    -- Unpacked signals for simulation visibility (VCD).
    signal dbg_haddr  : std_logic_vector(31 downto 0);
    signal dbg_htrans : std_logic_vector(1 downto 0);
    signal dbg_hwrite : std_ulogic;
    signal dbg_hsel   : std_ulogic;
    signal dbg_hrdata : std_logic_vector(31 downto 0);

begin

    -- Zero-wait-state slave outputs.
    ahbso.hready  <= '1';
    ahbso.hresp   <= HRESP_OKAY;
    ahbso.hrdata  <= hrdata_w;
    ahbso.hsplit  <= (others => '0');
    ahbso.hirq    <= (others => '0');
    ahbso.hconfig <= hconfig;
    ahbso.hindex  <= hindex;

    dbg_haddr  <= ahbsi.haddr;
    dbg_htrans <= ahbsi.htrans;
    dbg_hwrite <= ahbsi.hwrite;
    dbg_hsel   <= ahbsi.hsel(hindex);
    dbg_hrdata <= mem(index_q);

    -- Wide read: each 32-bit lane gets the corresponding word of the beat-aligned
    -- group, so a narrow access finds its word in its lane and a wide (line) beat
    -- gets WORDS distinct consecutive words.
    read_comb : process(mem, index_q)
        variable base : natural;
    begin
        base := (index_q / WORDS) * WORDS;
        for k in 0 to WORDS - 1 loop
            hrdata_w((k + 1) * 32 - 1 downto k * 32) <= mem((base + k) mod mem_words);
        end loop;
    end process;

    process(clk)
        variable size    : natural;
        variable byteoff : natural;
        variable base    : natural;
        variable wordk   : natural;
        variable bytep   : natural;
    begin
        if rising_edge(clk) then
            if rstn = '0' then
                sel_q   <= '0';
                write_q <= '0';
                index_q <= 0;
            else
                -- Data phase of the access captured last cycle.  The written bytes
                -- span [byteoff, byteoff+size) within the beat; map each onto the
                -- right 32-bit word lane.
                if sel_q = '1' and write_q = '1' then
                    size    := 2 ** to_integer(unsigned(hsize_q));
                    byteoff := to_integer(unsigned(offset_q));
                    base    := (index_q / WORDS) * WORDS;
                    for b in 0 to BYTES - 1 loop
                        if b >= byteoff and b < byteoff + size then
                            wordk := (base + (b / 4)) mod mem_words;
                            bytep := b mod 4;
                            mem(wordk)(8 * (bytep + 1) - 1 downto 8 * bytep) <=
                                ahbsi.hwdata(8 * (b + 1) - 1 downto 8 * b);
                        end if;
                    end loop;
                end if;

                -- Address phase: accept a new transfer (NONSEQ or SEQ).
                if ahbsi.hsel(hindex) = '1' and ahbsi.hready = '1'
                   and ahbsi.htrans(1) = '1' then
                    index_q  <= to_integer(unsigned(ahbsi.haddr(reg_bit_count - 1 downto 2)))
                                mod mem_words;
                    write_q  <= ahbsi.hwrite;
                    hsize_q  <= ahbsi.hsize;
                    offset_q <= ahbsi.haddr(OFFW - 1 downto 0);
                    sel_q    <= '1';
                else
                    sel_q   <= '0';
                    write_q <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture;
