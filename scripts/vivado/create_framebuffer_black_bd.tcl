# Create the MicroBlaze + AXI VDMA MM2S/S2MM subsystem used by the DDR3
# framebuffer and sprite-renderer bring-up. MIG, renderer and HDMI remain in
# the handwritten top level so their clocks and pins are explicit.

set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname [file dirname $script_dir]]
set xpr_file   [file join $repo_dir vivado Super_Mario.xpr]
set bd_name    framebuffer_black_bd

open_project $xpr_file

if {[llength [get_files -quiet */${bd_name}.bd]] != 0} {
    remove_files [get_files */${bd_name}.bd]
}
set old_bd_dir [file join $repo_dir vivado Super_Mario.srcs sources_1 bd $bd_name]
if {[file exists $old_bd_dir]} {
    file delete -force $old_bd_dir
}

create_bd_design $bd_name

set ui_clk [create_bd_port -dir I -type clk -freq_hz 100000000 ui_clk]
set spi_clk [create_bd_port -dir I -type clk -freq_hz 6250000 spi_axi_clk]
set ui_rst [create_bd_port -dir I -type rst ui_clk_sync_rst]
set_property CONFIG.POLARITY ACTIVE_HIGH $ui_rst
set calib [create_bd_port -dir I init_calib_complete]
set s2mm_clk [create_bd_port -dir I -type clk -freq_hz 74250000 \
    s2mm_axis_aclk]

set mb [create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:11.0 microblaze_0]
set_property -dict [list \
    CONFIG.C_AREA_OPTIMIZED {1} \
    CONFIG.C_DEBUG_ENABLED {1} \
    CONFIG.C_D_AXI {1} \
    CONFIG.C_D_LMB {1} \
    CONFIG.C_I_LMB {1} \
    CONFIG.C_USE_BARREL {1} \
    CONFIG.C_USE_HW_MUL {1} \
] $mb

set ilmb [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:lmb_bram_if_cntlr:4.0 ilmb_cntlr]
set dlmb [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:lmb_bram_if_cntlr:4.0 dlmb_cntlr]
set bram [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:blk_mem_gen:8.4 lmb_bram]
set_property -dict [list \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Use_Byte_Write_Enable {true} \
    CONFIG.Byte_Size {8} \
    CONFIG.Enable_B {Use_ENB_Pin} \
    CONFIG.Use_RSTA_Pin {true} \
    CONFIG.Use_RSTB_Pin {true} \
    CONFIG.Write_Width_A {32} \
    CONFIG.Write_Depth_A {32768} \
    CONFIG.Read_Width_A {32} \
    CONFIG.Write_Width_B {32} \
    CONFIG.Read_Width_B {32} \
] $bram

connect_bd_intf_net [get_bd_intf_pins $mb/ILMB] \
    [get_bd_intf_pins $ilmb/SLMB]
connect_bd_intf_net [get_bd_intf_pins $mb/DLMB] \
    [get_bd_intf_pins $dlmb/SLMB]
connect_bd_intf_net [get_bd_intf_pins $ilmb/BRAM_PORT] \
    [get_bd_intf_pins $bram/BRAM_PORTA]
connect_bd_intf_net [get_bd_intf_pins $dlmb/BRAM_PORT] \
    [get_bd_intf_pins $bram/BRAM_PORTB]

set mdm [create_bd_cell -type ip -vlnv xilinx.com:ip:mdm:3.2 mdm_0]
set_property CONFIG.C_USE_UART {0} $mdm
connect_bd_intf_net [get_bd_intf_pins $mb/DEBUG] \
    [get_bd_intf_pins $mdm/MBDEBUG_0]

set rst [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0]
connect_bd_net $ui_clk [get_bd_pins $rst/slowest_sync_clk]
connect_bd_net $ui_rst [get_bd_pins $rst/ext_reset_in]
connect_bd_net $calib [get_bd_pins $rst/dcm_locked]
connect_bd_net [get_bd_pins $mdm/Debug_SYS_Rst] \
    [get_bd_pins $rst/mb_debug_sys_rst]
connect_bd_net [get_bd_pins $rst/mb_reset] [get_bd_pins $mb/Reset]

# proc_sys_reset's auxiliary reset input is active-low by default. It is not
# used in this target, so hold it at the inactive level. Tying it low would
# keep MicroBlaze and every AXI peripheral permanently in reset.
set aux_reset_inactive [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:xlconstant:1.1 const_aux_reset_inactive]
set_property CONFIG.CONST_VAL {1} $aux_reset_inactive
connect_bd_net [get_bd_pins $aux_reset_inactive/dout] \
    [get_bd_pins $rst/aux_reset_in]

set vdma [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:axi_vdma:6.3 axi_vdma_0]
set_property -dict [list \
    CONFIG.c_include_mm2s {1} \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_num_fstores {3} \
    CONFIG.c_m_axi_mm2s_data_width {64} \
    CONFIG.c_m_axis_mm2s_tdata_width {16} \
    CONFIG.c_include_mm2s_dre {1} \
    CONFIG.c_mm2s_linebuffer_depth {4096} \
    CONFIG.c_mm2s_max_burst_length {16} \
    CONFIG.c_use_mm2s_fsync {0} \
    CONFIG.c_mm2s_genlock_mode {3} \
    CONFIG.c_m_axi_s2mm_data_width {64} \
    CONFIG.c_include_s2mm_dre {1} \
    CONFIG.c_s2mm_linebuffer_depth {4096} \
    CONFIG.c_s2mm_max_burst_length {16} \
    CONFIG.c_use_s2mm_fsync {0} \
    CONFIG.c_s2mm_genlock_mode {2} \
    CONFIG.c_include_internal_genlock {1} \
    CONFIG.c_flush_on_fsync {0} \
] $vdma

set uart [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:axi_uartlite:2.0 axi_uartlite_0]
set_property -dict [list \
    CONFIG.C_BAUDRATE {115200} \
    CONFIG.C_DATA_BITS {8} \
    CONFIG.C_USE_PARITY {0} \
] $uart

# Keep the card below the SD specification's 400 kHz initialization limit.
# spi_axi_clk is 6.25 MHz and Standard-mode AXI Quad SPI divides it by 16,
# producing a 390.625 kHz SCK. A clock converter isolates this slow AXI-Lite
# peripheral from the 100 MHz MicroBlaze interconnect.
set spi [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:axi_quad_spi:3.2 axi_quad_spi_0]
set_property -dict [list \
    CONFIG.C_TYPE_OF_AXI4_INTERFACE {0} \
    CONFIG.C_SPI_MODE {0} \
    CONFIG.C_NUM_TRANSFER_BITS {8} \
    CONFIG.C_NUM_SS_BITS {1} \
    CONFIG.C_SCK_RATIO {16} \
    CONFIG.C_FIFO_DEPTH {16} \
    CONFIG.C_USE_STARTUP {0} \
    CONFIG.Master_mode {1} \
] $spi

set spi_clock_converter [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:axi_clock_converter:2.1 spi_axi_clock_converter]

set spi_rst [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:proc_sys_reset:5.0 spi_proc_sys_reset]
connect_bd_net $spi_clk [get_bd_pins $spi_rst/slowest_sync_clk]
connect_bd_net $ui_rst [get_bd_pins $spi_rst/ext_reset_in]
connect_bd_net $calib [get_bd_pins $spi_rst/dcm_locked]
connect_bd_net [get_bd_pins $aux_reset_inactive/dout] \
    [get_bd_pins $spi_rst/aux_reset_in]

# MicroBlaze holds this output low while the S2MM channel is stopped.  Once
# S2MM is completely programmed, software raises it and the sprite stream
# starts from pixel (0, 0), so VDMA can never attach in the middle of a line.
set render_gpio [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:axi_gpio:2.0 render_enable_gpio]
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {32} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_DOUT_DEFAULT {0x00000000} \
] $render_gpio

# Reliable software-to-pixel-domain resource write channel. Channel 1 carries
# a stable 32-bit command; channel 2 returns a one-bit toggle acknowledge.
set asset_gpio [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:axi_gpio:2.0 sprite_asset_gpio]
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {32} \
    CONFIG.C_ALL_OUTPUTS {1} \
    CONFIG.C_DOUT_DEFAULT {0x00000000} \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_GPIO2_WIDTH {1} \
    CONFIG.C_ALL_INPUTS_2 {1} \
] $asset_gpio

set sc [create_bd_cell -type ip \
    -vlnv xilinx.com:ip:smartconnect:1.0 axi_smartconnect_0]
set_property -dict [list CONFIG.NUM_SI {3} CONFIG.NUM_MI {6}] $sc

connect_bd_intf_net [get_bd_intf_pins $mb/M_AXI_DP] \
    [get_bd_intf_pins $sc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins $vdma/M_AXI_MM2S] \
    [get_bd_intf_pins $sc/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins $vdma/M_AXI_S2MM] \
    [get_bd_intf_pins $sc/S02_AXI]
connect_bd_intf_net [get_bd_intf_pins $sc/M01_AXI] \
    [get_bd_intf_pins $vdma/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins $sc/M02_AXI] \
    [get_bd_intf_pins $uart/S_AXI]
connect_bd_intf_net [get_bd_intf_pins $sc/M03_AXI] \
    [get_bd_intf_pins $render_gpio/S_AXI]
connect_bd_intf_net [get_bd_intf_pins $sc/M04_AXI] \
    [get_bd_intf_pins $spi_clock_converter/S_AXI]
connect_bd_intf_net [get_bd_intf_pins $sc/M05_AXI] \
    [get_bd_intf_pins $asset_gpio/S_AXI]
connect_bd_intf_net [get_bd_intf_pins $spi_clock_converter/M_AXI] \
    [get_bd_intf_pins $spi/AXI_LITE]

set ddr_port [create_bd_intf_port -mode Master \
    -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_DDR]
set_property -dict [list \
    CONFIG.PROTOCOL {AXI4} \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.DATA_WIDTH {256} \
    CONFIG.NUM_READ_OUTSTANDING {8} \
    CONFIG.NUM_WRITE_OUTSTANDING {8} \
] $ddr_port
connect_bd_intf_net [get_bd_intf_pins $sc/M00_AXI] $ddr_port

set axis_port [create_bd_intf_port -mode Master \
    -vlnv xilinx.com:interface:axis_rtl:1.0 MM2S_AXIS]
connect_bd_intf_net [get_bd_intf_pins $vdma/M_AXIS_MM2S] $axis_port

set s2mm_axis_port [create_bd_intf_port -mode Slave \
    -vlnv xilinx.com:interface:axis_rtl:1.0 S2MM_AXIS]
set_property -dict [list \
    CONFIG.TDATA_NUM_BYTES {2} \
    CONFIG.HAS_TKEEP {1} \
    CONFIG.HAS_TLAST {1} \
    CONFIG.HAS_TREADY {1} \
    CONFIG.TUSER_WIDTH {1} \
] $s2mm_axis_port
set_property CONFIG.ASSOCIATED_BUSIF {S2MM_AXIS} $s2mm_clk
connect_bd_intf_net $s2mm_axis_port \
    [get_bd_intf_pins $vdma/S_AXIS_S2MM]

set uart_rx [create_bd_port -dir I uart_rxd]
set uart_tx [create_bd_port -dir O uart_txd]
connect_bd_net $uart_rx [get_bd_pins $uart/rx]
connect_bd_net $uart_tx [get_bd_pins $uart/tx]

set sd_miso [create_bd_port -dir I sd_miso]
set sd_mosi [create_bd_port -dir O sd_mosi]
set sd_sck  [create_bd_port -dir O sd_clk]
set sd_ss   [create_bd_port -dir O sd_cs]

# AXI Quad SPI advertises a generic bidirectional QSPI interface. This board
# has a fixed Standard-SPI SD socket, so make the directions explicit. In
# particular, never allow IO1/MISO to become an FPGA output and clamp DAT0 low.
connect_bd_net $sd_miso [get_bd_pins $spi/io1_i]
connect_bd_net $sd_mosi [get_bd_pins $spi/io0_o]
connect_bd_net $sd_sck  [get_bd_pins $spi/sck_o]
connect_bd_net $sd_ss   [get_bd_pins $spi/ss_o]
connect_bd_net [get_bd_pins $spi/io0_o] [get_bd_pins $spi/io0_i]
connect_bd_net [get_bd_pins $spi/sck_o] [get_bd_pins $spi/sck_i]
connect_bd_net [get_bd_pins $spi/ss_o] [get_bd_pins $spi/ss_i]

set render_control [create_bd_port -dir O -from 31 -to 0 render_control]
connect_bd_net $render_control [get_bd_pins $render_gpio/gpio_io_o]

set asset_command [create_bd_port -dir O -from 31 -to 0 asset_command]
set asset_ack [create_bd_port -dir I asset_ack]
connect_bd_net $asset_command [get_bd_pins $asset_gpio/gpio_io_o]
connect_bd_net $asset_ack [get_bd_pins $asset_gpio/gpio2_io_i]

foreach pin [list \
    $mb/Clk \
    $ilmb/LMB_Clk $dlmb/LMB_Clk \
    $vdma/s_axi_lite_aclk $vdma/m_axi_mm2s_aclk \
    $vdma/m_axis_mm2s_aclk \
    $vdma/m_axi_s2mm_aclk \
    $uart/s_axi_aclk $render_gpio/s_axi_aclk $asset_gpio/s_axi_aclk $sc/aclk \
    $spi_clock_converter/s_axi_aclk] {
    connect_bd_net $ui_clk [get_bd_pins $pin]
}
connect_bd_net $s2mm_clk [get_bd_pins $vdma/s_axis_s2mm_aclk]
connect_bd_net $spi_clk \
    [get_bd_pins $spi/s_axi_aclk] \
    [get_bd_pins $spi/ext_spi_clk] \
    [get_bd_pins $spi_clock_converter/m_axi_aclk]

set periph_resetn [get_bd_pins $rst/peripheral_aresetn]
set bus_reset [get_bd_pins $rst/bus_struct_reset]
connect_bd_net $periph_resetn \
    [get_bd_pins $vdma/axi_resetn] \
    [get_bd_pins $uart/s_axi_aresetn] \
    [get_bd_pins $render_gpio/s_axi_aresetn] \
    [get_bd_pins $asset_gpio/s_axi_aresetn] \
    [get_bd_pins $spi_clock_converter/s_axi_aresetn] \
    [get_bd_pins $sc/aresetn]
set spi_resetn [get_bd_pins $spi_rst/peripheral_aresetn]
connect_bd_net $spi_resetn \
    [get_bd_pins $spi/s_axi_aresetn] \
    [get_bd_pins $spi_clock_converter/m_axi_aresetn]
connect_bd_net $bus_reset \
    [get_bd_pins $ilmb/LMB_Rst] \
    [get_bd_pins $dlmb/LMB_Rst]

# Explicit assignments avoid Vivado placing the external DDR window on top of
# an AXI-Lite peripheral. The VDMA sees only DDR in its read address space.
assign_bd_address -offset 0x00000000 -range 128K \
    -target_address_space [get_bd_addr_spaces $mb/Data] \
    [get_bd_addr_segs $dlmb/SLMB/Mem]
assign_bd_address -offset 0x00000000 -range 128K \
    -target_address_space [get_bd_addr_spaces $mb/Instruction] \
    [get_bd_addr_segs $ilmb/SLMB/Mem]
assign_bd_address -offset 0x44A00000 -range 64K \
    -target_address_space [get_bd_addr_spaces $mb/Data] \
    [get_bd_addr_segs $vdma/S_AXI_LITE/Reg]
assign_bd_address -offset 0x40600000 -range 64K \
    -target_address_space [get_bd_addr_spaces $mb/Data] \
    [get_bd_addr_segs $uart/S_AXI/Reg]
assign_bd_address -offset 0x41200000 -range 64K \
    -target_address_space [get_bd_addr_spaces $mb/Data] \
    [get_bd_addr_segs $render_gpio/S_AXI/Reg]
assign_bd_address -offset 0x41210000 -range 64K \
    -target_address_space [get_bd_addr_spaces $mb/Data] \
    [get_bd_addr_segs $asset_gpio/S_AXI/Reg]
assign_bd_address -offset 0x44A10000 -range 64K \
    -target_address_space [get_bd_addr_spaces $mb/Data] \
    [get_bd_addr_segs $spi/AXI_LITE/Reg]
assign_bd_address -offset 0x80000000 -range 512M \
    -target_address_space [get_bd_addr_spaces $mb/Data] \
    [get_bd_addr_segs $ddr_port/Reg]
assign_bd_address -offset 0x80000000 -range 512M \
    -target_address_space [get_bd_addr_spaces $vdma/Data_MM2S] \
    [get_bd_addr_segs $ddr_port/Reg]
assign_bd_address -offset 0x80000000 -range 512M \
    -target_address_space [get_bd_addr_spaces $vdma/Data_S2MM] \
    [get_bd_addr_segs $ddr_port/Reg]
exclude_bd_addr_seg -target_address_space \
    [get_bd_addr_spaces $vdma/Data_MM2S] \
    [get_bd_addr_segs $vdma/S_AXI_LITE/Reg]
exclude_bd_addr_seg -target_address_space \
    [get_bd_addr_spaces $vdma/Data_MM2S] \
    [get_bd_addr_segs $uart/S_AXI/Reg]
exclude_bd_addr_seg -target_address_space \
    [get_bd_addr_spaces $vdma/Data_MM2S] \
    [get_bd_addr_segs $render_gpio/S_AXI/Reg]
exclude_bd_addr_seg -target_address_space \
    [get_bd_addr_spaces $vdma/Data_MM2S] \
    [get_bd_addr_segs $asset_gpio/S_AXI/Reg]
exclude_bd_addr_seg -target_address_space \
    [get_bd_addr_spaces $vdma/Data_MM2S] \
    [get_bd_addr_segs $spi/AXI_LITE/Reg]
exclude_bd_addr_seg -target_address_space \
    [get_bd_addr_spaces $vdma/Data_S2MM] \
    [get_bd_addr_segs $vdma/S_AXI_LITE/Reg]
exclude_bd_addr_seg -target_address_space \
    [get_bd_addr_spaces $vdma/Data_S2MM] \
    [get_bd_addr_segs $uart/S_AXI/Reg]
exclude_bd_addr_seg -target_address_space \
    [get_bd_addr_spaces $vdma/Data_S2MM] \
    [get_bd_addr_segs $render_gpio/S_AXI/Reg]
exclude_bd_addr_seg -target_address_space \
    [get_bd_addr_spaces $vdma/Data_S2MM] \
    [get_bd_addr_segs $asset_gpio/S_AXI/Reg]
exclude_bd_addr_seg -target_address_space \
    [get_bd_addr_spaces $vdma/Data_S2MM] \
    [get_bd_addr_segs $spi/AXI_LITE/Reg]

validate_bd_design
save_bd_design

set bd_file [get_files */${bd_name}.bd]
generate_target all $bd_file
make_wrapper -files $bd_file -top
set wrapper [file join [file dirname $bd_file] hdl ${bd_name}_wrapper.v]
add_files -norecurse $wrapper

puts "FRAMEBUFFER_BLACK_BD_OK"
puts "BD_FILE=$bd_file"
puts "WRAPPER=$wrapper"
close_project
