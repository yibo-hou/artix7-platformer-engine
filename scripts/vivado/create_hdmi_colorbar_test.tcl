# Add a standalone HDMI color-bar target to the existing Super_Mario project.
#
# This selects the color-bar top in the shared source catalog and creates an
# independent constraint set and runs:
#   sources_1 (temporarily selects hdmi_colorbar_top)
#   colorbar_constrs
#   colorbar_synth
#   colorbar_impl

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname [file dirname $script_dir]]
set xpr_file   [file join $repo_dir vivado Super_Mario.xpr]

open_project $xpr_file

if {[llength [get_ips -quiet clk_wiz_hdmi_720p]] == 0} {
    create_ip -name clk_wiz -vendor xilinx.com -library ip \
        -module_name clk_wiz_hdmi_720p
}

set_property -dict [list \
    CONFIG.PRIMITIVE {MMCM} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.PRIM_IN_FREQ {50.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {74.250} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {371.250} \
    CONFIG.USE_LOCKED {true} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
] [get_ips clk_wiz_hdmi_720p]

generate_target all [get_ips clk_wiz_hdmi_720p]
export_ip_user_files -of_objects [get_ips clk_wiz_hdmi_720p] \
    -no_script -sync -force

set colorbar_rtl [list \
    [file join $repo_dir rtl top hdmi_colorbar_top.sv] \
    [file join $repo_dir rtl hdmi hdmi_720p.sv] \
    [file join $repo_dir rtl video hdmi_timing_720p.sv] \
    [file join $repo_dir rtl video hdmi_rgb565_source.sv] \
    [file join $repo_dir rtl hdmi hdmi_tmds_encoder.sv] \
    [file join $repo_dir rtl hdmi hdmi_tmds_serializer.sv] \
]

foreach rtl_file $colorbar_rtl {
    if {[llength [get_files -quiet -of_objects \
            [get_filesets sources_1] $rtl_file]] == 0} {
        add_files -fileset sources_1 -norecurse $rtl_file
    }
}
set_property top hdmi_colorbar_top [get_filesets sources_1]

# Remove the obsolete script-owned source set created by an earlier revision.
# The external RTL files remain in the repository and are already in sources_1.
if {[llength [get_filesets -quiet colorbar_sources]] != 0} {
    delete_fileset [get_filesets colorbar_sources]
}

if {[llength [get_filesets -quiet colorbar_constrs]] == 0} {
    create_fileset -constrset colorbar_constrs
}

set colorbar_xdc [file join $repo_dir constraints hdmi_colorbar_cf7a100b.xdc]
if {[llength [get_files -quiet -of_objects \
        [get_filesets colorbar_constrs] $colorbar_xdc]] == 0} {
    add_files -fileset colorbar_constrs -norecurse $colorbar_xdc
}

# An earlier revision of this script used a separate source set. Recreate only
# these script-owned runs if that older form is present.
if {[llength [get_runs -quiet colorbar_synth]] != 0 &&
        [get_property SRCSET [get_runs colorbar_synth]] ne "sources_1"} {
    if {[llength [get_runs -quiet colorbar_impl]] != 0} {
        delete_runs [get_runs colorbar_impl]
    }
    delete_runs [get_runs colorbar_synth]
}

if {[llength [get_runs -quiet colorbar_synth]] == 0} {
    create_run colorbar_synth -flow {Vivado Synthesis 2025} \
        -srcset sources_1 -constrset colorbar_constrs \
        -part xc7a100tfgg484-2
}
if {[llength [get_runs -quiet colorbar_impl]] == 0} {
    create_run colorbar_impl -flow {Vivado Implementation 2025} \
        -parent_run colorbar_synth -part xc7a100tfgg484-2
}

set actual_1 [get_property CONFIG.C_CLKOUT0_ACTUAL_FREQ \
    [get_ips clk_wiz_hdmi_720p]]
set actual_2 [get_property CONFIG.C_CLKOUT1_ACTUAL_FREQ \
    [get_ips clk_wiz_hdmi_720p]]

puts "COLORBAR_TARGET_OK"
puts "PIXEL_CLOCK_ACTUAL_MHZ=$actual_1"
puts "SERIAL_CLOCK_ACTUAL_MHZ=$actual_2"

close_project
