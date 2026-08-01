-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
library std;
use std.textio;
library noelv;
library testing;
library a200t_clk;
library a200t_ddr3;
library a200t_constants;
use a200t_constants.constants.all;
library adt;
use adt.strings;

library vunit_lib;
use vunit_lib.run_types_pkg.all;
use vunit_lib.run_pkg.all;
use vunit_lib.runner_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.com_types_pkg.all;
use vunit_lib.com_pkg.all;
use vunit_lib.stream_master_pkg.all;
use vunit_lib.stream_slave_pkg.all;
use vunit_lib.uart_pkg.all;

--! A simulation entity top level for the noelv board design.
entity tb is
    generic (
        runner_cfg: string := runner_cfg_default
        ; sim_duration_ns: natural := 10_000_000 -- 10ms
        ; reset_duration: time := 20 ns
        ; is_simulation: boolean := true
        ; memfile: string := ""
        ; memsize: natural := 262144
        ; noelv_memfile: string := ""
        ; noelv_memsize: natural := 4096
        ; reset_strategy: string := "NONE"
        ; skip_internal_test: boolean := true
        -- The baud rate can not be too high, else the UART implementation will
        -- miss characters.
        ; baud_rate: positive := 200_000
        ; hexfile: string := ""
    );

end entity;
