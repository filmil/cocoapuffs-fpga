-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library testing;

package run_types_pkg is
    constant runner_cfg_default : string := "";
    type runner_t is record
        p_data : integer;
    end record;
    constant null_runner : runner_t := (p_data => 0);
end package;

library ieee;
use ieee.std_logic_1164.all;
package run_pkg is
    use work.run_types_pkg.all;
    type runner_sync_t is record
        p_dummy : integer;
    end record;
    signal runner : runner_sync_t;
    procedure test_runner_setup(signal r : inout runner_sync_t; constant cfg : string);
    procedure test_runner_cleanup(signal r : inout runner_sync_t);
    impure function test_suite return boolean;
    impure function run(name : string) return boolean;
end package;

library ieee;
use ieee.std_logic_1164.all;
package body run_pkg is
    type prot_bool_t is protected
        impure function get_and_clear return boolean;
    end protected;
    type prot_bool_t is protected body
        variable val : boolean := true;
        impure function get_and_clear return boolean is
            variable ret : boolean := val;
        begin
            val := false;
            return ret;
        end;
    end protected body;
    shared variable first_v : prot_bool_t;
    procedure test_runner_setup(signal r : inout runner_sync_t; constant cfg : string) is begin null; end;
    procedure test_runner_cleanup(signal r : inout runner_sync_t) is begin null; end;
    impure function test_suite return boolean is begin return first_v.get_and_clear; end;
    impure function run(name : string) return boolean is begin return true; end;
end package body;

package runner_pkg is
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
package check_pkg is
    procedure check_equal(a, b : integer; msg : string := "");
    procedure check_equal(a, b : unsigned; msg : string := "");
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
package body check_pkg is
    procedure check_equal(a, b : integer; msg : string := "") is
    begin
        assert a = b report "Check failed: " & msg & " (got " & integer'image(a) & ", expected " & integer'image(b) & ")" severity failure;
    end;
    procedure check_equal(a, b : unsigned; msg : string := "") is
    begin
        assert a = b report "Check failed: " & msg severity failure;
    end;
end package body;

library ieee;
use ieee.std_logic_1164.all;
package logger_pkg is
    procedure info(msg : string);
end package;

library ieee;
use ieee.std_logic_1164.all;
package body logger_pkg is
    procedure info(msg : string) is
        use std.textio.all;
        variable l : line;
    begin
        write(l, string'("INFO: ") & msg);
        writeline(output, l);
    end;
end package body;

library ieee;
use ieee.std_logic_1164.all;
package com_types_pkg is
    type actor_t is record
        p_id_number : integer;
    end record;
    constant null_actor : actor_t := (p_id_number => 0);
    subtype network_t is integer;
end package;

library ieee;
use ieee.std_logic_1164.all;
package com_pkg is
    use work.com_types_pkg.all;
    signal net : network_t;
end package;

library ieee;
use ieee.std_logic_1164.all;
package comm_types is
    type prot_comm_t is protected
        procedure push(data : std_logic_vector(7 downto 0));
        impure function pop return std_logic_vector;
        impure function has_data return boolean;
    end protected;
end package;

package body comm_types is
    type prot_comm_t is protected body
        variable val : std_logic_vector(7 downto 0);
        variable valid : boolean := false;
        procedure push(data : std_logic_vector(7 downto 0)) is
        begin
            val := data;
            valid := true;
        end;
        impure function pop return std_logic_vector is
        begin
            valid := false;
            return val;
        end;
        impure function has_data return boolean is begin return valid; end;
    end protected body;
end package body;

library ieee;
use ieee.std_logic_1164.all;
package stream_master_pkg is
    use work.com_types_pkg.all;
    use work.comm_types.all;
    shared variable uart_tx_comm : prot_comm_t;
    type stream_master_t is record
        p_actor : actor_t;
    end record;
    procedure push_stream(signal net : inout network_t; stream : stream_master_t; data : std_logic_vector);
end package;

package body stream_master_pkg is
    procedure push_stream(signal net : inout network_t; stream : stream_master_t; data : std_logic_vector) is
    begin
        while uart_tx_comm.has_data loop
            wait for 1 ns;
        end loop;
        uart_tx_comm.push(data);
    end;
end package body;

library ieee;
use ieee.std_logic_1164.all;
package stream_slave_pkg is
    use work.com_types_pkg.all;
    use work.comm_types.all;
    shared variable uart_rx_comm : prot_comm_t;
    type stream_slave_t is record
        p_actor : actor_t;
    end record;
    procedure pop_stream(signal net : inout network_t; stream : stream_slave_t; data : out std_logic_vector);
    procedure check_stream(signal net : inout network_t; stream : stream_slave_t; expected : string; msg : string := "");
    procedure wait_for_string(signal net : inout network_t; stream : stream_slave_t; target : string);
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
package body stream_slave_pkg is
    procedure pop_stream(signal net : inout network_t; stream : stream_slave_t; data : out std_logic_vector) is
    begin
        while not uart_rx_comm.has_data loop
            wait for 1 ns;
        end loop;
        data := uart_rx_comm.pop;
    end;

    procedure check_stream(signal net : inout network_t; stream : stream_slave_t; expected : string; msg : string := "") is
        variable actual_byte : std_logic_vector(7 downto 0);
        variable actual_char : character;
    begin
        for i in expected'range loop
            pop_stream(net, stream, actual_byte);
            actual_char := character'val(to_integer(unsigned(actual_byte)));
            assert actual_char = expected(i)
                report "check_stream failed: " & msg & " (got '" & actual_char & "', expected '" & expected(i) & "')"
                severity failure;
        end loop;
    end procedure;

    procedure wait_for_string(signal net : inout network_t; stream : stream_slave_t; target : string) is
        variable actual_byte : std_logic_vector(7 downto 0);
        variable actual_char : character;
        variable match_idx : integer := target'low;
    begin
        while match_idx <= target'high loop
            pop_stream(net, stream, actual_byte);
            actual_char := character'val(to_integer(unsigned(actual_byte)));
            if actual_char = target(match_idx) then
                match_idx := match_idx + 1;
            else
                match_idx := target'low;
            end if;
        end loop;
    end procedure;
end package body;

library ieee;
use ieee.std_logic_1164.all;
package uart_pkg is
    use work.com_types_pkg.all;
    use work.run_types_pkg.all;
    use work.stream_master_pkg.all;
    use work.stream_slave_pkg.all;

    type uart_master_t is record
        p_actor : actor_t;
        p_baud_rate : natural;
        p_idle_state : std_logic;
    end record;
    type uart_slave_t is record
        p_actor : actor_t;
        p_baud_rate : natural;
        p_idle_state : std_logic;
        p_data_length : positive;
    end record;

    procedure set_baud_rate(signal net : inout network_t; uart : uart_master_t; baud : natural);
    procedure set_baud_rate(signal net : inout network_t; uart : uart_slave_t; baud : natural);
end package;

library ieee;
use ieee.std_logic_1164.all;
package body uart_pkg is
    procedure set_baud_rate(signal net : inout network_t; uart : uart_master_t; baud : natural) is begin null; end;
    procedure set_baud_rate(signal net : inout network_t; uart : uart_slave_t; baud : natural) is begin null; end;
end package body;

-- Actual entities to be instantiated
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library testing;
use work.uart_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;
use work.comm_types.all;

entity uart_master is
    generic (uart : uart_master_t);
    port (tx : out std_logic);
end entity;

architecture stub of uart_master is
begin
    process
        variable baud_rate : natural := 200_000;
        variable bit_period : time;
        variable data : std_logic_vector(7 downto 0);
    begin
        bit_period := 1.0/baud_rate * 1000 ms;
        tx <= uart.p_idle_state;
        loop
            if uart_tx_comm.has_data then
                data := uart_tx_comm.pop;
                testing.uart.send_bits(bit_period, data, tx);
            else
                wait for 1 ns;
            end if;
        end loop;
    end process;
end architecture;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library testing;
use work.uart_pkg.all;
use work.stream_master_pkg.all;
use work.stream_slave_pkg.all;
use work.comm_types.all;

entity uart_slave is
    generic (uart : uart_slave_t);
    port (rx : in std_logic);
end entity;

architecture stub of uart_slave is
begin
    process
        variable baud_rate : natural := 200_000;
        variable bit_period : time;
        variable data : std_logic_vector(7 downto 0);
    begin
        bit_period := 1.0/baud_rate * 1000 ms;
        loop
            testing.uart.rcv_bits(bit_period, data, rx);
            uart_rx_comm.push(data);
        end loop;
    end process;
end architecture;
