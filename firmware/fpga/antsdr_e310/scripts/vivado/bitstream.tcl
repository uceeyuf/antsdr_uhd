# Experimental bring-up artifact, using the standalone E310 electrical profile.
set root_dir [file normalize [file join [file dirname [info script]] ../..]]
open_project [file join $root_dir vivado project antsdr_e310 antsdr_e310.xpr]
if {[get_property STATUS [get_runs impl_1]] ni {"route_design Complete!" "write_bitstream Complete!"}} {
    error "Run build.sh route successfully before generating a bitstream"
}
if {[get_property NEEDS_REFRESH [get_runs impl_1]]} {
    error "Implementation is stale; rerun synthesis and routing"
}
open_run impl_1
report_cdc -details -file [file join $root_dir artifacts routed_cdc_details.rpt]
set setup [get_timing_paths -delay_type max -max_paths 1]
set hold [get_timing_paths -delay_type min -max_paths 1]
if {[get_property SLACK $setup] < 0 || [get_property SLACK $hold] < 0} {
    error "Constrained setup or hold timing failed"
}
close_design
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
}
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
    error "Implementation bitstream step failed"
}
open_run impl_1
file copy -force [file join [get_property DIRECTORY [get_runs impl_1]] antsdr_e310.bit] \
    [file join $root_dir artifacts antsdr_e310_experimental.bit]
write_hw_platform -fixed -include_bit -force -file [file join $root_dir artifacts antsdr_e310_experimental.xsa]
close_project
