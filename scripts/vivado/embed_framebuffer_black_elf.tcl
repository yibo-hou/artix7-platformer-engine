# Insert the compiled MicroBlaze application into the implemented BRAM image.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname [file dirname $script_dir]]
set output_dir [file join $repo_dir build framebuffer_black]
set run_dir    [file join $repo_dir vivado Super_Mario.runs \
                    framebuffer_black_impl]

set mmi_file [file join $run_dir framebuffer_black_top.mmi]
set elf_file [file join $output_dir super_mario_game.elf]
set hw_bit   [file join $output_dir framebuffer_black_hw.bit]
set out_bit  [file join $output_dir framebuffer_black_top.bit]

foreach required [list $mmi_file $elf_file $hw_bit] {
    if {![file exists $required]} {
        error "Required input does not exist: $required"
    }
}

set command [list updatemem \
    -meminfo $mmi_file \
    -data $elf_file \
    -bit $hw_bit \
    -proc subsystem/framebuffer_black_bd_i/microblaze_0 \
    -out $out_bit \
    -force]

if {[catch {exec {*}$command 2>@1} output]} {
    puts $output
    error "Failed to embed super_mario_game.elf"
}

puts $output
puts "FRAMEBUFFER_BLACK_FINAL_BIT=$out_bit"
