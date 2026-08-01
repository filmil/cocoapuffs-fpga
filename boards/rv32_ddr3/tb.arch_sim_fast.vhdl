-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_textio.all;
use std.textio.all;
library vunit;
use vunit.string_ops;
library adt;

architecture sim_fast of tb is
    file prog_file: text open read_mode is program_file;

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

    tb_rx <= txd;
    rxd <= 'H';
    -- Testbench UART send / receive.
    rcv0: process is
        variable rcv: string(1 to adt.strings.MaxString);
        variable l: textio.line;
        variable lfpos: natural;
    begin
        loop
            testing.uart.rcv_string(bit_period, rcv, tb_rx);
            lfpos := string_ops.find(rcv, LF);
            textio.write(l, rcv(1 to lfpos));
            textio.writeline(textio.output, l);
            adt.strings.PushFront(InQ, rcv);
        end loop;
    end process;

    snd0: process is
        variable s: string(1 to adt.strings.MaxString);
        variable e: boolean;
        variable l: textio.line;
    begin
        loop
            wait for 10 ns;
            --adt.strings.PopBack(InQ, s, e);
            if e = false then
                if program_file /= "" then
                end if;
            end if;
        end loop;
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
    uut0: entity rv32_ddr3.board
    generic map (
        is_simulation => is_simulation
        , memfile => memfile
        , memsize => memsize
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

end architecture;

configuration cfg_tb_fast of tb is
    for sim_fast
    end for;
end configuration;
