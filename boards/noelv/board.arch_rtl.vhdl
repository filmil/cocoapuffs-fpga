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

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library gaisler;
use gaisler.noelv.all;
use gaisler.uart.all;

library bridges;
library debug;

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
        --! The reset strategy to use (e.g., "MINI", "NONE").
        RESET_STRATEGY: string(1 to 4);
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

    --! Configuration for the NOEL-V system (noelvsys). Only the noelvsys
    --! generics that are non-zero in this design are captured here; the
    --! remaining generics are left at 0 at the instantiation site.
    type noelv_config_t is record
        --! Number of CPU cores.
        ncpu: integer;
        --! Number of extra AHB masters (1 in simulation, 0 on hardware).
        nextmst: integer;
        --! Number of extra AHB slaves.
        nextslv: integer;
        --! Number of debug-bus masters.
        ndbgmst: integer;
        --! Number of interrupt domains.
        nintdom: integer;
        --! AHB data bus width, in bits.
        busw: integer;
        --! Core configuration selector forwarded to noelvcpu. See cfg_map() in
        --! grlib noelv_cpu_cfg.vhd: 16#400# selects the NOEL-V high-performance
        --! (NV-HP) core (dual-issue, FPU enabled).
        cfg: integer;
    end record;

    --! Master configuration record for the board.
    type config_t is record
        --! CPU-specific configuration.
        cpu: cpu_config_t;
        --! UART-specific configuration.
        uart: uart_config_t;
        --! BRAM-specific configuration.
        bram: bram_config_t;
        --! Noel-V Boot BRAM-specific configuration.
        noelv_boot_bram: bram_config_t;
        --! RAM-specific configuration.
        ram: ram_config_t;
        --! Timer-specific configuration.
        timer: timer_config_t;
        --! PIC-specific configuration.
        pic: pic_config_t;
        --! NOEL-V system (noelvsys) configuration.
        noelv: noelv_config_t;
        --! The number of ports for the CPU bus multiplexer.
        mux_ports: natural;
    end record;

    function to_natural(b: boolean) return natural is
    begin
        if b then return 1; else return 0; end if;
    end function;

    --! Number of extra AHB masters needed only by simulation infrastructure
    --! (1 in simulation, 0 on hardware).
    function get_nextmst(sim : boolean) return integer is
    begin
        if sim then
            return 1;
        else
            return 0;
        end if;
    end function;

    constant cfg: config_t := (
        cpu => (
            RESET_PC => x"00000000",
            COMPRESSED => 1,
            MDU => 0,
            PRE_REGISTER => 1,
            RESET_STRATEGY => RESET_STRATEGY,
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
        noelv_boot_bram => (
            base_address => x"00000000",
            memsize => noelv_memsize,
            reg_bit_count => 12
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
        noelv => (
            ncpu    => 1,
            nextmst => get_nextmst(IS_SIMULATION),
            nextslv => 2,
            ndbgmst => 1,
            nintdom => 1,
            busw    => 32,
            -- 16#300# selects the NOEL-V general-purpose (NV-GP) core: dual-issue,
            -- FPU, RV-C.  GP is the FPGA-targeted core (HP/16#400# is for ASIC).
            -- cfg_typ = (cfg/256) mod 16: 4 = HP, 3 = GP.  XLEN is independent of
            -- cfg -- RV64 comes from noelv_cfg_64.vhd (NV_XLEN=64).  See cfg_map()
            -- in grlib noelv_cpu_cfg.vhd.
            cfg     => 16#300#
        ),
        mux_ports => 2
    );

    -- Clocks
    -- clk: 200MHz.
    signal clk, locked, reset: std_ulogic;
    signal clk100, clk400pi0, clk200, clk400pi2: std_ulogic;
    signal clk50: std_ulogic;

    -- UART
    signal uart1_host: wb.host.bus_type;
    signal uart1_per: wb.per.bus_type;
    signal i_wb: signals.i_wb;
    signal o_wb: signals.o_wb;
    signal txd, rxd: std_ulogic;
    signal uart1_irq: std_ulogic;
    signal uart1_en: std_ulogic;

    -- UART multiplexing
    signal txd_serv, txd_noelv: std_ulogic;
    signal rxd_serv, rxd_noelv: std_ulogic;
    signal uarti_noelv : uart_in_type;
    signal uarto_noelv : uart_out_type;

    -- percontrol
    signal perctl0_wb_host: wb.host.bus_type;
    signal perctl0_per: wb.per.bus_type;
    signal perctl0_en: std_ulogic;
    signal perctl_reg: std_ulogic_vector(31 downto 0);

    -- Noel-V signals
    -- Number of extra AHB masters on the NOEL-V system, sourced from the board
    -- cfg record (1 in simulation, 0 on hardware). Used to size the master
    -- vector below.
    constant NEXTMST_VAL : integer := cfg.noelv.nextmst;

    signal noelv_reset_n: std_ulogic;
    -- Raw (asynchronous) NOEL-V reset request, decoded from the clk100/wb-domain
    -- percontrol register, plus its clk50-domain synchronizer.  See the reset
    -- synchronizer below for why this crossing must be registered.
    signal noelv_reset_n_async: std_ulogic;
    signal noelv_rst_sync: std_ulogic_vector(1 downto 0) := "00";
    -- HW bring-up debug: sticky latch, set once NOEL-V drives its UART TX low
    -- (i.e. it actually transmitted a start bit) after being released from reset.
    signal dbg_noelv_tx_seen: std_ulogic := '0';
    -- HW bring-up debug: capture the first 4 bytes NOEL-V writes to the apbuart
    -- data register (0xFF900000) and present an 8-bit diagnostic word on the LEDs
    -- using the human-friendly readout: led4 led3 = frame number (00..11), led2
    -- led1 = the 2 data bits of that frame. The frame counter free-runs
    -- (~5.4 s/frame) and wraps forever, so the sequence repeats indefinitely.
    -- Expected good char sequence: 68 'h', 61 'a', 6c 'l', 74 't'.
    signal cap0, cap1, cap2, cap3: std_logic_vector(7 downto 0) := (others => '0');
    signal cap_count:  integer range 0 to 4 := 0;
    signal cap_next:   std_ulogic := '0';
    signal flash_div:  unsigned(27 downto 0) := (others => '0');  -- ~5.4 s/frame
    signal frame:      unsigned(1 downto 0) := "00";             -- shown on led4 led3
    signal diag:       std_logic_vector(7 downto 0);             -- the 8 diagnostic bits
    signal frame_data: std_logic_vector(1 downto 0);             -- shown on led2 led1
    signal noelv_ahbsi: ahb_slv_in_type;
    signal noelv_ahbso_vec: ahb_slv_out_vector_type(1 downto 0);
    signal noelv_wb_host: wb.host.bus_type;
    signal noelv_wb_per: wb.per.bus_type;

    signal noelv_gclk : std_ulogic_vector(0 to 0);
    signal noelv_uarti : uart_in_type;
    signal noelv_apbo : apb_slv_out_vector;
    signal noelv_ahbmo : ahb_mst_out_vector_type(NEXTMST_VAL downto 1);
    signal noelv_dbgmo : ahb_mst_out_vector_type(0 downto 0);
    signal noelv_dbgmi : ahb_mst_in_vector_type(0 downto 0);

    -- Spin slave PnP
    constant noelv_spin_hconfig : ahb_config_type := (
        0 => ahb_device_reg(VENDOR_CONTRIB, 16#002#, 0, 0, 0),
        4 => ahb_membar(16#000#, '1', '1', 16#FFF#), -- 0x00000000, 1MB mask
        others => (others => '0')
    );

    -- DDR3 RAM
    signal ddr3_ports: ddr3.phy32.host_type;
    signal ram0_wb_host: wb.host.bus_type;
    signal ram0_wb_per: wb.per.bus_type;

    signal ram_mux_host_ports: wb.host.bus_array_t(1 downto 0);
    signal ram_mux_per_ports: wb.per.bus_array_t(1 downto 0);
    signal ram0_wb_host_muxed: wb.host.bus_type;
    signal ram0_wb_per_from_slave: wb.per.bus_type;

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

    --! AHB transaction recorder (debug peripheral, issue #149).
    signal rec_dump_raw     : std_ulogic;
    signal rec_dump_clean   : std_ulogic;
    signal rec_dump_serv    : std_ulogic_vector(1 downto 0); --! perctl(2) sync to clk50
    signal rec_dump_trigger : std_ulogic;
    signal rec_dump_clean_d : std_ulogic;                    --! key1 rising-edge detect
    signal rec_dump_serv_d  : std_ulogic;                    --! SERV-bit rising-edge detect
    --! key2 -> NOEL-V-only reset (debounced like key1).
    signal key2_reset_raw   : std_ulogic;
    signal key2_reset_clean : std_ulogic;
    signal rec_tx_data      : std_ulogic_vector(7 downto 0);
    signal rec_tx_valid     : std_ulogic;
    signal rec_tx_ready     : std_ulogic;
    signal rec_txd          : std_ulogic;
    signal rec_dumping      : std_ulogic;

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
        clkout4 => clk50,
        locked => locked
    );

    leds0: entity a200t.leds
    port map(
        clk => clk100,
        locked => locked,
        reset_n => reset_n,
        led1 => open, -- HW debug: driven directly below
        led2 => open, -- HW debug: driven directly below
        led3 => open, -- HW debug: driven directly below
        led4 => open, -- led4,
        reset => reset
    );

    -- AHB recorder UART-steal DISABLED for clean Zircon serial (issue #149): the
    -- recorder still snoops the bus, but it no longer hijacks the UART ~30 s after
    -- the NOEL-V handoff.  With the steal enabled, the SERV perctl(2) rising edge
    -- (first handoff after a fresh program) triggers a dump that clobbers the
    -- console right around the physboot->kernel transition, so the FIRST post-
    -- program boot never shows "starting user space"/userboot on the wire (only a
    -- subsequent, no-reprogram boot -- perctl(2) already latched high -- was clean).
    -- Dropping the `rec_txd when rec_dumping = '1'` branch gives NOEL-V the UART for
    -- the whole boot.  Re-add it for the LR/SC bus-trace hunt.
    uart1_txd <= txd_serv when perctl_reg(0) = '0' else
                 txd_noelv;
    rxd_serv <= uart1_rxd;
    rxd_noelv <= uart1_rxd;

    -- AHB transaction recorder: snoops NOEL-V's AHB and, on a debounced key1
    -- press, steals the UART to dump the captured trace. See //ip/debug and #149.
    rec_dump_raw <= not key1_n;   --! active-low button -> active-high "pressed"

    rec_debounce: entity debug.debouncer
        generic map (count_bits => 20)             --! ~21 ms @ 50 MHz
        port map (clk => clk50, rstn => noelv_reset_n,
                  raw => rec_dump_raw, clean => rec_dump_clean);

    --! key2 (active-low) drives the NOEL-V-only reset; debounce it just like key1.
    --! Its debouncer resets from the global reset_n (NOT noelv_reset_n, which it
    --! feeds -- that would be a loop).
    key2_reset_raw <= not key2_n;
    key2_debounce: entity debug.debouncer
        generic map (count_bits => 20)             --! ~26 ms @ 40 MHz
        port map (clk => clk50, rstn => reset_n,
                  raw => key2_reset_raw, clean => key2_reset_clean);

    --! Synchronize SERV's percontrol bit2 (clk100 domain) into clk50, and register
    --! the trigger sources for rising-edge detection.  SERV still auto-triggers a
    --! dump ~30 s after enabling NOEL-V so the trace prints with nobody at the board.
    rec_serv_sync: process(clk50) is
    begin
        if rising_edge(clk50) then
            rec_dump_serv    <= rec_dump_serv(0) & perctl_reg(2);
            rec_dump_clean_d <= rec_dump_clean;
            rec_dump_serv_d  <= rec_dump_serv(1);
        end if;
    end process;
    --! One-shot pulse on each key1 press OR the SERV bit going high.  A held level
    --! (button held, or the latched SERV bit) would jam the recorder's rising-edge
    --! dump input high and block further dumps; edge-detecting both makes every
    --! press "dump the current window + re-arm", so repeated presses redo the trace.
    rec_dump_trigger <= (rec_dump_clean and not rec_dump_clean_d)
                     or (rec_dump_serv(1) and not rec_dump_serv_d);

    rec_recorder: entity debug.ahb_recorder
        generic map (addr_bits => 13)              --! 8192 records (sliding window)
        port map (
            clk => clk50, rstn => noelv_reset_n,
            haddr  => noelv_ahbsi.haddr(31 downto 0),
            htrans => noelv_ahbsi.htrans,
            hwrite => noelv_ahbsi.hwrite,
            hready => noelv_ahbsi.hready,
            hwdata => noelv_ahbsi.hwdata(31 downto 0),
            dump => rec_dump_trigger,
            tx_data => rec_tx_data, tx_valid => rec_tx_valid,
            tx_ready => rec_tx_ready,
            recording => open, full => open, dumping => rec_dumping);

    rec_serializer: entity debug.uart_tx
        generic map (clk_freq_hz => 40_000_000, baud_rate => 115_200)  -- clk50 now 40 MHz
        port map (clk => clk50, rstn => noelv_reset_n,
                  data => rec_tx_data, valid => rec_tx_valid,
                  ready => rec_tx_ready, tx => rec_txd);

    -- HW bring-up debug LEDs (active low: lit = condition true). Trace the
    -- SERV -> NOEL-V UART handoff chain so we can see on the board where it
    -- breaks when nothing prints.
    dbg_tx_latch: process(clk50)
    begin
        if rising_edge(clk50) then
            if noelv_reset_n = '1' and txd_noelv = '0' then
                dbg_noelv_tx_seen <= '1';
            end if;
        end if;
    end process;

    -- Capture the data of the first 4 writes NOEL-V makes to the apbuart data
    -- register at 0xFF900000.  In AHB the write data is valid the cycle AFTER the
    -- address phase, so register the address match and grab hwdata next cycle.
    dbg_cap: process(clk50)
    begin
        if rising_edge(clk50) then
            if noelv_reset_n = '0' then
                cap_count <= 0;
                cap_next  <= '0';
                cap0 <= (others => '0'); cap1 <= (others => '0');
                cap2 <= (others => '0'); cap3 <= (others => '0');
            else
                if cap_next = '1' then
                    case cap_count is
                        when 0 => cap0 <= noelv_ahbsi.hwdata(7 downto 0);
                        when 1 => cap1 <= noelv_ahbsi.hwdata(7 downto 0);
                        when 2 => cap2 <= noelv_ahbsi.hwdata(7 downto 0);
                        when 3 => cap3 <= noelv_ahbsi.hwdata(7 downto 0);
                        when others => null;
                    end case;
                    if cap_count < 4 then cap_count <= cap_count + 1; end if;
                end if;
                if noelv_ahbsi.htrans(1) = '1' and noelv_ahbsi.hready = '1'
                   and noelv_ahbsi.hwrite = '1'
                   and noelv_ahbsi.haddr(31 downto 20) = x"FF9"
                   and noelv_ahbsi.haddr(19 downto 0) = x"00000"
                   and cap_count < 4 then
                    cap_next <= '1';
                else
                    cap_next <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Free-running ~5.4 s/frame counter; wraps 00->01->10->11->00 forever.
    dbg_flash: process(clk50)
    begin
        if rising_edge(clk50) then
            flash_div <= flash_div + 1;
            if flash_div = 0 then
                frame <= frame + 1;
            end if;
        end if;
    end process;

    -- The 8 diagnostic bits, computed on-chip from the captured apbuart writes.
    diag(0) <= '1' when cap_count >= 1 else '0';                 -- wrote data reg at least once
    diag(1) <= '1' when cap_count >= 4 else '0';                 -- wrote it at least 4 times
    diag(2) <= '1' when cap0 = x"68" else '0';                   -- 1st char == 0x68 ('h')
    diag(3) <= '1' when cap1 = x"61" else '0';                   -- 2nd char == 0x61 ('a')
    diag(4) <= '1' when cap2 = x"6c" else '0';                   -- 3rd char == 0x6c ('l')
    diag(5) <= '1' when cap3 = x"74" else '0';                   -- 4th char == 0x74 ('t')
    diag(6) <= '1' when (cap1 = cap2) and (cap2 = cap3) else '0';-- writes all identical (constant data)
    diag(7) <= '1' when (cap0 = cap1) and (cap1 = cap2)
                        and (cap2 = cap3) else '0';              -- all 4 writes identical

    with to_integer(frame) select frame_data <=
        diag(1 downto 0) when 0,
        diag(3 downto 2) when 1,
        diag(5 downto 4) when 2,
        diag(7 downto 6) when 3,
        "00"             when others;

    -- Drive the LEDs (active low: lit = '1').
    --   led4 led3 = frame number (00,01,10,11)
    --   led2 led1 = the two data bits for that frame
    led4 <= not frame(1);
    led3 <= not frame(0);
    led2 <= not frame_data(1);
    led1 <= not frame_data(0);

    o_wb <= wb.host.into_old_type(uart1_host);
    uart1_per <= wb.per.from_old_type(i_wb);
    uart1_en <= '1' when (cpu0_host_out.cyc = '1'
                   and cpu0_host_out.adr(31 downto 30) = "01"
                   and cpu0_host_out.adr(7 downto 0) = x"10") -- Assumes UART at 0x40000010
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
        , uart_address => std_logic_vector(cfg.uart.uart_address)
    )
    port map(
        clk => clk100,
        reset => reset,

        txd => txd_serv,
        rxd => rxd_serv,

        o_wb => o_wb,
        i_wb => i_wb

        , irq => uart1_irq
    );

    perctl0_en <= '1' when (cpu0_host_out.cyc = '1'
                   and cpu0_host_out.adr(31 downto 30) = "01"
                   and cpu0_host_out.adr(7 downto 0) = x"40")
             else '0';

    process(cpu0_host_out, perctl0_en)
    begin
        perctl0_wb_host.adr <= cpu0_host_out.adr;
        perctl0_wb_host.dat <= cpu0_host_out.dat;
        perctl0_wb_host.we <= cpu0_host_out.we;
        perctl0_wb_host.sel <= cpu0_host_out.sel;
        perctl0_wb_host.cyc <= perctl0_en;
    end process;

    perctl0: entity wb.percontrol
    generic map (
        base_address => x"40000040"
    )
    port map(
        clk => clk100,
        reset => reset,
        wbi => perctl0_wb_host,
        wbo => perctl0_per,
        perctl => perctl_reg
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

    -- Noel-V Reset.
    --
    -- perctl_reg lives in SERV's clk100 / Wishbone domain; the handoff sets
    -- perctl_reg(1) on a clk100 edge.  Feeding the combinational decode straight
    -- into the clk50 NOEL-V reset deasserts reset asynchronously to clk50, so the
    -- core's flops can leave reset on different clk50 edges (a recovery/removal
    -- violation) and the pipeline starts in an inconsistent state -- it boots in
    -- the testbench (clean rstn) but wedges on hardware.  Use an async-assert /
    -- sync-deassert reset synchronizer so the release is aligned to clk50.
    --
    -- key2 (active-low push-button, pin L20) is an additional NOEL-V-ONLY reset:
    -- while held it asserts the core reset, so NOEL-V can be re-run from its boot
    -- stub -- re-executing the DDR3-resident payload -- without a SERV re-upload or
    -- a power cycle.  It is AND-ed in alongside the global reset and the percontrol
    -- "run" bit (so it does not disturb SERV/DDR3).  key2 is DEBOUNCED
    -- (key2_reset_clean, active-high "pressed"); the sync-deassert synchronizer
    -- below still aligns the release to clk50.
    noelv_reset_n_async <= (not reset) and perctl_reg(1) and (not key2_reset_clean);

    noelv_rst_sync_proc: process(clk50, noelv_reset_n_async)
    begin
        if noelv_reset_n_async = '0' then
            noelv_rst_sync <= "00";
        elsif rising_edge(clk50) then
            noelv_rst_sync <= noelv_rst_sync(0) & '1';
        end if;
    end process;
    noelv_reset_n <= noelv_rst_sync(1);

    -- Boot memory connected directly to the AHB bus (no Wishbone bridge), so
    -- NOEL-V's instruction-fetch bursts are served at one word per clock on the
    -- AHB clock domain (clk50).
    noelv_boot_ram: entity bridges.ahb_bram
    generic map (
        hindex        => 0,
        haddr         => 16#C00#,
        hmask         => 16#FFF#,
        memfile       => noelv_memfile,
        memsize       => cfg.noelv_boot_bram.memsize,
        reg_bit_count => cfg.noelv_boot_bram.reg_bit_count
    )
    port map (
        clk   => clk50,
        rstn  => noelv_reset_n,
        ahbsi => noelv_ahbsi,
        ahbso => noelv_ahbso_vec(0)
    );

    noelv_gclk(0) <= clk50;
    noelv_uarti.rxd <= rxd_noelv;
    noelv_uarti.ctsn <= '1';
    noelv_uarti.extclk <= '0';
    noelv_apbo(0) <= apb_none;

    noelv0: entity gaisler.noelvsys
    generic map (
        fabtech  => 0,
        -- memtech=artix7 (50): map the cache/TLB RAMs through techmap
        -- memory_unisim (RAMB/RAMD primitives) instead of Vivado-inferred
        -- memory_inferred.  GROUND TRUTH (AHB recorder, 2026-07-08): with
        -- memtech=0 the synthesized caches NEVER HIT -- the same 8-word ifetch
        -- line re-read from the bus 512x while the identical RTL in sim
        -- caches it after one fill.  A never-hitting D$ also breaks sc.w/sc.d
        -- (GRLIB requires a cache hit on the SC path), which is what wedged
        -- the Zircon kernel's first compare_exchange.  memtech=0 (inferred)
        -- on Xilinx is the least-tested grlib combination; artix7 is the
        -- supported mapping.  Sim testbenches keep memtech=0 (proven fine).
        memtech  => 50,
        ncpu     => cfg.noelv.ncpu,
        nextmst  => cfg.noelv.nextmst,
        nextslv  => cfg.noelv.nextslv,
        nextapb  => 0,
        ndbgmst  => cfg.noelv.ndbgmst,
        nintdom  => cfg.noelv.nintdom,
        neiid    => 0,
        -- Fixed-cacheability mask (MMU is off): bit i => address[31:28]=i is
        -- cacheable. 16#000F# caches the low 1 GB DDR3 (0x0-0x3FFFFFFF) so LR/SC
        -- reservations live in L1 and sc.d never reaches the ahb2wb_bridge (which
        -- doesn't honor them). Devices (CLINT 0xE.., UART 0xF.., boot BRAM 0xC..)
        -- stay uncached.
        cached   => 16#000F#,
        wbmask   => 0,
        busw     => cfg.noelv.busw,
        cmemconf => 0,
        rfconf   => 0,
        fpuconf  => 0,
        tcmconf  => 0,
        mulconf  => 0,
        intcconf => 0,
        disas    => 0,
        ahbtrace => 0,
        cfg      => cfg.noelv.cfg,
        devid    => 0,
        nodbus   => 0,
        trace    => 0,
        scantest => 0
    )
    port map (
        clk => clk50,
        gclk => std_logic_vector(noelv_gclk),
        rstn => noelv_reset_n,
        ahbsi => noelv_ahbsi,
        ahbso => noelv_ahbso_vec,
        uarti => noelv_uarti,
        uarto => uarto_noelv,
        -- Set other required ports to open or default
        ahbmo => noelv_ahbmo,
        dbgmi => noelv_dbgmi,
        dbgmo => noelv_dbgmo,
        apbo => noelv_apbo,
        -- dsuen=1 enables the RISC-V debug module's hart control: dmnvx gates the
        -- per-hart debug enable as en(i) := dsuen and dbgi(i).dsu, so with dsuen=0
        -- the dmnv could read hart status over JTAG but the hart ignored haltreq.
        -- dsubreak=0: run normally (halt on demand via the DM, not on reset).
        dsuen => '1',
        dsubreak => '0'
    );

    -- grmon debug AHB master: a JTAG->AHB bridge that taps the FPGA config JTAG
    -- via BSCANE2 (artix7, tech=50) and acts as an AHB master on the NOEL-V bus,
    -- so grmon (over the config JTAG) can read/write memory and the NOEL-V debug
    -- module live.  External JTAG pins tie off; the internal BSCANE2 tap is used.
    ahbjtag0: entity gaisler.ahbjtag
        generic map (tech => 50, hindex => 0)
        port map (
            rst      => noelv_reset_n,
            clk      => clk50,
            tck      => '0',
            tms      => '0',
            tdi      => '0',
            ahbi     => noelv_dbgmi(0),
            ahbo     => noelv_dbgmo(0),
            tapi_tdo => '0'
        );

    txd_noelv <= uarto_noelv.txd;

    noelv_bridge: entity bridges.ahb2wb_bridge
    generic map (
        HSEL_INDEX => 1,
        HINDEX     => 1
    )
    port map (
        clk_ahb => clk50,
        clk_wb => clk100,
        rst => reset,
        ahb_ahbsi => noelv_ahbsi,
        ahb_ahbso => noelv_ahbso_vec(1),
        wb_wbo => noelv_wb_host,
        wb_wbi => noelv_wb_per
    );

    ram_mux_host_ports(0) <= ram0_wb_host;
    ram_mux_host_ports(1) <= noelv_wb_host;

    ram_mux: entity wb.wb_mux
    generic map (
        PORTS_COUNT => 2
    )
    port map (
        clk => clk100,
        rst => reset,
        host_ports => ram_mux_host_ports,
        per_ports => ram_mux_per_ports,
        host_port => ram0_wb_host_muxed,
        per_port => ram0_wb_per_from_slave
    );

    ram0_wb_per <= ram_mux_per_ports(0);
    noelv_wb_per <= ram_mux_per_ports(1);

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
            wb_host => ram0_wb_host_muxed,
            wb_per => ram0_wb_per_from_slave,

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
            wb_host => ram0_wb_host_muxed,
            wb_per => ram0_wb_per_from_slave,

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
    cpu0_reset <= reset when IS_SIMULATION else (reset or (not ram_inited));
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
        input(5) => wb.per.into_old_type(perctl0_per),
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
