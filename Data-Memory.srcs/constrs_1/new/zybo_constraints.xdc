# Clock
set_property PACKAGE_PIN L16 [get_ports clk_i]
set_property IOSTANDARD LVCMOS33 [get_ports clk_i]
create_clock -period 8.000 -name clk_i [get_ports clk_i]

# Reset
set_property PACKAGE_PIN R18 [get_ports rst_i]
set_property IOSTANDARD LVCMOS33 [get_ports rst_i]

# LED0 on Zybo
set_property PACKAGE_PIN M14 [get_ports led_o]
set_property IOSTANDARD LVCMOS33 [get_ports led_o]