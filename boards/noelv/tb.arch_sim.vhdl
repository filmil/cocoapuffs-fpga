-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;
library testing;
use testing.uart;
library noelv;

library vunit_lib;
use vunit_lib.run_pkg.all;
use vunit_lib.check_pkg.all;
use vunit_lib.logger_pkg.all;
use vunit_lib.uart_pkg.all;
use vunit_lib.stream_master_pkg.all;
use vunit_lib.stream_slave_pkg.all;
use vunit_lib.com_pkg.all;
use vunit_lib.com_types_pkg.all;

architecture sim of tb is
    signal clk, clk_n: std_logic;
    signal reset, reset_n: std_logic;

    signal ddr3_dq_p: std_logic_vector(DQ_WIDTH-1 downto 0);
    signal ddr3_dqs_p, ddr3_dqs_n:  std_logic_vector(DQS_WIDTH-1 downto 0);

    signal ddr3_dm: std_ulogic_vector(DQ_WIDTH/8-1 downto 0);
    signal ddr3_a: std_ulogic_vector(DDR3_A_WIDTH-1 downto 0);
    signal ddr3_ba: std_ulogic_vector(BA_WIDTH-1 downto 0);
    signal ddr3_ras, ddr3_cas, ddr3_we, ddr3_odt, ddr3_reset, ddr3_cke: std_ulogic;
    signal ddr3_clk_p, ddr3_clk_n: std_ulogic;
    signal txd, rxd: std_ulogic;
    signal led1, led2, led3, led4: std_ulogic;

    --! Chip select active zero. (a.k.a. `cs_n`).
    signal cs_n: std_ulogic;
    signal mgt_clk, mgt_clk_n: std_ulogic;

    constant uart_slave : uart_slave_t := (p_actor => (p_id_number => 101), p_baud_rate => baud_rate, p_idle_state => '1', p_data_length => 8);
    constant uart_rx_stream : stream_slave_t := (p_actor => (p_id_number => 101));

    constant sim_duration : time := sim_duration_ns * 1 ns;

begin

    uart_slave_inst: entity vunit_lib.uart_slave
        generic map (uart => uart_slave)
        port map (rx => txd);

    main: process
    begin
        test_runner_setup(runner, runner_cfg);

        set_baud_rate(net, uart_slave, baud_rate);

        while test_suite loop
            if run("test_halt") then
                wait until reset = '0';

                info("Waiting for 'halt.' on UART...");
                -- Monitor UART for "halt." using wait_for_string
                wait_for_string(net, uart_rx_stream, "halt.");

                info("Received 'halt.', terminating test.");
            end if;
        end loop;

        test_runner_cleanup(runner);
        std.env.finish;
        wait;
    end process;

    watchdog: process
    begin
        wait for sim_duration - 100 ns;
        assert false report "Test failed: 'halt.' not found within " & time'image(sim_duration) severity failure;
        wait;
    end process;

    --! Generate clock and reset, and a simulation limit.
    clkgen0: entity a200t_clk.clk
    generic map(
        sim_duration => sim_duration
        , reset_duration => reset_duration
    )
    port map(
        clk => clk -- 200MHz
        , clk_n => clk_n
        , reset => reset
        , reset_n => reset_n
        , mgt_clk => mgt_clk
        , mgt_clk_n => mgt_clk_n
    );

    --! The top level design.
    uut0: entity noelv.board(rtl)
    generic map (
        IS_SIMULATION => is_simulation
        , memfile => memfile
        , memsize => memsize
        , noelv_memfile => noelv_memfile
        , noelv_memsize => noelv_memsize
        , reset_strategy => reset_strategy
        , baud_rate => baud_rate
    )
    port map(
        sys_clk_p => clk,
        sys_clk_n => clk_n,
        reset_n => reset_n,
        mgt_clk0_n => mgt_clk_n,
        mgt_clk0_p => mgt_clk,
        key1_n => '1',
        key2_n => '1',
        key3_n => '1',
        key4_n => '1',
        led1 => led1,
        led2 => led2,
        led3 => led3,
        led4 => led4,

        ddr3_dqs_p => ddr3_dqs_p,
        ddr3_dqs_n => ddr3_dqs_n,
        ddr3_dq_p => ddr3_dq_p,
        ddr3_dm => ddr3_dm,
        ddr3_a => ddr3_a,
        ddr3_ba => ddr3_ba,
        ddr3_s0 => cs_n,
        ddr3_ras => ddr3_ras,
        ddr3_cas => ddr3_cas,
        ddr3_we => ddr3_we,
        ddr3_odt => ddr3_odt,
        ddr3_reset => ddr3_reset,
        ddr3_cke => ddr3_cke,
        ddr3_clk_p => ddr3_clk_p,
        ddr3_clk_n => ddr3_clk_n,

        uart1_txd => txd,
        uart1_rxd => rxd
    );

    --! The simulated RAM on the physical board.
    ram0: entity a200t_ddr3.a200t_ddr3
    port map(
        ddr3_dqs => ddr3_dqs_p
        , ddr3_dqs_n => ddr3_dqs_n
        , ddr3_dq => ddr3_dq_p
        , ddr3_dm => ddr3_dm
        , ddr3_a => ddr3_a
        , ddr3_ba => ddr3_ba
        , ddr3_ras => ddr3_ras
        , ddr3_cas => ddr3_cas
        , ddr3_we => ddr3_we
        , ddr3_odt => ddr3_odt
        , clk_n => ddr3_clk_n
        , clk_p => ddr3_clk_p
        , ddr3_cke => ddr3_cke
        , rst_n => ddr3_reset
        , cs_n => cs_n
        , tdqs_n => open
    );

end architecture;
