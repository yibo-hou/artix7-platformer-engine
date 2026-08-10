# Add an independent MIG AXI write/read/compare target to Super_Mario.xpr.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname [file dirname $script_dir]]
set xpr_file   [file join $repo_dir vivado Super_Mario.xpr]
set top_file   [file join $repo_dir rtl top ddr3_axi_selftest_top.sv]
set xdc_file   [file join $repo_dir constraints ddr3_selftest_cf7a100b.xdc]

open_project $xpr_file

if {[llength [get_ips -quiet mig_7series_0]] != 1} {
    error "mig_7series_0 is missing; run scripts/vivado/create_cf7a100b_mig.tcl first"
}

if {[llength [get_files -quiet -of_objects [get_filesets sources_1] \
        $top_file]] == 0} {
    add_files -fileset sources_1 -norecurse $top_file
}
set_property file_type SystemVerilog [get_files $top_file]
set_property top ddr3_axi_selftest_top [get_filesets sources_1]

if {[llength [get_filesets -quiet ddr3_selftest_constrs]] == 0} {
    create_fileset -constrset ddr3_selftest_constrs
}
if {[llength [get_files -quiet -of_objects \
        [get_filesets ddr3_selftest_constrs] $xdc_file]] == 0} {
    add_files -fileset ddr3_selftest_constrs -norecurse $xdc_file
}

if {[llength [get_runs -quiet ddr3_selftest_synth]] == 0} {
    create_run ddr3_selftest_synth -flow {Vivado Synthesis 2025} \
        -srcset sources_1 -constrset ddr3_selftest_constrs \
        -part xc7a100tfgg484-2
}
if {[llength [get_runs -quiet ddr3_selftest_impl]] == 0} {
    create_run ddr3_selftest_impl -flow {Vivado Implementation 2025} \
        -parent_run ddr3_selftest_synth -part xc7a100tfgg484-2
}

puts "DDR3_SELFTEST_TARGET_OK"
close_project
