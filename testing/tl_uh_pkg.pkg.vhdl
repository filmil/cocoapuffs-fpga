-- SPDX-License-Identifier: Apache-2.0
library ieee;
    use ieee.std_logic_1164.all;
library vunit_lib;
    context vunit_lib.vunit_context;
    context vunit_lib.vc_context;

--! @file
--! @brief TileLink Uncached Heavyweight (TL-UH) test package.
package tl_uh_pkg is

--! Default timeout for TileLink operations.
constant timeout: time := 1000 ns;

--! Message record for TileLink Uncached Heavyweight bus master.
type bus_master_uh_msg_t is record
    --! Operation address.
    adr: std_ulogic_vector(31 downto 0);
    --! Write data 0.
    dat0: std_ulogic_vector(31 downto 0);
    --! Write data 1.
    dat1: std_ulogic_vector(31 downto 0);
    --! Write data 2.
    dat2: std_ulogic_vector(31 downto 0);
    --! Write data 3.
    dat3: std_ulogic_vector(31 downto 0);
    --! Byte select mask.
    sel: std_ulogic_vector(3 downto 0);
    --! Transfer size.
    size: std_ulogic_vector(2 downto 0);
    --! True if it is a write operation.
    is_write: boolean;
    --! True if it is an atomic operation.
    is_atomic: boolean;
    --! Opcode of the atomic operation.
    opcode: std_ulogic_vector(2 downto 0);
    --! Parameter associated with the atomic opcode.
    param: std_ulogic_vector(2 downto 0);
end record;

--! Decode a VUnit message into a TileLink UH bus master message.
impure function decode_bus_master_uh_msg(msg: msg_t) return bus_master_uh_msg_t;
--! Encode a TileLink UH bus master message into a VUnit message.
impure function encode_bus_master_uh_msg(msg: bus_master_uh_msg_t) return msg_t;

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

--! @brief Perform a TileLink burst write operation of 8 bytes.
--! @param net The VUnit network.
--! @param bus_handle Handle to the TileLink bus.
--! @param address Address to start writing to.
--! @param dat0 Data to write for the first 4 bytes.
--! @param dat1 Data to write for the second 4 bytes.
--! @param sel Byte select mask applied to all beats.
--! @param timeout Operation timeout.
procedure bus_write_burst_8B(
    signal net: inout network_t;
    bus_handle: bus_master_t;
    address: std_ulogic_vector(31 downto 0);
    dat0: std_ulogic_vector(31 downto 0);
    dat1: std_ulogic_vector(31 downto 0);
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

--! @brief Perform a TileLink burst read operation of 8 bytes.
--! @param net The VUnit network.
--! @param bus_handle Handle to the TileLink bus.
--! @param address Address to start reading from.
--! @param val0 variable to store the first read beat.
--! @param val1 variable to store the second read beat.
--! @param sel Byte select mask.
--! @param timeout Operation timeout.
procedure bus_read_burst_8B(
    signal net: inout network_t;
    bus_handle: bus_master_t;
    address: std_ulogic_vector(31 downto 0);
    variable val0: out std_ulogic_vector(31 downto 0);
    variable val1: out std_ulogic_vector(31 downto 0);
    sel: std_ulogic_vector(3 downto 0) := (others => '1');
    timeout: time := timeout
);

--! @brief Perform a TileLink atomic operation.
--! @param net The VUnit network.
--! @param bus_handle Handle to the TileLink bus.
--! @param address Address for the atomic operation.
--! @param data Data for the atomic operation.
--! @param opcode Atomic operation opcode.
--! @param param Atomic operation parameter.
--! @param value variable to store the original value read from the memory.
--! @param sel Byte select mask.
--! @param timeout Operation timeout.
procedure bus_atomic(
    signal net: inout network_t;
    bus_handle: bus_master_t;
    address: std_ulogic_vector(31 downto 0);
    data: std_ulogic_vector(31 downto 0);
    opcode: std_ulogic_vector(2 downto 0);
    param: std_ulogic_vector(2 downto 0);
    variable value: out std_ulogic_vector(31 downto 0);
    sel: std_ulogic_vector(3 downto 0) := (others => '1');
    timeout: time := timeout
);

end package;

package body tl_uh_pkg is

    impure function decode_bus_master_uh_msg(msg: msg_t) return bus_master_uh_msg_t is
        variable msg_out: bus_master_uh_msg_t;
    begin
        msg_out.adr := pop(msg);
        msg_out.dat0 := pop(msg);
        msg_out.dat1 := pop(msg);
        msg_out.dat2 := pop(msg);
        msg_out.dat3 := pop(msg);
        msg_out.sel := pop(msg);
        msg_out.size := pop(msg);
        msg_out.is_write := pop(msg);
        msg_out.is_atomic := pop(msg);
        msg_out.opcode := pop(msg);
        msg_out.param := pop(msg);
        return msg_out;
    end function;

    impure function encode_bus_master_uh_msg(msg: bus_master_uh_msg_t) return msg_t is
        variable msg_out: msg_t := new_msg;
    begin
        push(msg_out, msg.adr);
        push(msg_out, msg.dat0);
        push(msg_out, msg.dat1);
        push(msg_out, msg.dat2);
        push(msg_out, msg.dat3);
        push(msg_out, msg.sel);
        push(msg_out, msg.size);
        push(msg_out, msg.is_write);
        push(msg_out, msg.is_atomic);
        push(msg_out, msg.opcode);
        push(msg_out, msg.param);
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
        variable payload: bus_master_uh_msg_t;
        variable msg: msg_t;
    begin
        payload := (
            adr => address,
            dat0 => data,
            dat1 => (others => '0'),
            dat2 => (others => '0'),
            dat3 => (others => '0'),
            sel => sel,
            size => "010",
            is_write => true,
            is_atomic => false,
            opcode => (others => '0'),
            param => (others => '0')
        );
        msg := encode_bus_master_uh_msg(payload);
        send(net, bus_handle.p_actor, msg, timeout => timeout);
    end procedure;

    procedure bus_write_burst_8B(
        signal net: inout network_t;
        bus_handle: bus_master_t;
        address: std_ulogic_vector(31 downto 0);
        dat0: std_ulogic_vector(31 downto 0);
        dat1: std_ulogic_vector(31 downto 0);
        sel: std_ulogic_vector(3 downto 0) := (others => '1');
        timeout: time := timeout
    ) is
        variable payload: bus_master_uh_msg_t;
        variable msg: msg_t;
    begin
        payload := (
            adr => address,
            dat0 => dat0,
            dat1 => dat1,
            dat2 => (others => '0'),
            dat3 => (others => '0'),
            sel => sel,
            size => "011",
            is_write => true,
            is_atomic => false,
            opcode => (others => '0'),
            param => (others => '0')
        );
        msg := encode_bus_master_uh_msg(payload);
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
        variable payload, reply_payload: bus_master_uh_msg_t;
        variable msg, reply_msg: msg_t;
    begin
        payload := (
            adr => address,
            dat0 => (others => 'U'),
            dat1 => (others => 'U'),
            dat2 => (others => 'U'),
            dat3 => (others => 'U'),
            sel => sel,
            size => "010",
            is_write => false,
            is_atomic => false,
            opcode => (others => '0'),
            param => (others => '0')
        );
        msg := encode_bus_master_uh_msg(payload);
        send(net, bus_handle.p_actor, msg, timeout => timeout);
        reply_payload.dat0 := (others => 'U');
        receive_reply(net, msg, reply_msg, timeout => timeout);
        reply_payload := decode_bus_master_uh_msg(reply_msg);
        value := reply_payload.dat0;
    end procedure;

    procedure bus_read_burst_8B(
        signal net: inout network_t;
        bus_handle: bus_master_t;
        address: std_ulogic_vector(31 downto 0);
        variable val0: out std_ulogic_vector(31 downto 0);
        variable val1: out std_ulogic_vector(31 downto 0);
        sel: std_ulogic_vector(3 downto 0) := (others => '1');
        timeout: time := timeout
    ) is
        variable payload, reply_payload: bus_master_uh_msg_t;
        variable msg, reply_msg: msg_t;
    begin
        payload := (
            adr => address,
            dat0 => (others => 'U'),
            dat1 => (others => 'U'),
            dat2 => (others => 'U'),
            dat3 => (others => 'U'),
            sel => sel,
            size => "011",
            is_write => false,
            is_atomic => false,
            opcode => (others => '0'),
            param => (others => '0')
        );
        msg := encode_bus_master_uh_msg(payload);
        send(net, bus_handle.p_actor, msg, timeout => timeout);
        reply_payload.dat0 := (others => 'U');
        receive_reply(net, msg, reply_msg, timeout => timeout);
        reply_payload := decode_bus_master_uh_msg(reply_msg);
        val0 := reply_payload.dat0;
        val1 := reply_payload.dat1;
    end procedure;

    procedure bus_atomic(
        signal net: inout network_t;
        bus_handle: bus_master_t;
        address: std_ulogic_vector(31 downto 0);
        data: std_ulogic_vector(31 downto 0);
        opcode: std_ulogic_vector(2 downto 0);
        param: std_ulogic_vector(2 downto 0);
        variable value: out std_ulogic_vector(31 downto 0);
        sel: std_ulogic_vector(3 downto 0) := (others => '1');
        timeout: time := timeout
    ) is
        variable payload, reply_payload: bus_master_uh_msg_t;
        variable msg, reply_msg: msg_t;
    begin
        payload := (
            adr => address,
            dat0 => data,
            dat1 => (others => '0'),
            dat2 => (others => '0'),
            dat3 => (others => '0'),
            sel => sel,
            size => "010",
            is_write => false,
            is_atomic => true,
            opcode => opcode,
            param => param
        );
        msg := encode_bus_master_uh_msg(payload);
        send(net, bus_handle.p_actor, msg, timeout => timeout);
        reply_payload.dat0 := (others => 'U');
        receive_reply(net, msg, reply_msg, timeout => timeout);
        reply_payload := decode_bus_master_uh_msg(reply_msg);
        value := reply_payload.dat0;
    end procedure;

end package body;
