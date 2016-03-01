###############################################################################
# This XDC is intended for use with the Xilinx KC705 Development Board with a 
# xc7k325t-ffg900-2 part
###############################################################################

##-------------------------------------
## LED Status Pinout   (bottom to top)
##-------------------------------------

set_property PACKAGE_PIN AU39 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[7]}]
set_property PACKAGE_PIN AP42 [get_ports {led[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[6]}]
set_property PACKAGE_PIN AP41 [get_ports {led[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[5]}]
set_property PACKAGE_PIN AR35 [get_ports {led[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[4]}]
set_property PACKAGE_PIN AT37 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[3]}]
set_property PACKAGE_PIN AR37 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[2]}]
set_property PACKAGE_PIN AN39 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[1]}]
set_property PACKAGE_PIN AM39 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[0]}]

set_property SLEW SLOW [get_ports {led[7]}]
set_property SLEW SLOW [get_ports {led[6]}]
set_property SLEW SLOW [get_ports {led[5]}]
set_property SLEW SLOW [get_ports {led[4]}]
set_property SLEW SLOW [get_ports {led[3]}]
set_property SLEW SLOW [get_ports {led[2]}]
set_property SLEW SLOW [get_ports {led[1]}]
set_property SLEW SLOW [get_ports {led[0]}]

set_property DRIVE 4 [get_ports {led[7]}]
set_property DRIVE 4 [get_ports {led[6]}]
set_property DRIVE 4 [get_ports {led[5]}]
set_property DRIVE 4 [get_ports {led[4]}]
set_property DRIVE 4 [get_ports {led[3]}]
set_property DRIVE 4 [get_ports {led[2]}]
set_property DRIVE 4 [get_ports {led[1]}]
set_property DRIVE 4 [get_ports {led[0]}]

# BUTTON
set_property PACKAGE_PIN AP40 [get_ports button_s]
set_property IOSTANDARD LVCMOS18 [get_ports button_s]
set_property PACKAGE_PIN AR40 [get_ports button_n]
set_property IOSTANDARD LVCMOS18 [get_ports button_n]
set_property PACKAGE_PIN AV39 [get_ports button_c]
set_property IOSTANDARD LVCMOS18 [get_ports button_c]
set_property PACKAGE_PIN AU38 [get_ports button_e]
set_property IOSTANDARD LVCMOS18 [get_ports button_e]
set_property PACKAGE_PIN AW40 [get_ports button_w]
set_property IOSTANDARD LVCMOS18 [get_ports button_w]

# DIP SW
set_property PACKAGE_PIN AV30 [get_ports {dipsw[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {dipsw[0]}]
set_property PACKAGE_PIN AY33 [get_ports {dipsw[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {dipsw[1]}]
set_property PACKAGE_PIN BA31 [get_ports {dipsw[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {dipsw[2]}]
set_property PACKAGE_PIN BA32 [get_ports {dipsw[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {dipsw[3]}]
set_property PACKAGE_PIN AW30 [get_ports {dipsw[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {dipsw[4]}]
set_property PACKAGE_PIN AY30 [get_ports {dipsw[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {dipsw[5]}]
set_property PACKAGE_PIN BA30 [get_ports {dipsw[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {dipsw[6]}]
set_property PACKAGE_PIN BB31 [get_ports {dipsw[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {dipsw[7]}]



create_clock -period 5.000 -name sysclk_p [get_ports clk200_p]
set_property PACKAGE_PIN H19 [get_ports clk200_p]
set_property IOSTANDARD DIFF_SSTL15 [get_ports clk200_p]
set_property PACKAGE_PIN G18 [get_ports clk200_n]
set_property IOSTANDARD DIFF_SSTL15 [get_ports clk200_n]

