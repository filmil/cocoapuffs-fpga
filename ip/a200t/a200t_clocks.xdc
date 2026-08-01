# SPDX-License-Identifier: Apache-2.0
create_clock -add -name sys_clk_p -period 5.0 -waveform {0 2.5} [get_ports {sys_clk_p}];

