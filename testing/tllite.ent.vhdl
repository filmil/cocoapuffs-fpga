-- SPDX-License-Identifier: Apache-2.0
library ieee;
    use ieee.std_logic_1164.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

library tl;
use tl.types.all;
use work.tllite_pkg.all;

--! @brief TileLink host simulation model for VUnit.
--! @details This entity bridges the VUnit bus master actor to TileLink
--!          Channel A and Channel D protocols.
entity tllite is
    generic(
        --! The VUnit bus handle.
        bus_handle: bus_master_t;
        --! The VUnit logger.
        logger: logger_t := get_logger("unnamed.tllite")
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

architecture sim of tllite is
begin
    p0: process
        variable msg, reply_msg: msg_t;
        variable cmd: bus_master_msg_t;
        variable a_done, d_done: boolean;
    begin
        host_port <= host_type_new;

        wait until rst = '0';
        wait until clk = '1';

        loop
            receive(net, bus_handle.p_actor, msg);
            cmd := decode_bus_master_msg(msg);

            wait until clk = '1';
            if cmd.is_write then
                if cmd.sel = "1111" then
                    host_port.a.opcode <= OP_PUT_FULL_DATA;
                else
                    host_port.a.opcode <= OP_PUT_PARTIAL_DATA;
                end if;
            else
                host_port.a.opcode <= OP_GET;
            end if;

            host_port.a.address <= cmd.adr;
            host_port.a.data <= cmd.dat;
            host_port.a.mask <= cmd.sel;
            host_port.a.source <= (others => '0');
            host_port.a.size <= "010"; -- 4 bytes
            host_port.a.param <= "000";
            host_port.a.corrupt <= '0';
            host_port.a.valid <= '1';
            host_port.d_ready <= '1';

            a_done := false;
            d_done := false;

            while not (a_done and d_done) loop
                wait until clk = '1';
                if not a_done and per_port.a_ready = '1' then
                    a_done := true;
                    host_port.a.valid <= '0';
                end if;

                if not d_done and per_port.d.valid = '1' then
                    d_done := true;
                    host_port.d_ready <= '0';
                    if not cmd.is_write then
                        cmd.dat := per_port.d.data;
                    end if;
                end if;
            end loop;

            if cmd.is_write then
                reply_msg := msg;
                reply(net, msg, reply_msg);
                log(logger, "write: adr=0x" & to_hstring(cmd.adr)
                    & " dat=0x" & to_hstring(cmd.dat)
                    & " mask=" & to_string(cmd.sel));
            else
                reply_msg := encode_bus_master_msg(cmd);
                reply(net, msg, reply_msg);
                log(logger, "read: adr=0x" & to_hstring(cmd.adr)
                    & " dat=0x" & to_hstring(cmd.dat)
                    & " mask=" & to_string(cmd.sel));
            end if;

            -- Deassert all signals.
            host_port <= host_type_new;
        end loop;
    end process;
end architecture;
