-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library vunit_lib;
use vunit_lib.types_pkg.all;
use vunit_lib.com_types_pkg.all;
use vunit_lib.stream_slave_pkg.all;

package vunit_helpers_pkg is
    procedure wait_for_string(signal net : inout network_t; stream : stream_slave_t; target : string);
end package;

package body vunit_helpers_pkg is
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
