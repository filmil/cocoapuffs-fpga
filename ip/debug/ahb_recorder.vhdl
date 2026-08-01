-- SPDX-License-Identifier: Apache-2.0

--! @brief Minimal AHB bus-transaction trace buffer (see issue #149).
--!
--! It passively snoops an AHB master's request bus (decomposed into plain
--! std_logic ports so it is grlib-independent and can be unit-tested under
--! NVC) and continuously records one entry per accepted transfer into an
--! on-chip BRAM organised as a **circular sliding window**: once the buffer
--! has filled it keeps recording, overwriting the oldest entry, so it always
--! holds the most recent `2**addr_bits` transfers. When `dump` is asserted it
--! streams the captured window out, oldest-first, as ASCII-hex lines over a
--! byte handshake (`tx_*`, wired to a UART at the board level), then resumes
--! recording where it left off (the window keeps sliding).
--!
--! The sliding window matters for catching a *late* hang: the last AHB traffic
--! before the bus goes quiet (e.g. the core parks in a wfi loop) is exactly
--! what stays in the buffer, so a single dump after the hang shows the lead-up.
--!
--! Capture is deliberately minimal: one record = { cycle, addr, w/r, data },
--! captured on the address-accept beat (htrans=NONSEQ/SEQ and hready='1'), which
--! is exactly the beat that names the access -- including the last one before a
--! bus hang (hready stuck low afterwards). The data field is the write data on
--! the bus at that beat (one AHB beat early; the addr/cycle/direction are exact).
library ieee;
use ieee.std_logic_1164.all;

entity ahb_recorder is
    generic (
        --! Number of records the buffer holds is 2**addr_bits.
        addr_bits : positive := 8
    );
    port (
        --! Clock; everything is synchronous to its rising edge.
        clk       : in  std_ulogic;
        --! Active-low synchronous reset.
        rstn      : in  std_ulogic;

        --! Snooped AHB address (from e.g. grlib ahb_slv_in_type.haddr).
        haddr     : in  std_ulogic_vector(31 downto 0);
        --! Snooped AHB transfer type; bit 1 set => NONSEQ/SEQ (a real access).
        htrans    : in  std_ulogic_vector(1 downto 0);
        --! Snooped AHB direction: '1' = write, '0' = read.
        hwrite    : in  std_ulogic;
        --! Snooped AHB ready: a beat is accepted when htrans(1)='1' and hready='1'.
        hready    : in  std_ulogic;
        --! Snooped AHB write data bus.
        hwdata    : in  std_ulogic_vector(31 downto 0);

        --! Dump request: a rising edge streams the window out, then resumes.
        dump      : in  std_ulogic;

        --! Dump byte to the UART transmitter (valid while tx_valid='1').
        tx_data   : out std_ulogic_vector(7 downto 0);
        --! Held high until the consumer asserts tx_ready (one byte per clk
        --! where both tx_valid and tx_ready are high).
        tx_valid  : out std_ulogic;
        --! Consumer-ready handshake input from the UART transmitter.
        tx_ready  : in  std_ulogic;

        --! High while capturing (low only during a dump stream-out).
        recording : out std_ulogic;
        --! High once the sliding window has wrapped at least once (buffer full).
        full      : out std_ulogic;
        --! High while a dump is streaming out; used to "steal" the UART TX pin.
        dumping   : out std_ulogic
    );
end entity;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

architecture rtl of ahb_recorder is

    --! Number of record slots in the buffer.
    constant depth     : positive := 2**addr_bits;
    --! One record: { hwrite(1), cycle(32), haddr(32), hwdata(32) } = 97 bits.
    constant rec_width : positive := 97;

    --! Record storage; inferred as a BRAM (synchronous read in S_FETCH).
    type mem_t is array(0 to depth-1) of std_ulogic_vector(rec_width-1 downto 0);
    signal mem : mem_t;

    --! Circular write pointer (wraps at `depth`); the buffer is a sliding window.
    signal wr_ptr   : unsigned(addr_bits-1 downto 0);
    --! Circular read pointer used while dumping.
    signal rd_ptr   : unsigned(addr_bits-1 downto 0);
    --! Records remaining to stream out, snapshotted at the dump request.
    signal dump_rem : unsigned(addr_bits downto 0);

    --! Free-running cycle counter, stored in each record as a timestamp.
    signal cycle     : unsigned(31 downto 0);
    --! Previous `dump` level, for rising-edge detection.
    signal dump_prev : std_ulogic;
    --! Set once the buffer has wrapped at least once (all `depth` slots valid).
    signal wrapped   : std_ulogic;

    --! Recorder state machine.
    type state_t is (S_REC, S_FETCH, S_EMIT);
    signal state    : state_t;
    --! Record currently being streamed out.
    signal rec_reg  : std_ulogic_vector(rec_width-1 downto 0);
    --! Character index within the current record's formatted line.
    signal char_idx : integer range 0 to 31;

    --! One formatted line "CCCCCCCC W AAAAAAAA DDDDDDDD\r\n" = 30 chars (0..29).
    constant last_char : integer := 29;

    --! @brief Convert a 4-bit nibble to its lowercase ASCII hex character.
    function hexchar(n : std_ulogic_vector(3 downto 0)) return std_ulogic_vector is
        variable v : integer;
    begin
        v := to_integer(unsigned(n));
        if v < 10 then
            return std_ulogic_vector(to_unsigned(16#30# + v, 8));        --! '0'..'9'
        else
            return std_ulogic_vector(to_unsigned(16#61# + v - 10, 8));   --! 'a'..'f'
        end if;
    end function;

    --! @brief Byte to emit at character position `idx` of record `r`.
    --! r layout: (96)=hwrite, (95:64)=cycle, (63:32)=addr, (31:0)=data.
    function byte_at(idx : integer; r : std_ulogic_vector(96 downto 0))
        return std_ulogic_vector is
    begin
        case idx is
            when 0 to 7   => return hexchar(r(95 - idx*4 downto 92 - idx*4));   --! cycle
            when 8        => return x"20";                                      --! ' '
            when 9        => if r(96) = '1' then return x"57";                  --! 'W'
                             else return x"52"; end if;                         --! 'R'
            when 10       => return x"20";                                      --! ' '
            when 11 to 18 => return hexchar(r(63 - (idx-11)*4 downto 60 - (idx-11)*4)); --! addr
            when 19       => return x"20";                                      --! ' '
            when 20 to 27 => return hexchar(r(31 - (idx-20)*4 downto 28 - (idx-20)*4)); --! data
            when 28       => return x"0d";                                      --! '\r'
            when others   => return x"0a";                                      --! '\n'
        end case;
    end function;

begin

    --! High while capturing (low only during a dump stream-out).
    recording <= '1' when state = S_REC else '0';
    --! High once the sliding window has wrapped at least once.
    full      <= wrapped;
    --! High during the dump stream-out (anything other than S_REC).
    dumping   <= '1' when state /= S_REC else '0';

    --! Combinational byte-stream output; a byte is offered only in S_EMIT.
    tx_valid <= '1' when state = S_EMIT else '0';
    tx_data  <= byte_at(char_idx, rec_reg);

    --! @brief Main process: continuously capture, then dump the window on request.
    process(clk) is
    begin
        if rising_edge(clk) then
            if rstn = '0' then
                wr_ptr    <= (others => '0');
                rd_ptr    <= (others => '0');
                dump_rem  <= (others => '0');
                cycle     <= (others => '0');
                dump_prev <= '0';
                wrapped   <= '0';
                char_idx  <= 0;
                state     <= S_REC;
            else
                cycle     <= cycle + 1;
                dump_prev <= dump;

                case state is

                when S_REC =>
                    --! Circular capture: one record per accepted transfer, the
                    --! oldest slot overwritten once the window has wrapped.
                    if htrans(1) = '1' and hready = '1' then
                        mem(to_integer(wr_ptr)) <=
                            hwrite & std_ulogic_vector(cycle) & haddr & hwdata;
                        if wr_ptr = to_unsigned(depth-1, wr_ptr'length) then
                            wr_ptr  <= (others => '0');
                            wrapped <= '1';
                        else
                            wr_ptr <= wr_ptr + 1;
                        end if;
                    end if;
                    --! On a dump rising edge, snapshot the window (the latest
                    --! `depth` records when wrapped, else [0, wr_ptr)) and stream
                    --! it out oldest-first, starting at the oldest slot.
                    if dump = '1' and dump_prev = '0' then
                        if wrapped = '1' then
                            rd_ptr   <= wr_ptr;     --! oldest = next-to-overwrite
                            dump_rem <= to_unsigned(depth, dump_rem'length);
                        else
                            rd_ptr   <= (others => '0');
                            dump_rem <= resize(wr_ptr, dump_rem'length);
                        end if;
                        state <= S_FETCH;
                    end if;

                when S_FETCH =>
                    if dump_rem = 0 then
                        --! Done; keep the buffer and resume the sliding window.
                        state <= S_REC;
                    else
                        --! Registered (BRAM) read; valid next cycle in S_EMIT.
                        rec_reg  <= mem(to_integer(rd_ptr));
                        char_idx <= 0;
                        state    <= S_EMIT;
                    end if;

                when S_EMIT =>
                    --! Advance one character per accepted byte; next record at EOL.
                    if tx_ready = '1' then
                        if char_idx = last_char then
                            rd_ptr   <= rd_ptr + 1;   --! circular (wraps at depth)
                            dump_rem <= dump_rem - 1;
                            state    <= S_FETCH;
                        else
                            char_idx <= char_idx + 1;
                        end if;
                    end if;

                end case;
            end if;
        end if;
    end process;

end architecture;
