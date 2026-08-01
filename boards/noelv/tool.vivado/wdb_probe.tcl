# vivado_repl (3.9.0) probe: the WDB is staged in runfiles via data=[:ddr3test_trace].
# First a DISCOVERY pass: confirm the WDB opens and whether we can read a signal
# value out of a static WDB (the key unknown for using the REPL this way).
puts "##### REPL WDB QUERY DISCOVERY @ [pwd] #####"
set wdb boards/noelv/tool.vivado/ddr3test_trace.wdb
puts "wdb exists = [file exists $wdb]"
if {[catch {open_wave_database $wdb} e]} {
    puts "open_wave_database ERR: $e"
    exit
}
puts "open_wave_database OK"
if {[catch {current_time} t]} { puts "current_time ERR: $t" } else { puts "current_time = $t" }

set objs [get_objects -nocase -r *ahbo_hbusreq*]
puts "ahbo_hbusreq objects found = [llength $objs]"
foreach o $objs {
    if {[catch {get_value $o} v]} { puts "  get_value ERR $o: $v" } else { puts "  $o = $v" }
}
puts "##### END DISCOVERY #####"
exit
