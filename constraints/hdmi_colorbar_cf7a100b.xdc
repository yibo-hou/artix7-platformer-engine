# Standalone HDMI color-bar test constraints for the ALIENTEK DaVinci Pro
# DaVinci Pro CF7A100B (XC7A100T-2FGG484).

# 50 MHz board oscillator. R4 is not a clock-capable input, matching the
# vendor XDC, so the dedicated-clock-route exception is required. The
# Clocking Wizard generated XDC already declares this input as a 20 ns clock.
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS15} [get_ports sys_clk_i]
set_property CLOCK_DEDICATED_ROUTE FALSE \
    [get_nets -of_objects [get_ports sys_clk_i]]

# Active-low board reset.
set_property -dict {PACKAGE_PIN U7 IOSTANDARD LVCMOS15} [get_ports sys_rst_n]

# Four user LEDs.
set_property -dict {PACKAGE_PIN V9 IOSTANDARD LVCMOS15} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN Y8 IOSTANDARD LVCMOS15} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN Y7 IOSTANDARD LVCMOS15} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN W7 IOSTANDARD LVCMOS15} [get_ports {led[3]}]

# HDMI_B output. The N-side package pin is fixed by the differential mate.
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
