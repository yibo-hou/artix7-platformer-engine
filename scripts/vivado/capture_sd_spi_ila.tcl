# Program the framebuffer target and capture one SD SPI transaction.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname [file dirname $script_dir]]
set output_dir [file join $repo_dir build framebuffer_black]
set bit_file   [file join $output_dir framebuffer_black_top.bit]
set ltx_file   [file join $output_dir framebuffer_black_top.ltx]
set csv_file   [file join $output_dir sd_spi_ila.csv]

open_hw_manager
connect_hw_server
open_hw_target

set device [lindex [get_hw_devices xc7a100t_0] 0]
if {$device eq ""} {
    error "xc7a100t_0 not found on JTAG"
}

current_hw_device $device
set_property PROGRAM.FILE $bit_file $device
set_property PROBES.FILE $ltx_file $device
program_hw_devices $device
refresh_hw_device -update_hw_probes true $device

set ila [lindex [get_hw_ilas -of_objects $device \
    -filter {CELL_NAME =~ "*framebuffer_debug*"}] 0]
if {$ila eq ""} {
    error "framebuffer_debug ILA not found"
}

set cs_probe [lindex [get_hw_probes -of_objects $ila \
    -filter {NAME == "sd_cs_OBUF"}] 0]
if {$cs_probe eq ""} {
    error "SD CS probe not found; probes are: [get_hw_probes -of_objects $ila]"
}

set_property CONTROL.TRIGGER_POSITION 512 $ila
set_property TRIGGER_COMPARE_VALUE {eq1'b0} $cs_probe
run_hw_ila $ila
wait_on_hw_ila $ila
upload_hw_ila_data $ila
write_hw_ila_data -force -csv_file $csv_file [get_hw_ila_data -of_objects $ila]

puts "SD_SPI_ILA_CAPTURED=$csv_file"
close_hw_manager
