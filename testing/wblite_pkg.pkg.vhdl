-- SPDX-License-Identifier: Apache-2.0
library ieee;
    use ieee.std_logic_1164.all;
library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

--! @brief Package for Wishbone Lite bus master operations in VUnit.
--! @details Provides types, functions, and procedures to perform bus read and
--!          write operations using VUnit's verification components.
package wblite_pkg is

--! Default timeout for bus operations.
constant timeout: time := 1000 ns;

--! @brief Record type for Wishbone bus master messages.
type bus_master_msg_t is record
    --! Address for the bus transaction.
    adr: std_ulogic_vector(31 downto 0);
    --! Data for the bus transaction.
    dat: std_ulogic_vector(31 downto 0);
    --! Byte select signals.
    sel: std_ulogic_vector(3 downto 0);
    --! True if the transaction is a write, false if it is a read.
    is_write: boolean;
end record;

--! @brief Decodes a VUnit message into a bus_master_msg_t record.
--! @param msg The VUnit message to decode.
--! @return The decoded bus_master_msg_t record.
impure function decode_bus_master_msg(msg: msg_t) return bus_master_msg_t;

--! @brief Encodes a bus_master_msg_t record into a VUnit message.
--! @param msg The bus_master_msg_t record to encode.
--! @return The encoded VUnit message.
impure function encode_bus_master_msg(msg: bus_master_msg_t) return msg_t;

--! @brief Performs a Wishbone bus write operation.
--! @param net The VUnit network signal.
--! @param bus_handle The handle to the bus master verification component.
--! @param address The address to write to.
--! @param data The data to write.
--! @param sel The byte select signals (default: all bits set).
--! @param timeout The timeout for the operation (default: 1000 ns).
procedure bus_write(
    signal net: inout network_t;
    bus_handle: bus_master_t;
    address: std_ulogic_vector(31 downto 0);
    data: std_ulogic_vector(31 downto 0);
    sel: std_ulogic_vector(3 downto 0) := (others => '1');
    timeout: time := timeout
);

--! @brief Performs a Wishbone bus read operation.
--! @param net The VUnit network signal.
--! @param bus_handle The handle to the bus master verification component.
--! @param address The address to read from.
--! @param value The variable to store the read data.
--! @param sel The byte select signals (default: all bits set).
--! @param timeout The timeout for the operation (default: 1000 ns).
procedure bus_read(
    signal net: inout network_t;
    bus_handle: bus_master_t;
    address: std_ulogic_vector(31 downto 0);
    variable value: out std_ulogic_vector(31 downto 0);
    sel: std_ulogic_vector(3 downto 0) := (others => '1');
    timeout: time := timeout
);

end package;


package body wblite_pkg is

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
        variable msg, reply_msg: msg_t;
    begin
        payload := (
            adr => address,
            dat => data,
            sel => sel,
            is_write => true
        );
        msg := encode_bus_master_msg(payload);
        send(net, bus_handle.p_actor, msg, timeout => timeout);
        receive_reply(net, msg, reply_msg, timeout => timeout);
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
