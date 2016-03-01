`timescale 1ps / 1ps
//`default_nettype none
`include "../rtl/setup.v"
(* DowngradeIPIdentifiedWarnings = "yes" *)
module top # (
	parameter          PL_SIM_FAST_LINK_TRAINING           = "FALSE",      // Simulation Speedup
	parameter          PCIE_EXT_CLK                        = "TRUE", // Use External Clocking Module
	parameter          PCIE_EXT_GT_COMMON                  = "FALSE", // Use External GT COMMON Module
	parameter          C_DATA_WIDTH                        = 256,         // RX/TX interface data width
	parameter          KEEP_WIDTH                          = C_DATA_WIDTH / 32,
 // parameter          EXT_PIPE_SIM                        = "FALSE",  // This Parameter has effect on selecting Enable External PIPE Interface in GUI.
	parameter          PL_LINK_CAP_MAX_LINK_SPEED          = 4,  // 1- GEN1, 2 - GEN2, 4 - GEN3
	parameter          PL_LINK_CAP_MAX_LINK_WIDTH          = 8,  // 1- X1, 2 - X2, 4 - X4, 8 - X8
  // USER_CLK2_FREQ = AXI Interface Frequency
  //   0: Disable User Clock
  //   1: 31.25 MHz
  //   2: 62.50 MHz  (default)
  //   3: 125.00 MHz
  //   4: 250.00 MHz
  //   5: 500.00 MHz
	parameter  integer USER_CLK2_FREQ                 = 4,
	parameter          REF_CLK_FREQ                   = 0,           // 0 - 100 MHz, 1 - 125 MHz,  2 - 250 MHz
	parameter          AXISTEN_IF_RQ_ALIGNMENT_MODE   = "FALSE",
	parameter          AXISTEN_IF_CC_ALIGNMENT_MODE   = "FALSE",
	parameter          AXISTEN_IF_CQ_ALIGNMENT_MODE   = "FALSE",
	parameter          AXISTEN_IF_RC_ALIGNMENT_MODE   = "FALSE",
	parameter          AXISTEN_IF_ENABLE_CLIENT_TAG   = 0,
	parameter          AXISTEN_IF_RQ_PARITY_CHECK     = 0,
	parameter          AXISTEN_IF_CC_PARITY_CHECK     = 0,
	parameter          AXISTEN_IF_MC_RX_STRADDLE      = 0,
	parameter          AXISTEN_IF_ENABLE_RX_MSG_INTFC = 0,
	parameter   [17:0] AXISTEN_IF_ENABLE_MSG_ROUTE    = 18'h2FFFF
) (
	output  [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_txp,
	output  [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_txn,
	input   [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxp,
	input   [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxn,

	input                                           sys_clk_p,
	input                                           sys_clk_n,
	input                                           sys_rst_n,



	// 200MHz reference clock input
	input wire clk200_p,
	input wire clk200_n,
	//-SI5324 I2C programming interface
	inout wire i2c_clk,
	inout wire i2c_data,
	output wire i2c_mux_rst_n,
	output wire si5324_rst_n,
	// 156.25 MHz clock in
	input wire xphy_refclk_clk_p,
	input wire xphy_refclk_clk_n,
	// 10G PHY ports
	output wire xphy0_txp,
	output wire xphy0_txn,
	input wire xphy0_rxp,
	input wire xphy0_rxn,
	output wire xphy1_txp,
	output wire xphy1_txn,
	input wire xphy1_rxp,
	input wire xphy1_rxn,
	output wire xphy2_txp,
	output wire xphy2_txn,
	input wire xphy2_rxp,
	input wire xphy2_rxn,
	output wire xphy3_txp,
	output wire xphy3_txn,
	input wire xphy3_rxp,
	input wire xphy3_rxn,
	output wire [3:0] sfp_tx_disable,   
	// SI570 user clock (input 156.25MHz)
	input wire si570_refclk_p,
	input wire si570_refclk_n,
	// USER SMA GPIO clock (output to USER SMA clock)
	output wire user_sma_clock_p,
	output wire user_sma_clock_n,
	// SMA MGT reference clock (input from USER SMA GPIO for SFP+ module)
	input wire sma_mgt_refclk_p,
	input wire sma_mgt_refclk_n,

	// BUTTON
	input wire button_n,
	input wire button_s,
	input wire button_w,
	input wire button_e,
	input wire button_c,
	// DIP SW
	input wire [7:0] dipsw,
	// Diagnostic LEDs
	output wire [7:0] led
);

  // Local Parameters derived from user selection
  localparam integer USER_CLK_FREQ         = ((PL_LINK_CAP_MAX_LINK_SPEED == 3'h4) ? 5 : 4);
  localparam        TCQ = 1;
  localparam EXT_PIPE_SIM = "FALSE";

  // Wire Declarations

  wire                                       user_lnk_up;
  wire                                       user_clk;
  wire                                       user_reset;

  //----------------------------------------------------------------------------------------------------------------//
  //  AXI Interface                                                                                                 //
  //----------------------------------------------------------------------------------------------------------------//

  wire                                       s_axis_rq_tlast;
  wire                 [C_DATA_WIDTH-1:0]    s_axis_rq_tdata;
  wire                             [59:0]    s_axis_rq_tuser;
  wire                   [KEEP_WIDTH-1:0]    s_axis_rq_tkeep;
  wire                              [3:0]    s_axis_rq_tready;
  wire                                       s_axis_rq_tvalid;

  wire                 [C_DATA_WIDTH-1:0]    m_axis_rc_tdata;
  wire                             [74:0]    m_axis_rc_tuser;
  wire                                       m_axis_rc_tlast;
  wire                   [KEEP_WIDTH-1:0]    m_axis_rc_tkeep;
  wire                                       m_axis_rc_tvalid;
  wire                             [21:0]    m_axis_rc_tready;

  wire                 [C_DATA_WIDTH-1:0]    m_axis_cq_tdata;
  wire                             [84:0]    m_axis_cq_tuser;
  wire                                       m_axis_cq_tlast;
  wire                   [KEEP_WIDTH-1:0]    m_axis_cq_tkeep;
  wire                                       m_axis_cq_tvalid;
  wire                             [21:0]    m_axis_cq_tready;

  wire                 [C_DATA_WIDTH-1:0]    s_axis_cc_tdata;
  wire                             [32:0]    s_axis_cc_tuser;
  wire                                       s_axis_cc_tlast;
  wire                   [KEEP_WIDTH-1:0]    s_axis_cc_tkeep;
  wire                                       s_axis_cc_tvalid;
  wire                              [3:0]    s_axis_cc_tready;


  //----------------------------------------------------------------------------------------------------------------//
  //  Configuration (CFG) Interface                                                                                 //
  //----------------------------------------------------------------------------------------------------------------//


  wire                              [1:0]    pcie_tfc_nph_av;
  wire                              [1:0]    pcie_tfc_npd_av;

  wire                              [3:0]    pcie_rq_seq_num;
  wire                                       pcie_rq_seq_num_vld;
  wire                              [5:0]    pcie_rq_tag;
  wire                                       pcie_rq_tag_vld;
  wire                                       pcie_cq_np_req;
  wire                              [5:0]    pcie_cq_np_req_count;

  wire                                       cfg_phy_link_down;
  wire                              [3:0]    cfg_negotiated_width;
  wire                              [2:0]    cfg_current_speed;
  wire                              [2:0]    cfg_max_payload;
  wire                              [2:0]    cfg_max_read_req;
  wire                              [7:0]    cfg_function_status;
  wire                              [5:0]    cfg_function_power_state;
  wire                             [11:0]    cfg_vf_status;
  wire                             [17:0]    cfg_vf_power_state;
  wire                              [1:0]    cfg_link_power_state;

  // Error Reporting Interface
  wire                                       cfg_err_cor_out;
  wire                                       cfg_err_nonfatal_out;
  wire                                       cfg_err_fatal_out;

  wire                                       cfg_ltr_enable;
  wire                              [5:0]    cfg_ltssm_state;
  wire                              [1:0]    cfg_rcb_status;
  wire                              [1:0]    cfg_dpa_substate_change;
  wire                              [1:0]    cfg_obff_enable;
  wire                                       cfg_pl_status_change;

  wire                              [1:0]    cfg_tph_requester_enable;
  wire                              [5:0]    cfg_tph_st_mode;
  wire                              [5:0]    cfg_vf_tph_requester_enable;
  wire                             [17:0]    cfg_vf_tph_st_mode;
  // Management Interface
  wire                             [18:0]    cfg_mgmt_addr;
  wire                                       cfg_mgmt_write;
  wire                             [31:0]    cfg_mgmt_write_data;
  wire                              [3:0]    cfg_mgmt_byte_enable;
  wire                                       cfg_mgmt_read;
  wire                             [31:0]    cfg_mgmt_read_data;
  wire                                       cfg_mgmt_read_write_done;
  wire                                       cfg_mgmt_type1_cfg_reg_access;
  wire                                       cfg_msg_received;
  wire                              [7:0]    cfg_msg_received_data;
  wire                              [4:0]    cfg_msg_received_type;
  wire                                       cfg_msg_transmit;
  wire                              [2:0]    cfg_msg_transmit_type;
  wire                             [31:0]    cfg_msg_transmit_data;
  wire                                       cfg_msg_transmit_done;
  wire                              [7:0]    cfg_fc_ph;
  wire                             [11:0]    cfg_fc_pd;
  wire                              [7:0]    cfg_fc_nph;
  wire                             [11:0]    cfg_fc_npd;
  wire                              [7:0]    cfg_fc_cplh;
  wire                             [11:0]    cfg_fc_cpld;
  wire                              [2:0]    cfg_fc_sel;
  wire                              [2:0]    cfg_per_func_status_control;
  wire                             [15:0]    cfg_per_func_status_data;
  wire                              [15:0]   cfg_subsys_vend_id = 16'h3776;      
  wire                                       cfg_config_space_enable;
  wire                             [63:0]    cfg_dsn;
  wire                              [7:0]    cfg_ds_port_number;
  wire                              [7:0]    cfg_ds_bus_number;
  wire                              [4:0]    cfg_ds_device_number;
  wire                              [2:0]    cfg_ds_function_number;
  wire                                       cfg_err_cor_in;
  wire                                       cfg_err_uncor_in;
  wire                              [1:0]    cfg_flr_in_process;
  wire                              [1:0]    cfg_flr_done;
  wire                                       cfg_hot_reset_out;
  wire                                       cfg_hot_reset_in;
  wire                                       cfg_link_training_enable;
  wire                              [2:0]    cfg_per_function_number;
  wire                                       cfg_per_function_output_request;
  wire                                       cfg_per_function_update_done;
  wire                                       cfg_power_state_change_interrupt;
  wire                                       cfg_req_pm_transition_l23_ready;
  wire                              [5:0]    cfg_vf_flr_in_process;
  wire                              [5:0]    cfg_vf_flr_done;
  wire                                       cfg_power_state_change_ack;

  wire                                       cfg_ext_read_received;
  wire                                       cfg_ext_write_received;
  wire                              [9:0]    cfg_ext_register_number;
  wire                              [7:0]    cfg_ext_function_number;
  wire                             [31:0]    cfg_ext_write_data;
  wire                              [3:0]    cfg_ext_write_byte_enable;
  wire                             [31:0]    cfg_ext_read_data;
  wire                                       cfg_ext_read_data_valid;
  //----------------------------------------------------------------------------------------------------------------//
  // EP Only                                                                                                        //
  //----------------------------------------------------------------------------------------------------------------//

  // Interrupt Interface Signals
  wire                              [3:0]    cfg_interrupt_int;
  wire                              [1:0]    cfg_interrupt_pending;
  wire                                       cfg_interrupt_sent;
  wire                              [1:0]    cfg_interrupt_msi_enable;
  wire                              [5:0]    cfg_interrupt_msi_vf_enable;
  wire                              [5:0]    cfg_interrupt_msi_mmenable;
  wire                                       cfg_interrupt_msi_mask_update;
  wire                             [31:0]    cfg_interrupt_msi_data;
  wire                              [3:0]    cfg_interrupt_msi_select;
  wire                             [31:0]    cfg_interrupt_msi_int;
  wire                             [63:0]    cfg_interrupt_msi_pending_status;
  wire                                       cfg_interrupt_msi_sent;
  wire                                       cfg_interrupt_msi_fail;
  wire                              [2:0]    cfg_interrupt_msi_attr;
  wire                                       cfg_interrupt_msi_tph_present;
  wire                              [1:0]    cfg_interrupt_msi_tph_type;
  wire                              [8:0]    cfg_interrupt_msi_tph_st_tag;
  wire                              [2:0]    cfg_interrupt_msi_function_number;


// Clock and Reset
wire clk200;
IBUFGDS # (
	.DIFF_TERM    ("TRUE"),
	.IBUF_LOW_PWR ("FALSE")
) diff_clk_200 (
        .I(clk200_p),
        .IB(clk200_n),
        .O(clk200)
);

reg [7:0] cold_counter = 8'h0;
reg cold_reset = 1'b0;

always @(posedge clk200) begin
        if (cold_counter != 8'hff) begin
                cold_reset <= 1'b1;
                cold_counter <= cold_counter + 8'd1;
        end else
                cold_reset <= 1'b0;
end

wire sys_rst;

assign sys_rst = (button_c | cold_reset | ~user_lnk_up | user_reset);


  //----------------------------------------------------------------------------------------------------------------//
  //    System(SYS) Interface                                                                                       //
  //----------------------------------------------------------------------------------------------------------------//
  wire					             pipe_mmcm_rst_n;
  wire                                               sys_clk;
  wire                                               sys_rst_n_c;


  // User Clock LED Heartbeat
  reg    [25:0]                              user_clk_heartbeat;
  //-----------------------------------------------------------------------------------------------------------------------

  IBUF   sys_reset_n_ibuf (.O(sys_rst_n_c), .I(sys_rst_n));
  
  // ref_clk IBUFDS from the edge connector
  IBUFDS_GTE2 refclk_ibuf (.O(sys_clk), .ODIV2(), .I(sys_clk_p), .CEB(1'b0), .IB(sys_clk_n));


    // LED's enabled for Reference Board design
`ifdef macchan
    OBUF   led_0_obuf (.O(led[0]), .I(sys_rst_n_c));
    OBUF   led_1_obuf (.O(led[1]), .I(!user_reset));
    OBUF   led_2_obuf (.O(led[2]), .I(user_lnk_up));
    OBUF   led_3_obuf (.O(led[3]), .I(user_clk_heartbeat[25]));
`endif

  // Create a Clock Heartbeat
  always @(posedge user_clk) begin
    if(!sys_rst_n_c) begin
     user_clk_heartbeat <= #TCQ 26'd0;
    end else begin
      user_clk_heartbeat <= #TCQ user_clk_heartbeat + 1'b1;
    end
  end

      // Tie off for pipe_mmcm_rst_n   
      assign  	pipe_mmcm_rst_n                    =1'b1;




// Support Level Wrapper
pcie3_7x_0_support #
   (	 
    .PL_LINK_CAP_MAX_LINK_WIDTH     ( PL_LINK_CAP_MAX_LINK_WIDTH ), // PCIe Lane Width
    .C_DATA_WIDTH                   ( C_DATA_WIDTH ),               //  AXI interface data width
    .KEEP_WIDTH                     ( KEEP_WIDTH ),                 // TSTRB width
    .PCIE_REFCLK_FREQ               ( REF_CLK_FREQ ),               // PCIe Reference Clock Frequency
    .PCIE_USERCLK1_FREQ             ( USER_CLK_FREQ ),              // PCIe Core Clock Frequency - Core Clock Freq
    .PCIE_USERCLK2_FREQ             ( USER_CLK2_FREQ )              // PCIe User Clock Frequency - User Clock Freq 
   ) 
pcie3_7x_0_support_i (

    //---------------------------------------------------------------------------------------//
    //  PCI Express (pci_exp) Interface                                                      //
    //---------------------------------------------------------------------------------------//

    // Tx
    .pci_exp_txn                                   ( pci_exp_txn ),
    .pci_exp_txp                                   ( pci_exp_txp ),

    // Rx
    .pci_exp_rxn                                   ( pci_exp_rxn ),
    .pci_exp_rxp                                   ( pci_exp_rxp ),

  //----------------------------------------------------------------------------------------------------------------//
  // Clock & GT COMMON Sharing Interface                                                                         //
  //----------------------------------------------------------------------------------------------------------------//
    .pipe_pclk_out_slave                           ( ),
    .pipe_rxusrclk_out                             ( ),
    .pipe_rxoutclk_out                             ( ),
    .pipe_dclk_out                                 ( ),
    .pipe_userclk1_out                             ( ),
    .pipe_oobclk_out                               ( ),
    .pipe_userclk2_out                             ( ),
    .pipe_mmcm_lock_out                            ( ),
    .pipe_pclk_sel_slave                           ({PL_LINK_CAP_MAX_LINK_WIDTH{1'b0}}),
    .pipe_mmcm_rst_n		     		   ( pipe_mmcm_rst_n),

    //---------------------------------------------------------------------------------------//
    //  AXI Interface                                                                        //
    //---------------------------------------------------------------------------------------//

    .user_clk                                       ( user_clk ),
    .user_reset                                     ( user_reset ),
    .user_lnk_up                                    ( user_lnk_up ),
    .user_app_rdy                                   ( ),

    .s_axis_rq_tlast                                ( s_axis_rq_tlast ),
    .s_axis_rq_tdata                                ( s_axis_rq_tdata ),
    .s_axis_rq_tuser                                ( s_axis_rq_tuser ),
    .s_axis_rq_tkeep                                ( s_axis_rq_tkeep ),
    .s_axis_rq_tready                               ( s_axis_rq_tready ),
    .s_axis_rq_tvalid                               ( s_axis_rq_tvalid ),

    .m_axis_rc_tdata                                ( m_axis_rc_tdata ),
    .m_axis_rc_tuser                                ( m_axis_rc_tuser ),
    .m_axis_rc_tlast                                ( m_axis_rc_tlast ),
    .m_axis_rc_tkeep                                ( m_axis_rc_tkeep ),
    .m_axis_rc_tvalid                               ( m_axis_rc_tvalid ),
    .m_axis_rc_tready                               ( m_axis_rc_tready[0] ),

    .m_axis_cq_tdata                                ( m_axis_cq_tdata ),
    .m_axis_cq_tuser                                ( m_axis_cq_tuser ),
    .m_axis_cq_tlast                                ( m_axis_cq_tlast ),
    .m_axis_cq_tkeep                                ( m_axis_cq_tkeep ),
    .m_axis_cq_tvalid                               ( m_axis_cq_tvalid ),
    .m_axis_cq_tready                               ( m_axis_cq_tready[0] ),

    .s_axis_cc_tdata                                ( s_axis_cc_tdata ),
    .s_axis_cc_tuser                                ( s_axis_cc_tuser ),
    .s_axis_cc_tlast                                ( s_axis_cc_tlast ),
    .s_axis_cc_tkeep                                ( s_axis_cc_tkeep ),
    .s_axis_cc_tvalid                               ( s_axis_cc_tvalid ),
    .s_axis_cc_tready                               ( s_axis_cc_tready ),

    //---------------------------------------------------------------------------------------//
    //  Configuration (CFG) Interface                                                        //
    //---------------------------------------------------------------------------------------//

    .pcie_tfc_nph_av                                ( pcie_tfc_nph_av ),
    .pcie_tfc_npd_av                                ( pcie_tfc_npd_av ),
    .pcie_rq_seq_num                                ( pcie_rq_seq_num ),
    .pcie_rq_seq_num_vld                            ( pcie_rq_seq_num_vld ),
    .pcie_rq_tag                                    ( pcie_rq_tag ),
    .pcie_rq_tag_vld                                ( pcie_rq_tag_vld ),

    .pcie_cq_np_req                                 ( pcie_cq_np_req ),
    .pcie_cq_np_req_count                           ( pcie_cq_np_req_count ),

    .cfg_phy_link_down                              ( cfg_phy_link_down ),
    .cfg_phy_link_status                            ( ),
    .cfg_negotiated_width                           ( cfg_negotiated_width ),
    .cfg_current_speed                              ( cfg_current_speed ),
    .cfg_max_payload                                ( cfg_max_payload ),
    .cfg_max_read_req                               ( cfg_max_read_req ),
    .cfg_function_status                            ( cfg_function_status ),
    .cfg_function_power_state                       ( cfg_function_power_state ),
    .cfg_vf_status                                  ( cfg_vf_status ),
    .cfg_vf_power_state                             ( cfg_vf_power_state ),
    .cfg_link_power_state                           ( cfg_link_power_state ),

    // Error Reporting Interface
    .cfg_err_cor_out                                ( cfg_err_cor_out ),
    .cfg_err_nonfatal_out                           ( cfg_err_nonfatal_out ),
    .cfg_err_fatal_out                              ( cfg_err_fatal_out ),

    .cfg_ltr_enable                                 ( cfg_ltr_enable ),
    .cfg_ltssm_state                                ( cfg_ltssm_state ),
    .cfg_rcb_status                                 ( cfg_rcb_status ),
    .cfg_dpa_substate_change                        ( cfg_dpa_substate_change ),
    .cfg_obff_enable                                ( cfg_obff_enable ),
    .cfg_pl_status_change                           ( cfg_pl_status_change ),

    .cfg_tph_requester_enable                       ( cfg_tph_requester_enable ),
    .cfg_tph_st_mode                                ( cfg_tph_st_mode ),
    .cfg_vf_tph_requester_enable                    ( cfg_vf_tph_requester_enable ),
    .cfg_vf_tph_st_mode                             ( cfg_vf_tph_st_mode ),
    // Management Interface
    .cfg_mgmt_addr                                  ( cfg_mgmt_addr ),
    .cfg_mgmt_write                                 ( cfg_mgmt_write ),
    .cfg_mgmt_write_data                            ( cfg_mgmt_write_data ),
    .cfg_mgmt_byte_enable                           ( cfg_mgmt_byte_enable ),
    .cfg_mgmt_read                                  ( cfg_mgmt_read ),
    .cfg_mgmt_read_data                             ( cfg_mgmt_read_data ),
    .cfg_mgmt_read_write_done                       ( cfg_mgmt_read_write_done ),
    .cfg_mgmt_type1_cfg_reg_access                  ( cfg_mgmt_type1_cfg_reg_access ),
    .cfg_msg_received                               ( cfg_msg_received ),
    .cfg_msg_received_data                          ( cfg_msg_received_data ),
    .cfg_msg_received_type                          ( cfg_msg_received_type ),
    .cfg_msg_transmit                               ( cfg_msg_transmit ),
    .cfg_msg_transmit_type                          ( cfg_msg_transmit_type ),
    .cfg_msg_transmit_data                          ( cfg_msg_transmit_data ),
    .cfg_msg_transmit_done                          ( cfg_msg_transmit_done ),
    .cfg_fc_ph                                      ( cfg_fc_ph ),
    .cfg_fc_pd                                      ( cfg_fc_pd ),
    .cfg_fc_nph                                     ( cfg_fc_nph ),
    .cfg_fc_npd                                     ( cfg_fc_npd ),
    .cfg_fc_cplh                                    ( cfg_fc_cplh ),
    .cfg_fc_cpld                                    ( cfg_fc_cpld ),
    .cfg_fc_sel                                     ( cfg_fc_sel ),
    .cfg_per_func_status_control                    ( cfg_per_func_status_control ),
    .cfg_per_func_status_data                       ( cfg_per_func_status_data ),

    .cfg_subsys_vend_id                             ( cfg_subsys_vend_id ),
    .cfg_config_space_enable                        ( cfg_config_space_enable ),
    .cfg_dsn                                        ( cfg_dsn ),
    .cfg_ds_bus_number                              ( cfg_ds_bus_number ),
    .cfg_ds_device_number                           ( cfg_ds_device_number ),
    .cfg_ds_function_number                         ( cfg_ds_function_number ),
    .cfg_ds_port_number                             ( cfg_ds_port_number ),
    .cfg_err_cor_in                                 ( cfg_err_cor_in ),
    .cfg_err_uncor_in                               ( cfg_err_uncor_in ),
    .cfg_flr_in_process                             ( cfg_flr_in_process ),
    .cfg_flr_done                                   ( cfg_flr_done ),
    .cfg_hot_reset_in                               ( cfg_hot_reset_in ),
    .cfg_hot_reset_out                              ( cfg_hot_reset_out ),
    .cfg_link_training_enable                       ( cfg_link_training_enable ),
    .cfg_per_function_number                        ( cfg_per_function_number ),
    .cfg_per_function_output_request                ( cfg_per_function_output_request ),
    .cfg_per_function_update_done                   ( cfg_per_function_update_done ),
    .cfg_power_state_change_interrupt               ( cfg_power_state_change_interrupt ),
    .cfg_power_state_change_ack                     ( cfg_power_state_change_ack  ),
    .cfg_req_pm_transition_l23_ready                ( cfg_req_pm_transition_l23_ready ),
    .cfg_vf_flr_in_process                          ( cfg_vf_flr_in_process ),
    .cfg_vf_flr_done                                ( cfg_vf_flr_done ),

    .cfg_ext_read_received                          ( cfg_ext_read_received ),
    .cfg_ext_write_received                         ( cfg_ext_write_received ),
    .cfg_ext_register_number                        ( cfg_ext_register_number ),
    .cfg_ext_function_number                        ( cfg_ext_function_number ),
    .cfg_ext_write_data                             ( cfg_ext_write_data ),
    .cfg_ext_write_byte_enable                      ( cfg_ext_write_byte_enable ),
    .cfg_ext_read_data                              ( cfg_ext_read_data ),
    .cfg_ext_read_data_valid                        ( cfg_ext_read_data_valid ),
    //-------------------------------------------------------------------------------//
    // EP Only                                                                       //
    //-------------------------------------------------------------------------------//

    // Interrupt Interface Signals
    .cfg_interrupt_int                              ( cfg_interrupt_int ),
    .cfg_interrupt_pending                          ( cfg_interrupt_pending ),
    .cfg_interrupt_sent                             ( cfg_interrupt_sent ),
    .cfg_interrupt_msi_enable                       ( cfg_interrupt_msi_enable ),
    .cfg_interrupt_msi_vf_enable                    ( cfg_interrupt_msi_vf_enable ),
    .cfg_interrupt_msi_mmenable                     ( cfg_interrupt_msi_mmenable ),
    .cfg_interrupt_msi_mask_update                  ( cfg_interrupt_msi_mask_update ),
    .cfg_interrupt_msi_data                         ( cfg_interrupt_msi_data ),
    .cfg_interrupt_msi_select                       ( cfg_interrupt_msi_select ),
    .cfg_interrupt_msi_int                          ( cfg_interrupt_msi_int ),
    .cfg_interrupt_msi_pending_status               ( cfg_interrupt_msi_pending_status ),
    .cfg_interrupt_msi_sent                         ( cfg_interrupt_msi_sent ),
    .cfg_interrupt_msi_fail                         ( cfg_interrupt_msi_fail ),
    .cfg_interrupt_msi_attr                         ( cfg_interrupt_msi_attr ),
    .cfg_interrupt_msi_tph_present                  ( cfg_interrupt_msi_tph_present ),
    .cfg_interrupt_msi_tph_type                     ( cfg_interrupt_msi_tph_type ),
    .cfg_interrupt_msi_tph_st_tag                   ( cfg_interrupt_msi_tph_st_tag ),
    .cfg_interrupt_msi_function_number              ( cfg_interrupt_msi_function_number ),

   //--------------------------------------------------------------------------------------//
   //  System(SYS) Interface                                                               //
   //--------------------------------------------------------------------------------------//
   .sys_clk                                        ( sys_clk ),
   .sys_reset                                      ( ~sys_rst_n_c )

  );


  //------------------------------------------------------------------------------------------------------------------//
  //       PIO Example Design Top Level                                                                               //
  //------------------------------------------------------------------------------------------------------------------//
  pcie_app_7vx #(
    .TCQ                                    ( TCQ                           ),
    .C_DATA_WIDTH                           ( C_DATA_WIDTH                   ),
    .AXISTEN_IF_RQ_ALIGNMENT_MODE           ( AXISTEN_IF_RQ_ALIGNMENT_MODE   ),
    .AXISTEN_IF_CC_ALIGNMENT_MODE           ( AXISTEN_IF_CC_ALIGNMENT_MODE   ),
    .AXISTEN_IF_CQ_ALIGNMENT_MODE           ( AXISTEN_IF_CQ_ALIGNMENT_MODE   ),
    .AXISTEN_IF_RC_ALIGNMENT_MODE           ( AXISTEN_IF_RC_ALIGNMENT_MODE   ),
    .AXISTEN_IF_ENABLE_CLIENT_TAG           ( AXISTEN_IF_ENABLE_CLIENT_TAG   ),
    .AXISTEN_IF_RQ_PARITY_CHECK             ( AXISTEN_IF_RQ_PARITY_CHECK     ),
    .AXISTEN_IF_CC_PARITY_CHECK             ( AXISTEN_IF_CC_PARITY_CHECK     ),
    .AXISTEN_IF_MC_RX_STRADDLE              ( AXISTEN_IF_MC_RX_STRADDLE      ),
    .AXISTEN_IF_ENABLE_RX_MSG_INTFC         ( AXISTEN_IF_ENABLE_RX_MSG_INTFC ),
    .AXISTEN_IF_ENABLE_MSG_ROUTE            ( AXISTEN_IF_ENABLE_MSG_ROUTE    )

  ) pcie_app_7vx_i (

    //-------------------------------------------------------------------------------------//
    //  AXI Interface                                                                      //
    //-------------------------------------------------------------------------------------//

    .s_axis_rq_tlast                                ( s_axis_rq_tlast ),
    .s_axis_rq_tdata                                ( s_axis_rq_tdata ),
    .s_axis_rq_tuser                                ( s_axis_rq_tuser ),
    .s_axis_rq_tkeep                                ( s_axis_rq_tkeep ),
    .s_axis_rq_tready                               ( s_axis_rq_tready ),
    .s_axis_rq_tvalid                               ( s_axis_rq_tvalid ),

    .m_axis_rc_tdata                                ( m_axis_rc_tdata ),
    .m_axis_rc_tuser                                ( m_axis_rc_tuser ),
    .m_axis_rc_tlast                                ( m_axis_rc_tlast ),
    .m_axis_rc_tkeep                                ( m_axis_rc_tkeep ),
    .m_axis_rc_tvalid                               ( m_axis_rc_tvalid ),
    .m_axis_rc_tready                               ( m_axis_rc_tready ),

    .m_axis_cq_tdata                                ( m_axis_cq_tdata ),
    .m_axis_cq_tuser                                ( m_axis_cq_tuser ),
    .m_axis_cq_tlast                                ( m_axis_cq_tlast ),
    .m_axis_cq_tkeep                                ( m_axis_cq_tkeep ),
    .m_axis_cq_tvalid                               ( m_axis_cq_tvalid ),
    .m_axis_cq_tready                               ( m_axis_cq_tready ),

    .s_axis_cc_tdata                                ( s_axis_cc_tdata ),
    .s_axis_cc_tuser                                ( s_axis_cc_tuser ),
    .s_axis_cc_tlast                                ( s_axis_cc_tlast ),
    .s_axis_cc_tkeep                                ( s_axis_cc_tkeep ),
    .s_axis_cc_tvalid                               ( s_axis_cc_tvalid ),
    .s_axis_cc_tready                               ( s_axis_cc_tready ),



    //--------------------------------------------------------------------------------//
    //  Configuration (CFG) Interface                                                 //
    //--------------------------------------------------------------------------------//

    .pcie_tfc_nph_av                                ( pcie_tfc_nph_av ),
    .pcie_tfc_npd_av                                ( pcie_tfc_npd_av ),

    .pcie_rq_seq_num                                ( pcie_rq_seq_num ),
    .pcie_rq_seq_num_vld                            ( pcie_rq_seq_num_vld ),
    .pcie_rq_tag                                    ( pcie_rq_tag ),
    .pcie_rq_tag_vld                                ( pcie_rq_tag_vld ),

    .pcie_cq_np_req                                 ( pcie_cq_np_req ),
    .pcie_cq_np_req_count                           ( pcie_cq_np_req_count ),

    .cfg_phy_link_down                              ( cfg_phy_link_down ),
    .cfg_negotiated_width                           ( cfg_negotiated_width ),
    .cfg_current_speed                              ( cfg_current_speed ),
    .cfg_max_payload                                ( cfg_max_payload ),
    .cfg_max_read_req                               ( cfg_max_read_req ),
    .cfg_function_status                            ( cfg_function_status ),
    .cfg_function_power_state                       ( cfg_function_power_state ),
    .cfg_vf_status                                  ( cfg_vf_status ),
    .cfg_vf_power_state                             ( cfg_vf_power_state ),
    .cfg_link_power_state                           ( cfg_link_power_state ),

    // Error Reporting Interface
    .cfg_err_cor_out                                ( cfg_err_cor_out ),
    .cfg_err_nonfatal_out                           ( cfg_err_nonfatal_out ),
    .cfg_err_fatal_out                              ( cfg_err_fatal_out ),

    .cfg_ltr_enable                                 ( cfg_ltr_enable ),
    .cfg_ltssm_state                                ( cfg_ltssm_state ),
    .cfg_rcb_status                                 ( cfg_rcb_status ),
    .cfg_dpa_substate_change                        ( cfg_dpa_substate_change ),
    .cfg_obff_enable                                ( cfg_obff_enable ),
    .cfg_pl_status_change                           ( cfg_pl_status_change ),

    .cfg_tph_requester_enable                       ( cfg_tph_requester_enable ),
    .cfg_tph_st_mode                                ( cfg_tph_st_mode ),
    .cfg_vf_tph_requester_enable                    ( cfg_vf_tph_requester_enable ),
    .cfg_vf_tph_st_mode                             ( cfg_vf_tph_st_mode ),
    // Management Interface
    .cfg_mgmt_addr                                  ( cfg_mgmt_addr ),
    .cfg_mgmt_write                                 ( cfg_mgmt_write ),
    .cfg_mgmt_write_data                            ( cfg_mgmt_write_data ),
    .cfg_mgmt_byte_enable                           ( cfg_mgmt_byte_enable ),
    .cfg_mgmt_read                                  ( cfg_mgmt_read ),
    .cfg_mgmt_read_data                             ( cfg_mgmt_read_data ),
    .cfg_mgmt_read_write_done                       ( cfg_mgmt_read_write_done ),
    .cfg_mgmt_type1_cfg_reg_access                  ( cfg_mgmt_type1_cfg_reg_access ),
    .cfg_msg_received                               ( cfg_msg_received ),
    .cfg_msg_received_data                          ( cfg_msg_received_data ),
    .cfg_msg_received_type                          ( cfg_msg_received_type ),
    .cfg_msg_transmit                               ( cfg_msg_transmit ),
    .cfg_msg_transmit_type                          ( cfg_msg_transmit_type ),
    .cfg_msg_transmit_data                          ( cfg_msg_transmit_data ),
    .cfg_msg_transmit_done                          ( cfg_msg_transmit_done ),
    .cfg_fc_ph                                      ( cfg_fc_ph ),
    .cfg_fc_pd                                      ( cfg_fc_pd ),
    .cfg_fc_nph                                     ( cfg_fc_nph ),
    .cfg_fc_npd                                     ( cfg_fc_npd ),
    .cfg_fc_cplh                                    ( cfg_fc_cplh ),
    .cfg_fc_cpld                                    ( cfg_fc_cpld ),
    .cfg_fc_sel                                     ( cfg_fc_sel ),
    .cfg_per_func_status_control                    ( cfg_per_func_status_control ),
    .cfg_per_func_status_data                       ( cfg_per_func_status_data ),
    .cfg_config_space_enable                        ( cfg_config_space_enable ),
    .cfg_dsn                                        ( cfg_dsn ),
    .cfg_ds_bus_number                              ( cfg_ds_bus_number ),
    .cfg_ds_device_number                           ( cfg_ds_device_number ),
    .cfg_ds_function_number                         ( cfg_ds_function_number ),
    .cfg_ds_port_number                             ( cfg_ds_port_number ),
    .cfg_err_cor_in                                 ( cfg_err_cor_in ),
    .cfg_err_uncor_in                               ( cfg_err_uncor_in ),
    .cfg_flr_in_process                             ( cfg_flr_in_process ),
    .cfg_flr_done                                   ( cfg_flr_done ),
    .cfg_hot_reset_in                               ( cfg_hot_reset_in ),
    .cfg_hot_reset_out                              ( cfg_hot_reset_out ),
    .cfg_link_training_enable                       ( cfg_link_training_enable ),
    .cfg_per_function_number                        ( cfg_per_function_number ),
    .cfg_per_function_output_request                ( cfg_per_function_output_request ),
    .cfg_per_function_update_done                   ( cfg_per_function_update_done ),
    .cfg_power_state_change_interrupt               ( cfg_power_state_change_interrupt ),
    .cfg_req_pm_transition_l23_ready                ( cfg_req_pm_transition_l23_ready ),
    .cfg_vf_flr_in_process                          ( cfg_vf_flr_in_process ),
    .cfg_vf_flr_done                                ( cfg_vf_flr_done ),
    .cfg_power_state_change_ack                     ( cfg_power_state_change_ack ),
    .cfg_ext_read_received                          ( cfg_ext_read_received ),
    .cfg_ext_write_received                         ( cfg_ext_write_received ),
    .cfg_ext_register_number                        ( cfg_ext_register_number ),
    .cfg_ext_function_number                        ( cfg_ext_function_number ),
    .cfg_ext_write_data                             ( cfg_ext_write_data ),
    .cfg_ext_write_byte_enable                      ( cfg_ext_write_byte_enable ),
    .cfg_ext_read_data                              ( cfg_ext_read_data ),
    .cfg_ext_read_data_valid                        ( cfg_ext_read_data_valid ),


    //-------------------------------------------------------------------------------------//
    // EP Only                                                                             //
    //-------------------------------------------------------------------------------------//

    // Interrupt Interface Signals
    .cfg_interrupt_int                              ( cfg_interrupt_int ),
    .cfg_interrupt_pending                          ( cfg_interrupt_pending ),
    .cfg_interrupt_sent                             ( cfg_interrupt_sent ),
    .cfg_interrupt_msi_enable                       ( cfg_interrupt_msi_enable ),
    .cfg_interrupt_msi_vf_enable                    ( cfg_interrupt_msi_vf_enable ),
    .cfg_interrupt_msi_mmenable                     ( cfg_interrupt_msi_mmenable ),
    .cfg_interrupt_msi_mask_update                  ( cfg_interrupt_msi_mask_update ),
    .cfg_interrupt_msi_data                         ( cfg_interrupt_msi_data ),
    .cfg_interrupt_msi_select                       ( cfg_interrupt_msi_select ),
    .cfg_interrupt_msi_int                          ( cfg_interrupt_msi_int ),
    .cfg_interrupt_msi_pending_status               ( cfg_interrupt_msi_pending_status ),
    .cfg_interrupt_msi_sent                         ( cfg_interrupt_msi_sent ),
    .cfg_interrupt_msi_fail                         ( cfg_interrupt_msi_fail ),
    .cfg_interrupt_msi_attr                         ( cfg_interrupt_msi_attr ),
    .cfg_interrupt_msi_tph_present                  ( cfg_interrupt_msi_tph_present ),
    .cfg_interrupt_msi_tph_type                     ( cfg_interrupt_msi_tph_type ),
    .cfg_interrupt_msi_tph_st_tag                   ( cfg_interrupt_msi_tph_st_tag ),
    .cfg_interrupt_msi_function_number              ( cfg_interrupt_msi_function_number ),


    .user_clk                                       ( user_clk ),
    .user_reset                                     ( user_reset ),
    .user_lnk_up                                    ( user_lnk_up ),

	.dipsw(dipsw),
	.led(led)
  );









































// -------------------
// -- Local Signals --
// -------------------
  
// Ethernet related signal declarations
wire		xphyrefclk_i;
wire		xgemac_clk_156;
wire		dclk_i;
wire		clk156_25; 
wire		xphy_gt0_tx_resetdone;
wire		xphy_gt1_tx_resetdone;
wire		xphy_gt2_tx_resetdone;
wire		xphy_gt3_tx_resetdone;
wire		xphy_tx_fault;
   
wire [63:0]	xgmii_txd_0, xgmii_txd_1, xgmii_txd_2, xgmii_txd_3;
wire [7:0]	xgmii_txc_0, xgmii_txc_1, xgmii_txc_2, xgmii_txc_3;
wire [63:0]	xgmii_rxd_0, xgmii_rxd_1, xgmii_rxd_2, xgmii_rxd_3;
wire [7:0]	xgmii_rxc_0, xgmii_rxc_1, xgmii_rxc_2, xgmii_rxc_3;

wire [3:0]	xphy_tx_disable;
wire		xphy_gt_txclk322;
wire		xphy_gt_txusrclk;
wire		xphy_gt_txusrclk2;
wire		xphy_gt_qplllock;
wire		xphy_gt_qplloutclk;
wire		xphy_gt_qplloutrefclk;
wire		xphy_gt_txuserrdy;
wire		xphy_areset_clk_156_25;
wire		xphy_reset_counter_done;
wire		xphy_gttxreset;
wire		xphy_gtrxreset;


wire [4:0]	xphy0_prtad;
wire		xphy0_signal_detect;
wire [7:0]	xphy0_status;

wire [4:0]	xphy1_prtad;
wire		xphy1_signal_detect;
wire [7:0]	xphy1_status;

wire [4:0]	xphy2_prtad;
wire		xphy2_signal_detect;
wire [7:0]	xphy2_status;

wire [4:0]	xphy3_prtad;
wire		xphy3_signal_detect;
wire [7:0]	xphy3_status;

// ---------------
// Clock and Reset
// ---------------

//- Clocking
wire [11:0]	device_temp;
wire		clk50;
reg [1:0]	clk_divide = 2'b00;


always @(posedge clk200)
	clk_divide  <= clk_divide + 1'b1;

BUFG buffer_clk50 (
	.I    (clk_divide[1]),
	.O    (clk50	)
);

`ifdef USE_SI5324
//-SI 5324 programming
clock_control cc_inst (
	.i2c_clk(i2c_clk),
	.i2c_data(i2c_data),
	.i2c_mux_rst_n(i2c_mux_rst_n),
	.si5324_rst_n(si5324_rst_n),
	.rst(sys_rst),
	.clk50(clk50)
);
`endif
wire clksi570;
IBUFDS IBUFDS_0 (
	.I(si570_refclk_p),
	.IB(si570_refclk_n),
	.O(clksi570)
);
OBUFDS OBUFDS_0 (
	.I(clksi570),
	.O(user_sma_clock_p),
	.OB(user_sma_clock_n)
);

 
`ifdef SIMULATION
// Deliberately not driving to default value or assigning a value
// It will be driven by the simulation testbench by dot reference
wire sim_speedup_control;
`else
wire sim_speedup_control = 1'b0;
`endif
 
//- Network Path instance #0
assign xphy0_prtad = 5'd0;
assign xphy0_signal_detect  = 1'b1;
assign xphy_tx_fault = 1'b0;

network_path_shared network_path_inst_0 (
`ifdef USE_SI5324
	.xphy_refclk_p(xphy_refclk_clk_p),
	.xphy_refclk_n(xphy_refclk_clk_n),
`else
	.xphy_refclk_p(sma_mgt_refclk_p),
	.xphy_refclk_n(sma_mgt_refclk_n),
`endif
	.xphy_txp(xphy0_txp),
	.xphy_txn(xphy0_txn),
	.xphy_rxp(xphy0_rxp),
	.xphy_rxn(xphy0_rxn),
	.txusrclk(xphy_gt_txusrclk),
	.txusrclk2(xphy_gt_txusrclk2),
	.tx_resetdone(xphy_gt0_tx_resetdone),
	.xgmii_txd(xgmii_txd_0),
	.xgmii_txc(xgmii_txc_0),
	.xgmii_rxd(xgmii_rxd_0),
	.xgmii_rxc(xgmii_rxc_0),
	.areset_clk156(xphy_areset_clk_156_25),
	.gttxreset(xphy_gttxreset),
	.gtrxreset(xphy_gtrxreset),
	.txuserrdy(xphy_gt_txuserrdy),
	.qplllock(xphy_gt_qplllock),
	.qplloutclk(xphy_gt_qplloutclk),
	.qplloutrefclk(xphy_gt_qplloutrefclk),
	.reset_counter_done(xphy_reset_counter_done),
	.dclk(xgemac_clk_156),  
	.xphy_status(xphy0_status),
	.xphy_tx_disable(xphy_tx_disable[0]),
	.signal_detect(xphy0_signal_detect),
	.tx_fault(xphy_tx_fault), 
	.prtad(xphy0_prtad),
	.clk156(xgemac_clk_156),
	.sys_rst(sys_rst),
	.sim_speedup_control(sim_speedup_control)
); 

`ifdef ENABLE_XGMII1
//- Network Path instance #1
assign xphy1_prtad = 5'd1;
assign xphy1_signal_detect = 1'b1;

network_path network_path_inst_1 (
	.xphy_txp(xphy1_txp),
	.xphy_txn(xphy1_txn),
	.xphy_rxp(xphy1_rxp),
	.xphy_rxn(xphy1_rxn),
	.txusrclk(xphy_gt_txusrclk),
	.txusrclk2(xphy_gt_txusrclk2),
	.tx_resetdone(xphy_gt1_tx_resetdone),
	.xgmii_txd(xgmii_txd_1),
	.xgmii_txc(xgmii_txc_1),
	.xgmii_rxd(xgmii_rxd_1),
	.xgmii_rxc(xgmii_rxc_1),
	.areset_clk156(xphy_areset_clk_156_25),
	.gttxreset(xphy_gttxreset),
	.gtrxreset(xphy_gtrxreset),
	.txuserrdy(xphy_gt_txuserrdy),
	.qplllock(xphy_gt_qplllock),
	.qplloutclk(xphy_gt_qplloutclk),
	.qplloutrefclk(xphy_gt_qplloutrefclk),
	.reset_counter_done(xphy_reset_counter_done),
	.dclk(xgemac_clk_156),  
	.xphy_status(xphy1_status),
	.xphy_tx_disable(xphy_tx_disable[1]),
	.signal_detect(xphy1_signal_detect),
	.tx_fault(xphy_tx_fault), 
	.prtad(xphy1_prtad),
	.clk156(xgemac_clk_156),
	.sys_rst(sys_rst),
	.sim_speedup_control(sim_speedup_control)
  ); 
`endif

`ifdef ENABLE_XGMII2
//- Network Path instance #2
assign xphy2_prtad = 5'd2;
assign xphy2_signal_detect = 1'b1;

network_path network_path_inst_2 (
	.xphy_txp(xphy2_txp),
	.xphy_txn(xphy2_txn),
	.xphy_rxp(xphy2_rxp),
	.xphy_rxn(xphy2_rxn),
	.txusrclk(xphy_gt_txusrclk),
	.txusrclk2(xphy_gt_txusrclk2),
	.tx_resetdone(xphy_gt2_tx_resetdone),
	.xgmii_txd(xgmii_txd_2),
	.xgmii_txc(xgmii_txc_2),
	.xgmii_rxd(xgmii_rxd_2),
	.xgmii_rxc(xgmii_rxc_2),
	.areset_clk156(xphy_areset_clk_156_25),
	.gttxreset(xphy_gttxreset),
	.gtrxreset(xphy_gtrxreset),
	.txuserrdy(xphy_gt_txuserrdy),
	.qplllock(xphy_gt_qplllock),
	.qplloutclk(xphy_gt_qplloutclk),
	.qplloutrefclk(xphy_gt_qplloutrefclk),
	.reset_counter_done(xphy_reset_counter_done),
	.dclk(xgemac_clk_156),  
	.xphy_status(xphy2_status),
	.xphy_tx_disable(xphy_tx_disable[2]),
	.signal_detect(xphy2_signal_detect),
	.tx_fault(xphy_tx_fault), 
	.prtad(xphy2_prtad),
	.clk156(xgemac_clk_156),
	.sys_rst(sys_rst),
	.sim_speedup_control(sim_speedup_control)
  ); 
`endif

`ifdef ENABLE_XGMII3
//- Network Path instance #3
assign xphy3_prtad = 5'd3;
assign xphy3_signal_detect = 1'b1;

network_path network_path_inst_3 (
	.xphy_txp(xphy3_txp),
	.xphy_txn(xphy3_txn),
	.xphy_rxp(xphy3_rxp),
	.xphy_rxn(xphy3_rxn),
	.txusrclk(xphy_gt_txusrclk),
	.txusrclk2(xphy_gt_txusrclk2),
	.tx_resetdone(xphy_gt3_tx_resetdone),
	.xgmii_txd(xgmii_txd_3),
	.xgmii_txc(xgmii_txc_3),
	.xgmii_rxd(xgmii_rxd_3),
	.xgmii_rxc(xgmii_rxc_3),
	.areset_clk156(xphy_areset_clk_156_25),
	.gttxreset(xphy_gttxreset),
	.gtrxreset(xphy_gtrxreset),
	.txuserrdy(xphy_gt_txuserrdy),
	.qplllock(xphy_gt_qplllock),
	.qplloutclk(xphy_gt_qplloutclk),
	.qplloutrefclk(xphy_gt_qplloutrefclk),
	.reset_counter_done(xphy_reset_counter_done),
	.dclk(xgemac_clk_156),  
	.xphy_status(xphy3_status),
	.xphy_tx_disable(xphy_tx_disable[3]),
	.signal_detect(xphy3_signal_detect),
	.tx_fault(xphy_tx_fault), 
	.prtad(xphy3_prtad),
	.clk156(xgemac_clk_156),
	.sys_rst(sys_rst),
	.sim_speedup_control(sim_speedup_control)
); 
`endif

// ----------------------
// -- User Application --
// ----------------------

wire [63:0] xgmii_txd;
wire [7:0] xgmii_txc;
app app_inst (
	.sys_rst(sys_rst),
	// XGMII interface
	.xgmii_clk(xgemac_clk_156),
	.xgmii_txd(xgmii_txd),
	.xgmii_txc(xgmii_txc),
	.xgmii_rxd(xgmii_rxd_0),
	.xgmii_rxc(xgmii_rxc_0),
	.xphy_status(xphy0_status),
	// BUTTON
	.button_n(button_n),
	.button_s(button_s),
	.button_w(button_w),
	.button_e(button_e),
	.button_c(button_c),
	// DIP SW
	.dipsw(dipsw),
	// Diagnostic LEDs
	.led() //led)
);

// Combined 10GBASE-R quad link status
//assign led[7:0] = {4'b000, xphy3_status[0], xphy2_status[0], xphy1_status[0], xphy0_status[0]};

//- Disable Laser when unconnected on SFP+
assign sfp_tx_disable = 4'b0000;

assign xgmii_txc_0 = xgmii_txc;
assign xgmii_txd_0 = xgmii_txd;
`ifdef ENABLE_XGMII1
assign xgmii_txc_1 = xgmii_txc;
assign xgmii_txd_1 = xgmii_txd;
`endif
`ifdef ENABLE_XGMII2
assign xgmii_txc_2 = xgmii_txc;
assign xgmii_txd_2 = xgmii_txd;
`endif
`ifdef ENABLE_XGMII3
assign xgmii_txc_3 = xgmii_txc;
assign xgmii_txd_3 = xgmii_txd;
`endif

endmodule
`default_nettype wire
