-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library wb;
library tl;
use tl.types.all;

--! @file
--! @brief TileLink UH to Wishbone Lite converter component.

--! @brief Converter from TL-UH protocol to Wishbone Lite.
--! @details Converts TL-UH (including ArithmeticData, LogicalData, and bursts)
--!          to Wishbone.
entity tl_uh2wblite is
    port(
        --! Global clock.
        clk: in std_ulogic;
        --! Synchronous reset, active high.
        rst: in std_ulogic;

        --! TileLink peripheral/target interface.
        tl_i: in host_type;
        --! TileLink peripheral/target output.
        tl_o: out per_type;

        --! Wishbone host/master interface output.
        wb_o: out wb.host.bus_type;
        --! Wishbone host/master input from peripheral.
        wb_i: in wb.per.bus_type
    );
end entity;

architecture rtl of tl_uh2wblite is
    --! Internal state for the FSM.
    type state_t is (
        --! Idle state waiting for a valid request.
        IDLE,
        --! Wait state to sequence A-channel bursts.
        A_WAIT,
        --! Reading from Wishbone to gather original data for ALUs/Get.
        WB_RD_WAIT,
        --! Single cycle for combinational ALU propagation.
        ALU,
        --! Writing data (computed or standard) to Wishbone.
        WB_WR_WAIT,
        --! Returning the response beat to the master on the D-channel.
        TL_RESP
    );
    signal state: state_t := IDLE;

    --! Captured A-channel request for processing.
    signal saved_a: a_type;
    --! Captured Wishbone read data for read-modify-write or Get ops.
    signal saved_wb_dat: std_ulogic_vector(31 downto 0);
    --! Computed combinational ALU result.
    signal alu_res: std_ulogic_vector(31 downto 0);
    
    --! Counter for multi-beat bursts.
    signal beat_count: unsigned(7 downto 0) := (others => '0');
    --! Rolling address used specifically for sequential Get requests.
    signal get_address: std_ulogic_vector(31 downto 0) := (others => '0');

    --! Internal signal for the tl_o port.
    signal tl_o_internal: per_type;

    --! Masks the bytes of `val` based on bits of `sel`. Each bit of `sel` is
    --! a lane selector.
    --! @param val Full data value.
    --! @param sel Byte selector mask.
    --! @return Byte-masked value where inactive bytes are forced to zero.
    function masked_value(
        val: std_ulogic_vector(31 downto 0);
        sel: std_ulogic_vector(3 downto 0)
    ) return std_ulogic_vector is
        variable mask: std_ulogic_vector(31 downto 0) := (others => '0');
    begin
        for i in sel'low to sel'high loop
            mask((i + 1) * 8 - 1 downto i * 8) := (others => sel(i));
        end loop;
        return val and mask;
    end function;

    --! Calculates total number of 32-bit beats expected in a transaction
    --! based on the `size` code.
    --! @param size The size specifier from the TileLink request.
    --! @return Integer count of 32-bit beats for the request.
    function get_total_beats(
        size: std_ulogic_vector(2 downto 0)
    ) return unsigned is
        variable s: integer := to_integer(unsigned(size));
    begin
        if s <= 2 then
            return to_unsigned(1, 8);
        else
            return shift_left(to_unsigned(1, 8), s - 2);
        end if;
    end function;

begin
    -- ALU is combinational
    process(saved_a, saved_wb_dat)
        variable res: std_ulogic_vector(31 downto 0);
        variable s_mem, s_req: signed(31 downto 0);
        variable u_mem, u_req: unsigned(31 downto 0);
    begin
        s_mem := signed(saved_wb_dat);
        s_req := signed(saved_a.data);
        u_mem := unsigned(saved_wb_dat);
        u_req := unsigned(saved_a.data);

        if saved_a.opcode = OP_ARITHMETIC_DATA then
            case saved_a.param is
                when PARAM_ARITH_MIN =>
                    if s_mem < s_req then
                        res := saved_wb_dat;
                    else
                        res := saved_a.data;
                    end if;
                when PARAM_ARITH_MAX =>
                    if s_mem > s_req then
                        res := saved_wb_dat;
                    else
                        res := saved_a.data;
                    end if;
                when PARAM_ARITH_MINU =>
                    if u_mem < u_req then
                        res := saved_wb_dat;
                    else
                        res := saved_a.data;
                    end if;
                when PARAM_ARITH_MAXU =>
                    if u_mem > u_req then
                        res := saved_wb_dat;
                    else
                        res := saved_a.data;
                    end if;
                when PARAM_ARITH_ADD =>
                    res := std_ulogic_vector(u_mem + u_req);
                when others =>
                    res := saved_a.data;
            end case;
        elsif saved_a.opcode = OP_LOGICAL_DATA then
            case saved_a.param is
                when PARAM_LOGIC_XOR =>
                    res := saved_wb_dat xor saved_a.data;
                when PARAM_LOGIC_OR =>
                    res := saved_wb_dat or saved_a.data;
                when PARAM_LOGIC_AND =>
                    res := saved_wb_dat and saved_a.data;
                when PARAM_LOGIC_SWAP =>
                    res := saved_a.data;
                when others =>
                    res := saved_a.data;
            end case;
        else
            res := saved_a.data;
        end if;
        alu_res <= res;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                tl_o_internal <= per_type_new;
                wb_o <= wb.host.new_bus_type;
                beat_count <= (others => '0');
            else
                -- Default assignments
                wb_o.cyc <= '0';
                tl_o_internal.a_ready <= '0';
                tl_o_internal.d.valid <= '0';

                case state is
                    when IDLE =>
                        tl_o_internal.a_ready <= '1';
                        if tl_i.a.valid = '1' and tl_o_internal.a_ready = '1' then
                            tl_o_internal.a_ready <= '0';
                            saved_a <= tl_i.a;
                            beat_count <= get_total_beats(tl_i.a.size);
                            if tl_i.a.opcode = OP_GET then
                                get_address <= tl_i.a.address;
                                state <= WB_RD_WAIT;
                            elsif tl_i.a.opcode = OP_ARITHMETIC_DATA or
                                  tl_i.a.opcode = OP_LOGICAL_DATA then
                                state <= WB_RD_WAIT;
                            else
                                state <= WB_WR_WAIT;
                            end if;
                        end if;

                    when A_WAIT =>
                        tl_o_internal.a_ready <= '1';
                        if tl_i.a.valid = '1' and tl_o_internal.a_ready = '1' then
                            tl_o_internal.a_ready <= '0';
                            saved_a <= tl_i.a;
                            if tl_i.a.opcode = OP_ARITHMETIC_DATA or
                               tl_i.a.opcode = OP_LOGICAL_DATA then
                                state <= WB_RD_WAIT;
                            else
                                state <= WB_WR_WAIT;
                            end if;
                        end if;

                    when WB_RD_WAIT =>
                        wb_o.cyc <= '1';
                        if saved_a.opcode = OP_GET then
                            wb_o.adr <= get_address;
                        else
                            wb_o.adr <= saved_a.address;
                        end if;
                        wb_o.we <= '0';
                        wb_o.sel <= (others => '1'); -- full word for ALU or Get

                        if wb_i.ack = '1' then
                            wb_o.cyc <= '0';
                            saved_wb_dat <= wb_i.rdt;
                            if saved_a.opcode = OP_GET then
                                state <= TL_RESP;
                            else
                                state <= ALU;
                            end if;
                        end if;

                    when ALU =>
                        state <= WB_WR_WAIT;

                    when WB_WR_WAIT =>
                        wb_o.cyc <= '1';
                        wb_o.adr <= saved_a.address;

                        if saved_a.opcode = OP_ARITHMETIC_DATA or
                           saved_a.opcode = OP_LOGICAL_DATA then
                            wb_o.we <= '1';
                            wb_o.sel <= saved_a.mask;
                            -- Apply mask properly
                            wb_o.dat <= (saved_wb_dat and
                                         not masked_value(x"FFFFFFFF",
                                                          saved_a.mask))
                                        or masked_value(alu_res, saved_a.mask);
                        else
                            wb_o.dat <= saved_a.data;
                            wb_o.sel <= saved_a.mask;
                            if saved_a.opcode = OP_PUT_FULL_DATA or
                               saved_a.opcode = OP_PUT_PARTIAL_DATA then
                                wb_o.we <= '1';
                            else
                                wb_o.we <= '0';
                            end if;
                        end if;

                        if wb_i.ack = '1' then
                            wb_o.cyc <= '0';
                            if not (saved_a.opcode = OP_ARITHMETIC_DATA or
                                    saved_a.opcode = OP_LOGICAL_DATA) then
                                saved_wb_dat <= wb_i.rdt;
                            end if;

                            if saved_a.opcode = OP_PUT_FULL_DATA or
                               saved_a.opcode = OP_PUT_PARTIAL_DATA then
                                if beat_count > 1 then
                                    beat_count <= beat_count - 1;
                                    state <= A_WAIT;
                                else
                                    state <= TL_RESP;
                                end if;
                            else
                                state <= TL_RESP;
                            end if;
                        end if;

                    when TL_RESP =>
                        tl_o_internal.d.valid <= '1';
                        if saved_a.opcode = OP_GET or
                           saved_a.opcode = OP_ARITHMETIC_DATA or
                           saved_a.opcode = OP_LOGICAL_DATA then
                            tl_o_internal.d.opcode <= OP_ACCESS_ACK_DATA;
                            tl_o_internal.d.data <= saved_wb_dat;
                        else
                            tl_o_internal.d.opcode <= OP_ACCESS_ACK;
                            tl_o_internal.d.data <= (others => '0');
                        end if;
                        tl_o_internal.d.size <= saved_a.size;
                        tl_o_internal.d.source <= saved_a.source;
                        tl_o_internal.d.sink <= (others => '0');
                        tl_o_internal.d.corrupt <= '0';

                        if tl_i.d_ready = '1' then
                            if saved_a.opcode = OP_PUT_FULL_DATA or
                               saved_a.opcode = OP_PUT_PARTIAL_DATA then
                                state <= IDLE;
                            else
                                if beat_count > 1 then
                                    beat_count <= beat_count - 1;
                                    if saved_a.opcode = OP_GET then
                                        get_address <= std_ulogic_vector(
                                            unsigned(get_address) + 4
                                        );
                                        state <= WB_RD_WAIT;
                                    else
                                        state <= A_WAIT;
                                    end if;
                                else
                                    state <= IDLE;
                                end if;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

    tl_o <= tl_o_internal;
end architecture;
