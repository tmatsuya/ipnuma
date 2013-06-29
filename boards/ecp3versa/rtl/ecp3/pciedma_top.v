`default_nettype none
module top (
	input rstn,
	input FLIP_LANES,
	input refclkp,
	input refclkn,
	input hdinp,
	input hdinn,
	output hdoutp,
	output hdoutn,
	input [7:0] dip_switch,
	output [7:0] led,
	output reg [13:0] led_out,
	output dp,
	input reset_n
);

reg  [20:0] rstn_cnt;
reg  sys_rst_n;
wire sys_rst = ~sys_rst_n;
wire [15:0] rx_data, tx_data;
wire [6:0] rx_bar_hit;
wire [7:0] pd_num;
wire ph_cr, pd_cr, nph_cr, npd_cr;
wire [7:0] bus_num ;
wire [4:0] dev_num ;
wire [2:0] func_num ;

wire rx_st, rx_end;
wire rx_us_req, rx_malf_tlp ;
wire tx_req, tx_rdy, tx_st, tx_end;

wire [8:0] tx_ca_ph ;
wire [12:0] tx_ca_pd  ;
wire [8:0] tx_ca_nph ;
wire [12:0] tx_ca_npd ;
wire [8:0] tx_ca_cplh;
wire [12:0] tx_ca_cpld ;
wire tx_ca_p_recheck ;
wire tx_ca_cpl_recheck ;
wire clk_125;
// Reset management
always @(posedge clk_125 or negedge rstn) begin
	if (!rstn) begin
		rstn_cnt <= 21'd0 ;
		sys_rst_n <= 1'b0 ;
	end else begin
		if (rstn_cnt[20])		// 4ms in real hardware
			sys_rst_n <= 1'b1 ;
		else
			rstn_cnt <= rstn_cnt + 1'b1 ;
	end
end

pcie_top pcie(
	.refclkp			( refclkp ),
	.refclkn			( refclkn ),
	.sys_clk_125			( clk_125 ),
	.ext_reset_n			( rstn ),
	.rstn				( sys_rst_n ),
	.flip_lanes			( FLIP_LANES ),
	.hdinp0				( hdinp ),
	.hdinn0				( hdinn ),
	.hdoutp0			( hdoutp ),
	.hdoutn0			( hdoutn ),
	.msi				( 8'd0 ),
	.inta_n				( 1'b1 ),
	// This PCIe interface uses dynamic IDs.
	.vendor_id			(16'h3776),
	.device_id			(16'h8010),
	.rev_id				(8'h00),
	.class_code			(24'h000000),
	.subsys_ven_id			(16'h3776),
	.subsys_id			(16'h8010),
	.load_id			(1'b1),
	// Inputs
	.force_lsm_active		( 1'b0 ),
	.force_rec_ei			( 1'b0 ),
	.force_phy_status		( 1'b0 ),
	.force_disable_scr		( 1'b0 ),
	.hl_snd_beacon			( 1'b0 ),
	.hl_disable_scr			( 1'b0 ),
	.hl_gto_dis			( 1'b0 ),
	.hl_gto_det			( 1'b0 ),
	.hl_gto_hrst			( 1'b0 ),
	.hl_gto_l0stx			( 1'b0 ),
	.hl_gto_l1			( 1'b0 ),
	.hl_gto_l2			( 1'b0 ),
	.hl_gto_l0stxfts		( 1'b0 ),
	.hl_gto_lbk			( 1'd0 ),
	.hl_gto_rcvry			( 1'b0 ),
	.hl_gto_cfg			( 1'b0 ),
	.no_pcie_train			( 1'b0 ),
	// Power Management Interface
	.tx_dllp_val			( 2'd0 ),
	.tx_pmtype			( 3'd0 ),
	.tx_vsd_data			( 24'd0 ),
	.tx_req_vc0			( tx_req ),
	.tx_data_vc0			( tx_data ),
	.tx_st_vc0			( tx_st ),
	.tx_end_vc0			( tx_end ),
	.tx_nlfy_vc0			( 1'b0 ),
	.ph_buf_status_vc0		( 1'b0 ),
	.pd_buf_status_vc0		( 1'b0 ),
	.nph_buf_status_vc0		( 1'b0 ),
	.npd_buf_status_vc0		( 1'b0 ),
	.ph_processed_vc0		( ph_cr ),
	.pd_processed_vc0		( pd_cr ),
	.nph_processed_vc0		( nph_cr ),
	.npd_processed_vc0		( npd_cr ),
	.pd_num_vc0			( pd_num ),
	.npd_num_vc0			( 8'd1 ),
	// From User logic
	.cmpln_tout			( 1'b0 ),
	.cmpltr_abort_np		( 1'b0 ),
	.cmpltr_abort_p			( 1'b0 ),
	.unexp_cmpln			( 1'b0 ),
	.ur_np_ext			( 1'b0 ),
	.ur_p_ext			( 1'b0 ),
	.np_req_pend			( 1'b0 ),
	.pme_status			( 1'b0 ),
	.tx_rdy_vc0			( tx_rdy ),
	.tx_ca_ph_vc0			( tx_ca_ph ),
	.tx_ca_pd_vc0			( tx_ca_pd ),
	.tx_ca_nph_vc0			( tx_ca_nph ),
	.tx_ca_npd_vc0			( tx_ca_npd ),
	.tx_ca_cplh_vc0			( tx_ca_cplh ),
	.tx_ca_cpld_vc0			( tx_ca_cpld ),
	.tx_ca_p_recheck_vc0		( tx_ca_p_recheck ),
	.tx_ca_cpl_recheck_vc0		( tx_ca_cpl_recheck ),
	.rx_data_vc0			( rx_data ),
	.rx_st_vc0			( rx_st ) ,
	.rx_end_vc0			( rx_end ),
	.rx_us_req_vc0			( rx_us_req ),
	.rx_malf_tlp_vc0		( rx_malf_tlp ),
	.rx_bar_hit			( rx_bar_hit ),
	// From Config Registers
	.bus_num			( bus_num ),
	.dev_num			( dev_num ),
	.func_num			( func_num )
);

wire [6:0] slv_bar_i;
wire slv_ce_i;
wire slv_we_i;
wire [19:1] slv_adr_i;
wire [15:0] slv_dat_i;
wire [1:0] slv_sel_i;
wire [15:0] slv_dat_o, slv_dat1_o, slv_dat2_o;
reg [15:0] slv_dat0_o;

pcie_tlp inst_pcie_tlp (
	// System
	.pcie_clk(clk_125),
	.sys_rst(sys_rst),
	// Management
	.rx_bar_hit(rx_bar_hit),
	.bus_num(bus_num),
	.dev_num(dev_num),
	.func_num(func_num),
	// Receive
	.rx_st(rx_st),
	.rx_end(rx_end),
	.rx_data(rx_data),
	// Transmit
	.tx_req(tx_req),
	.tx_rdy(tx_rdy),
	.tx_st(tx_st),
	.tx_end(tx_end),
	.tx_data(tx_data),
	//Receive credits
	.pd_num(pd_num),
	.ph_cr(ph_cr),
	.pd_cr(pd_cr),
	.nph_cr(nph_cr),
	.npd_cr(npd_cr),
	// Slave bus
	.slv_bar_i(slv_bar_i),
	.slv_ce_i(slv_ce_i),
	.slv_we_i(slv_we_i),
	.slv_adr_i(slv_adr_i),
	.slv_dat_i(slv_dat_i),
	.slv_sel_i(slv_sel_i),
	.slv_dat_o(slv_dat_o),
	// LED and Switches
	.dipsw(dip_switch),
	.led(led),
	.segled(),
	.btn(reset_n)
);

always @(posedge clk_125) begin
	if (sys_rst == 1'b1) begin
		slv_dat0_o <= 16'h0;
	end else begin
		if (slv_bar_i[0] == 1'b1) begin
			case (slv_adr_i[9:1])
				9'h000: begin
					if (slv_we_i) begin
						if (slv_sel_i[0])
							led_out[7:0] <= slv_dat_i[7:0];
						if (slv_sel_i[1])
							led_out[13:8] <= slv_dat_i[13:8];
					end else
						slv_dat0_o <= {2'b0, led_out[13:0]};
				end
				default: begin
					slv_dat0_o <= 16'h0;
				end
			endcase
		end
	end
end

ram_dq ram_dq_inst1 (
	.Clock(clk_125),
	.ClockEn(slv_ce_i & slv_bar_i[2]),
	.Reset(sys_rst),
	.ByteEn(slv_sel_i),
	.WE(slv_we_i),
	.Address(slv_adr_i[14:1]),
	.Data(slv_dat_i),
	.Q(slv_dat1_o)
);

ram_dq ram_dq_inst2 (
	.Clock(clk_125),
	.ClockEn(slv_ce_i & slv_bar_i[4]),
	.Reset(sys_rst),
	.ByteEn(slv_sel_i),
	.WE(slv_we_i),
	.Address(slv_adr_i[14:1]),
	.Data(slv_dat_i),
	.Q(slv_dat2_o)
);

assign slv_dat_o = ( {16{slv_bar_i[0]}} & slv_dat0_o ) | ( {16{slv_bar_i[2]}} & slv_dat1_o ) | ( {16{slv_bar_i[4]}} & slv_dat2_o ) ; 

endmodule
`default_nettype wire
