-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
library std;
use std.textio;
library rv32_ddr3;
library testing;
library a200t_clk;
library a200t_ddr3;
library a200t_constants;
use a200t_constants.constants.all;
library adt;
use adt.strings;

--! A simulation entity top level for the rv32_ddr3 board design.
--!
--! The simulation entity contains an instance of a synthesizable board design,
--! and a bunch of other entity instances which simulate the hardware present on
--! the a200t board.
entity tb is
    generic (
        sim_duration_ns: natural := 200_000_000
        ; sim_duration: time := sim_duration_ns * 1 ns
        ; reset_duration: time := 20 ns
        ; is_simulation: boolean := true
        ; memfile: string
        ; memsize: natural
        ; reset_strategy: string
        ; skip_internal_test: boolean := true
        -- The baud rate can not be too high, else the UART implementation will
        -- miss characters.
        ; baud_rate: positive := 200_000
        ; program_file: string := ""
    );

end entity;

