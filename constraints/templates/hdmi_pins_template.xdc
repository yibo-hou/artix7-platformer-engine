# Replace all placeholders using the exact Artix-7 board schematic/master XDC.
# The board-level clock below is a 50 MHz input oscillator.

set_property PACKAGE_PIN <SYS_CLK_PIN> [get_ports sys_clk_i]
set_property IOSTANDARD <SYS_CLK_IOSTANDARD> [get_ports sys_clk_i]
create_clock -name sys_clk_i -period 20.000 [get_ports sys_clk_i]

set_property PACKAGE_PIN <HDMI_CLK_P_PIN> [get_ports tmds_clk_p]
set_property PACKAGE_PIN <HDMI_CLK_N_PIN> [get_ports tmds_clk_n]
set_property IOSTANDARD TMDS_33 [get_ports {tmds_clk_p tmds_clk_n}]

set_property PACKAGE_PIN <HDMI_DATA0_P_PIN> [get_ports {tmds_data_p[0]}]
set_property PACKAGE_PIN <HDMI_DATA0_N_PIN> [get_ports {tmds_data_n[0]}]
set_property PACKAGE_PIN <HDMI_DATA1_P_PIN> [get_ports {tmds_data_p[1]}]
set_property PACKAGE_PIN <HDMI_DATA1_N_PIN> [get_ports {tmds_data_n[1]}]
set_property PACKAGE_PIN <HDMI_DATA2_P_PIN> [get_ports {tmds_data_p[2]}]
set_property PACKAGE_PIN <HDMI_DATA2_N_PIN> [get_ports {tmds_data_n[2]}]
set_property IOSTANDARD TMDS_33 \
    [get_ports {tmds_data_p[*] tmds_data_n[*]}]
