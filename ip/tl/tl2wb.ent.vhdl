-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;

library wb;
library tl;
use tl.types.all;

--! @brief Converter between TileLink and Wishbone Lite.
--! @details This entity acts as a TileLink peripheral on its host side and
--!          converts requests to Wishbone bus cycles. It currently supports
--!          Get, PutFullData, and PutPartialData operations.
entity tl2wb is
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

architecture rtl of tl2wb is
    type state_t is (IDLE, WB_WAIT, TL_RESP);
    signal state: state_t := IDLE;

    signal saved_a: a_type;
    signal saved_wb_dat: std_ulogic_vector(31 downto 0);
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                tl_o <= per_type_new;
                wb_o <= wb.host.new_bus_type;
            else
                -- Default assignments
                wb_o.cyc <= '0';
                tl_o.a_ready <= '0';
                tl_o.d.valid <= '0';

                case state is
                    when IDLE =>
                        tl_o.a_ready <= '1';
                        if tl_i.a.valid = '1' then
                            tl_o.a_ready <= '0';
                            saved_a <= tl_i.a;
                            state <= WB_WAIT;
                        end if;

                    when WB_WAIT =>
                        wb_o.cyc <= '1';
                        wb_o.adr <= saved_a.address;
                        wb_o.dat <= saved_a.data;
                        wb_o.sel <= saved_a.mask;
                        
                        if saved_a.opcode = OP_PUT_FULL_DATA or
                           saved_a.opcode = OP_PUT_PARTIAL_DATA then
                            wb_o.we <= '1';
                        else
                            wb_o.we <= '0';
                        end if;

                        if wb_i.ack = '1' then
                            wb_o.cyc <= '0';
                            saved_wb_dat <= wb_i.rdt;
                            state <= TL_RESP;
                        end if;

                    when TL_RESP =>
                        tl_o.d.valid <= '1';
                        if saved_a.opcode = OP_GET then
                            tl_o.d.opcode <= OP_ACCESS_ACK_DATA;
                            tl_o.d.data <= saved_wb_dat;
                        else
                            tl_o.d.opcode <= OP_ACCESS_ACK;
                            tl_o.d.data <= (others => '0');
                        end if;
                        tl_o.d.size <= saved_a.size;
                        tl_o.d.source <= saved_a.source;
                        tl_o.d.sink <= (others => '0');
                        tl_o.d.corrupt <= '0';

                        if tl_i.d_ready = '1' then
                            -- Keep valid=1 for this cycle, but go to IDLE
                            -- next cycle
                            state <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
