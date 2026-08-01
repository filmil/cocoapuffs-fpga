puts "SIM_TCL: Starting simulation"
open_vcd {{VCD_FILE}}

# Force key registers to break delta cycle oscillation at time 0.
# Variable initialization in the muntjac fork helps but is not sufficient
# on its own — the combinatorial loop between backend and cache still
# needs defined initial values to converge.
# See: https://github.com/lowRISC/muntjac/issues/4
catch {add_force /tb/reset 1}
catch {add_force /tb/uut0/muntjac_core_inst/core_inst/pipeline/frontend/resp_latched 0}
catch {add_force /tb/uut0/muntjac_core_inst/core_inst/pipeline/backend/de_ex_valid 0}

# Log all signals to VCD
log_vcd /*

puts "SIM_TCL: Running simulation"
set start_time [current_time]
if { [catch {run 100us} result] } {
    puts "SIM_TCL: Error during simulation: $result"
    close_vcd
    exit 1
}
set end_time [current_time]
if { $start_time == $end_time } {
    puts "SIM_TCL: Error: time did not advance from $start_time"
    close_vcd
    exit 1
}
puts "SIM_TCL: Simulation advanced to $end_time"

close_vcd
puts "SIM_TCL: Done"
exit
