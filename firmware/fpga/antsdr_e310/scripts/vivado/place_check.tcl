# Offline placement check only. No bitstream is produced by this target.
set root_dir [file normalize [file join [file dirname [info script]] ../..]]
open_project [file join $root_dir vivado project antsdr_e310 antsdr_e310.xpr]
set done_states {"place_design Complete!" "Not started phys_opt_design"}
if {[get_property STATUS [get_runs impl_1]] ni $done_states} {
    launch_runs impl_1 -to_step place_design -jobs 4
    wait_on_run impl_1
}
if {[get_property STATUS [get_runs impl_1]] ni $done_states} {
    error "E310 placement failed: [get_property STATUS [get_runs impl_1]]"
}
close_project
open_checkpoint [file join $root_dir vivado project antsdr_e310 antsdr_e310.runs impl_1 antsdr_e310_placed.dcp]
report_clocks -file [file join $root_dir artifacts placed_clocks.rpt]
report_drc -file [file join $root_dir artifacts placed_drc.rpt]
report_timing_summary -report_unconstrained -file [file join $root_dir artifacts placed_timing.rpt]
close_project
