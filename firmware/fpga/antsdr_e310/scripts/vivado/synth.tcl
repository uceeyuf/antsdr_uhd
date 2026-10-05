set root_dir [file normalize [file join [file dirname [info script]] ../..]]
open_project [file join $root_dir vivado project antsdr_e310 antsdr_e310.xpr]
if {[get_property STATUS [get_runs synth_1]] ne "Not started"} { reset_run synth_1 }
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "E310 synthesis failed: [get_property STATUS [get_runs synth_1]]"
}
open_run synth_1
file mkdir [file join $root_dir artifacts]
report_utilization -file [file join $root_dir artifacts utilization.rpt]
report_drc -file [file join $root_dir artifacts synth_drc.rpt]
set drc_errors [get_drc_violations -quiet -filter {SEVERITY == Error}]
if {[llength $drc_errors]} { error "Synthesis DRC errors: $drc_errors" }
write_hw_platform -fixed -force -file [file join $root_dir artifacts e310_synthesis_only.xsa]
close_project
