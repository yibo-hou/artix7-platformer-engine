# Register the complete DDR3 framebuffer black-display target and its runs.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname [file dirname $script_dir]]
set xpr_file   [file join $repo_dir vivado Super_Mario.xpr]

open_project $xpr_file

if {[llength [get_ips -quiet clk_wiz_hdmi_framebuffer]] == 0} {
    create_ip -name clk_wiz -vendor xilinx.com -library ip \
        -module_name clk_wiz_hdmi_framebuffer
}
set_property -dict [list \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_SOURCE {No_buffer} \
    CONFIG.PRIM_IN_FREQ {50.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {74.250} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {371.250} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
] [get_ips clk_wiz_hdmi_framebuffer]
generate_target all [get_ips clk_wiz_hdmi_framebuffer]
export_ip_user_files -of_objects [get_ips clk_wiz_hdmi_framebuffer] \
    -no_script -sync -force

if {[llength [get_ips -quiet ila_framebuffer_black]] == 0} {
    create_ip -name ila -vendor xilinx.com -library ip \
        -module_name ila_framebuffer_black
}
set_property -dict [list \
    CONFIG.C_DATA_DEPTH {4096} \
    CONFIG.C_NUM_OF_PROBES {28} \
    CONFIG.C_PROBE0_WIDTH {1} \
    CONFIG.C_PROBE1_WIDTH {1} \
    CONFIG.C_PROBE2_WIDTH {1} \
    CONFIG.C_PROBE3_WIDTH {1} \
    CONFIG.C_PROBE4_WIDTH {16} \
    CONFIG.C_PROBE5_WIDTH {1} \
    CONFIG.C_PROBE6_WIDTH {1} \
    CONFIG.C_PROBE7_WIDTH {1} \
    CONFIG.C_PROBE8_WIDTH {1} \
    CONFIG.C_PROBE9_WIDTH {32} \
    CONFIG.C_PROBE10_WIDTH {1} \
    CONFIG.C_PROBE11_WIDTH {1} \
    CONFIG.C_PROBE12_WIDTH {2} \
    CONFIG.C_PROBE13_WIDTH {1} \
    CONFIG.C_PROBE14_WIDTH {1} \
    CONFIG.C_PROBE15_WIDTH {1} \
    CONFIG.C_PROBE16_WIDTH {1} \
    CONFIG.C_PROBE17_WIDTH {1} \
    CONFIG.C_PROBE18_WIDTH {1} \
    CONFIG.C_PROBE19_WIDTH {1} \
    CONFIG.C_PROBE20_WIDTH {2} \
    CONFIG.C_PROBE21_WIDTH {14} \
    CONFIG.C_PROBE22_WIDTH {1} \
    CONFIG.C_PROBE23_WIDTH {1} \
    CONFIG.C_PROBE24_WIDTH {1} \
    CONFIG.C_PROBE25_WIDTH {1} \
    CONFIG.C_PROBE26_WIDTH {1} \
    CONFIG.C_PROBE27_WIDTH {1} \
] [get_ips ila_framebuffer_black]
generate_target all [get_ips ila_framebuffer_black]
export_ip_user_files -of_objects [get_ips ila_framebuffer_black] \
    -no_script -sync -force

set rtl_files [list \
    [file join $repo_dir rtl top framebuffer_black_top.sv] \
    [file join $repo_dir rtl top sprite_bringup_pattern.sv] \
    [file join $repo_dir rtl sprite sprite_engine.sv] \
    [file join $repo_dir rtl sprite sprite_frame_stream.sv] \
    [file join $repo_dir rtl hdmi hdmi_720p.sv] \
    [file join $repo_dir rtl video hdmi_timing_720p.sv] \
    [file join $repo_dir rtl video hdmi_rgb565_source.sv] \
    [file join $repo_dir rtl hdmi hdmi_tmds_encoder.sv] \
    [file join $repo_dir rtl hdmi hdmi_tmds_serializer.sv] \
    [file join $repo_dir rtl memory hdmi_pixel_fifo.sv] \
    [file join $repo_dir rtl video hdmi_vdma_fifo_bridge.sv] \
]
foreach rtl_file $rtl_files {
    if {[llength [get_files -quiet -of_objects \
            [get_filesets sources_1] $rtl_file]] == 0} {
        add_files -fileset sources_1 -norecurse $rtl_file
    }
}
set_property top framebuffer_black_top [get_filesets sources_1]

if {[llength [get_filesets -quiet framebuffer_black_constrs]] == 0} {
    create_fileset -constrset framebuffer_black_constrs
}
set xdc_file [file join $repo_dir constraints framebuffer_black_cf7a100b.xdc]
if {[llength [get_files -quiet -of_objects \
        [get_filesets framebuffer_black_constrs] $xdc_file]] == 0} {
    add_files -fileset framebuffer_black_constrs -norecurse $xdc_file
}

if {[llength [get_runs -quiet framebuffer_black_synth]] == 0} {
    create_run framebuffer_black_synth -flow {Vivado Synthesis 2025} \
        -srcset sources_1 -constrset framebuffer_black_constrs \
        -part xc7a100tfgg484-2
}
if {[llength [get_runs -quiet framebuffer_black_impl]] == 0} {
    create_run framebuffer_black_impl -flow {Vivado Implementation 2025} \
        -parent_run framebuffer_black_synth -part xc7a100tfgg484-2
}

puts "FRAMEBUFFER_BLACK_TARGET_OK"
close_project
