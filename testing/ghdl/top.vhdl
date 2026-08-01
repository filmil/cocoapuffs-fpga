-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
library top;
use top.all;

entity top_entity is
        port(
            clk, rst: in std_logic;
            result: out std_logic
            );
end entity;

architecture rtl of top_entity is

    signal result2: std_logic;

begin

    try_inst: entity try_ent
        port map(
            clk => clk,
            rst => rst,
            result => result
    );

    try_inst2: entity try_ent
        port map(
            clk => clk,
            rst => rst,
            result => result2
    );

end architecture;

