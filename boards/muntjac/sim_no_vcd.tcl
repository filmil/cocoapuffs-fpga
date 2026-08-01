puts "SIM_TCL: Starting simulation script (NO VCD)"
puts "SIM_TCL: Running simulation"
set start_time [current_time]
if { [catch {run 1ns} result] } {
    puts "SIM_TCL: Error during simulation: $result"
    exit 1
}
set end_time [current_time]
if { $start_time == $end_time } {
    puts "SIM_TCL: Error during simulation: time did not advance from $start_time. Possible FATAL_ERROR."
    exit 1
}
puts "SIM_TCL: Exiting simulation"
exit
