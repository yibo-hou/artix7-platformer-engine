# Generate the ALIENTEK CF7A100B DDR3 MIG IP in the existing Vivado project.
# Run from the repository root:
#   vivado -mode batch -source scripts/vivado/create_cf7a100b_mig.tcl

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname [file dirname $script_dir]]
set xpr_file   [file join $repo_dir vivado Super_Mario.xpr]
set mig_prj    [file join $repo_dir vivado ip mig cf7a100b_mig.prj]

if {![file exists $xpr_file]} {
    error "Vivado project not found: $xpr_file"
}
if {![file exists $mig_prj]} {
    error "MIG project file not found: $mig_prj"
}

open_project $xpr_file

if {[llength [get_ips -quiet mig_7series_0]] == 0} {
    create_ip -name mig_7series -vendor xilinx.com -library ip \
        -module_name mig_7series_0
}

set_property CONFIG.XML_INPUT_FILE $mig_prj [get_ips mig_7series_0]
generate_target all [get_ips mig_7series_0]
export_ip_user_files -of_objects [get_ips mig_7series_0] -no_script -sync -force

puts "MIG_OK: [get_property IP_FILE [get_ips mig_7series_0]]"
close_project
