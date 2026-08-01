-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;

entity a200t_ddr3 is
    port (
        ddr3_dqs: inout std_logic_vector;
        ddr3_dqs_n: inout std_logic_vector;
        ddr3_dq: inout std_logic_vector;
        ddr3_dm: in std_ulogic_vector;
        ddr3_a: in std_ulogic_vector;
        ddr3_ba: in std_ulogic_vector;
        ddr3_ras: in std_ulogic;
        ddr3_cas: in std_ulogic;
        ddr3_we: in std_ulogic;
        ddr3_odt: in std_ulogic;
        clk_n: in std_ulogic;
        clk_p: in std_ulogic;
        ddr3_cke: in std_ulogic;
        rst_n: in std_ulogic;
        cs_n: in std_ulogic;
        tdqs_n: out std_ulogic
    );
end entity;

architecture sim of a200t_ddr3 is
begin
    tdqs_n <= '1';
end architecture;
