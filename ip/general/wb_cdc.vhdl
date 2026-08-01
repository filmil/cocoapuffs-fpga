-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
library wb;
use wb.host;
use wb.per;

--! @brief An asynchronous Wishbone Clock Domain Crossing (CDC) bridge.
--! @details This entity bridges a Wishbone bus from a host clock domain (e.g., 50MHz)
--!          to a peripheral clock domain (e.g., 100MHz) using a 4-phase handshake.
entity wb_cdc is
    port (
        clk_host  : in std_ulogic; -- e.g., 50MHz
        clk_per   : in std_ulogic; -- e.g., 100MHz
        rst       : in std_ulogic;

        -- Host side interface (e.g. at 50MHz)
        host_i    : in wb.host.bus_type;
        host_o    : out wb.per.bus_type;

        -- Peripheral side interface (e.g. at 100MHz)
        per_o     : out wb.host.bus_type;
        per_i     : in wb.per.bus_type
    );
end entity;

architecture rtl of wb_cdc is
    -- Host domain state
    type host_state_t is (ST_HOST_IDLE, ST_HOST_REQ, ST_HOST_WAIT_ACK_LOW);
    signal host_state : host_state_t := ST_HOST_IDLE;

    signal host_adr : std_ulogic_vector(31 downto 0);
    signal host_dat : std_ulogic_vector(31 downto 0);
    signal host_sel : std_ulogic_vector(3 downto 0);
    signal host_we  : std_ulogic;

    signal host_req : std_ulogic := '0';
    signal host_ack_sync : std_ulogic := '0';
    signal host_ack_q : std_ulogic_vector(1 downto 0) := (others => '0');

    -- Peripheral domain state
    type per_state_t is (ST_PER_IDLE, ST_PER_START, ST_PER_WAIT, ST_PER_DONE);
    signal per_state : per_state_t := ST_PER_IDLE;

    signal per_req_sync : std_ulogic := '0';
    signal per_req_q : std_ulogic_vector(1 downto 0) := (others => '0');
    signal per_ack : std_ulogic := '0';

    -- Data register in peripheral clock domain to pass read data back to host domain
    signal per_rdt : std_ulogic_vector(31 downto 0);

begin

    ---------------------------------------------------------------------------
    -- Host Domain (clk_host)
    ---------------------------------------------------------------------------
    process(clk_host, rst)
    begin
        if rst = '1' then
            host_state <= ST_HOST_IDLE;
            host_req <= '0';
            host_ack_q <= (others => '0');
            host_ack_sync <= '0';
            host_o <= wb.per.new_bus_type;
        elsif rising_edge(clk_host) then
            -- Synchronize per_ack to host domain
            host_ack_q(1) <= host_ack_q(0);
            host_ack_q(0) <= per_ack;
            host_ack_sync <= host_ack_q(1);

            case host_state is
                when ST_HOST_IDLE =>
                    host_o.ack <= '0';
                    if host_i.cyc = '1' then
                        -- Register request parameters
                        host_adr <= host_i.adr;
                        host_dat <= host_i.dat;
                        host_sel <= host_i.sel;
                        host_we  <= host_i.we;
                        host_req <= '1';
                        host_state <= ST_HOST_REQ;
                    end if;

                when ST_HOST_REQ =>
                    if host_ack_sync = '1' then
                        host_o.ack <= '1';
                        host_o.rdt <= per_rdt;
                        host_req <= '0';
                        host_state <= ST_HOST_WAIT_ACK_LOW;
                    end if;

                when ST_HOST_WAIT_ACK_LOW =>
                    if host_ack_sync = '0' then
                        host_o.ack <= '0';
                        host_state <= ST_HOST_IDLE;
                    else
                        host_o.ack <= '1'; -- Keep ack high until ack_sync goes low
                    end if;
            end case;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- Peripheral Domain (clk_per)
    ---------------------------------------------------------------------------
    process(clk_per, rst)
    begin
        if rst = '1' then
            per_state <= ST_PER_IDLE;
            per_req_q <= (others => '0');
            per_req_sync <= '0';
            per_ack <= '0';
            per_o <= wb.host.new_bus_type;
        elsif rising_edge(clk_per) then
            -- Synchronize host_req to peripheral domain
            per_req_q(1) <= per_req_q(0);
            per_req_q(0) <= host_req;
            per_req_sync <= per_req_q(1);

            case per_state is
                when ST_PER_IDLE =>
                    per_o.cyc <= '0';
                    if per_req_sync = '1' then
                        per_o.adr <= host_adr;
                        per_o.dat <= host_dat;
                        per_o.sel <= host_sel;
                        per_o.we  <= host_we;
                        per_o.cyc <= '1';
                        per_state <= ST_PER_START;
                    end if;

                when ST_PER_START =>
                    per_o.cyc <= '1';
                    if per_i.ack = '1' then
                        per_rdt <= per_i.rdt;
                        per_ack <= '1';
                        per_o.cyc <= '0';
                        per_state <= ST_PER_WAIT;
                    end if;

                when ST_PER_WAIT =>
                    per_o.cyc <= '0';
                    if per_req_sync = '0' then
                        per_ack <= '0';
                        per_state <= ST_PER_IDLE;
                    end if;

                when others =>
                    per_state <= ST_PER_IDLE;
            end case;
        end if;
    end process;

end architecture;
