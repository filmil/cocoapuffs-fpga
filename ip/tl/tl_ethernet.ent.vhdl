-- SPDX-License-Identifier: Apache-2.0
library ieee;
use ieee.std_logic_1164.all;

library tl;
use tl.types.all;

--! @file
--! @brief TileLink-UH Ethernet Controller entity definition.

--! @brief TileLink-UH Ethernet Controller.
--! This component provides a TileLink-UH interface to an Ethernet PHY
--! using the RGMII protocol.
entity tl_ethernet is
    generic (
        --! Base address of the controller in the memory map.
        BASE_ADDRESS : std_ulogic_vector(ADDRESS_WIDTH-1 downto 0) := (others => '0')
    );
    port (
        --! Global clock.
        clk       : in  std_ulogic;
        --! Synchronous reset, active high.
        rst       : in  std_ulogic;

        --! TileLink peripheral interface.
        tl_i      : in  host_type;
        --! TileLink peripheral output.
        tl_o      : out per_type;

        --! RGMII transmit clock
        eth_txck  : out std_ulogic;
        --! RGMII transmit control
        eth_txctl : out std_ulogic;
        --! RGMII transmit data
        eth_txd   : out std_ulogic_vector(3 downto 0);

        --! RGMII receive clock
        eth_rxck  : in  std_ulogic;
        --! RGMII receive control
        eth_rxctl : in  std_ulogic;
        --! RGMII receive data
        eth_rxd   : in  std_ulogic_vector(3 downto 0);

        --! Management Data Clock
        eth_mdc   : out std_ulogic;
        --! Management Data Input/Output
        eth_mdio  : inout std_logic;

        --! PHY Chip Reset Signal (active low)
        eth_reset : out std_ulogic;

        --! Interrupt signal
        irq       : out std_ulogic
    );
end entity tl_ethernet;
