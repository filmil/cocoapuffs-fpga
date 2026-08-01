-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
library a200t;
library a200t_constants;
library wb;
use wb.signals;
library ddr3;
library serv;
library uberddr3;
library general;
use general.types.all;
use ieee.numeric_std.all;

architecture rtl of board is
    --! Configuration for the CPU.
    type cpu_config_t is record
        --! The initial value of the program counter upon reset.
        RESET_PC: std_ulogic_vector(31 downto 0);
        --! Enables support for compressed instructions (RV32C) if non-zero.
        COMPRESSED: natural;
        --! Enables the Multiplication/Division Unit interface if non-zero.
        MDU: natural;
        --! If non-zero, registers signals before the decoder for better timing.
        PRE_REGISTER: natural;
        --! Enables Control and Status Registers if non-zero.
        WITH_CSR: natural;
        --! The bit-width of the register file (e.g., 2 for serial, 32 for parallel).
        RF_WIDTH: natural;
        --! Set to 1 if this is a simulation, 0 otherwise.
        is_sim: natural;
    end record;

    --! Configuration for the UART peripheral.
    type uart_config_t is record
        --! The frequency of the clock driving the UART (in Hz).
        clock_frequency: natural;
        --! The desired baud rate for serial communication.
        baud_rate: natural;
        --! The base address of the UART in the memory-mapped space.
        uart_address: std_ulogic_vector(31 downto 0);
    end record;

    --! Configuration for the BRAM (Block RAM) memory.
    type bram_config_t is record
        --! The base address of the BRAM in the memory-mapped space.
        base_address: std_ulogic_vector(31 downto 0);
        --! The total size of the BRAM in bytes.
        memsize: natural;
        --! The number of address bits used for register/memory indexing.
        reg_bit_count: natural;
    end record;

    --! Configuration for the main RAM (DDR3).
    type ram_config_t is record
        --! True if this is a simulation environment.
        is_simulation: boolean;
        --! The period of the memory controller clock in picoseconds.
        controller_clk_period_ps: positive;
        --! The period of the DDR3 physical clock in picoseconds.
        ddr3_clk_period_ps: positive;
        base_address: std_ulogic_vector(31 downto 0);
    end record;

    --! Configuration for the system timer.
    type timer_config_t is record
        --! The base address of the timer in the memory-mapped space.
        base_address: std_ulogic_vector(31 downto 0);
    end record;

    --! Configuration for the Programmable Interrupt Controller (PIC).
    type pic_config_t is record
        --! The base address of the PIC in the memory-mapped space.
        base_address: std_ulogic_vector(31 downto 0);
    end record;

    --! Master configuration record for the board.
    type config_t is record
        --! CPU-specific configuration.
        cpu: cpu_config_t;
        --! UART-specific configuration.
        uart: uart_config_t;
        --! BRAM-specific configuration.
        bram: bram_config_t;
        --! RAM-specific configuration.
        ram: ram_config_t;
        --! Timer-specific configuration.
        timer: timer_config_t;
        --! PIC-specific configuration.
        pic: pic_config_t;
        --! The number of ports for the CPU bus multiplexer.
        mux_ports: natural;
    end record;

    function to_natural(b: boolean) return natural is
    begin
        if b then return 1; else return 0; end if;
    end function;

    constant cfg: config_t := (
        cpu => (
            RESET_PC => x"00000000",
            COMPRESSED => 1,
            MDU => 0,
            PRE_REGISTER => 1,
            WITH_CSR => 1,
            RF_WIDTH => 32,
            is_sim => to_natural(IS_SIMULATION)
        ),
        uart => (
            clock_frequency => 100_000_000,
            baud_rate => baud_rate,
            uart_address => x"40000010"
        ),
        bram => (
            base_address => x"00000000",
            memsize => memsize,
            reg_bit_count => 18
        ),
        ram => (
            is_simulation => IS_SIMULATION,
            controller_clk_period_ps => 10000,
            ddr3_clk_period_ps => 2500,
            base_address => x"0000_0000"
        ),
        timer => (
            base_address => x"40000020"
        ),
        pic => (
            base_address => x"40000030"
        ),
        mux_ports => 2
    );

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

    -- BRAM
    signal bram0_wb_host: wb.host.bus_type;
    signal bram0_wb_per: wb.per.bus_type;

    -- RV32
    signal cpu0_timer_irq: std_ulogic;
    signal cpu0_per_in: wb.per.bus_type;
    signal cpu0_host_out, cpu0_host_out_raw: wb.host.bus_type;
    signal cpu0_per_in_old: wb.signals.i_wb;

    signal ibus_host: wb.host.bus_type;
    signal dbus_host: wb.host.bus_type;
    signal ibus_per: wb.per.bus_type;
    signal dbus_per: wb.per.bus_type;

    signal cpu0_mux_host_ports: wb.host.bus_array_t(1 downto 0);
    signal cpu0_mux_per_ports: wb.per.bus_array_t(1 downto 0);

    -- timer
    signal timer0_per: wb.per.bus_type;
    signal timer0_irq: std_ulogic;
    signal timer0_en: std_ulogic;

    -- pic
    signal pic0_per: wb.per.bus_type;
    signal pic0_irqi: std_ulogic_vector(1 downto 0);
    signal pic0_en: std_ulogic;

    signal ram_inited: std_ulogic;
    signal cpu0_reset: std_ulogic;
    signal bram_sel: std_ulogic;

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
        clock_frequency => cfg.uart.clock_frequency
        , baud_rate => cfg.uart.baud_rate
        , uart_address => cfg.uart.uart_address
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

    -- bram_sel is true if address is in the first 256KB.
    bram_sel <= '1' when (cpu0_host_out.adr(31 downto 18) = (31 downto 18 => '0')) else '0';

    -- Decode bram address: first 256KB of the first GB.
    bram0_wb_host <= cpu0_host_out when (cpu0_host_out.adr(31 downto 30) = "00" and bram_sel = '1')
                     else wb.host.new_bus_type;

    bram0: entity wb.bram
    generic map(
        base_address => cfg.bram.base_address,
        memfile => memfile,
        memsize => cfg.bram.memsize,
        reg_bit_count => cfg.bram.reg_bit_count
    )
    port map(
        clk => clk100,
        reset => reset,
        wbi => bram0_wb_host,
        wbo => bram0_wb_per
    );

    -- Decode ram address: the rest of the first GB.
    ram0_wb_host <=  cpu0_host_out when (cpu0_host_out.adr(31 downto 30) = "00" and bram_sel = '0')
                     else wb.host.new_bus_type;
    is_simulation_gen: if is_simulation generate
        ram0: entity a200t.ram(sim)
        generic map(
            is_simulation => cfg.ram.is_simulation
            , controller_clk_period_ps => cfg.ram.controller_clk_period_ps
            , ddr3_clk_period_ps => cfg.ram.ddr3_clk_period_ps
            , base_address => cfg.ram.base_address
        )
        port map(
            clk => clk100,
            rst => reset,

            clk_ddr => clk400pi0,
            clk_ddr90 => clk400pi2,
            clk_ref => clk200,

            ddr3_ports => ddr3_ports,
            ddr3_dqs_n => ddr3_dqs_n,
            ddr3_dqs_p => ddr3_dqs_p,
            ddr3_dq => ddr3_dq_p,
            wb_host => ram0_wb_host,
            wb_per => ram0_wb_per,

            calib_complete => ram_inited,
            uart_tx => open,
            user_self_refresh => '0',
            debug => open
        );
    end generate;

    is_rtl_gen: if not is_simulation generate
        ram0: entity a200t.ram(xilinx_rtl)
        generic map(
            is_simulation => cfg.ram.is_simulation
            , controller_clk_period_ps => cfg.ram.controller_clk_period_ps
            , ddr3_clk_period_ps => cfg.ram.ddr3_clk_period_ps
            , base_address => cfg.ram.base_address
        )
        port map(
            clk => clk100,
            rst => reset,

            clk_ddr => clk400pi0,
            clk_ddr90 => clk400pi2,
            clk_ref => clk200,

            ddr3_ports => ddr3_ports,
            ddr3_dqs_n => ddr3_dqs_n,
            ddr3_dqs_p => ddr3_dqs_p,
            ddr3_dq => ddr3_dq_p,
            wb_host => ram0_wb_host,
            wb_per => ram0_wb_per,

            calib_complete => ram_inited,
            uart_tx => open,
            user_self_refresh => '0',
            debug => open
        );
    end generate;

    -- Debug WB signals - since xsim can't display structs in vcd.
    cpu0_host_debug: entity wb.debug_host port map(i => cpu0_host_out);
    cpu0_per_debug: entity wb.debug_per port map(i => cpu0_per_in);

    -- cpu0: Processor.
    cpu0_reset <= reset or (not ram_inited);
    cpu0: entity serv.serv_rf_top
    generic map(
        RESET_PC => cfg.cpu.RESET_PC,
        COMPRESSED => cfg.cpu.COMPRESSED,
        MDU => cfg.cpu.MDU,
        PRE_REGISTER => cfg.cpu.PRE_REGISTER,
        RESET_STRATEGY => reset_strategy,
        WITH_CSR => cfg.cpu.WITH_CSR,
        RF_WIDTH => cfg.cpu.RF_WIDTH
    )
    port map(
        clk => clk100,
        i_rst => cpu0_reset,
        i_timer_irq => cpu0_timer_irq,

        o_ibus_adr => ibus_host.adr,
        o_ibus_cyc => ibus_host.cyc,
        i_ibus_rdt => ibus_per.rdt,
        i_ibus_ack => ibus_per.ack,

        o_dbus_adr => dbus_host.adr,
        o_dbus_dat => dbus_host.dat,
        o_dbus_sel => dbus_host.sel,
        o_dbus_we => dbus_host.we,
        o_dbus_cyc => dbus_host.cyc,
        i_dbus_rdt => dbus_per.rdt,
        i_dbus_ack => dbus_per.ack,

        o_ext_rs1 => open,
        o_ext_rs2 => open,
        o_ext_funct3 => open,
        i_ext_rd => x"00000000",
        i_ext_ready => '0',
        o_mdu_valid => open
    );

    ibus_host.dat <= (others => '0');
    ibus_host.we <= '0';
    ibus_host.sel <= (others => '1');

    cpu0_mux_host_ports(0) <= ibus_host;
    cpu0_mux_host_ports(1) <= dbus_host;
    ibus_per <= cpu0_mux_per_ports(0);
    dbus_per <= cpu0_mux_per_ports(1);

    cpu0_mux: entity wb.wb_mux
    generic map(
        PORTS_COUNT => cfg.mux_ports
    )
    port map(
        clk => clk100,
        rst => reset,
        host_ports => cpu0_mux_host_ports,
        per_ports => cpu0_mux_per_ports,
        host_port => cpu0_host_out_raw,
        per_port => cpu0_per_in
    );

    -- Wishbone return path peripheral multiplexer.
    wb_mux0: entity wb.rdt_mux
    port map(
        rst => reset,
        input(0) => wb.per.into_old_type(ram0_wb_per),
        input(1) => wb.per.into_old_type(uart1_per),
        input(2) => wb.per.into_old_type(timer0_per),
        input(3) => wb.per.into_old_type(pic0_per),
        input(4) => wb.per.into_old_type(bram0_wb_per),
        output => cpu0_per_in_old
    );
    cpu0_per_in <= wb.per.from_old_type(cpu0_per_in_old);

    timer0: entity wb.timer
    generic map(
        base_address => cfg.timer.base_address
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
        base_address => cfg.pic.base_address
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
