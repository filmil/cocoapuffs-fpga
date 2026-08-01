# custom_tcl_script for :ddr3test_trace (live xsim -- values readable here).
# At the steady wedge (40 us), dump the WHOLE bus-interface (bif0/x0) state plus
# the data-cache->bus request, to see exactly what gates hbusreq for the 0x40000
# store (which bif0 holds but never requests the bus for).
open_vcd {{VCD_FILE}}
log_vcd [get_objects -r /* ]
log_wave -recursive *

run 40000 ns
puts "########## BIF0 BUS-INTERFACE STATE @ [current_time] ##########"
set n 0
foreach o [get_objects -nocase -r *bif0/x0/*] {
    if {![catch {get_value -radix hex $o} v]} {
        puts "   $o = $v"
        incr n
        if {$n > 120} { puts "   ... (truncated)"; break }
    }
}
puts "########## ($n bif0 signals) ##########"

run -all
close_vcd
exit
