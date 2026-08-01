-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library tl;
use tl.types.all;

--! @file
--! @brief TileLink-UH Ethernet Controller architecture.

--! @brief Architecture of TileLink-UH Ethernet Controller.
architecture rtl of tl_ethernet is
    type state_t is (IDLE, RESPOND);
    signal state : state_t := IDLE;
    signal saved_a : a_type;

    signal mdio_data : std_ulogic_vector(31 downto 0) := (others => '0');
    signal rx_fifo_data : std_ulogic_vector(31 downto 0) := (others => '0');
    signal tx_fifo_data : std_ulogic_vector(31 downto 0) := (others => '0');

begin
    -- Minimal functional stub:
    -- Drive PHY reset.
    eth_reset <= not rst;

    -- Drive MDC slow clock (dummy)
    eth_mdc <= '0';

    -- RGMII Tx outputs
    eth_txck <= '0';
    eth_txctl <= '0';
    eth_txd <= (others => '0');

    irq <= '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE;
                tl_o <= per_type_new;
                mdio_data <= (others => '0');
                rx_fifo_data <= (others => '0');
                tx_fifo_data <= (others => '0');
            else
                tl_o.a_ready <= '0';
                tl_o.d.valid <= '0';

                case state is
                    when IDLE =>
                        tl_o.a_ready <= '1';
                        if tl_i.a.valid = '1' then
                            saved_a <= tl_i.a;
                            state <= RESPOND;
                            tl_o.a_ready <= '0';

                            -- Example simple register writes
                            if tl_i.a.opcode = OP_PUT_FULL_DATA or tl_i.a.opcode = OP_PUT_PARTIAL_DATA then
                                if tl_i.a.address = std_ulogic_vector(unsigned(BASE_ADDRESS) + 4) then
                                    mdio_data <= tl_i.a.data;
                                elsif tl_i.a.address = std_ulogic_vector(unsigned(BASE_ADDRESS) + 16) then
                                    tx_fifo_data <= tl_i.a.data;
                                    rx_fifo_data <= tl_i.a.data; -- loopback locally for test
                                end if;
                            end if;
                        end if;

                    when RESPOND =>
                        tl_o.d.valid <= '1';
                        tl_o.d.source <= saved_a.source;
                        tl_o.d.size <= saved_a.size;
                        tl_o.d.corrupt <= '0';

                        if saved_a.opcode = OP_GET then
                            tl_o.d.opcode <= OP_ACCESS_ACK_DATA;
                            if saved_a.address = std_ulogic_vector(unsigned(BASE_ADDRESS) + 4) then
                                tl_o.d.data <= mdio_data;
                            elsif saved_a.address = std_ulogic_vector(unsigned(BASE_ADDRESS) + 32) then
                                tl_o.d.data <= rx_fifo_data;
                            else
                                tl_o.d.data <= (others => '0');
                            end if;
                        else
                            tl_o.d.opcode <= OP_ACCESS_ACK;
                            tl_o.d.data <= (others => '0');
                        end if;

                        if tl_i.d_ready = '1' then
                            state <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
