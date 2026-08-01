# SPDX-License-Identifier: Apache-2.0
create_clock -add -name sys_clk_p -period 5.0 -waveform {0 2.5} [get_ports {sys_clk_p}];

# Xilinx docs say only positive end of the diffferential clock should be constrained.
#create_clock -add -name sys_clk_n -period 5.0 -waveform {2.5 5.0} [get_ports {sys_clk_n}];

# This should theoretically be there.
# create_clock -add -name clk100mhz -period 10.0 -waveform {0 5} [get_ports {top/clock_generator/CLKOUT0}];

set_property -dict { PACKAGE_PIN R4 IOSTANDARD LVDS_25 } [get_ports { sys_clk_p }];
set_property -dict { PACKAGE_PIN T4 IOSTANDARD LVDS_25 } [get_ports { sys_clk_n }];

set_property -dict { PACKAGE_PIN L15 IOSTANDARD LVCMOS33 } [get_ports { tx }];
set_property -dict { PACKAGE_PIN L14 IOSTANDARD LVCMOS33 } [get_ports { rx }];

set_property -dict { PACKAGE_PIN F15 IOSTANDARD LVCMOS33 } [get_ports { reset_n }];

set_property CONFIG_VOLTAGE 3.3 [current_design];
set_property CFGBVS VCCO [current_design];

# All LEDs are lit when driven low.
set_property -dict { PACKAGE_PIN L13 IOSTANDARD LVCMOS33 } [get_ports { led1 }];
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports { led2 }];
set_property -dict { PACKAGE_PIN K14 IOSTANDARD LVCMOS33 } [get_ports { led3 }];
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports { led4 }];