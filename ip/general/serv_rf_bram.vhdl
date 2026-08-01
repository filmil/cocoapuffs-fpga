-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library general;
use general.types.all;

--! @brief A dual-port 32-bit parallel BRAM based register file for the SERV core.
--!
--! This module implements a 64x32-bit register file using a BRAM with a
--! parallel data interface.
entity serv_rf_bram is
    generic (
        --! Enables Control and Status Registers if non-zero.
        WITH_CSR : natural := 1
    );
    port (
        --! Global clock.
        clk : in std_ulogic;
        --! Synchronous reset. Sets all RAM values to zero.
        i_rst : in std_ulogic;

        -- SERV RF Interface (Parallel)
        --! Structured parallel input interface.
        i_rf : in serv_rf_in_t;
        --! Structured parallel output interface.
        o_rf : out serv_rf_out_t
    );
end entity;

architecture rtl of serv_rf_bram is

    function f(v: std_ulogic) return std_ulogic is
    begin
        if v = '1' then return '1'; else return '0'; end if;
    end function;

    function f(v: std_ulogic_vector) return std_ulogic_vector is
        variable res : std_ulogic_vector(v'range);
    begin
        for i in v'range loop
            res(i) := f(v(i));
        end loop;
        return res;
    end function;

    function f(v: serv_rf_in_t) return serv_rf_in_t is
        variable res : serv_rf_in_t;
    begin
        res.wreq := f(v.wreq);
        res.rreq := f(v.rreq);
        res.w0.reg := f(v.w0.reg);
        res.w0.en := f(v.w0.en);
        res.w0.data := f(v.w0.data);
        res.w1.reg := f(v.w1.reg);
        res.w1.en := f(v.w1.en);
        res.w1.data := f(v.w1.data);
        res.r0.reg := f(v.r0.reg);
        res.r1.reg := f(v.r1.reg);
        return res;
    end function;

    function f(b: boolean) return std_ulogic is
    begin
        if b then return '1'; else return '0'; end if;
    end function;

    signal i_rf_f : serv_rf_in_t;
    signal i_rst_f : std_ulogic;

    -- 64 words of 32 bits.
    type ram_t is array (0 to 63) of std_ulogic_vector(31 downto 0);
    signal ram : ram_t := (others => (others => '0'));

    -- Debug signals for XSim record visibility
    -- Inputs
    signal dbg_i_wreq    : std_ulogic;
    signal dbg_i_rreq    : std_ulogic;
    signal dbg_i_w0_reg  : std_ulogic_vector(5 downto 0);
    signal dbg_i_w0_en   : std_ulogic;
    signal dbg_i_w0_data : std_ulogic_vector(31 downto 0);
    signal dbg_i_w1_reg  : std_ulogic_vector(5 downto 0);
    signal dbg_i_w1_en   : std_ulogic;
    signal dbg_i_w1_data : std_ulogic_vector(31 downto 0);
    signal dbg_i_r0_reg  : std_ulogic_vector(5 downto 0);
    signal dbg_i_r1_reg  : std_ulogic_vector(5 downto 0);

    -- Outputs
    signal dbg_o_ready   : std_ulogic;
    signal dbg_o_r0_data : std_ulogic_vector(31 downto 0);
    signal dbg_o_r1_data : std_ulogic_vector(31 downto 0);

    -- Register file content debug (individual signals for VCD)
    signal dbg_x0,  dbg_x1,  dbg_x2,  dbg_x3  : std_ulogic_vector(31 downto 0);
    signal dbg_x4,  dbg_x5,  dbg_x6,  dbg_x7  : std_ulogic_vector(31 downto 0);
    signal dbg_x8,  dbg_x9,  dbg_x10, dbg_x11 : std_ulogic_vector(31 downto 0);
    signal dbg_x12, dbg_x13, dbg_x14, dbg_x15 : std_ulogic_vector(31 downto 0);

    signal o_rf_s : serv_rf_out_t;

begin

    i_rf_f <= f(i_rf);
    i_rst_f <= f(i_rst);

    o_rf <= o_rf_s;

    -- Full Interface Debug
    dbg_i_wreq    <= i_rf_f.wreq;
    dbg_i_rreq    <= i_rf_f.rreq;
    dbg_i_w0_reg  <= i_rf_f.w0.reg;
    dbg_i_w0_en   <= i_rf_f.w0.en;
    dbg_i_w0_data <= i_rf_f.w0.data;
    dbg_i_w1_reg  <= i_rf_f.w1.reg;
    dbg_i_w1_en   <= i_rf_f.w1.en;
    dbg_i_w1_data <= i_rf_f.w1.data;
    dbg_i_r0_reg  <= i_rf_f.r0.reg;
    dbg_i_r1_reg  <= i_rf_f.r1.reg;

    dbg_o_ready   <= o_rf_s.ready;
    dbg_o_r0_data <= o_rf_s.r0.data;
    dbg_o_r1_data <= o_rf_s.r1.data;

    -- Register Content Debug
    dbg_x0  <= ram(0);  dbg_x1  <= ram(1);  dbg_x2  <= ram(2);  dbg_x3  <= ram(3);
    dbg_x4  <= ram(4);  dbg_x5  <= ram(5);  dbg_x6  <= ram(6);  dbg_x7  <= ram(7);
    dbg_x8  <= ram(8);  dbg_x9  <= ram(9);  dbg_x10 <= ram(10); dbg_x11 <= ram(11);
    dbg_x12 <= ram(12); dbg_x13 <= ram(13); dbg_x14 <= ram(14); dbg_x15 <= ram(15);

    o_rf_s.ready <= '1'; -- Parallel interface is always ready.

    process(clk)
    begin
        if rising_edge(clk) then
            if i_rst_f = '1' then
                ram <= (others => (others => '0'));
            else
                -- Parallel RAM write for both ports.
                if i_rf_f.w0.en = '1' and unsigned(i_rf_f.w0.reg) /= 0 then
                    ram(to_integer(unsigned(i_rf_f.w0.reg))) <= i_rf_f.w0.data;
                end if;
                if i_rf_f.w1.en = '1' and unsigned(i_rf_f.w1.reg) /= 0 then
                    ram(to_integer(unsigned(i_rf_f.w1.reg))) <= i_rf_f.w1.data;
                end if;
            end if;
        end if;
    end process;

    -- Combinatorial parallel read.
    -- Register x0 is always read as zero.
    o_rf_s.r0.data <= ram(to_integer(unsigned(i_rf_f.r0.reg)))
                    when unsigned(i_rf_f.r0.reg) /= 0 else (others => '0');

    o_rf_s.r1.data <= ram(to_integer(unsigned(i_rf_f.r1.reg)))
                    when unsigned(i_rf_f.r1.reg) /= 0 else (others => '0');

end architecture;
