# CSR-record X inspector, iteration 2: use the EXACT escaped paths from the
# v1 CSRX-DISCOVER sweep and dump the records that feed the fetch-permission
# path.  get_value on a record prints the whole aggregate; also enumerate
# children both as .field and /field to learn the addressing that works.
puts "SIM_TCL: sim_csr_xdump v3 -- precalc/pmpaddr at t=1ns, 200ns, 6500ns"
open_vcd {{VCD_FILE}}

set c0 {/tb_noelvsys_only/noelv0/\cpuloop(0)\/core/u0/c0/c0}
# v5: precalc is now DEFINED+granting at cctrl, yet the S-fetch still faults.
# Watch the icache interface across the fetch window (fault commits at
# ~5637 ns): ici (request, incl. mode) and ico (response: mexc/exctype tell
# WHO raised the fault).
# v7: the csrw COMMITS (trace C[pmpaddr0=...]) but the register never holds
# the value even with reorder+NOPs.  Suspect: the iunv:14010 every-cycle tie
# `v.csr.pmpaddr(pmp_entries to 15) := zero` with pmp_entries=0.  Dump the
# GENERICS + watch rin.csr.pmpaddr around the write cycle (~4800-5000 ns).
run 1 ns
foreach g [list pmp_entries pmp_g pmp_no_tor physaddr pmp_msb] {
    if {[catch {set v [get_value "$c0/iu0/$g"]} err]} {
        puts "GEN $g : <fail>"
    } else {
        puts "GEN $g : $v"
    }
}
run 4749 ns
foreach t {25 25 25 25 25 25 25 25 25 25} {
    run $t ns
    foreach obj [list "$c0/iu0/rin.csr.pmpaddr" "$c0/iu0/r.csr.pmpaddr"] {
        if {[catch {set v [get_value -radix hex $obj]} err]} {
            puts "RINP [current_time] $obj : <fail>"
        } else {
            puts "RINP [current_time] [string range $obj end-19 end] : [string range $v 0 60]"
        }
    }
}
run 900 ns
set targets [list \
    "$c0/csr_mmu" \
    "$c0/mmu_csr" \
    "$c0/iu0/r.csr.satp" \
    "$c0/iu0/r.csr.prv" \
    "$c0/iu0/r.csr.v" \
    "$c0/iu0/r.csr.dfeaturesen" \
    "$c0/iu0/r.csr.pma_data" \
    "$c0/iu0/r.csr.pma_addr" \
    "$c0/iu0/r.csr.pma_precalc" \
    "$c0/iu0/r.csr.pmp_precalc" \
    "$c0/iu0/r.csr.pmpcfg0" \
    "$c0/iu0/r.csr.mstatus" \
    "$c0/iu0/r.mmu" \
]
foreach obj $targets {
    if {[catch {set v [get_value -radix hex $obj]} err]} {
        puts "CSRX $obj : <fail: $err>"
    } else {
        puts "CSRX $obj : $v"
    }
}

# enumerate children of the interface records (learn field addressing)
foreach parent [list "$c0/csr_mmu" "$c0/mmu_csr" "$c0/iu0/r"] {
    puts "CSRX-CHILDREN of $parent :"
    if {[catch {
        foreach o [get_objects "$parent.*"] { puts "CSRX-CH $o" }
    } e1]} { puts "CSRX-CH dot-form failed: $e1" }
    if {[catch {
        foreach o [get_objects "$parent/*"] { puts "CSRX-CH2 $o" }
    } e2]} { puts "CSRX-CH2 slash-form failed: $e2" }
}

run -all
close_vcd
puts "SIM_TCL: simulation finished at [current_time]"
exit
