# Validate and synthesize the generated CF7A100B MIG out of context.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname [file dirname $script_dir]]
set xpr_file   [file join $repo_dir vivado Super_Mario.xpr]

open_project $xpr_file
set mig [get_ips mig_7series_0]
if {[llength $mig] != 1} {
    error "Expected exactly one mig_7series_0 IP"
}

report_ip_status
synth_ip $mig
puts "MIG_SYNTH_OK"
close_project
