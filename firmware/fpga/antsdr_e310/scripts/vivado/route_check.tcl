# Route and report the experimental board design. Do not silently accept errors.
set root_dir [file normalize [file join [file dirname [info script]] ../..]]
open_project [file join $root_dir vivado project antsdr_e310 antsdr_e310.xpr]
set ps_xdc [file join $root_dir xdc e310_ps_clocks.xdc]
if {[llength [get_files -quiet $ps_xdc]] == 0} { add_files -fileset constrs_1 $ps_xdc }
set_property USED_IN_SYNTHESIS false [get_files $ps_xdc]
set_property PROCESSING_ORDER LATE [get_files $ps_xdc]
reset_run impl_1
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
set result [get_property STATUS [get_runs impl_1]]
if {$result ne "route_design Complete!"} { error "E310 route failed: $result" }
open_run impl_1
report_drc -file [file join $root_dir artifacts routed_drc.rpt]
report_timing_summary -report_unconstrained -file [file join $root_dir artifacts routed_timing.rpt]
report_cdc -file [file join $root_dir artifacts routed_cdc.rpt]
report_bus_skew -file [file join $root_dir artifacts routed_bus_skew.rpt]
write_checkpoint -force [file join $root_dir artifacts e310_routed.dcp]
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} {
    error "E310 routed design has DRC errors"
}
close_project
