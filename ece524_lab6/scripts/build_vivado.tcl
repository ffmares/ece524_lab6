# Run from Vivado Tcl Console: source scripts/build_vivado.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
if {[llength [get_projects -quiet]] == 0} {
    open_project [file join $root ece524_lab6.xpr]
}
if {[file normalize [get_property DIRECTORY [current_project]]] ne $root} {
    error "Open ece524_lab6.xpr before running this script"
}
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "Synthesis failed"}
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Implementation failed"}
open_run impl_1
set reports [file join $root reports]
file mkdir $reports
report_timing_summary -check_timing_verbose -file [file join $reports timing_summary.rpt]
report_drc -file [file join $reports drc.rpt]
report_utilization -file [file join $reports utilization.rpt]
foreach delay_type {max min} {
    set paths [get_timing_paths -delay_type $delay_type -max_paths 1]
    if {[llength $paths] == 0} {error "No timing paths found"}
    if {[get_property SLACK $paths] < 0} {error "Timing failed: inspect reports"}
}
write_bitstream -force [file join $reports main_fsm.bit]
puts "Bitstream and implementation reports written to $reports"
