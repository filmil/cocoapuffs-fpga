-- SPDX-License-Identifier: Apache-2.0
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library grlib;
    use grlib.amba.all;
    use grlib.stdlib.all;

library gaisler;
    use gaisler.plic.all;

-- Focused testbench for the GRLIB grplic_ahb (RISC-V PLIC).
--
-- Purpose: settle the "why does seip never assert" question for the Zircon
-- APBUART interrupt console.  On the FPGA the kernel/JTAG saw the PLIC fully and
-- correctly configured (priority[1]=1, pending=0x2, enable_ctx1=0x2,
-- threshold_ctx1=0) yet the hart's mip.SEIP stayed 0.  The S-context eip is an
-- INTERNAL wire (grplic.irqo(1) -> plic_eip(1) -> old_eip(0).seip), not
-- JTAG-visible, so it could never be observed directly on hardware.
--
-- This bench drives the exact same AHB configuration the kernel does, asserts
-- the APBUART interrupt line (ahbi.hirq(1), edge for irqtype=1), and directly
-- observes irqo(1).  It mirrors the real noelvsys instantiation:
--   ncpu=1, priorities=8, pendingbuff=1, irqtype=1, thrshld=1.
-- Context/target 1 is hart-0 S-mode, so irqo(1) is the seip source.
entity grplic_tb is
end entity;

architecture sim of grplic_tb is
    signal clk      : std_ulogic := '0';
    signal rstn     : std_ulogic := '0';

    signal ahbsi    : ahb_slv_in_type;
    signal ahbso    : ahb_slv_out_type;
    signal irqo     : std_logic_vector(1*4-1 downto 0);

    signal stop_sim : boolean := false;
    signal fail_count : natural := 0;

    -- Register map offsets (relative to base; the decoder ignores bits >= 22).
    constant PRIO_SRC1   : std_logic_vector(31 downto 0) := x"00000004";
    constant PENDING_0   : std_logic_vector(31 downto 0) := x"00001000";
    constant ENABLE_CTX1 : std_logic_vector(31 downto 0) := x"00002080";
    constant THRESH_CTX1 : std_logic_vector(31 downto 0) := x"00201000";
    constant CLAIM_CTX1  : std_logic_vector(31 downto 0) := x"00201004";
begin
    clk  <= not clk after 5 ns when not stop_sim else '0';
    rstn <= '1' after 100 ns;

    dut : grplic_ahb
        generic map (
            hindex      => 0,
            haddr       => 16#F80#,
            hmask       => 16#FC0#,
            nsources    => NAHBIRQ,
            ncpu        => 1,
            priorities  => 8,
            pendingbuff => 1,
            irqtype     => 1,
            thrshld     => 1
            )
        port map (
            rst  => rstn,
            clk  => clk,
            ahbi => ahbsi,
            ahbo => ahbso,
            irqo => irqo
            );

    main : process
        -- One pipelined single AHB transfer against the grplic slave.  Holds
        -- hsel(0) through the access, drops htrans to IDLE in the data phase so
        -- no second address is latched, then polls the slave's hready.
        procedure ahb_xfer(addr   : std_logic_vector(31 downto 0);
                           data   : std_logic_vector(31 downto 0);
                           wr     : std_ulogic;
                           rd_val : out std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk) and ahbso.hready = '1';
            ahbsi.hsel(0) <= '1';
            ahbsi.haddr   <= addr;
            ahbsi.hsize   <= "010";           -- 32-bit (grplic errors otherwise)
            ahbsi.hwrite  <= wr;
            ahbsi.htrans  <= HTRANS_NONSEQ;

            wait until rising_edge(clk);
            ahbsi.hwdata(31 downto 0) <= data;
            ahbsi.htrans  <= HTRANS_IDLE;

            loop
                wait until rising_edge(clk);
                if ahbso.hready = '1' then
                    rd_val := ahbso.hrdata(31 downto 0);
                    exit;
                end if;
            end loop;
            ahbsi.hsel(0) <= '0';
        end procedure;

        procedure ahb_write(addr : std_logic_vector(31 downto 0);
                            data : std_logic_vector(31 downto 0)) is
            variable dummy : std_logic_vector(31 downto 0);
        begin
            ahb_xfer(addr, data, '1', dummy);
        end procedure;

        procedure ahb_read(addr : std_logic_vector(31 downto 0);
                           val  : out std_logic_vector(31 downto 0)) is
        begin
            ahb_xfer(addr, x"00000000", '0', val);
        end procedure;

        procedure check(cond : boolean; name : string; got : std_logic_vector(31 downto 0)) is
        begin
            if cond then
                report name & ": OK (0x" & to_hstring(got) & ")";
            else
                report name & ": FAIL (0x" & to_hstring(got) & ")" severity error;
                fail_count <= fail_count + 1;
            end if;
        end procedure;

        variable v : std_logic_vector(31 downto 0);
    begin
        -- Initialize AHB master-side signals.
        ahbsi.hsel     <= (others => '0');
        ahbsi.haddr    <= (others => '0');
        ahbsi.hwrite   <= '0';
        ahbsi.htrans   <= HTRANS_IDLE;
        ahbsi.hsize    <= "010";
        ahbsi.hburst   <= (others => '0');
        ahbsi.hwdata   <= (others => '0');
        ahbsi.hprot    <= (others => '0');
        ahbsi.hready   <= '1';
        ahbsi.hmaster  <= (others => '0');
        ahbsi.hmastlock<= '0';
        ahbsi.hmbsel   <= (others => '0');
        ahbsi.hirq     <= (others => '0');
        ahbsi.testen   <= '0';
        ahbsi.testrst  <= '1';
        ahbsi.scanen   <= '0';
        ahbsi.testoen  <= '1';
        ahbsi.testin   <= (others => '0');
        ahbsi.endian   <= '0';

        wait until rstn = '1';
        wait until rising_edge(clk);

        -- 1) Configure the PLIC exactly like the kernel: source 1 priority = 1,
        --    S-context (ctx 1) enable bit for source 1, threshold = 0.
        ahb_write(PRIO_SRC1,   x"00000001");
        ahb_write(ENABLE_CTX1, x"00000002");
        ahb_write(THRESH_CTX1, x"00000000");

        -- Read the config back (proves the register file matches the HW/JTAG view).
        ahb_read(PRIO_SRC1, v);
        check(v(2 downto 0) = "001", "priority[1] == 1", v);
        ahb_read(ENABLE_CTX1, v);
        check(v = x"00000002", "enable_ctx1 == 0x2", v);

        -- irqo must still be idle before any interrupt.
        report "irqo before hirq = 0x" & to_hstring("0000" & irqo);
        check(irqo = "0000", "irqo idle pre-hirq", x"0000000" & irqo);

        -- 2) Assert the APBUART interrupt line (source 1). Edge-triggered gateway
        --    converts the 0->1 edge into a pending request that latches.
        wait until rising_edge(clk);
        ahbsi.hirq(1) <= '1';

        -- Let the gateway forward the edge and the encoder/target settle
        -- (gateway reg -> ipbits reg -> encoder comb -> meip reg -> irqo).
        for i in 0 to 9 loop
            wait until rising_edge(clk);
        end loop;

        -- 3) Cross-check register-visible state (matches the JTAG reads).
        ahb_read(PENDING_0, v);
        check(v(1) = '1', "pending source 1 set", v);

        -- 4) THE DECISIVE OBSERVATION: is the S-context eip (irqo(1)) asserted?
        report "irqo after hirq = 0x" & to_hstring("0000" & irqo);
        check(irqo(1) = '1', "irqo(1)/seip ASSERTED", x"0000000" & irqo);

        -- 5) Now emulate the hart claiming the interrupt (read claim/complete).
        --    max_id must read 1, and the claim must clear irqo(1) (gateway ip->0).
        ahb_read(CLAIM_CTX1, v);
        check(v(5 downto 0) = "000001", "claim_ctx1 == source 1", v);
        for i in 0 to 4 loop
            wait until rising_edge(clk);
        end loop;
        report "irqo after claim = 0x" & to_hstring("0000" & irqo);
        check(irqo(1) = '0', "irqo(1) cleared after claim", x"0000000" & irqo);

        if fail_count = 0 then
            report "GRPLIC SEIP TEST: ALL CHECKS PASSED";
        else
            report "GRPLIC SEIP TEST: " & integer'image(fail_count) &
                   " FAILURE(S)" severity failure;
        end if;

        stop_sim <= true;
        wait;
    end process;

end architecture;
