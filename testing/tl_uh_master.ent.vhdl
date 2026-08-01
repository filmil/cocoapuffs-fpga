-- SPDX-License-Identifier: Apache-2.0
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

library tl;
use tl.types.all;
use work.tl_uh_pkg.all;

--! @file
--! @brief TileLink Uncached Heavyweight (TL-UH) master component.

--! @brief TileLink Uncached Heavyweight (TL-UH) host simulation model for VUnit.
entity tl_uh_master is
    generic(
        --! The VUnit bus handle.
        bus_handle: bus_master_t;
        --! The VUnit logger.
        logger: logger_t := get_logger("unnamed.tl_uh_master")
    );
    port(
        --! Global clock.
        clk: in std_ulogic;
        --! Synchronous reset, active high.
        rst: in std_ulogic;
        --! TileLink host port output.
        host_port: out host_type;
        --! TileLink host port input.
        per_port: in per_type
    );
end entity;

architecture sim of tl_uh_master is
    --! Calculates total number of 32-bit beats expected in a transaction based on the `size` code.
    --! @param size The size specifier from the TileLink request.
    --! @return Integer count of 32-bit beats for the request.
    function get_total_beats(size: std_ulogic_vector(2 downto 0)) return integer is
        variable s: integer := to_integer(unsigned(size));
    begin
        if s <= 2 then
            return 1;
        else
            return 2 ** (s - 2);
        end if;
    end function;
begin
    p0: process
        variable msg, reply_msg: msg_t;
        variable cmd: bus_master_uh_msg_t;
        variable a_done, d_done: boolean;
        variable total_beats: integer;
        variable beat_idx: integer;
        variable current_addr: unsigned(31 downto 0);
        variable d_beat_idx: integer;
    begin
        host_port <= host_type_new;

        wait until rst = '0';
        wait until clk = '1';

        loop
            receive(net, bus_handle.p_actor, msg);
            cmd := decode_bus_master_uh_msg(msg);
            total_beats := get_total_beats(cmd.size);

            wait until clk = '1';

            -- Single-beat or Get multi-beat (Get only sends 1 A-beat)
            if not cmd.is_write or cmd.is_atomic then
                host_port.a.opcode <= OP_GET;
                if cmd.is_atomic then
                    host_port.a.opcode <= cmd.opcode;
                    host_port.a.param <= cmd.param;
                else
                    host_port.a.param <= "000";
                end if;

                host_port.a.address <= cmd.adr;
                host_port.a.data <= cmd.dat0;
                host_port.a.mask <= cmd.sel;
                host_port.a.source <= (others => '0');
                host_port.a.size <= cmd.size;
                host_port.a.corrupt <= '0';
                host_port.a.valid <= '1';
                host_port.d_ready <= '1';

                a_done := false;
                d_beat_idx := 0;

                while d_beat_idx < total_beats loop
                    wait until clk = '1';
                    if not a_done and per_port.a_ready = '1' then
                        a_done := true;
                        host_port.a.valid <= '0';
                    end if;

                    if per_port.d.valid = '1' then
                        host_port.d_ready <= '0';
                        if d_beat_idx = 0 then cmd.dat0 := per_port.d.data; end if;
                        if d_beat_idx = 1 then cmd.dat1 := per_port.d.data; end if;
                        if d_beat_idx = 2 then cmd.dat2 := per_port.d.data; end if;
                        if d_beat_idx = 3 then cmd.dat3 := per_port.d.data; end if;
                        d_beat_idx := d_beat_idx + 1;
                        if d_beat_idx < total_beats then
                            host_port.d_ready <= '1'; -- ready for next
                        end if;
                    end if;
                end loop;

                -- Wait for A to complete if it hasn't (unlikely since D is done)
                while not a_done loop
                    wait until clk = '1';
                    if per_port.a_ready = '1' then
                        a_done := true;
                        host_port.a.valid <= '0';
                    end if;
                end loop;

            else
                -- Write burst (PutFullData / PutPartialData)
                beat_idx := 0;
                current_addr := unsigned(cmd.adr);

                if cmd.sel = "1111" then
                    host_port.a.opcode <= OP_PUT_FULL_DATA;
                else
                    host_port.a.opcode <= OP_PUT_PARTIAL_DATA;
                end if;

                host_port.a.source <= (others => '0');
                host_port.a.size <= cmd.size;
                host_port.a.param <= "000";
                host_port.a.corrupt <= '0';
                host_port.d_ready <= '1';

                d_done := false;

                while beat_idx < total_beats or not d_done loop
                    if beat_idx < total_beats then
                        host_port.a.valid <= '1';
                        host_port.a.address <= std_ulogic_vector(current_addr);
                        if beat_idx = 0 then host_port.a.data <= cmd.dat0; end if;
                        if beat_idx = 1 then host_port.a.data <= cmd.dat1; end if;
                        if beat_idx = 2 then host_port.a.data <= cmd.dat2; end if;
                        if beat_idx = 3 then host_port.a.data <= cmd.dat3; end if;
                        host_port.a.mask <= cmd.sel;
                    else
                        host_port.a.valid <= '0';
                    end if;

                    wait until clk = '1';

                    if beat_idx < total_beats and per_port.a_ready = '1' then
                        beat_idx := beat_idx + 1;
                        current_addr := current_addr + 4;
                    end if;

                    if not d_done and per_port.d.valid = '1' then
                        d_done := true;
                        host_port.d_ready <= '0';
                    end if;
                end loop;
            end if;

            if cmd.is_write and not cmd.is_atomic then
                reply_msg := msg;
                reply(net, msg, reply_msg);
                log(logger, "write: adr=0x" & to_hstring(cmd.adr)
                    & " dat0=0x" & to_hstring(cmd.dat0)
                    & " mask=" & to_string(cmd.sel));
            elsif cmd.is_atomic then
                reply_msg := encode_bus_master_uh_msg(cmd);
                reply(net, msg, reply_msg);
                log(logger, "atomic: adr=0x" & to_hstring(cmd.adr)
                    & " op=" & to_string(cmd.opcode)
                    & " param=" & to_string(cmd.param)
                    & " ret_dat=0x" & to_hstring(cmd.dat0));
            else
                reply_msg := encode_bus_master_uh_msg(cmd);
                reply(net, msg, reply_msg);
                log(logger, "read: adr=0x" & to_hstring(cmd.adr)
                    & " dat0=0x" & to_hstring(cmd.dat0)
                    & " dat1=0x" & to_hstring(cmd.dat1)
                    & " mask=" & to_string(cmd.sel));
            end if;

            -- Deassert all signals.
            host_port <= host_type_new;
        end loop;
    end process;
end architecture;
