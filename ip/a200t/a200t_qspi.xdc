# set_property -dict { PACKAGE_PIN L12 IOSTANDARD LVCMOS33 } [get_ports { qspi_clk }];
set_property -dict { PACKAGE_PIN T19 IOSTANDARD LVCMOS33 } [get_ports { qspi_cs }];
set_property -dict { PACKAGE_PIN P22 IOSTANDARD LVCMOS33 } [get_ports { qspi_dq0 }];
set_property -dict { PACKAGE_PIN R22 IOSTANDARD LVCMOS33 } [get_ports { qspi_dq1 }];
set_property -dict { PACKAGE_PIN P21 IOSTANDARD LVCMOS33 } [get_ports { qspi_dq2 }];
set_property -dict { PACKAGE_PIN R21 IOSTANDARD LVCMOS33 } [get_ports { qspi_dq3 }];
