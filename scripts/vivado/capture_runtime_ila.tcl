# Capture the currently running framebuffer design without reprogramming it.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname [file dirname $script_dir]]
set csv_file   [file join $repo_dir build framebuffer_black runtime_ila.csv]
set probes_file [file join $repo_dir build framebuffer_black \
    framebuffer_black_top.ltx]

open_hw_manager
connect_hw_server
open_hw_target

set device [lindex [get_hw_devices xc7a100t_0] 0]
if {$device eq ""} {
    error "xc7a100t_0 not found on JTAG"
}
current_hw_device $device
set_property PROBES.FILE $probes_file $device
refresh_hw_device -update_hw_probes true $device

set ila [lindex [get_hw_ilas -of_objects $device \
    -filter {CELL_NAME =~ "*framebuffer_debug*"}] 0]
if {$ila eq ""} {
    error "framebuffer_debug ILA not found"
}

set calib_probe [lindex [get_hw_probes -of_objects $ila \
    -filter {NAME == "init_calib_complete"}] 0]
if {$calib_probe eq ""} {
    error "MIG calibration probe not found"
}

set_property CONTROL.TRIGGER_POSITION 2048 $ila
set_property TRIGGER_COMPARE_VALUE {eq1'b1} $calib_probe
run_hw_ila $ila
wait_on_hw_ila $ila
upload_hw_ila_data $ila
write_hw_ila_data -force -csv_file $csv_file \
    [get_hw_ila_data -of_objects $ila]

puts "RUNTIME_ILA_CAPTURED=$csv_file"
close_hw_manager
