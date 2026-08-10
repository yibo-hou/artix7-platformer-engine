# Build the independent DDR3 AXI self-test target.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname [file dirname $script_dir]]
set xpr_file   [file join $repo_dir vivado Super_Mario.xpr]
set output_dir [file join $repo_dir build ddr3_selftest]
set report_dir [file join $output_dir reports]

file mkdir $report_dir
open_project $xpr_file
set_property top ddr3_axi_selftest_top [get_filesets sources_1]
if {[get_property TOP [get_filesets sources_1]] ne "ddr3_axi_selftest_top"} {
    error "Unable to select ddr3_axi_selftest_top for the DDR3 build"
}

# MIG is synthesized out of context. Reset it as well so changes to
# vivado/ip/mig/cf7a100b_mig.prj cannot leave a stale port list or clock structure in
# the parent run.
if {[llength [get_runs -quiet mig_7series_0_synth_1]] != 0} {
    reset_run mig_7series_0_synth_1
}
reset_run ddr3_selftest_synth
launch_runs ddr3_selftest_synth -jobs 4
wait_on_run ddr3_selftest_synth
if {[get_property STATUS [get_runs ddr3_selftest_synth]] ne \
        "synth_design Complete!"} {
    error "DDR3 self-test synthesis failed: [get_property STATUS \
        [get_runs ddr3_selftest_synth]]"
}

launch_runs ddr3_selftest_impl -to_step write_bitstream -jobs 4
wait_on_run ddr3_selftest_impl
if {[get_property STATUS [get_runs ddr3_selftest_impl]] ne \
        "write_bitstream Complete!"} {
    error "DDR3 self-test implementation failed: [get_property STATUS \
        [get_runs ddr3_selftest_impl]]"
}

open_run ddr3_selftest_impl
report_timing_summary -delay_type min_max -report_unconstrained \
    -check_timing_verbose -max_paths 10 \
    -file [file join $report_dir timing_summary.rpt]
report_drc -file [file join $report_dir drc.rpt]
report_utilization -file [file join $report_dir utilization.rpt]

set run_dir [get_property DIRECTORY [get_runs ddr3_selftest_impl]]
set bit_file [file join $run_dir ddr3_axi_selftest_top.bit]
if {![file exists $bit_file]} {
    error "Expected bitstream was not generated: $bit_file"
}
file copy -force $bit_file \
    [file join $output_dir ddr3_axi_selftest_top.bit]

puts "DDR3_SELFTEST_BUILD_OK"
puts "BITSTREAM=[file join $output_dir ddr3_axi_selftest_top.bit]"
close_project
