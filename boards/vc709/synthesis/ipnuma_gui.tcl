# PlanAhead Launch Script
set design top
set rtl_top top
set sim_top board
set device xc7vx690t-2-ffg1761
set proj_dir runs 
set impl_const ../constraints/ipnuma.xdc

create_project -name ${design} -force -dir "./${proj_dir}" -part ${device}

# Project Settings

set_property top ${design} [current_fileset]
set_property verilog_define {{USE_VIVADO=1}} [current_fileset]
set_property verilog_define { {USE_DDR3_FIFO=1} {USE_XPHY=1} {USE_PVTMON=1} } [current_fileset]

#add_files -fileset constrs_1 -norecurse ../constraints/xilinx_pcie_7x_ep_x4g2_KC705_REVC.xdc
#set_property used_in_synthesis true [get_files ../constraints/xilinx_pcie_7x_ep_x4g2_KC705_REVC.xdc]
add_files -fileset constrs_1 -norecurse ./${impl_const}
set_property used_in_synthesis true [get_files ./${impl_const}]

add_files -fileset constrs_1 -norecurse ../constraints/v7_xt_xgemac_xphy.xdc
add_files -fileset constrs_1 -norecurse ../constraints/v7_xt_conn_trd.xdc
add_files -fileset constrs_1 -norecurse ../constraints/xilinx_pcie3_7x_ep_x8g3_VC709.xdc


# Project Design Files from IP Catalog (comment out IPs using legacy Coregen cores)
#import_ip -files {../ip_catalog/ten_gig_eth_pcs_pma_ip.xci} -name ten_gig_eth_pcs_pma_ip 
#import_ip -files {../ip_catalog/pcie_7x_0.xci} -name pcie_7x_0
#import_ip -files {../ip_catalog/afifo72_w250_r156.xci} -name afifo72_w250_r156
#import_ip -files {../ip_catalog/afifo72_w156_r250.xci} -name afifo72_w156_r250
import_ip -files {../ip_catalog/pcie3_7x_0.xci} -name pcie3_7x_0

read_ip -files {../ip_catalog/ten_gig_eth_pcs_pma_ip/ten_gig_eth_pcs_pma_ip.xci}
read_ip -files {../ip_catalog/ten_gig_eth_pcs_pma_ip_shared_logic_in_core/ten_gig_eth_pcs_pma_ip_shared_logic_in_core.xci}


# Other Custom logic sources/rtl files
#read_verilog "../rtl/network_path/xgbaser_gt_diff_quad_wrapper.v"
#read_verilog "../rtl/network_path/xgbaser_gt_same_quad_wrapper.v"
#read_verilog "../rtl/network_path/network_path.v"
#read_verilog "../rtl/network_path/ten_gig_eth_pcs_pma_ip_GT_Common_wrapper.v"
#read_verilog "../rtl/top.v"
#read_verilog "../../../cores/xgmiisync/rtl/xgmiisync.v"
#read_verilog "../../../cores/crc32/rtl/CRC32_D64.v"
#read_verilog "../../../cores/crc32/rtl/CRC32_D32.v"
#read_verilog "../rtl/pcie/support/pcie_7x_0_pipe_clock.v"
#read_verilog "../rtl/pcie/support/pcie_7x_0_support.v"
#read_verilog "../rtl/pcie/pcie_app_7x.v"
#read_verilog "../rtl/pcie/PIO.v"
#read_verilog "../rtl/pcie/PIO_EP.v"
#read_verilog "../rtl/pcie/PIO_EP_MEM_ACCESS.v"
#read_verilog "../rtl/pcie/PIO_RX_ENGINE.v"
#read_verilog "../rtl/pcie/PIO_TO_CTRL.v"
#read_verilog "../rtl/pcie/PIO_TX_ENGINE.v"
#read_verilog "../rtl/pcie/PIO_RX_SNOOP.v"
#read_verilog "../rtl/pcie/XGMII_TX_ENGINE.v"
#read_verilog "../rtl/pcie/PIO_TX_SNOOP.v"
#read_verilog "../rtl/pcie/XGMII_RX_ENGINE.v"
#read_verilog "../rtl/pcie/TX_MUX.v"
#read_verilog "../rtl/biosrom.v"
read_verilog "../rtl/network_path/network_path_shared.v"
read_verilog "../rtl/network_path/network_path.v"
read_vhdl "../rtl/clock_control/clock_control.vhd"
read_vhdl "../rtl/clock_control/clock_control_program.vhd"
read_vhdl "../rtl/clock_control/kcpsm6.vhd"
read_verilog "../rtl/top.v"
read_verilog "../rtl/app.v"
read_verilog "../../../cores/xgmiisync/rtl/xgmiisync.v"
read_verilog "../../../cores/crc32/rtl/CRC32_D64.v"

read_verilog "../rtl/pcie/support/pcie3_7x_0_pipe_clock.v"
read_verilog "../rtl/pcie/support/pcie3_7x_0_support.v"
read_verilog "../rtl/pcie/pcie_app_7vx.v"
read_verilog "../rtl/pcie/PIO.v"
read_verilog "../rtl/pcie/PIO_EP.v"
read_verilog "../rtl/pcie/PIO_EP_MEM_ACCESS.v"
read_verilog "../rtl/pcie/PIO_RX_ENGINE.v"
read_verilog "../rtl/pcie/PIO_TO_CTRL.v"
read_verilog "../rtl/pcie/PIO_TX_ENGINE.v"
read_verilog "../rtl/pcie/EP_MEM.v"
read_verilog "../rtl/pcie/PIO_INTR_CTRL.v"
read_verilog "../rtl/biosrom.v"


# NGC files
#read_edif "../ip_cores/dma/netlist/eval/dma_back_end_axi.ngc"

#Setting Rodin Sythesis options
set_property flow {Vivado Synthesis 2014} [get_runs synth_1]
set_property steps.phys_opt_design.is_enabled true [get_runs impl_1]

set_property flow {Vivado Implementation 2014} [get_runs impl_1]

####################
# Set up Simulations
# Get the current working directory
#set CurrWrkDir [pwd]
#
#if [info exists env(MODELSIM)] {
#  puts "MODELSIM env pointing to ini exists..."
#} elseif {[file exists $CurrWrkDir/modelsim.ini] == 1} {
#  set env(MODELSIM) $CurrWrkDir/modelsim.ini
#  puts "Setting \$MODELSIM to modelsim.ini"
#} else {
#  puts "\n\nERROR! modelsim.ini not found!"
#  exit
#}

#set_property target_simulator ModelSim [current_project]
#set_property -name modelsim.vlog_more_options -value +acc -objects [get_filesets sim_1]
#set_property -name modelsim.vsim_more_options -value {+notimingchecks -do "../../../../wave.do; run -all" +TESTNAME=basic_test -GSIM_COLLISION_CHECK=NONE } -objects [get_filesets sim_1]
#set_property compxlib.compiled_library_dir {} [current_project]
#
#set_property include_dirs { ../testbench ../testbench/dsport ../include } [get_filesets sim_1]
#
