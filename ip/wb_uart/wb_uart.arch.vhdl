-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
library wb;
library lib_uart;

architecture rtl of wb_uart is

-- 8 bit bus.
constant BITS: natural := wb.signals.BITS_NARROW;
subtype std_logic_byte is std_logic_vector(BITS-1 downto 0);

-- Signals going into the FIFO.
type fifo_in_t is record
    write_data: std_logic_byte;
    write_en: std_logic;
    read_en: std_logic;
end record;
-- Should I just absorb the constraint into the main type?
signal rd_fifo_in, wr_fifo_in: fifo_in_t;

type fifo_out_t is record
    read_data: std_logic_byte;
    full: std_logic;
    empty: std_logic;
end record;
signal rd_fifo_out, wr_fifo_out: fifo_out_t;

-- UART signal types.
-- Naming matches the naming of the uart. This is probably wrong, since
type uart_in_t is record
    data_stream_in: std_logic_byte;
    data_stream_in_stb: std_logic;
    rx: std_logic;
end record;
type uart_out_t is record
    data_stream_in_ack: std_logic;
    data_stream_out: std_logic_byte;
    data_stream_out_stb: std_logic;
    tx: std_logic;
end record;

-- One set of UART signals, for the only UART present.
-- uart_in is part of the input datapath (outside to inside).
signal uart_in: uart_in_t;
-- Part of the output datapath (inside to outside).
signal uart_out: uart_out_t;

-- Enables a read for the UART and write FIFO.
signal rd_eni: std_logic;

-- Internal reg_t of this module.
type reg_t is record
    bus_is_read, bus_is_write: boolean; -- Denote read or write cycle.
    -- input and output bytes from the bus.
    bus_d_in, bus_d_out: std_logic_byte;

    bus_ack, wr_uart_en: std_logic;
    rd_fifo_read: std_logic;
    wr_fifo_write: std_logic;
    wr_uart_strobe: std_logic;
    rx_was_empty, tx_was_empty: std_ulogic;
end record;

-- Constructor for reg_t
function reg_t_new return reg_t is
        variable ret: reg_t;
begin
        ret := (
            bus_is_read => false,
            bus_is_write => false,
            bus_ack => '0',
            bus_d_in => (others => '0'),
            bus_d_out => (others => '0'),
            rd_fifo_read => '0',
            wr_fifo_write => '0',
            wr_uart_strobe => '0',
            wr_uart_en => '0'
            , rx_was_empty => '1'
            , tx_was_empty => '1'
        );
        return ret;
    end function;

signal r, rin: reg_t;

begin

    -- UART, the entry point for the data from outside the system.
    ux: entity lib_uart.uart
        generic map (
            baud => baud_rate,
            clock_frequency => clock_frequency
        )
        port map (
            clock => clk,
            reset => reset,

            -- Inputs
            data_stream_in => wr_fifo_out.read_data,
            data_stream_in_stb => r.wr_uart_strobe,
            rx => uart_in.rx,

            -- Outputs
            data_stream_in_ack => uart_out.data_stream_in_ack,
            data_stream_out => uart_out.data_stream_out,
            data_stream_out_stb => uart_out.data_stream_out_stb,
            tx => uart_out.tx
        );

    -- FIFO on the read datapath (outside to inside).
    rd_fx: entity lib_uart.generic_fifo
        generic map (
            fifo_width => BITS,
            fifo_depth => fifo_depth
        )
        port map(
            clock => clk,
            reset => reset,

            -- Inputs
            write_data => rd_fifo_in.write_data,
            write_en => rd_fifo_in.write_en,
            read_en => rd_fifo_in.read_en,

            -- Outputs
            read_data => rd_fifo_out.read_data,
            full => rd_fifo_out.full,
            empty => rd_fifo_out.empty,

            -- Unused
            level => open
        );

    -- FIFO on the write datapath (inside to outside).
    wr_fx: entity lib_uart.generic_fifo
        generic map (
            fifo_width => BITS,
            fifo_depth => fifo_depth
        )
        port map(
            clock => clk,
            reset => reset,

            -- Inputs
            write_data => r.bus_d_in,
            write_en => r.wr_fifo_write,
            read_en => r.wr_uart_en,

            -- Outputs
            read_data => wr_fifo_out.read_data,
            full => wr_fifo_out.full,
            empty => wr_fifo_out.empty,

            -- Unused
            level => open
        );

    -- read datapath.
    -- connections from uart to read fifo
    rd_fifo_in.write_data <= uart_out.data_stream_out; -- All combinatorial, is it a good idea?
    rd_fifo_in.write_en <= uart_out.data_stream_out_stb  -- uart data out is valid
                           and not rd_fifo_out.full; -- don't write if fifo is full

    -- write datapath.
    wr_fifo_in.write_data <= wb_inputs.adr(BITS-1 downto 0);
    wr_fifo_in.write_en <= r.wr_fifo_write;
    wr_fifo_in.read_en <= r.wr_uart_en;

    -- write datapath
    uart_in.data_stream_in <= wr_fifo_out.read_data;
    uart_in.data_stream_in_stb <= r.wr_uart_en;

    -- uart connections driver
    tx <= uart_out.tx;
    uart_in.rx <= rx;

    -- Connect to the outside world. Delayed by 1 clk.

    -- Outputs are driver from the status register, not from comb network.
    -- Delayed by 1 clk as a result.
    wb_outputs.rdt <= x"00000"
        -- status of the write datapath.
        & wr_fifo_out.full & wr_fifo_out.empty
        -- status of the read datapath.
        & rd_fifo_out.full & rd_fifo_out.empty
        & rd_fifo_out.read_data;

    comb: process(
        -- This was likely a mistake. There should be only one signal here.
        wb_inputs,
        rx,
        reset,
        rd_fifo_out,
        uart_out,
        rd_eni,
        wr_fifo_out,
        r)

        variable v: reg_t;
        variable address_matches, bus_is_cycle: boolean;
        variable bus_is_read, bus_is_write: boolean := false;
        variable wr_uart_en: boolean := false;
        variable bus_ack: boolean := false;

    begin
        -- This is wrong. It should be v := r; But I don't have it in me
        -- to figure out why it wouldn't work. I'll leave the design like
        -- this for now.
        v := reg_t_new;

        v.rx_was_empty := rd_fifo_out.empty;
        v.tx_was_empty := wr_fifo_out.empty;

        -- Interrupt if we completed transmit, or if we started receive.
        -- Asserted for one cycle only.
        irq <= (r.rx_was_empty and not rd_fifo_out.empty)
               or (r.tx_was_empty and not wr_fifo_out.empty);

        -- Shorthand for recognizing bus transaction.
        address_matches := wb_inputs.adr = uart_address;
        bus_is_cycle := wb_inputs.cyc = '1' and wb_inputs.sel(0) = '1';

        -- write transaction from the bus into wr_fifo.
        bus_is_write := address_matches and bus_is_cycle and wb_inputs.we = '1';
        if bus_is_write then
            v.bus_is_write := true;
            v.bus_d_in := wb_inputs.dat(BITS-1 downto 0);
            -- But write only if the write fifo is not full.
            if wr_fifo_out.full = '0' then
                v.wr_fifo_write := '1';
            end if;
        end if;

        -- read transaction request from rd_fifo to the bus.
        -- accept only if the read fifo is not empty.
        bus_is_read := address_matches and bus_is_cycle and wb_inputs.we = '0';
        if bus_is_read then
            v.bus_is_read := true;
            v.bus_d_out := rd_fifo_out.read_data; -- put the data on the bus.
            -- Remove something from the read FIFO only if there is something.
            if rd_fifo_out.empty = '0' then
                v.rd_fifo_read := '1';
            end if;
        end if;

        -- wr datapath fifo to uart. write something if there is something to write
        if uart_out.data_stream_in_ack = '1' then
            v.wr_uart_en := '1';
        end if;
        v.wr_uart_strobe := r.wr_uart_strobe;
        if v.wr_uart_strobe = '0' and wr_fifo_out.empty = '0' then
            v.wr_uart_strobe := '1';
        end if;
        if wr_fifo_out.empty = '1' then
            v.wr_uart_strobe := '0';
        end if;

        bus_ack := bus_is_write or bus_is_read;

        -- ack must be combinatorial.
        if bus_ack then
            wb_outputs.ack <= '1';
        else
            wb_outputs.ack <= '0';
        end if;

        if bus_ack and rd_fifo_out.empty = '0' and bus_is_read then
            rd_fifo_in.read_en <= '1';
        else
            rd_fifo_in.read_en <= '0';
        end if;

        if reset = '1' then -- sync reset
            v := reg_t_new;
        end if;

        rin <= v; -- drive the register input
    end process;

    seq: process(clk)
    begin
        if rising_edge(clk) then r <= rin; end if;
    end process;

end architecture;

