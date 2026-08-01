-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;

entity try_ent is
        port(
            clk, rst: in std_logic;
            result: out std_logic
        );
end entity;

architecture empty of try_ent is
begin
    result <= clk and rst;

end architecture;

