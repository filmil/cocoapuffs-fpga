-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;

entity fail_tb is
end entity fail_tb;

architecture b of fail_tb is
begin
    process
    begin
        report "Error: Your descriptive error message here" severity error;
        std.env.finish;
    end process;
end architecture;

