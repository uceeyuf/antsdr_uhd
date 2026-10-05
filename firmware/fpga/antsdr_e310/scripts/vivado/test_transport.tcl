set root_dir [file normalize [file join [file dirname [info script]] ../..]]
set proj_dir [file join $root_dir vivado transport_test]
create_project e310_transport_test $proj_dir -part xc7z020clg400-2 -force
set_property simulator_language Mixed [current_project]
source [file join $root_dir scripts vivado create_e310_sources.tcl]
add_files -fileset sim_1 [file join $root_dir tests tb_e310_transport.sv]
set_property top tb_e310_transport [get_filesets sim_1]
set_property top_auto_set false [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
close_sim
close_project
