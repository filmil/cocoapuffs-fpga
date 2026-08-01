-- SPDX-License-Identifier: Apache-2.0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @file
--! @brief Simulation model for the JL2121-N040I Gigabit Ethernet PHY.

--! @brief Ethernet PHY simulation model.
--! Provides a loopback for RGMII data and a simple MDIO responder.
entity phy is
    port (
        --! RGMII transmit clock
        eth_txck   : in  std_ulogic;
        --! RGMII transmit control
        eth_txctl  : in  std_ulogic;
        --! RGMII transmit data
        eth_txd    : in  std_ulogic_vector(3 downto 0);

        --! RGMII receive clock
        eth_rxck   : out std_ulogic;
        --! RGMII receive control
        eth_rxctl  : out std_ulogic;
        --! RGMII receive data
        eth_rxd    : out std_ulogic_vector(3 downto 0);

        --! Management Data Clock
        eth_mdc    : in  std_ulogic;
        --! Management Data Input/Output
        eth_mdio   : inout std_logic;

        --! PHY Chip Reset Signal (active low)
        eth_reset  : in  std_ulogic
    );
end entity phy;

architecture sim of phy is
begin
    -- Simple RGMII loopback
    eth_rxck  <= eth_txck;
    eth_rxctl <= eth_txctl;
    eth_rxd   <= eth_txd;

    -- High-Z MDIO for now
    eth_mdio  <= 'Z';
end architecture sim;
