-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
library axi;
library work;
library wb;

--! A simple converter from a Wishbone host to an AXI peripheral.
--!
--! Supports only minimal single-cycle transfers.
entity wb2axi_simple is
    port (
        clk, reset: in std_ulogic

        ; wb_host: in wb.host.bus_type
        ; wb_per: out wb.per.bus_type

        ; axi_host: out axi.host.bus_type
        ; axi_per: in axi.per.bus_type

    );
end entity;

architecture rtl of wb2axi_simple is

    signal swb_per: work.per.bus_type := work.per.new_bus_type;
    signal saxi_host: axi.host.bus_type := axi.host.new_bus_type;

    type state_type is record
        wb_per: work.per.bus_type;
        axi_host: axi.host.bus_type;
        aw_sent, w_sent, b_sent: boolean;
        ar_sent, r_sent: boolean;
    end record;

    function new_state_type return state_type is
        variable ret: state_type;
        variable vwb_per: work.per.bus_type := work.per.new_bus_type;
        variable vaxi_host: axi.host.bus_type  := axi.host.new_bus_type;
    begin
        ret := (
            wb_per => vwb_per,
            axi_host => vaxi_host,
            aw_sent => false,
            w_sent => false,
            b_sent => false,
            ar_sent => false,
            r_sent => false
        );
        ret.wb_per.ack := '0';
        return ret;
    end function;

    signal q: state_type := new_state_type;
    signal d: state_type := new_state_type;

begin

    wb_per <= swb_per;
    axi_host <= saxi_host;

    --! This is stupid, but the only way to expose the signals in VCD dumps.
    debug0: entity axi.debug_host
    port map( i => saxi_host);
    debug1: entity axi.debug_per
    port map ( i => axi_per);
    debug2: entity work.debug_per
    port map (i => swb_per);
    debug3: entity work.debug_host
    port map (i => wb_host);

    comb: process(q, wb_host, axi_per)
        variable v: state_type;
        variable aw_ok, ar_ok: boolean;
        variable aw_consumed, w_consumed, b_consumed: boolean;
        variable ar_consumed, r_consumed: boolean;
        variable r_ok: boolean;
    begin
        v := q; -- By default, no change to the state.
        v.axi_host.w.valid := '1';

        -- WB write cycle.
        -- First load AXI AW and W values.
        aw_consumed := q.axi_host.aw.valid = '1' and axi_per.aw.ready = '1';
        aw_ok := (q.axi_host.aw.valid = '0') or aw_consumed;
        if wb_host.cyc = '1' and aw_ok and wb_host.we = '1' then
            -- Load everything from the wishbone bus.
            v.axi_host.aw := (
                valid => '1',
                addr => wb_host.adr,
                len => (others => '0'),
                id => (0 => '1', others => '0'),
                burst => (others => '0')
            );
            v.axi_host.w := (
                data => wb_host.dat,
                strb => wb_host.sel,
                last => '1', -- In this controller, each write is always the last one.
                valid => '1'
            );
        end if;
        if aw_consumed then -- we can continue sending W.
            v.aw_sent := true;
            v.axi_host.aw.valid := '0';
        end if;

        -- AXI W send.
        v.axi_host.w.valid := '0';
        w_consumed := q.axi_host.w.valid = '1' and axi_per.w.ready = '1';
        if q.aw_sent and not q.w_sent then
            v.axi_host.aw.valid := '0';
            v.axi_host.w.valid := '1';
        end if;
        if w_consumed then
            v.w_sent := true;
            v.axi_host.w.valid := '0';
        end if;

        -- Handle B bus transaction. Mark ready and wait.
        if q.aw_sent and q.w_sent and not q.b_sent then
            v.axi_host.b.ready := '1';
        end if;
        b_consumed := q.axi_host.b.ready = '1' and axi_per.b.valid = '1';
        if b_consumed then
            v.b_sent := true;
            v.axi_host.b.ready := '0';
        end if;

        -- Mark end of the Wishbone cycle - everything is back to normal.
        if q.aw_sent and q.w_sent and q.b_sent  then
            -- Ack this cycle, ready to begin next cycle.
            v.wb_per.ack := '1';
        end if;
        -- If we acked in the last cycle, reset ack, and reset all valid and state bits.
        if q.wb_per.ack = '1' then
            -- Reset signals to initial state.
            v.wb_per.ack := '0';
            v.axi_host.aw.valid := '0';
            v.axi_host.w.valid := '0';
            v.axi_host.b.ready := '0';
            v.aw_sent := false;
            v.w_sent := false;
            v.b_sent := false;
        end if;

        -- Wishbone read cycle.
        ar_consumed := q.axi_host.ar.valid = '1' and axi_per.ar.ready = '1';
        ar_ok := (q.axi_host.ar.valid = '0') or ar_consumed;
        if wb_host.cyc = '1' and ar_ok and wb_host.we = '0' then
            v.axi_host.ar := (
                valid => '1',
                addr => wb_host.adr,
                len => (others => '0'),
                id => (0 => '1', others => '0'),
                burst => (others => '1')
            );
        end if;
        if ar_consumed and not q.ar_sent then
            v.ar_sent := true;
            v.axi_host.ar.valid := '0';
            -- Now wait for r to be available.
        end if;
        if q.ar_sent then
            v.axi_host.r.ready := '1';
        end if;
        r_ok := q.axi_host.r.ready = '1' and axi_per.r.valid = '1';
        if r_ok then
            v.axi_host.r.ready := '0';
            v.r_sent := true;
            v.wb_per.rdt := axi_per.r.data;
            if q.ar_sent and v.r_sent then
                v.wb_per.ack := '1';
            end if;
        end if;

        -- Invalidate ACK for the read transaction.
        if q.wb_per.ack = '1' then
            v.wb_per.ack := '0';
            v.axi_host.ar.valid := '0';
            v.axi_host.r.ready := '0';
            v.ar_sent := false;
            v.r_sent := false;
        end if;

        d <= v;
        swb_per <= q.wb_per;
        saxi_host <= q.axi_host;
    end process;

    seq: process(clk, reset)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                q <= new_state_type;
            else
                q <= d;
            end if;
        end if;
    end process;

end architecture;
