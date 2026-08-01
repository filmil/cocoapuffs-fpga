-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.devices.all;
library wb;
use wb.host;
use wb.per;

entity ahb2wb_bridge is
    generic (
        HSEL_INDEX : integer := 0;
        HINDEX     : integer := 0;
        ADDR       : integer := 16#000#;
        MASK       : integer := 16#C00#
    );
    port (
        clk_ahb : in std_ulogic; -- 50MHz
        clk_wb  : in std_ulogic; -- 100MHz
        rst     : in std_ulogic;

        ahb_ahbsi : in ahb_slv_in_type;
        ahb_ahbso : out ahb_slv_out_type;

        wb_wbo    : out wb.host.bus_type;
        wb_wbi    : in wb.per.bus_type
    );
end entity;

architecture rtl of ahb2wb_bridge is
    -- GRLIB PnP Configuration
    constant hconfig : ahb_config_type := (
        0 => ahb_device_reg(VENDOR_CONTRIB, 16#001#, 0, 0, 0),
        4 => ahb_membar(ADDR, '1', '1', MASK),
        others => (others => '0')
    );

    -- AHB domain state
    type ahb_state_t is (AHB_IDLE, AHB_DATA_PHASE, AHB_WAIT_ACK, AHB_CLEANUP);
    signal ahb_state : ahb_state_t := AHB_IDLE;

    signal ahb_haddr : std_logic_vector(31 downto 0);
    signal ahb_hwdata : std_logic_vector(31 downto 0);
    signal ahb_hwrite : std_ulogic;
    signal ahb_hready : std_ulogic := '1';
    signal ahb_hrdata : std_logic_vector(31 downto 0);

    -- AHB to WB request (4-phase handshake)
    signal ahb_req : std_ulogic := '0';
    signal ahb_ack_sync : std_ulogic := '0';
    signal ahb_ack_q : std_ulogic_vector(1 downto 0) := (others => '0');

    -- WB domain state
    type wb_state_t is (WB_IDLE, WB_START, WB_WAIT, WB_DONE);
    signal wb_state : wb_state_t := WB_IDLE;

    -- WB from AHB request (4-phase handshake)
    signal wb_req_sync : std_ulogic := '0';
    signal wb_req_q : std_ulogic_vector(1 downto 0) := (others => '0');
    signal wb_ack : std_ulogic := '0';

    -- WB data registers
    signal wb_adr : std_ulogic_vector(31 downto 0);
    signal wb_dat : std_ulogic_vector(31 downto 0);
    signal wb_we  : std_ulogic;
    signal wb_cyc : std_ulogic := '0';
    signal wb_hrdata_reg : std_logic_vector(31 downto 0);

    -- Per-byte write strobes derived from the AHB transfer size (hsize) and the
    -- low address bits.  Without this the bridge wrote every byte of the 32-bit
    -- word on a sub-word store (the NOEL-V replicates the byte across all lanes),
    -- so an `sb` clobbered the whole word -- which silently corrupted DDR3 and
    -- broke sbi_memcpy/sbi_memset (hence OpenSBI). One bit per byte of wb dat.
    signal ahb_sel : std_ulogic_vector(3 downto 0) := (others => '1');
    signal wb_sel  : std_ulogic_vector(3 downto 0) := (others => '1');

begin

    ---------------------------------------------------------------------------
    -- AHB Domain (50MHz)
    ---------------------------------------------------------------------------
    process(clk_ahb)
    begin
        if rising_edge(clk_ahb) then
            if rst = '1' then
                ahb_state <= AHB_IDLE;
                ahb_req <= '0';
                ahb_hready <= '1';
                ahb_ack_q <= (others => '0');
                ahb_ack_sync <= '0';
            else
                -- Synchronize WB ack to AHB domain
                ahb_ack_q <= ahb_ack_q(0) & wb_ack;
                ahb_ack_sync <= ahb_ack_q(1);

                case ahb_state is
                    when AHB_IDLE =>
                        -- Check for valid AHB transaction start.
                        if (ahb_ahbsi.hsel(HSEL_INDEX) = '1' and
                           (ahb_ahbsi.htrans = HTRANS_NONSEQ or ahb_ahbsi.htrans = HTRANS_SEQ)) then
                            ahb_haddr <= ahb_ahbsi.haddr;
                            ahb_hwrite <= ahb_ahbsi.hwrite;
                            -- Derive per-byte write strobes from hsize + offset.
                            case ahb_ahbsi.hsize(1 downto 0) is
                                when "00" =>            -- byte
                                    case ahb_ahbsi.haddr(1 downto 0) is
                                        when "00"   => ahb_sel <= "0001";
                                        when "01"   => ahb_sel <= "0010";
                                        when "10"   => ahb_sel <= "0100";
                                        when others => ahb_sel <= "1000";
                                    end case;
                                when "01" =>            -- halfword
                                    if ahb_ahbsi.haddr(1) = '0' then
                                        ahb_sel <= "0011";
                                    else
                                        ahb_sel <= "1100";
                                    end if;
                                when others =>          -- word (or wider)
                                    ahb_sel <= "1111";
                            end case;
                            ahb_hready <= '0';
                            if ahb_ahbsi.hwrite = '1' then
                                -- For writes, hwdata is available in the next cycle.
                                ahb_state <= AHB_DATA_PHASE;
                            else
                                -- For reads, start request immediately.
                                ahb_req <= '1';
                                ahb_state <= AHB_WAIT_ACK;
                            end if;
                        end if;

                    when AHB_DATA_PHASE =>
                        -- Capture write data
                        ahb_hwdata <= ahb_ahbsi.hwdata(31 downto 0);
                        ahb_req <= '1';
                        ahb_state <= AHB_WAIT_ACK;

                    when AHB_WAIT_ACK =>
                        if ahb_ack_sync = '1' then
                            -- Capture read data from WB domain (stable because ack is high)
                            ahb_hrdata <= wb_hrdata_reg;
                            ahb_req <= '0';
                            ahb_state <= AHB_CLEANUP;
                        end if;

                    when AHB_CLEANUP =>
                        -- Wait for WB ack to clear to complete 4-phase handshake
                        if ahb_ack_sync = '0' then
                            ahb_hready <= '1';
                            ahb_state <= AHB_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;

    ahb_ahbso.hready <= ahb_hready;
    ahb_ahbso.hrdata(31 downto 0) <= ahb_hrdata;
    ahb_ahbso.hresp <= HRESP_OKAY;
    ahb_ahbso.hindex <= HINDEX;
    ahb_ahbso.hirq <= (others => '0');
    ahb_ahbso.hconfig <= hconfig;
    ahb_ahbso.hsplit <= (others => '0');

    ---------------------------------------------------------------------------
    -- Wishbone Domain (100MHz)
    ---------------------------------------------------------------------------
    process(clk_wb)
    begin
        if rising_edge(clk_wb) then
            if rst = '1' then
                wb_state <= WB_IDLE;
                wb_ack <= '0';
                wb_req_q <= (others => '0');
                wb_req_sync <= '0';
                wb_cyc <= '0';
            else
                -- Synchronize AHB request to WB domain
                wb_req_q <= wb_req_q(0) & ahb_req;
                wb_req_sync <= wb_req_q(1);

                case wb_state is
                    when WB_IDLE =>
                        if wb_req_sync = '1' then
                            -- Capture signals from AHB domain (stable because req is high)
                            wb_adr <= std_ulogic_vector(ahb_haddr);
                            wb_we <= ahb_hwrite;
                            wb_dat <= std_ulogic_vector(ahb_hwdata);
                            wb_sel <= ahb_sel;
                            wb_state <= WB_START;
                        end if;

                    when WB_START =>
                        wb_cyc <= '1';
                        wb_state <= WB_WAIT;

                    when WB_WAIT =>
                        if wb_wbi.ack = '1' then
                            wb_cyc <= '0';
                            wb_hrdata_reg <= std_logic_vector(wb_wbi.rdt);
                            wb_ack <= '1';
                            wb_state <= WB_DONE;
                        end if;

                    when WB_DONE =>
                        -- Wait for AHB req to clear to complete 4-phase handshake
                        if wb_req_sync = '0' then
                            wb_ack <= '0';
                            wb_state <= WB_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;

    wb_wbo.adr <= wb_adr;
    wb_wbo.dat <= wb_dat;
    wb_wbo.we <= wb_we;
    wb_wbo.sel <= wb_sel;
    wb_wbo.cyc <= wb_cyc;

end architecture;
