library ieee;
use ieee.std_logic_1164.all;

--! A bus multplexer which monitors host bus activity and shunts the specific
--! bus through for the duration of the transaction.
entity wb_mux is
    generic(
        --! The number of ports to support.
        PORTS_COUNT: natural := 2
    );
    port(
        clk, rst: in std_ulogic;
        --! Host-side input ports.
        host_ports: in work.host.bus_array_t(PORTS_COUNT-1 downto 0);
        per_ports: out work.per.bus_array_t(PORTS_COUNT-1 downto 0);
        host_port: out work.host.bus_type;
        per_port: in work.per.bus_type
    );
end entity;

architecture rtl_roundrobin of wb_mux is
    subtype port_index_t is natural range 0 to PORTS_COUNT-1;
    type state_t is (IDLE, TX);
    -- Register type.
    type reg_t is record
        state: state_t;
        sampled_port_index: port_index_t;
        active_port_index: port_index_t;
    end record;

    constant reg_zero: reg_t := (
        state => IDLE,
        sampled_port_index => 0,
        active_port_index => 0
    );

    signal q, d: reg_t;

    procedure assign_host_port(
        signal host_port: out work.host.bus_type;
        signal host_ports: in work.host.bus_array_t;
        signal reg: reg_t
    ) is
    begin
        if reg.state = TX then
            host_port <= host_ports(reg.active_port_index);
        else
            host_port <= work.host.new_bus_type;
        end if;
    end procedure;

    procedure assign_per_ports(
        signal per_ports: out work.per.bus_array_t;
        signal per_port: in work.per.bus_type;
        signal reg: reg_t) is
        variable v_per_ports: work.per.bus_array_t(per_ports'range);
    begin
        v_per_ports(per_ports'range) := (others => work.per.new_bus_type);
        if reg.state = TX then
            v_per_ports(reg.active_port_index) := per_port;
        end if;
        per_ports <= v_per_ports;
    end procedure;

begin

    assign_host_port(host_port, host_ports, q);
    assign_per_ports(per_ports, per_port, q);

    comb: process(rst, host_ports, per_port, q) is
        variable v: reg_t;
    begin
        v := q;

        case q.state is
            when IDLE =>
                if host_ports(q.sampled_port_index).cyc = '1' then
                    v.active_port_index := q.sampled_port_index;
                    v.state := TX;
                else
                    if q.sampled_port_index = PORTS_COUNT-1 then
                        v.sampled_port_index := 0;
                    else
                        v.sampled_port_index := q.sampled_port_index + 1;
                    end if;
                end if;
            when TX =>
                -- End transaction is when ACK=1. Stop forwarding ports,
                -- and revert to no output.
                if per_port.ack = '1' then
                    v.state := IDLE;
                end if;
        end case;

        if rst = '1' then v := reg_zero; end if;
        d <= v;
    end process;

    seq: process(clk) is
    begin
        if rising_edge(clk) then
            q <= d;
        end if;
    end process;

end architecture;
