-- SPDX-License-Identifier: Apache-2.0
library ieee;
    use ieee.std_logic_1164.all;
library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

--! @file
--! @brief TileLink Lite test utilities for VUnit.

--! @brief TileLink Lite test package.
package tllite_pkg is

--! Default timeout for TileLink operations.
constant timeout: time := 1000 ns;

--! Message record for TileLink bus master.
type bus_master_msg_t is record
    --! Operation address.
    adr: std_ulogic_vector(31 downto 0);
    --! Write data.
    dat: std_ulogic_vector(31 downto 0);
    --! Byte select mask.
    sel: std_ulogic_vector(3 downto 0);
    --! True if it is a write operation.
    is_write: boolean;
end record;

--! Decode a VUnit message into a TileLink bus master message.
impure function decode_bus_master_msg(msg: msg_t) return bus_master_msg_t;
--! Encode a TileLink bus master message into a VUnit message.
impure function encode_bus_master_msg(msg: bus_master_msg_t) return msg_t;

--! @brief Perform a TileLink write operation.
--! @param net The VUnit network.
--! @param bus_handle Handle to the TileLink bus.
--! @param address Address to write to.
--! @param data Data to write.
--! @param sel Byte select mask.
--! @param timeout Operation timeout.
procedure bus_write(
    signal net: inout network_t;
    bus_handle: bus_master_t;
    address: std_ulogic_vector(31 downto 0);
    data: std_ulogic_vector(31 downto 0);
    sel: std_ulogic_vector(3 downto 0) := (others => '1');
    timeout: time := timeout
);

--! @brief Perform a TileLink read operation.
--! @param net The VUnit network.
--! @param bus_handle Handle to the TileLink bus.
--! @param address Address to read from.
--! @param value variable to store the read result.
--! @param sel Byte select mask.
--! @param timeout Operation timeout.
procedure bus_read(
    signal net: inout network_t;
    bus_handle: bus_master_t;
    address: std_ulogic_vector(31 downto 0);
    variable value: out std_ulogic_vector(31 downto 0);
    sel: std_ulogic_vector(3 downto 0) := (others => '1');
    timeout: time := timeout
);

end package;

package body tllite_pkg is

    impure function decode_bus_master_msg(msg: msg_t) return bus_master_msg_t is
        variable msg_out: bus_master_msg_t;
    begin
        msg_out.adr := pop(msg);
        msg_out.dat := pop(msg);
        msg_out.sel := pop(msg);
        msg_out.is_write := pop(msg);
        return msg_out;
    end function;

    impure function encode_bus_master_msg(msg: bus_master_msg_t) return msg_t is
        variable msg_out: msg_t := new_msg;
    begin
        push(msg_out, msg.adr);
        push(msg_out, msg.dat);
        push(msg_out, msg.sel);
        push(msg_out, msg.is_write);
        return msg_out;
    end function;

    procedure bus_write(
        signal net: inout network_t;
        bus_handle: bus_master_t;
        address: std_ulogic_vector(31 downto 0);
        data: std_ulogic_vector(31 downto 0);
        sel: std_ulogic_vector(3 downto 0) := (others => '1');
        timeout: time := timeout
    ) is
        variable payload: bus_master_msg_t;
        variable msg: msg_t;
    begin
        payload := (
            adr => address,
            dat => data,
            sel => sel,
            is_write => true
        );
        log("payload: " & to_string(payload));
        msg := encode_bus_master_msg(payload);
        log(to_string(msg));
        send(net, bus_handle.p_actor, msg, timeout => timeout);
    end procedure;

    procedure bus_read(
        signal net: inout network_t;
        bus_handle: bus_master_t;
        address: std_ulogic_vector(31 downto 0);
        variable value: out std_ulogic_vector(31 downto 0);
        sel: std_ulogic_vector(3 downto 0) := (others => '1');
        timeout: time := timeout
    ) is
        variable payload, reply_payload: bus_master_msg_t;
        variable msg, reply_msg: msg_t;
    begin
        payload := (
            adr => address,
            dat => (others => 'U'),
            sel => sel,
            is_write => false
        );
        msg := encode_bus_master_msg(payload);
        send(net, bus_handle.p_actor, msg, timeout => timeout);
        reply_payload.dat := (others => 'U');
        receive_reply(net, msg, reply_msg, timeout => timeout);
        reply_payload := decode_bus_master_msg(reply_msg);
        value := reply_payload.dat;
    end procedure;

end package body;
