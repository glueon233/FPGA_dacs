set_property PACKAGE_PIN J19 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN F13 [get_ports iis_bclk]
set_property PACKAGE_PIN E13 [get_ports iis_lrclk]
set_property IOSTANDARD LVCMOS33 [get_ports iis_lrclk]
set_property IOSTANDARD LVCMOS33 [get_ports iis_bclk]
set_property PACKAGE_PIN D14 [get_ports iis_sdata]
set_property IOSTANDARD LVCMOS33 [get_ports iis_sdata]
set_property PACKAGE_PIN AA1 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]

set_property PACKAGE_PIN A21 [get_ports lout]
set_property IOSTANDARD LVCMOS33 [get_ports lout]
set_property PACKAGE_PIN C20 [get_ports rout]
set_property IOSTANDARD LVCMOS33 [get_ports rout]


set_property DRIVE 16 [get_ports lout]

set_property PACKAGE_PIN M18 [get_ports {leds[1]}]
set_property PACKAGE_PIN N18 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[0]}]

set_property DRIVE 16 [get_ports rout]
set_property PULLTYPE KEEPER [get_ports rout]
set_property PULLTYPE KEEPER [get_ports lout]
