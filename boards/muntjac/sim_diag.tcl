puts "SIM_TCL: Starting simulation"
open_vcd {{VCD_FILE}}

# Force key registers to break delta cycle oscillation at time 0.
# Variable initialization in the muntjac fork helps but is not sufficient
# on its own — the combinatorial loop between backend and cache still
# needs defined initial values to converge.
# See: https://github.com/lowRISC/muntjac/issues/4
add_force /tb_minimal/rst_n 0
add_force /tb_minimal/uut/pipeline/frontend/resp_latched 0
add_force /tb_minimal/uut/pipeline/backend/de_ex_valid 0

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
