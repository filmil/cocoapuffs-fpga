# Run the full boot with NO VCD *logging*.  The rule declares a .raw.vcd output, so
# we open+close it (the file must exist or bazel fails the action), but we do NOT
# log_vcd/log_wave any signals -- that's what avoids the multi-GB dump + the huge
# per-cycle tracking overhead (the default tcl does log_vcd [get_objects -r /*]).
# The testbench's ahb_monitor prints every low-region store to stdout, which is
# exactly where physboot's placement is visible -- no waveform needed.
puts "SIM_TCL: opensbi_trace_zircon_zbi -- NO VCD logging; ahb_monitor stdout carries the placement"
open_vcd {{VCD_FILE}}
run -all
close_vcd
puts "SIM_TCL: simulation finished at [current_time]"
exit
