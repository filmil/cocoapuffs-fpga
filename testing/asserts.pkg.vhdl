-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package asserts is
    procedure eq(actual: in string; expect: in string);
end package;

package body asserts is
    procedure eq(actual: in string; expect: in string) is
        variable actual_part: string(1 to expect'length) := expect;
    begin
        if actual_part /= expect then
            report "Error: expected: '" & expect & "', actual: '" & actual_part & "'"
                severity failure;
        end if;
    end procedure;
end package body;
