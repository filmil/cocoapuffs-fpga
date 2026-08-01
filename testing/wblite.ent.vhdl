library ieee;
    use ieee.std_logic_1164.all;

library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

library wb;

use work.wblite_pkg.all;

entity wblite is
    generic(
        bus_handle: bus_master_t;
        logger: logger_t := get_logger("unnamed.wblite"));
    port(
        clk, rst: in std_ulogic;
        host_port: out wb.host.bus_type;
        per_port: in wb.per.bus_type);
end entity;

architecture sim of wblite is
begin
    p0: process
        variable msg, reply_msg: msg_t;
        variable cmd: bus_master_msg_t;
    begin
        host_port <= wb.host.new_bus_type;

        wait until rst = '0';
        wait until clk = '1';

        loop
            receive(net, bus_handle.p_actor, msg);
            cmd := decode_bus_master_msg(msg);

            wait until clk = '1';
            host_port.adr <= cmd.adr;
            host_port.dat <= cmd.dat;
            host_port.sel <= cmd.sel;
            host_port.we <= '1' when cmd.is_write else '0';
            host_port.cyc <= '1';

            -- Wait until peripheral acks.
            wait until per_port.ack = '1';
            wait until rising_edge(clk);
            if cmd.is_write then
                reply_msg := msg;
                reply(net, msg, reply_msg);
                log(logger, "write: adr=" & to_hstring(host_port.adr)
                    & " dat=" & to_hstring(host_port.dat)
                    & " sel=" & to_string(host_port.sel));
            else
                -- Collect what we got and forward to the bus master.
                cmd.dat := per_port.rdt;
                reply_msg := encode_bus_master_msg(cmd);
                reply(net, msg, reply_msg);
                log(logger, "read: adr=0x" & to_hstring(host_port.adr)
                    & " dat=0x" & to_hstring(per_port.rdt)
                    & " sel=0x" & to_string(host_port.sel));
            end if;
            -- Deassert all signals.
            host_port <= wb.host.new_bus_type;
        end loop;
    end process;
end architecture;

