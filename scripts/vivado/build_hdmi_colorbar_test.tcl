# Build the independent HDMI color-bar target after it has been created by
# create_hdmi_colorbar_test.tcl.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname [file dirname $script_dir]]
set xpr_file   [file join $repo_dir vivado Super_Mario.xpr]
set report_dir [file join $repo_dir build hdmi_colorbar reports]
set output_dir [file join $repo_dir build hdmi_colorbar]

file mkdir $report_dir

open_project $xpr_file
set_property top hdmi_colorbar_top [get_filesets sources_1]
if {[get_property TOP [get_filesets sources_1]] ne "hdmi_colorbar_top"} {
    error "Unable to select hdmi_colorbar_top for the color-bar build"
}
reset_run colorbar_synth
launch_runs colorbar_synth -jobs 4
wait_on_run colorbar_synth

if {[get_property STATUS [get_runs colorbar_synth]] ne \
        "synth_design Complete!"} {
    error "Color-bar synthesis failed: [get_property STATUS \
        [get_runs colorbar_synth]]"
}

launch_runs colorbar_impl -to_step write_bitstream -jobs 4
wait_on_run colorbar_impl

if {[get_property STATUS [get_runs colorbar_impl]] ne \
        "write_bitstream Complete!"} {
    error "Color-bar implementation failed: [get_property STATUS \
        [get_runs colorbar_impl]]"
}

open_run colorbar_impl
report_timing_summary -delay_type min_max -report_unconstrained \
    -check_timing_verbose -max_paths 10 \
    -file [file join $report_dir timing_summary.rpt]
report_drc -file [file join $report_dir drc.rpt]
report_utilization -file [file join $report_dir utilization.rpt]

set run_dir [get_property DIRECTORY [get_runs colorbar_impl]]
set bit_file [file join $run_dir hdmi_colorbar_top.bit]
if {![file exists $bit_file]} {
    error "Expected bitstream was not generated: $bit_file"
}
file copy -force $bit_file [file join $output_dir hdmi_colorbar_top.bit]

puts "COLORBAR_BUILD_OK"
puts "BITSTREAM=[file join $output_dir hdmi_colorbar_top.bit]"
close_project
