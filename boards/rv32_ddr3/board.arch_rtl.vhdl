-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
library a200t;
library a200t_constants;
library wb;
use wb.signals;
library ddr3;
library serving;
library uberddr3;

architecture rtl of board is
    -- Clocks
    -- clk: 200MHz.
    signal clk, locked, reset: std_ulogic;
    signal clk100, clk400pi0, clk200, clk400pi2: std_ulogic;

    -- UART
    signal uart1_host: wb.host.bus_type;
    signal uart1_per: wb.per.bus_type;
    signal i_wb: signals.i_wb;
    signal o_wb: signals.o_wb;
    signal txd, rxd: std_ulogic;
    signal uart1_irq: std_ulogic;
    signal uart1_en: std_ulogic;

    -- DDR3 RAM
    signal ddr3_ports: ddr3.phy32.host_type;
    signal ram0_wb_host: wb.host.bus_type;
    signal ram0_wb_per: wb.per.bus_type;

    -- RV32
    signal cpu0_timer_irq: std_ulogic;
    signal cpu0_per_in: wb.per.bus_type;
    signal cpu0_host_out, cpu0_host_out_raw: wb.host.bus_type;
    signal cpu0_per_in_old: wb.signals.i_wb;

    -- timer
    signal timer0_per: wb.per.bus_type;
    signal timer0_irq: std_ulogic;

    -- pic
    signal pic0_per: wb.per.bus_type;
    signal pic0_irqi: std_ulogic_vector(1 downto 0);

    subtype wb_mux_t is wb.signals.rdt_mux_in_t(3 downto 0);

    signal wb_mux: wb_mux_t;

    signal ram_inited: std_ulogic;
    signal cpu0_reset: std_ulogic;

    constant cpu0_is_sim: natural := 1 when IS_SIMULATION else 0;
begin

    cpu0_host_out <= wb.host.new_bus_type when reset = '1'
                     else cpu0_host_out_raw;

    clk0: entity a200t.clk
    port map (
        clk_p => sys_clk_p,
        clk_n => sys_clk_n,
        clk => clk
    );

    clkgen0: entity a200t.clkgen_complex
    port map(
        clk200MHz => clk,
        clkout0 => clk100,
        clkout1 => clk400pi0,
        clkout2 => clk200,
        clkout3 => clk400pi2,
        locked => locked
    );

    leds0: entity a200t.leds
    port map(
        clk => clk100,
        locked => locked,
        reset_n => reset_n,
        led1 => led1,
        led2 => led2,
        led3 => led3,
        led4 => open, -- led4,
        reset => reset
    );

    uart1_txd <= txd;
    rxd <= uart1_rxd;
    led4 <= not cpu0_reset;
    --led3 <= not cpu0_timer_irq;
    --led2 <= not cpu0_host_out.adr(31);
    --led1 <= not cpu0_host_out.adr(30);

    o_wb <= wb.host.into_old_type(uart1_host);
    uart1_per <= wb.per.from_old_type(i_wb);
    uart1_en <= '1' when (cpu0_host_out.cyc = '1'
                   and cpu0_host_out.adr(31 downto 30) = "01")
             else '0';
    uart1_host <= (
        adr => cpu0_host_out.adr,
        dat => cpu0_host_out.dat,
        we => cpu0_host_out.we,
        sel => cpu0_host_out.sel,
        cyc => uart1_en
    );
    uart1: entity a200t.uart
    generic map(
        clock_frequency => 100_000_000 -- Mhz
        , baud_rate => baud_rate
        , uart_address => x"4000_0010"
    )
    port map(
        clk => clk100,
        reset => reset,

        txd => txd,
        rxd => rxd,

        o_wb => o_wb,
        i_wb => i_wb

        , irq => uart1_irq
    );

    ddr3_ba <= ddr3_ports.ba;
    ddr3_a <= ddr3_ports.addr;
    ddr3_dm <= ddr3_ports.dm;
    ddr3_s0 <= ddr3_ports.cs_n;
    ddr3_ras <= ddr3_ports.ras_n;
    ddr3_cas <= ddr3_ports.cas_n;
    ddr3_we <= ddr3_ports.we_n;
    ddr3_odt <= ddr3_ports.odt;
    ddr3_reset <= ddr3_ports.reset_n;
    ddr3_cke <= ddr3_ports.cke;
    ddr3_clk_p <= ddr3_ports.ck_p;
    ddr3_clk_n <= ddr3_ports.ck_n;
    -- Decode ram address that starts with `10`.
    ram0_wb_host <=  cpu0_host_out when cpu0_host_out.adr(31 downto 30) = "10"
                     else wb.host.new_bus_type;
    is_simulation_gen: if is_simulation generate
        ram0: entity a200t.ram(sim)
        generic map(
            is_simulation => is_simulation
            , controller_clk_period_ps => 10000 -- 100MHz, 10ns
            , ddr3_clk_period_ps => 2500 -- 400MHz, 2.5ns
        )
        port map(
            clk => clk100,
            rst => reset,

            clk_ddr => clk400pi0,
            clk_ddr90 => clk400pi2,
            clk_ref => clk200,

            ddr3_ports => ddr3_ports,
            --This does not work
            --ddr3_inout => ddr3_inout,
            --using unpacked instead:
            ddr3_dqs_n => ddr3_dqs_n,
            ddr3_dqs_p => ddr3_dqs_p,
            ddr3_dq => ddr3_dq_p,
            wb_host => ram0_wb_host,
            wb_per => ram0_wb_per,

            calib_complete => ram_inited,
            uart_tx => open,
            user_self_refresh => '0', -- XXX: ????
            debug => open
        );
    end generate;

    is_rtl_gen: if not is_simulation generate
        ram0: entity a200t.ram(xilinx_rtl)
        generic map(
            is_simulation => is_simulation
            , controller_clk_period_ps => 10000 -- 100MHz, 10ns
            , ddr3_clk_period_ps => 2500 -- 400MHz, 2.5ns
        )
        port map(
            clk => clk100,
            rst => reset,

            clk_ddr => clk400pi0,
            clk_ddr90 => clk400pi2,
            clk_ref => clk200,

            ddr3_ports => ddr3_ports,
            --This does not work
            --ddr3_inout => ddr3_inout,
            --using unpacked instead:
            ddr3_dqs_n => ddr3_dqs_n,
            ddr3_dqs_p => ddr3_dqs_p,
            ddr3_dq => ddr3_dq_p,
            wb_host => ram0_wb_host,
            wb_per => ram0_wb_per,

            calib_complete => ram_inited,
            uart_tx => open,
            user_self_refresh => '0', -- XXX: ????
            debug => open
        );
    end generate;


    cpu0_reset <= reset or (not ram_inited);
    cpu0: entity serving.serving
    generic map(
        RESET_STRATEGY => reset_strategy,
        memfile => memfile,
        memsize => memsize,
        sim => cpu0_is_sim,
        WITH_CSR => 1
    )
    port map(
        i_clk => clk100,
        i_rst => cpu0_reset, -- Wait until ram is initialized to start the cpu.
        i_timer_irq => '0', -- cpu0_timer_irq,

        o_wb_adr => cpu0_host_out_raw.adr,
        o_wb_dat => cpu0_host_out_raw.dat,
        o_wb_sel => cpu0_host_out_raw.sel,
        o_wb_we => cpu0_host_out_raw.we,
        o_wb_stb => cpu0_host_out_raw.cyc,

        i_wb_rdt => cpu0_per_in.rdt,
        i_wb_ack => cpu0_per_in.ack
    );

    -- Wishbone return path peripheral multiplexer.
    wb_mux <= (
        -- All peripherals here.
        0 => wb.per.into_old_type(ram0_wb_per)
        , 1 => wb.per.into_old_type(uart1_per)
        , 2 => wb.per.into_old_type(timer0_per)
        , 3 => wb.per.into_old_type(pic0_per)
    );
    cpu0_per_in <= wb.per.from_old_type(cpu0_per_in_old);
    wb_mux0: entity wb.rdt_mux port map(
        rst => reset,
        input => wb_mux,
        output => cpu0_per_in_old
    );

    timer0: entity wb.timer
    generic map(
        base_address => x"4000_0020"
    )
    port map(
        clk => clk100,
        reset => reset
        , wbi => cpu0_host_out
        , wbo => timer0_per
        , irq => timer0_irq
    );

    pic0_irqi <= (
        0 => timer0_irq
        , 1 => uart1_irq
    );
    pic0: entity wb.pic
    generic map(
        base_address => x"4000_0030"
    )
    port map(
        clk => clk100,
        reset => reset
        , wbi => cpu0_host_out
        , wbo => pic0_per
        , irqo => cpu0_timer_irq
        , irqi => pic0_irqi
    );
end architecture;

