-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;

-- Entity name must be the target name with `_tb` appended.
entity pass_tb is
end entity pass_tb;

architecture b of pass_tb is
begin
    process
    begin
        report "Info: This test will pass";
        std.env.finish;
    end process;
end architecture;

