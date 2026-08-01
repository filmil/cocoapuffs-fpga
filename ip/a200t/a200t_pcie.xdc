# PCI Express pins for Alinx A200T
# MGT Clock 1 (PCIE Clock)
set_property PACKAGE_PIN F10 [get_ports { pcie_clk_p }];
set_property PACKAGE_PIN E10 [get_ports { pcie_clk_n }];

# PCIe Receive Lanes
set_property PACKAGE_PIN D9 [get_ports { pcie_rx_p[0] }];
set_property PACKAGE_PIN C9 [get_ports { pcie_rx_n[0] }];
set_property PACKAGE_PIN B10 [get_ports { pcie_rx_p[1] }];
set_property PACKAGE_PIN A10 [get_ports { pcie_rx_n[1] }];

# PCIe Transmit Lanes
set_property PACKAGE_PIN D7 [get_ports { pcie_tx_p[0] }];
set_property PACKAGE_PIN C7 [get_ports { pcie_tx_n[0] }];
set_property PACKAGE_PIN B6 [get_ports { pcie_tx_p[1] }];
set_property PACKAGE_PIN A6 [get_ports { pcie_tx_n[1] }];
