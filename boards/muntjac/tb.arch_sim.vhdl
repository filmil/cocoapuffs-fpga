-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
library std;
use std.textio;
library testing;

architecture sim of tb is
    constant bit_period: time := 1.0/baud_rate * 1000 ms;

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

    --! Used for UART communication.
    shared variable InQ: adt.strings.QueueP := adt.strings.NewQueue;
    signal tb_rx, tb_tx: std_logic;
begin

    -- Wire up the UART pins between TB nd uart1.
    tb_rx <= txd;
    rxd <= tb_tx;

    -- Testbench UART send / receive.
    rcv0: process is
        variable rcv: string(1 to adt.strings.MaxString);
        variable l: textio.line;
    begin
        loop
            testing.uart.rcv_string(bit_period, rcv, tb_rx);
            textio.write(l, rcv);
            textio.writeline(textio.output, l);
        end loop;
    end process;

    snd0: process is
    begin
        tb_tx <= '1';
        wait until reset = '0';
        wait for 4 us;
        testing.uart.send_string(bit_period, ":0800000067800000678000002A" & CR & LF, tb_tx);
        wait for 4 us;
        testing.uart.send_string(bit_period, ":00000001FF" & CR & LF, tb_tx);
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
    uut0: entity muntjac_board.board(rtl)
    generic map (
        is_simulation => is_simulation
        , memfile => memfile
        , memsize => memsize
        , reset_strategy => reset_strategy
        , baud_rate => baud_rate
        , muntjac_memfile => muntjac_memfile
        , muntjac_memsize => muntjac_memsize
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

configuration cfg_tb of tb is
    for sim
    end for;
end configuration;
