# Validate the relocatable source project without launching synthesis.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname [file dirname $script_dir]]
set xpr_file   [file join $repo_dir vivado Super_Mario.xpr]

open_project $xpr_file

set expected_files [list \
    [file join $repo_dir rtl top framebuffer_black_top.sv] \
    [file join $repo_dir rtl top ddr3_axi_selftest_top.sv] \
    [file join $repo_dir rtl sprite sprite_engine.sv] \
    [file join $repo_dir rtl sprite sprite_frame_stream.sv] \
    [file join $repo_dir rtl hdmi hdmi_720p.sv] \
    [file join $repo_dir rtl video hdmi_vdma_fifo_bridge.sv] \
    [file join $repo_dir rtl memory hdmi_pixel_fifo.sv] \
    [file join $repo_dir constraints framebuffer_black_cf7a100b.xdc] \
    [file join $repo_dir constraints ddr3_selftest_cf7a100b.xdc] \
    [file join $repo_dir vivado ip mig cf7a100b_mig.prj] \
]

foreach expected $expected_files {
    if {![file exists $expected]} {
        error "Required rebuild source is missing: $expected"
    }
}

set bd_file [lindex [get_files -quiet */framebuffer_black_bd.bd] 0]
if {$bd_file eq ""} {
    error "framebuffer_black_bd is missing from the project"
}
open_bd_design $bd_file
validate_bd_design

set required_ips {mig_7series_0 clk_wiz_hdmi_framebuffer ila_framebuffer_black}
foreach ip_name $required_ips {
    if {[llength [get_ips -quiet $ip_name]] != 1} {
        error "Expected exactly one configured IP named $ip_name"
    }
}

puts "VIVADO_VERSION=[version -short]"
puts "PROJECT_PART=[get_property PART [current_project]]"
puts "PROJECT_TOP=[get_property TOP [get_filesets sources_1]]"
puts "PROJECT_SOURCE_COUNT=[llength [get_files -of_objects [get_filesets sources_1]]]"
puts "VIVADO_SOURCE_PROJECT_OK"

close_bd_design [current_bd_design]
close_project
