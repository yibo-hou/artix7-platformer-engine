# Complete DDR3 -> VDMA MM2S -> asynchronous FIFO -> HDMI_B test.
# DDR3 pins and memory timing come from the MIG generated XDC.

set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS15} [get_ports sys_clk_i]
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS15} [get_ports sys_rst_n]
create_clock -name sys_clk_50 -period 20.000 [get_ports sys_clk_i]
set_property CLOCK_DEDICATED_ROUTE FALSE \
    [get_nets -of_objects [get_ports sys_clk_i]]

set_property -dict {PACKAGE_PIN V9 IOSTANDARD LVCMOS15} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN Y8 IOSTANDARD LVCMOS15} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN Y7 IOSTANDARD LVCMOS15} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS15} [get_ports {led[3]}]

# USB-UART bridge.
set_property -dict {PACKAGE_PIN E14 IOSTANDARD LVCMOS33} [get_ports uart_rxd]
set_property -dict {PACKAGE_PIN D17 IOSTANDARD LVCMOS33} [get_ports uart_txd]

# On-board microSD socket, SPI mode.
set_property -dict {PACKAGE_PIN B17 IOSTANDARD LVCMOS33 PULLUP TRUE} [get_ports sd_miso]
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33} [get_ports sd_mosi]
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33} [get_ports sd_clk]
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33 PULLUP TRUE} [get_ports sd_cs]

# HDMI_B output. Differential N pins are selected by their P-pin mates.
set_property -dict {PACKAGE_PIN J20 IOSTANDARD TMDS_33} [get_ports tmds_clk_p]
set_property IOSTANDARD TMDS_33 [get_ports tmds_clk_n]
set_property -dict {PACKAGE_PIN J22 IOSTANDARD TMDS_33} [get_ports {tmds_data_p[0]}]
set_property -dict {PACKAGE_PIN K21 IOSTANDARD TMDS_33} [get_ports {tmds_data_p[1]}]
set_property -dict {PACKAGE_PIN H20 IOSTANDARD TMDS_33} [get_ports {tmds_data_p[2]}]
set_property IOSTANDARD TMDS_33 [get_ports {tmds_data_n[0]}]
set_property IOSTANDARD TMDS_33 [get_ports {tmds_data_n[1]}]
set_property IOSTANDARD TMDS_33 [get_ports {tmds_data_n[2]}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
