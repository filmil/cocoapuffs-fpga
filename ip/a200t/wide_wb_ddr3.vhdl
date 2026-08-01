-- SPDX-License-Identifier: Apache-2.0

--! @file wide_wb_ddr3.vhdl
--! @brief An adapter between a regular 32-bit Wishbone bus, and a 256-bit wide
--! Wishbone bus used by the DDR3 controller.
--!
--! See @ref wide_wb_ddr3 for more details.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library wb;
library work;

--! @brief An adapter between a regular 32-bit Wishbone bus, and a 256-bit wide
--! Wishbone bus used by the DDR3 controller.
entity wide_wb_ddr3 is
    port(
        --! The clock and reset signals.
        clk, reset: in std_ulogic

        --! The host side Wishbone interface.
        ; hostside_wb_host: in wb.host.bus_type
        ; hostside_wb_per: out wb.per.bus_type

        --! The peripheral side Wishbone interface.
        ; perside_wb_host: out work.ddr3.wb_host_type
        ; perside_wb_per: in work.ddr3.wb_per_type
    );
end entity;

architecture rtl of wide_wb_ddr3 is

    signal s_hs_wb_per: wb.per.bus_type;
    signal s_ps_wb_host: work.ddr3.wb_host_type;

    type state_type is (idle, read1, wait1, write1);

    type reg_type is record
        state: state_type;
        host_buf: work.ddr3.wb_host_type;
        per_buf: wb.per.bus_type;
        index: natural;
    end record;

    constant zero_state: reg_type := (
        state => idle,
        host_buf => work.ddr3.new_wb_host_type,
        per_buf => wb.per.new_bus_type,
        index => 0
    );
    signal r, rin: reg_type := zero_state;

begin

    -- Assign signals to output ports. Vivado does not allow using ports as
    -- signals.
    hostside_wb_per <= s_hs_wb_per;
    perside_wb_host <= s_ps_wb_host;

    comb: process(r, reset, hostside_wb_host, perside_wb_per) is
        variable v: reg_type;
        variable index: natural;
    begin
        v := r;
        index := 0;

        case v.state is
            when idle =>
                -- Load host buffer if a cycle is incoming.
                if hostside_wb_host.cyc = '1' then
                    v.host_buf := (
                        cyc => hostside_wb_host.cyc
                        , stb => hostside_wb_host.cyc -- same as `cyc` in our simple bus.
                        , we => hostside_wb_host.we
                        , adr => (others => '0')
                        , data => (others => '0')
                        , sel => (others => '0')
                        , aux => (others => '0')
                    );
                    -- Which of the 64 32-bit words should be modified?
                    index := to_integer(unsigned(hostside_wb_host.adr(4 downto 2)));
                    v.index := index;
                    -- The UberDDR3 wishbone address is burst-addressable: one
                    -- unit per 32-byte burst, 25 bits spanning the full 1 GB.
                    -- The burst index for byte address A is A(29 downto 5); the
                    -- in-burst 32-bit word is selected via index/sel above.
                    -- (The historical `adr(26 downto 5) & "000"` dropped byte-
                    -- address bits 29:27 -- the 1 GB window aliased every
                    -- 128 MB on hardware, JTAG-proven 2026-07-08.)
                    v.host_buf.adr := hostside_wb_host.adr(29 downto 5);
                    v.host_buf.data(32*index+31 downto 32*index) := hostside_wb_host.dat;
                    v.host_buf.sel(4*index+3 downto 4*index) := hostside_wb_host.sel;

                    if hostside_wb_host.we = '1' then -- write cycle
                        v.state := write1;
                    else
                        v.state := read1; -- read cycle is next
                        v.host_buf.data := (others => '-');
                    end if;
                end if;

            when write1 =>
                if perside_wb_per.stall = '0' then -- per is ready to go.
                  if perside_wb_per.ack = '1' then -- per acknowledged.
                    v.per_buf.rdt := (others => '-');
                    v.per_buf.ack := '1'; -- propagate the ack to host.
                    v.state := wait1;
                  end if;
                end if;
                -- Otherwise stay here until the peripheral acks.

            when read1 =>
                if perside_wb_per.stall = '0' then -- per is ready to go.
                    if perside_wb_per.ack = '1' then -- per acknowledged.
                                                     -- v.index is the correct index.
                        v.per_buf.rdt := perside_wb_per.data(32*v.index+31 downto 32*v.index);
                        v.per_buf.ack := '1';
                        -- read per's writing.
                        v.state := wait1;
                    end if;
                end if;
                -- otherwise stay here until per acks.

            when wait1 =>
                v := zero_state; -- clear and return to idle.
        end case;

        --  update.
        if reset = '1' then
            v := zero_state;
        end if;

        -- Output update
        s_ps_wb_host <= r.host_buf;
        s_hs_wb_per <= r.per_buf;
        rin <= v;
    end process;

    seq: process(clk, reset) is
    begin
        if rising_edge(clk) then
                r <= rin;
        end if;
    end process;

end architecture;
