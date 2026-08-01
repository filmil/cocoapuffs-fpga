-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library a200t;
library a200t_constants;
library wb;
use wb.signals;
library ddr3;
library serving;
library uberddr3;
library tl;
use tl.types.all;
library general;

architecture rtl of board is
    -- Clocks
    -- clk: 200MHz.
    signal clk, locked, reset: std_ulogic;
    signal clk50, clk100, clk400pi0, clk200, clk400pi2: std_ulogic;

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
    signal cpu0_host_out_ram: wb.host.bus_type;

    -- timer
    signal timer0_per: wb.per.bus_type;
    signal timer0_irq: std_ulogic;

    -- pic
    signal pic0_per: wb.per.bus_type;
    signal pic0_irqi: std_ulogic_vector(1 downto 0);

    -- percontrol
    signal percontrol_per: wb.per.bus_type;
    signal perctl_out: std_ulogic_vector(31 downto 0);
    signal muntjac_reset: std_ulogic;

    -- perinput
    signal perinput_per: wb.per.bus_type;
    constant MUNTJAC_OUT_BITS: natural := 143 + 1 + 135 + 1 + 1; -- mem_a_o, mem_a_valid, mem_c_o, mem_e_o, mem_e_valid
    signal perin_bits: std_ulogic_vector(MUNTJAC_OUT_BITS-1 downto 0);

    -- WB MUX
    subtype wb_mux_t is wb.signals.rdt_mux_in_t(5 downto 0);
    signal wb_mux: wb_mux_t;

    signal ram_inited: std_ulogic;
    signal cpu0_reset: std_ulogic;

    constant cpu0_is_sim: natural := 1 when IS_SIMULATION else 0;

    -- Muntjac
    signal muntjac_tl_host: tl.types.host_type_c;
    signal muntjac_tl_per: tl.types.per_type_c;

    signal muntjac_wb_host_50: wb.host.bus_type;
    signal muntjac_wb_per_50: wb.per.bus_type;
    signal muntjac_wb_host_100: wb.host.bus_type;
    signal muntjac_wb_per_100: wb.per.bus_type;
    signal muntjac_ram_en: std_ulogic;
    signal muntjac_ram_host: wb.host.bus_type;
    signal muntjac_uart_host: wb.host.bus_type;
    signal muntjac_bram_host: wb.host.bus_type;
    signal muntjac_ram_per: wb.per.bus_type;
    signal muntjac_uart_per: wb.per.bus_type;
    signal muntjac_bram_per: wb.per.bus_type;
    signal muntjac_bram_en: std_ulogic;

    signal ddr3_mux_hosts: wb.host.bus_array_t(1 downto 0);
    signal ddr3_mux_pers: wb.per.bus_array_t(1 downto 0);

    signal uart16550_txd, uart16550_rxd: std_logic;
    signal uart1_txd_mux, uart1_rxd_mux: std_logic;

    signal muntjac_mem_a_o: std_logic_vector(142 downto 0);
    signal muntjac_mem_b_i: std_logic_vector(69 downto 0) := (others => '0');
    signal muntjac_mem_c_o: std_logic_vector(134 downto 0);
    signal muntjac_mem_d_i: std_logic_vector(80 downto 0);
    signal muntjac_mem_e_o: std_logic_vector(0 downto 0);

    signal muntjac_mem_a_valid: std_logic;
    signal muntjac_mem_d_ready: std_logic;
    signal muntjac_ready_en: std_logic;

    signal muntjac_tl_host_a: tl.types.a_type;


    -- Muntjac Component
    component muntjac_core_wrapper is
        port (
            clk_i: in std_logic;
            rst_ni: in std_logic;
            mem_a_ready_i: in std_logic;
            mem_a_valid_o: out std_logic;
            mem_a_o: out std_logic_vector(142 downto 0);

            mem_b_ready_o: out std_logic;
            mem_b_valid_i: in std_logic;
            mem_b_i: in std_logic_vector(69 downto 0);

            mem_c_ready_i: in std_logic;
            mem_c_valid_o: out std_logic;
            mem_c_o: out std_logic_vector(134 downto 0);

            mem_d_ready_o: out std_logic;
            mem_d_valid_i: in std_logic;
            mem_d_i: in std_logic_vector(80 downto 0);

            mem_e_ready_i: in std_logic;
            mem_e_valid_o: out std_logic;
            mem_e_o: out std_logic_vector(0 downto 0);

            irq_software_m_i: in std_logic;
            irq_timer_m_i: in std_logic;
            irq_external_m_i: in std_logic;
            irq_external_s_i: in std_logic;
            hart_id_i: in std_logic_vector(63 downto 0);
            hpm_event_i: in std_logic_vector(9 downto 0)
        );
    end component;

    -- UART16550 Component
    component uart_top is
        port (
            wb_clk_i: in std_logic;
            wb_rst_i: in std_logic;
            wb_adr_i: in std_logic_vector(2 downto 0);
            wb_dat_i: in std_logic_vector(7 downto 0);
            wb_dat_o: out std_logic_vector(7 downto 0);
            wb_we_i: in std_logic;
            wb_stb_i: in std_logic;
            wb_cyc_i: in std_logic;
            wb_ack_o: out std_logic;
            wb_sel_i: in std_logic_vector(3 downto 0);
            int_o: out std_logic;
            stx_pad_o: out std_logic;
            srx_pad_i: in std_logic;
            rts_pad_o: out std_logic;
            cts_pad_i: in std_logic;
            dtr_pad_o: out std_logic;
            dsr_pad_i: in std_logic;
            ri_pad_i: in std_logic;
            dcd_pad_i: in std_logic
        );
    end component;

    signal uart16550_dat_o: std_logic_vector(7 downto 0);
    signal uart16550_en: std_ulogic;

    --! @brief Computes the UART enable signal based on Wishbone cycle and address.
    --! @details This procedure qualifies the UART transaction by checking if the
    --!          Wishbone cycle is active and if the upper address bits match the
    --!          designated UART base address prefix (0x80000000).
    --! @param cyc The Wishbone cycle signal.
    --! @param adr The Wishbone address bus.
    --! @param en  The resulting output enable signal.
    procedure update_uart_en(
        signal cyc : in std_ulogic;
        signal adr : in std_ulogic_vector(31 downto 0);
        signal en  : out std_ulogic
    ) is
        constant MUNTJAC_UART_BASE : std_ulogic_vector(31 downto 0) := x"40000010";
    begin
        if cyc = '1' and adr(31 downto 4) = MUNTJAC_UART_BASE(31 downto 4) then
            en <= '1';
        else
            en <= '0';
        end if;
    end procedure;

    --! @brief Computes the UART1 enable signal based on Wishbone cycle and address.
    --! @details This procedure qualifies the UART1 transaction by checking if the
    --!          Wishbone cycle is active and if the address bits match the
    --!          designated UART1 address range (0x40000000 - 0x7FFFFFFF).
    --! @param cyc The Wishbone cycle signal.
    --! @param adr The Wishbone address bus.
    --! @param en  The resulting output enable signal.
    procedure update_uart1_en(
        signal cyc : in std_ulogic;
        signal adr : in std_ulogic_vector(31 downto 0);
        signal en  : out std_ulogic
    ) is
    begin
        if cyc = '1' and adr(31 downto 30) = "01" then
            en <= '1';
        else
            en <= '0';
        end if;
    end procedure;

    --! @brief Multiplexes the Wishbone peripheral return buses.
    --! @details Routes the appropriate peripheral bus response back to the host
    --!          based on the active cycle demux signal.
    --! @param cyc_out The one-hot demultiplexer output indicating the active target.
    --! @param ram_per The Wishbone return bus from the RAM subsystem.
    --! @param uart_per The Wishbone return bus from the UART subsystem.
    --! @param wb_per The resulting multiplexed return bus.
    procedure mux_wb_per(
        signal cyc_out  : in std_ulogic_vector(1 downto 0);
        signal ram_per  : in wb.per.bus_type;
        signal uart_per : in wb.per.bus_type;
        signal wb_per   : out wb.per.bus_type
    ) is
    begin
        if cyc_out(0) = '1' then
            wb_per <= ram_per;
        elsif cyc_out(1) = '1' then
            wb_per <= uart_per;
        else
            wb_per <= wb.per.new_bus_type;
        end if;
    end procedure;

    --! @brief Routes Wishbone host signals based on a cycle multiplexer.
    --! @details Assigns the host bus signals and specifically sets the cycle
    --!          signal based on the provided cycle demultiplexer output or enable signal.
    --! @param cyc       The cycle signal to assign.
    --! @param host_in   The host bus containing address, data, select, and write enable.
    --! @param host_out  The resulting routed host bus.
    procedure route_wb_host(
        signal cyc       : in std_ulogic;
        signal host_in   : in wb.host.bus_type;
        signal host_out  : out wb.host.bus_type
    ) is
    begin
        host_out.cyc <= cyc;
        host_out.adr <= host_in.adr;
        host_out.dat <= host_in.dat;
        host_out.sel <= host_in.sel;
        host_out.we  <= host_in.we;
    end procedure;

    --! @brief Assembles the Wishbone multiplexer input array for the CPU.
    --! @details Gathers the peripheral bus responses into a single array for the rdt_mux.
    --! @param ddr3_per   The DDR3 Wishbone peripheral response.
    --! @param uart_per   The UART Wishbone peripheral response.
    --! @param timer_per  The Timer Wishbone peripheral response.
    --! @param pic_per    The PIC Wishbone peripheral response.
    --! @param perctl_per The Peripheral Control Wishbone peripheral response.
    --! @param perinput_per The Peripheral Input Wishbone peripheral response.
    --! @param mux_in     The resulting multiplexer input array.
    procedure assemble_wb_mux(
        signal ddr3_per   : in wb.per.bus_type;
        signal uart_per   : in wb.per.bus_type;
        signal timer_per  : in wb.per.bus_type;
        signal pic_per    : in wb.per.bus_type;
        signal perctl_per : in wb.per.bus_type;
        signal perinput_per : in wb.per.bus_type;
        signal mux_in     : out wb_mux_t
    ) is
    begin
        mux_in(0) <= wb.per.into_old_type(ddr3_per);
        mux_in(1) <= wb.per.into_old_type(uart_per);
        mux_in(2) <= wb.per.into_old_type(timer_per);
        mux_in(3) <= wb.per.into_old_type(pic_per);
        mux_in(4) <= wb.per.into_old_type(perctl_per);
        mux_in(5) <= wb.per.into_old_type(perinput_per);
    end procedure;

    --! @brief Unpacks the TileLink Channel A packed vector into a VHDL record.
    --! @details Slices the 143-bit SystemVerilog-compatible packed vector into
    --!          the individual fields of the 32-bit VHDL a_type record.
    --! @param packed_a The 143-bit packed vector from muntjac_core.
    --! @param record_a The resulting VHDL a_type record.
    procedure unpack_tl_a(
        signal packed_a : in std_logic_vector(142 downto 0);
        signal record_a : out a_type
    ) is
    begin
        record_a.opcode <= packed_a(142 downto 140);
        record_a.param <= packed_a(139 downto 137);
        record_a.size <= packed_a(135 downto 133);
        record_a.source <= "0000" & packed_a(132 downto 129);
        record_a.address <= packed_a(104 downto 73);
        record_a.mask <= packed_a(68 downto 65);
        record_a.corrupt <= packed_a(64);
        record_a.data <= packed_a(31 downto 0);
    end procedure;

    --! @brief Packs a VHDL TileLink Channel D record into a SystemVerilog vector.
    --! @details Assembles the 81-bit SystemVerilog-compatible packed vector from
    --!          the individual fields of the 32-bit VHDL d_type record.
    --! @param record_d The VHDL d_type record from the converter.
    --! @param packed_d The resulting 81-bit packed vector for muntjac_core.
    procedure pack_tl_d(
        signal record_d : in d_type;
        signal packed_d : out std_logic_vector(80 downto 0)
    ) is
    begin
        packed_d(80 downto 78) <= record_d.opcode;
        packed_d(77 downto 75) <= record_d.param;
        packed_d(74 downto 71) <= '0' & record_d.size;
        packed_d(70 downto 67) <= record_d.source(3 downto 0);
        packed_d(66) <= record_d.sink(0);
        packed_d(65) <= '0';
        packed_d(64) <= record_d.corrupt;
        packed_d(63 downto 0) <= x"00000000" & record_d.data;
    end procedure;
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
        clkout4 => clk50, -- Actually 50MHz now!
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
        led4 => open,
        reset => reset
    );

    -- Multiplexing UART TX and RX based on perctl_out(1)
    uart1_txd <= uart1_txd_mux when perctl_out(1) = '0' else uart16550_txd;
    uart1_rxd_mux <= uart1_rxd;
    uart16550_rxd <= std_logic(uart1_rxd);

    led4 <= not cpu0_reset;

    o_wb <= wb.host.into_old_type(uart1_host);
    uart1_per <= wb.per.from_old_type(i_wb);
    update_uart1_en(cpu0_host_out.cyc, cpu0_host_out.adr, uart1_en);
    route_wb_host(uart1_en, cpu0_host_out, uart1_host);
    uart1: entity a200t.uart
    generic map(
        clock_frequency => 100_000_000,
        baud_rate => baud_rate,
        uart_address => x"4000_0010"
    )
    port map(
        clk => clk100,
        reset => reset,
        txd => uart1_txd_mux,
        rxd => uart1_rxd_mux,
        o_wb => o_wb,
        i_wb => i_wb,
        irq => uart1_irq
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

    -- RV32 to DDR3 Decode
    cpu0_host_out_ram <= cpu0_host_out when cpu0_host_out.adr(31 downto 30) = "10"
                     else wb.host.new_bus_type;

    ddr3_mux_hosts(0) <= cpu0_host_out_ram;
    ddr3_mux_hosts(1) <= muntjac_ram_host;

    -- DDR3 Wishbone Multiplexer
    ddr3_wb_mux: entity wb.wb_mux
    generic map (
        PORTS_COUNT => 2
    )
    port map (
        clk => clk100,
        rst => reset,
        host_ports => ddr3_mux_hosts,
        per_ports => ddr3_mux_pers,
        host_port => ram0_wb_host,
        per_port => ram0_wb_per
    );

    muntjac_ram_per <= ddr3_mux_pers(1);

    is_simulation_gen: if is_simulation generate
        ram0: entity a200t.ram(sim)
        generic map(
            is_simulation => is_simulation,
            controller_clk_period_ps => 10000,
            ddr3_clk_period_ps => 2500
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
            is_simulation => is_simulation,
            controller_clk_period_ps => 10000,
            ddr3_clk_period_ps => 2500
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
        i_rst => cpu0_reset,
        i_timer_irq => '0',

        o_wb_adr => cpu0_host_out_raw.adr,
        o_wb_dat => cpu0_host_out_raw.dat,
        o_wb_sel => cpu0_host_out_raw.sel,
        o_wb_we => cpu0_host_out_raw.we,
        o_wb_stb => cpu0_host_out_raw.cyc,

        i_wb_rdt => cpu0_per_in.rdt,
        i_wb_ack => cpu0_per_in.ack
    );

    assemble_wb_mux(ddr3_mux_pers(0), uart1_per, timer0_per, pic0_per, percontrol_per, perinput_per, wb_mux);
    cpu0_per_in <= wb.per.from_old_type(cpu0_per_in_old);
    wb_mux0: entity wb.rdt_mux
    port map(
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
        reset => reset,
        wbi => cpu0_host_out,
        wbo => timer0_per,
        irq => timer0_irq
    );

    pic0_irqi <= (
        0 => timer0_irq,
        1 => uart1_irq
    );
    pic0: entity wb.pic
    generic map(
        base_address => x"4000_0030"
    )
    port map(
        clk => clk100,
        reset => reset,
        wbi => cpu0_host_out,
        wbo => pic0_per,
        irqo => cpu0_timer_irq,
        irqi => pic0_irqi
    );

    percontrol0: entity wb.percontrol
    generic map(
        base_address => x"4000_0040",
        initial_value => x"0000_0001"
    )
    port map(
        clk => clk100,
        reset => reset,
        wbi => cpu0_host_out,
        wbo => percontrol_per,
        perctl => perctl_out
    );
    muntjac_reset <= perctl_out(0);

    perin_bits(142 downto 0) <= std_ulogic_vector(muntjac_mem_a_o);
    perin_bits(143) <= muntjac_mem_a_valid;
    perin_bits(278 downto 144) <= std_ulogic_vector(muntjac_mem_c_o);
    perin_bits(279) <= muntjac_mem_e_o(0);
    perin_bits(280) <= '0'; -- Placeholder for mem_e_valid if needed, or just 0

    perinput0: entity wb.perinput
    generic map(
        base_address => x"4000_0050",
        num_bits => MUNTJAC_OUT_BITS
    )
    port map(
        clk => clk100,
        reset => reset,
        wbi => cpu0_host_out,
        wbo => perinput_per,
        perin => perin_bits
    );

    muntjac_ready_en <= '1' when muntjac_reset = '0' and cpu0_reset = '0' else '0';

    -- Muntjac instantiation
    muntjac_core_inst: muntjac_core_wrapper
    port map (
        clk_i => clk50,
        rst_ni => not (muntjac_reset or cpu0_reset),
        mem_a_ready_i => muntjac_tl_per.a_ready and muntjac_ready_en,
        mem_a_valid_o => muntjac_mem_a_valid,
        mem_a_o => muntjac_mem_a_o,

        mem_b_ready_o => open,
        mem_b_valid_i => '0',
        mem_b_i => (others => '0'),

        mem_c_ready_i => muntjac_ready_en,
        mem_c_valid_o => open,
        mem_c_o => open,

        mem_d_ready_o => muntjac_mem_d_ready,
        mem_d_valid_i => muntjac_tl_per.d.valid and muntjac_ready_en,
        mem_d_i => muntjac_mem_d_i,

        mem_e_ready_i => muntjac_ready_en,
        mem_e_valid_o => open,
        mem_e_o => open,

        irq_software_m_i => '0',
        irq_timer_m_i => '0',
        irq_external_m_i => '0',
        irq_external_s_i => '0',
        hart_id_i => (others => '0'),
        hpm_event_i => (others => '0')
    );

    unpack_tl_a(muntjac_mem_a_o, muntjac_tl_host_a);
    muntjac_tl_host <= (
        a => (
            valid => muntjac_mem_a_valid,
            opcode => muntjac_tl_host_a.opcode,
            param => muntjac_tl_host_a.param,
            size => muntjac_tl_host_a.size,
            source => muntjac_tl_host_a.source,
            address => muntjac_tl_host_a.address,
            mask => muntjac_tl_host_a.mask,
            corrupt => muntjac_tl_host_a.corrupt,
            data => muntjac_tl_host_a.data
        ),
        b_ready => '0',
        c => c_type_new,
        d_ready => muntjac_mem_d_ready,
        e => e_type_new
    );

    pack_tl_d(muntjac_tl_per.d, muntjac_mem_d_i);

    -- TL to WB converter (running at 50MHz in muntjac domain)
    muntjac_tl2wb: entity tl.tl_c2wblite
    port map(
        clk => clk50,
        rst => muntjac_reset or cpu0_reset,
        tl_i => muntjac_tl_host,
        tl_o => muntjac_tl_per,
        wb_o => muntjac_wb_host_50,
        wb_i => muntjac_wb_per_50
    );

    -- Clock Domain Crossing (CDC) Bridge (from 50MHz to 100MHz)
    muntjac_wb_bridge: entity general.wb_cdc
    port map(
        clk_host => clk50,
        clk_per => clk100,
        rst => muntjac_reset or cpu0_reset,
        host_i => muntjac_wb_host_50,
        host_o => muntjac_wb_per_50,
        per_o => muntjac_wb_host_100,
        per_i => muntjac_wb_per_100
    );

    -- Decode UART, BRAM, and RAM enables in the 100MHz domain
    update_uart_en(muntjac_wb_host_100.cyc, muntjac_wb_host_100.adr, uart16550_en);
    muntjac_bram_en <= '1' when (muntjac_wb_host_100.cyc = '1'
                                 and uart16550_en = '0'
                                 and unsigned(muntjac_wb_host_100.adr) < muntjac_memsize)
                         else '0';
    muntjac_ram_en <= '1' when (muntjac_wb_host_100.cyc = '1'
                                and uart16550_en = '0'
                                and unsigned(muntjac_wb_host_100.adr) >= muntjac_memsize
                                and unsigned(muntjac_wb_host_100.adr) < x"80000000")
                        else '0';

    -- Route buses based on the decoded enables
    route_wb_host(uart16550_en, muntjac_wb_host_100, muntjac_uart_host);
    route_wb_host(muntjac_bram_en, muntjac_wb_host_100, muntjac_bram_host);
    route_wb_host(muntjac_ram_en, muntjac_wb_host_100, muntjac_ram_host);

    -- Multiplex responses back to the CDC bridge
    process(uart16550_en, muntjac_bram_en, muntjac_uart_per, muntjac_bram_per, muntjac_ram_per)
    begin
        if uart16550_en = '1' then
            muntjac_wb_per_100 <= muntjac_uart_per;
        elsif muntjac_bram_en = '1' then
            muntjac_wb_per_100 <= muntjac_bram_per;
        else
            muntjac_wb_per_100 <= muntjac_ram_per;
        end if;
    end process;

    -- Muntjac Independent Boot BRAM (16KB)
    muntjac_bram_inst: entity wb.bram
    generic map(
        base_address => x"00000000",
        memfile => muntjac_memfile,
        memsize => muntjac_memsize,
        reg_bit_count => 14
    )
    port map(
        clk => clk100,
        reset => reset,
        wbi => muntjac_bram_host,
        wbo => muntjac_bram_per
    );

    uart16550_inst: uart_top
    port map(
        wb_clk_i => clk100,
        wb_rst_i => muntjac_reset or cpu0_reset,
        wb_adr_i => muntjac_uart_host.adr(4 downto 2),
        wb_dat_i => muntjac_uart_host.dat(7 downto 0),
        wb_dat_o => uart16550_dat_o,
        wb_we_i => muntjac_uart_host.we,
        wb_stb_i => uart16550_en,
        wb_cyc_i => uart16550_en,
        wb_ack_o => muntjac_uart_per.ack,
        wb_sel_i => muntjac_uart_host.sel,
        int_o => open,
        stx_pad_o => uart16550_txd,
        srx_pad_i => uart16550_rxd,
        rts_pad_o => open,
        cts_pad_i => '0',
        dtr_pad_o => open,
        dsr_pad_i => '0',
        ri_pad_i => '0',
        dcd_pad_i => '0'
    );

    muntjac_uart_per.rdt <= x"000000" & uart16550_dat_o;

end architecture;
