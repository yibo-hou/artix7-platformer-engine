# Build the framebuffer black-display hardware and export an XSA for the
# MicroBlaze software build.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname [file dirname $script_dir]]
set xpr_file   [file join $repo_dir vivado Super_Mario.xpr]
set output_dir [file join $repo_dir build framebuffer_black]
set report_dir [file join $output_dir reports]
file mkdir $output_dir
file mkdir $report_dir

open_project $xpr_file
set_property top framebuffer_black_top [get_filesets sources_1]

foreach run_name {ila_framebuffer_black_synth_1 framebuffer_black_synth} {
    if {[llength [get_runs -quiet $run_name]] != 0} {
        reset_run [get_runs $run_name]
    }
}
reset_run [get_runs framebuffer_black_impl]

launch_runs framebuffer_black_synth -jobs 8
wait_on_run framebuffer_black_synth
if {[get_property STATUS [get_runs framebuffer_black_synth]] ne \
        "synth_design Complete!"} {
    error "Framebuffer black synthesis failed: [get_property STATUS \
        [get_runs framebuffer_black_synth]]"
}

launch_runs framebuffer_black_impl -to_step write_bitstream -jobs 8
wait_on_run framebuffer_black_impl
if {[get_property STATUS [get_runs framebuffer_black_impl]] ne \
        "write_bitstream Complete!"} {
    error "Framebuffer black implementation failed: [get_property STATUS \
        [get_runs framebuffer_black_impl]]"
}

open_run framebuffer_black_impl
report_timing_summary -delay_type min_max -report_unconstrained \
    -check_timing_verbose -max_paths 10 \
    -file [file join $report_dir timing_summary.rpt]
report_bus_skew -warn_on_violation \
    -file [file join $report_dir bus_skew.rpt]
report_drc -file [file join $report_dir drc.rpt]
report_utilization -file [file join $report_dir utilization.rpt]
write_debug_probes -force \
    [file join $output_dir framebuffer_black_top.ltx]

set run_dir [get_property DIRECTORY [get_runs framebuffer_black_impl]]
set raw_bit [file join $run_dir framebuffer_black_top.bit]
file copy -force $raw_bit [file join $output_dir framebuffer_black_hw.bit]
write_hw_platform -fixed -include_bit -force \
    -file [file join $output_dir framebuffer_black.xsa]

puts "FRAMEBUFFER_BLACK_HW_BUILD_OK"
puts "RAW_BIT=[file join $output_dir framebuffer_black_hw.bit]"
puts "XSA=[file join $output_dir framebuffer_black.xsa]"
puts "LTX=[file join $output_dir framebuffer_black_top.ltx]"
close_project
