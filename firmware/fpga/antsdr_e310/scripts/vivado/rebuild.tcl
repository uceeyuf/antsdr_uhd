# Rebuild in one Vivado process; only export artifacts after timing/DRC checks.
set root_dir [file normalize [file join [file dirname [info script]] ../..]]
open_project [file join $root_dir vivado project antsdr_e310 antsdr_e310.xpr]
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} { error "Synthesis failed" }
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} { error "Implementation failed" }
open_run impl_1
report_drc -file [file join $root_dir artifacts routed_drc.rpt]
report_timing_summary -report_unconstrained -file [file join $root_dir artifacts routed_timing.rpt]
report_cdc -file [file join $root_dir artifacts routed_cdc.rpt]
if {[llength [get_drc_violations -quiet -filter {SEVERITY == Error}]]} { error "DRC errors" }
foreach kind {min max} {
    if {[get_property SLACK [get_timing_paths -delay_type $kind -max_paths 1]] < 0} { error "Timing failed ($kind)" }
}
file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] antsdr_e310.bit] [file join $root_dir artifacts antsdr_e310_experimental.bit]
write_hw_platform -fixed -include_bit -force -file [file join $root_dir artifacts antsdr_e310_experimental.xsa]
close_project
